#!/bin/sh
# Provision a Symas OpenLDAP directory on first start, then run slapd in the
# foreground. Idempotent: if the database already exists, it just starts slapd.
#
# The classic slapd.conf format is used deliberately — it is the simplest
# robust way to provision a fixed demo directory (schema includes + one mdb
# backend + ACLs), and it is slapadd-friendly for offline seeding.
set -eu

PREFIX=/opt/symas
# Root suffix: explicit LDAP_ROOT_DN wins, else derive from LDAP_DOMAIN
# (activemq.apache.org -> dc=activemq,dc=apache,dc=org). NB: the project's
# LDAP_BASE_DN env is the broker's ou=ActiveMQ search subtree, NOT the suffix.
LDAP_DOMAIN="${LDAP_DOMAIN:-activemq.apache.org}"
BASE_DN="${LDAP_ROOT_DN:-$(printf '%s' "$LDAP_DOMAIN" | sed 's/^/dc=/; s/\./,dc=/g')}"
ADMIN_DN="${LDAP_ADMIN_DN:-cn=admin,${BASE_DN}}"
ADMIN_PW="${LDAP_ADMIN_PASSWORD:-admin}"
ORG="${LDAP_ORGANISATION:-ActiveMQ}"
SEED_DIR="${LDAP_SEED_DIR:-/seed}"
DATA_DIR="${LDAP_DATA_DIR:-/var/lib/ldap}"
CONF="/etc/symas/slapd.conf"
SCHEMA="${PREFIX}/etc/openldap/schema"
MODDIR="${PREFIX}/lib/openldap"

# dc value = first RDN of the base DN (dc=activemq,... -> activemq)
DC="$(printf '%s' "$BASE_DN" | sed 's/^[^=]*=//; s/,.*//')"

log() { echo "[entrypoint] $*"; }

if [ ! -f "${DATA_DIR}/data.mdb" ]; then
  log "provisioning ${BASE_DN} (admin ${ADMIN_DN})"
  mkdir -p "$DATA_DIR" "$(dirname "$CONF")"

  # back_mdb ships as a loadable module in the Symas build; load it only if the
  # static binary doesn't already provide it (guarded so either layout works).
  MODLOAD=""
  if [ -f "${MODDIR}/back_mdb.so" ] || [ -f "${MODDIR}/back_mdb.la" ]; then
    MODLOAD="modulepath ${MODDIR}
moduleload back_mdb"
  fi

  ROOTPW="$("${PREFIX}/sbin/slappasswd" -s "$ADMIN_PW")"

  cat > "$CONF" <<EOF
include ${SCHEMA}/core.schema
include ${SCHEMA}/cosine.schema
include ${SCHEMA}/inetorgperson.schema
include ${SCHEMA}/nis.schema
${MODLOAD}

database mdb
maxsize 1073741824
suffix "${BASE_DN}"
rootdn "${ADMIN_DN}"
rootpw ${ROOTPW}
directory ${DATA_DIR}
index objectClass eq

# Demo ACLs: passwords are usable for bind auth only; the rest of the tree is
# world-readable so the broker's bind account can read groups/destinations.
access to attrs=userPassword
  by self write
  by anonymous auth
  by * none
access to *
  by * read
EOF

  # Base suffix entry, then every mounted seed LDIF (sorted), imported offline.
  ROOT_LDIF="$(mktemp)"
  cat > "$ROOT_LDIF" <<EOF
dn: ${BASE_DN}
objectClass: top
objectClass: dcObject
objectClass: organization
o: ${ORG}
dc: ${DC}
EOF
  "${PREFIX}/sbin/slapadd" -f "$CONF" -l "$ROOT_LDIF"
  rm -f "$ROOT_LDIF"

  if [ -d "$SEED_DIR" ]; then
    for f in $(find "$SEED_DIR" -maxdepth 1 -name '*.ldif' | sort); do
      log "importing seed $f"
      "${PREFIX}/sbin/slapadd" -f "$CONF" -l "$f"
    done
  fi
  log "provisioning complete"
else
  log "existing database found in ${DATA_DIR}; skipping provisioning"
fi

LDAP_PORT="${LDAP_PORT:-389}"
log "starting slapd on ldap://0.0.0.0:${LDAP_PORT}/"
# The Symas server package installs the slapd daemon under lib/ (the sbin/ dir
# holds the slap* tools — slapadd, slappasswd, etc.). `-d 0` keeps slapd in the
# foreground (the container's PID 1) with no debug output. A plain TCP listener
# is used (no ldapi:/// unix socket — it needs a runtime dir the broker never
# uses, and would fail startup here).
exec "${PREFIX}/lib/slapd" -f "$CONF" -h "ldap://0.0.0.0:${LDAP_PORT}/" -d 0
