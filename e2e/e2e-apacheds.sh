#!/usr/bin/env bash
# E2E test for the Apache DS (AD-mimic) image (apacheds-ad/Dockerfile) — the
# alternative LDAP backend that fakes Microsoft Active Directory. Runs the
# container with the seed LDIF mounted, waits for it to serve LDAP, then asserts
# it serves the AD-schema directory over the wire.
#
# What it asserts: the container becomes healthy and LDAP is reachable, an
# authenticated bind as the broker service account can read the directory, the
# Microsoft sAMAccountName schema is served (uid=admin carries sAMAccountName),
# and the seed loaded a non-trivial number of entries.
#
# The apacheds image is JRE-only (no ldapsearch), so the LDAP client runs in a
# throwaway alpine + openldap-clients container sharing the apacheds container's
# network namespace (so it reaches the server on 127.0.0.1).
#
# Assumes the image (APACHEDS_IMAGE:APACHEDS_VER) is already built —
# `make e2e-apacheds` builds it first.
set -euo pipefail

# Load committed defaults, then optional local overrides.
# shellcheck source=/dev/null
if [ -f .env.example ]; then set -a; . ./.env.example; set +a; fi
# shellcheck source=/dev/null
if [ -f .env         ]; then set -a; . ./.env;         set +a; fi

APACHEDS_IMAGE="${APACHEDS_IMAGE:-apacheds-ad}"
APACHEDS_VER="${APACHEDS_VER:-latest}"
# Prefer the fully-resolved ref the Makefile passes (carries DOCKER_LOGIN when
# set, matching what build-apacheds tagged); else fall back to bare name:tag.
APACHEDS_IMAGE_REF="${APACHEDS_IMAGE_REF:-${APACHEDS_IMAGE}:${APACHEDS_VER}}"
APACHEDS_CONTAINER="${APACHEDS_CONTAINER:-apacheds-e2e}"
LDAP_PORT="${APACHEDS_PORT:-10389}"
# Bind account + search base for the AD seed. The partition is rooted at
# ou=ActiveMQ (no dc=activemq root entry); anonymous bind is disabled.
BIND_DN="${APACHEDS_BIND_DN:-cn=mqbroker,ou=Services,ou=ActiveMQ,dc=activemq,dc=apache,dc=org}"
BIND_PW="${APACHEDS_BIND_PW:-admin}"
SEARCH_BASE="${APACHEDS_SEARCH_BASE:-ou=ActiveMQ,dc=activemq,dc=apache,dc=org}"
CLIENT_IMAGE="${LDAP_CLIENT_IMAGE:-alpine:3}"
READY_TIMEOUT="${E2E_READY_TIMEOUT_SECONDS:-120}"
POLL="${E2E_POLL_INTERVAL_SECONDS:-2}"
SEED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../apacheds-ad/ldif" && pwd)"

PASS=0; FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

cleanup() { docker rm -f "$APACHEDS_CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# ldapsearch from a throwaway client sharing the server's network namespace.
ldap_query() { # filter attrs... -> LLL output (rc ignored; assert on output)
  local filter="$1"; shift
  docker run --rm --network "container:${APACHEDS_CONTAINER}" "$CLIENT_IMAGE" \
    sh -c "apk add --no-cache openldap-clients >/dev/null 2>&1 && \
      ldapsearch -LLL -x -H ldap://127.0.0.1:${LDAP_PORT} \
        -D '${BIND_DN}' -w '${BIND_PW}' \
        -b '${SEARCH_BASE}' -s sub '${filter}' $*" 2>&1 || true
}

echo "=== E2E: Apache DS (AD-mimic) LDAP backend ==="
cleanup   # drop any stale container from a previous run

echo "== start the directory with the AD seed mounted =="
docker run -d --name "$APACHEDS_CONTAINER" \
  -v "${SEED_DIR}:/ldap/ldif:ro" \
  "${APACHEDS_IMAGE_REF}" >/dev/null

echo "== wait for the directory to become healthy / serve LDAP =="
ready=
for _ in $(seq 1 $(( READY_TIMEOUT / POLL ))); do
  if ! docker ps --filter "name=^${APACHEDS_CONTAINER}$" --filter status=running -q | grep -q .; then
    echo "  [container exited during startup]"; break
  fi
  if docker logs "$APACHEDS_CONTAINER" 2>&1 | grep -qi 'LDAP server started'; then ready=1; break; fi
  sleep "$POLL"
done
if [ -n "$ready" ]; then
  pass "directory started and LDAP is serving on :${LDAP_PORT}"
else
  fail "directory did not start serving LDAP within ${READY_TIMEOUT}s"
  echo "--- last 25 log lines ---"; docker logs "$APACHEDS_CONTAINER" 2>&1 | tail -25
  echo ""; echo "=== Results: ${PASS} passed, ${FAIL} failed ==="; exit 1
fi

echo "== authenticated bind + AD schema served (sAMAccountName) =="
adseed="$(ldap_query '(sAMAccountName=admin)' dn sAMAccountName)"
if printf '%s' "$adseed" | grep -qiE '^dn: uid=admin,ou=User,'; then
  pass "authenticated search (mqbroker bind) returned uid=admin"
else
  fail "authenticated search did not return uid=admin (got: $(printf '%s' "$adseed" | head -1))"
fi
if printf '%s' "$adseed" | grep -qiE '^sAMAccountName: admin'; then
  pass "Microsoft AD schema served (uid=admin carries sAMAccountName)"
else
  fail "sAMAccountName attribute not served on uid=admin (AD schema not loaded)"
fi

echo "== seed loaded (non-trivial entry count) =="
count="$(ldap_query '(objectClass=*)' dn | grep -c '^dn: ' || true)"
if [ "${count:-0}" -ge 10 ]; then
  pass "directory served ${count} entries under ${SEARCH_BASE}"
else
  fail "directory served only ${count} entries (expected the full seed)"
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ]
