# Minimal OpenLDAP image built from Symas's maintained OpenLDAP packages.
#
# Symas is the commercial steward of the OpenLDAP project and ships the
# freshest slapd builds via its apt repo (repo.symas.com). This replaces the
# unmaintained osixia/openldap:1.5.0 (code frozen 2021) with a small,
# self-owned image on a current Debian base — no third-party container glue to
# vendor. The provisioning entrypoint creates the demo's base DN + admin and
# slapadds the seed LDIF (which deliberately reuses non-unique cn permission
# groups across destination OUs — a bare slapd accepts this; curated images
# with a `unique` overlay reject it).
FROM debian:bookworm-slim

# pipefail so a failed `curl … | gpg` key fetch fails the build (DL4006).
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Symas OpenLDAP 2.6 release line for Debian bookworm. The repo + signing key
# are added once; the server/clients/lib packages install under /opt/symas.
ARG SYMAS_RELEASE=release26
ARG SYMAS_SUITE=bookworm
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y --no-install-recommends; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    curl -fsSL https://repo.symas.com/repo/gpg/RPM-GPG-KEY-symas-com-signing-key \
      | gpg --dearmor -o /usr/share/keyrings/symas.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/symas.gpg] https://repo.symas.com/repo/deb/main/${SYMAS_RELEASE} ${SYMAS_SUITE} main" \
      > /etc/apt/sources.list.d/symas.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends symas-openldap-server symas-openldap-clients; \
    apt-get purge -y --auto-remove gnupg; \
    apt-get clean; rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/symas/bin:/opt/symas/sbin:${PATH}" \
    LD_LIBRARY_PATH="/opt/symas/lib"

# Operator-tunable defaults (mirror .env.example). The entrypoint provisions
# from these on first start; a `.ldif`-bearing /seed is imported under the base.
# The directory root suffix is DERIVED from LDAP_DOMAIN (activemq.apache.org ->
# dc=activemq,dc=apache,dc=org) — matching how osixia behaved, and avoiding a
# clash with the broker's own LDAP_BASE_DN (which is the ou=ActiveMQ search
# subtree, not the suffix). Override the suffix directly with LDAP_ROOT_DN.
ENV LDAP_DOMAIN="activemq.apache.org" \
    LDAP_ORGANISATION="ActiveMQ" \
    LDAP_ADMIN_PASSWORD="admin" \
    LDAP_SEED_DIR="/seed" \
    LDAP_DATA_DIR="/var/lib/ldap"

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 389 636
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
