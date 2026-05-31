#!/usr/bin/env bash
# E2E smoke test for the OpenLDAP + ActiveMQ stack. Asserts the LDAP-backed
# authentication / authorization contract against an ALREADY-RUNNING stack
# (use `make e2e` to bring it up, run this, and tear it down).
#
# What it asserts: the broker boots, config templating resolved from env,
# authentication rejects invalid credentials, the LDAP-backed authorization
# matrix is enforced (admin may write admin+user destinations; user may write
# user destinations but is DENIED admin destinations), and the LDAP seed is
# present.
#
# Readiness note: the cachedLDAPAuthorizationMap is cold immediately after
# startup (OpenLDAP may still be importing the LDIF, and the map populates on
# first refresh), during which EVERY producer is denied on the advisory topic.
# The harness polls until admin can produce (cache warm) before asserting the
# matrix. `make e2e` sets a short LDAP_REFRESH_INTERVAL so warm-up is fast.
set -euo pipefail

# Load committed defaults, then optional local overrides.
# shellcheck source=/dev/null
if [ -f .env.example ]; then set -a; . ./.env.example; set +a; fi
# shellcheck source=/dev/null
if [ -f .env         ]; then set -a; . ./.env;         set +a; fi

ACTIVEMQ_VER="${ACTIVEMQ_VER:-5.19.6}"
ACTIVEMQ_CONTAINER="${ACTIVEMQ_CONTAINER:-activemq}"
OPENLDAP_CONTAINER="${OPENLDAP_CONTAINER:-openldap}"
CONSOLE_HOST="${ACTIVEMQ_CONSOLE_HOST:-localhost}"
CONSOLE_PORT="${ACTIVEMQ_CONSOLE_PORT:-8161}"
ADMIN_USER="${LDAP_ADMIN_USER:-admin}"
ADMIN_PW="${LDAP_ADMIN_PASSWORD:-admin}"
DEMO_USER="${DEMO_USER:-user}"
DEMO_PW="${DEMO_USER_PASSWORD:-admin}"
LDAP_BASE="${LDAP_BASE_DN:-dc=activemq,dc=apache,dc=org}"
LDAP_PORT="${LDAP_PORT:-389}"
READY_TIMEOUT="${E2E_READY_TIMEOUT_SECONDS:-120}"
POLL="${E2E_POLL_INTERVAL_SECONDS:-2}"
AMQ_BIN="/opt/apache-activemq-${ACTIVEMQ_VER}/bin/activemq"
CONF_DIR="/opt/apache-activemq-${ACTIVEMQ_VER}/conf"

PASS=0; FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

amq_produce() { # user password destination -> combined stdout+stderr (rc ignored; assert on output)
  docker exec "$ACTIVEMQ_CONTAINER" "$AMQ_BIN" producer \
    --user "$1" --password "$2" --destination "$3" \
    --message hello --messageCount 1 2>&1 || true
}

echo "=== E2E: ActiveMQ LDAP auth contract ==="

echo "== broker readiness =="
# The console is secured (Jetty JAAS), so it answers 401 to an unauthenticated
# request — that 401 IS the "broker up" signal. Accept any HTTP status code;
# `curl -sf` would wrongly treat 401 as failure and loop until timeout.
ready=
for _ in $(seq 1 $(( READY_TIMEOUT / POLL ))); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://${CONSOLE_HOST}:${CONSOLE_PORT}/admin/" 2>/dev/null || true)"
  if [ -n "$code" ] && [ "$code" != "000" ]; then ready=1; break; fi
  sleep "$POLL"
done
if [ -n "$ready" ]; then
  pass "broker web console responding on :${CONSOLE_PORT} (HTTP ${code})"
else
  fail "broker console not reachable within ${READY_TIMEOUT}s"
fi

echo "== config templating resolved (no leftover placeholders) =="
for f in activemq.xml login.config; do
  if docker exec "$ACTIVEMQ_CONTAINER" grep -q '#####' "${CONF_DIR}/${f}" 2>/dev/null; then
    fail "${f} still contains unresolved '##### ... #####' placeholders"
  else
    pass "${f} templating fully resolved from env"
  fi
done

echo "== authentication: invalid credentials rejected =="
if amq_produce "$ADMIN_USER" "WRONG_${RANDOM}" "queue://TEST" | grep -qi 'password is invalid'; then
  pass "bad password rejected (JMSSecurityException: password invalid)"
else
  fail "bad password was NOT rejected as expected"
fi

echo "== wait for LDAP authorization cache to warm =="
# Cold cache (or still-seeding LDAP) denies every producer on the advisory
# topic; poll admin->TEST until it actually produces before asserting.
authz_ready=
for _ in $(seq 1 $(( READY_TIMEOUT / POLL ))); do
  if amq_produce "$ADMIN_USER" "$ADMIN_PW" "queue://TEST" | grep -qi 'Produced: 1 messages'; then
    authz_ready=1; break
  fi
  sleep "$POLL"
done
if [ -n "$authz_ready" ]; then
  pass "authorization cache warm (admin produced to queue://TEST)"
else
  fail "authorization cache not warm within ${READY_TIMEOUT}s"
fi

echo "== authorization matrix =="
if amq_produce "$ADMIN_USER" "$ADMIN_PW" "queue://ADMINS.TEST" | grep -qi 'Produced: 1 messages'; then
  pass "admin ALLOWED to write queue://ADMINS.TEST"
else
  fail "admin unexpectedly denied queue://ADMINS.TEST"
fi
if amq_produce "$DEMO_USER" "$DEMO_PW" "queue://USERS.TEST" | grep -qi 'Produced: 1 messages'; then
  pass "user ALLOWED to write queue://USERS.TEST"
else
  fail "user unexpectedly denied queue://USERS.TEST"
fi
if amq_produce "$DEMO_USER" "$DEMO_PW" "queue://ADMINS.TEST" | grep -qi 'not authorized to write to'; then
  pass "user DENIED write to queue://ADMINS.TEST (authz enforced)"
else
  fail "user was NOT denied queue://ADMINS.TEST — authorization not enforced!"
fi

echo "== LDAP seed present =="
seed="$(docker exec "$OPENLDAP_CONTAINER" ldapsearch -x -H "ldap://localhost:${LDAP_PORT}" \
  -b "$LDAP_BASE" -D "cn=admin,${LDAP_BASE}" -w "$ADMIN_PW" 2>/dev/null || true)"
assert_seed() { if printf '%s' "$seed" | grep -qiE -- "$2"; then pass "$1"; else fail "$1"; fi; }
assert_seed "LDAP seed has uid=admin"                   'uid=admin'
assert_seed "LDAP seed has uid=user"                    'uid=user'
assert_seed "LDAP seed has admins group"                'cn=admins'
assert_seed "an LDAP group lists uid=user as a member"  'member:.*uid=user'

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ]
