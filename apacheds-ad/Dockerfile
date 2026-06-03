# syntax=docker/dockerfile:1
# ApacheDS-based in-memory LDAP server (the Microsoft-AD-mimic backend).
#
# The server itself is a release artifact of the companion repo
# github.com/AndriyKalashnykov/ldap-server (a fork of kwart/ldap-server,
# Main-Class com.github.kwart.ldap.LdapServer). This image just runs that jar
# on a current JRE and imports any LDIFs found under /ldap/ldif at startup —
# bind-mount ./ldif there (see apacheds-ad/docker-compose.yml) to seed the
# Microsoft sAMAccountName/memberOf schema that mimics Active Directory.
FROM eclipse-temurin:25.0.3_9-jre

LABEL maintainer="AndriyKalashnykov@gmail.com"

# Pinned, reproducible release artifact. LDAP_SERVER_RELEASE is the git tag in
# the ldap-server repo; the SHA256 pins the exact jar so a moved/rebuilt tag is
# detected at build time (the release tag is mutable). Bump both together.
ARG LDAP_SERVER_RELEASE=latest
ARG LDAP_SERVER_JAR_SHA256=9dfee37b955097cbc90e5555252e59dde85b5240175433f4e2178f7559fcdb98
ARG LDAP_SERVER_PORT=10389
ARG APP_UID=10389
ARG APP_GID=10389

ENV LDAP_SERVER_PORT=${LDAP_SERVER_PORT}

# apt upgrade clears base CVEs (the CI Trivy scan is a blocking gate); curl
# fetches the pinned release jar and is purged afterwards. The sha256sum -c
# gate fails the build if the (mutable) release tag's artifact ever changes.
# A non-root service account owns /ldap; the in-memory directory needs no
# writable data dir.
RUN set -eux; \
    apt-get update; apt-get upgrade -y; \
    apt-get install -y --no-install-recommends curl ca-certificates; \
    rm -f /usr/bin/pebble; \
    mkdir -p /ldap/ldif; \
    curl -fsSLo /ldap/ldap-server.jar \
      "https://github.com/AndriyKalashnykov/ldap-server/releases/download/${LDAP_SERVER_RELEASE}/ldap-server.jar"; \
    printf '%s  /ldap/ldap-server.jar\n' "${LDAP_SERVER_JAR_SHA256}" > /tmp/jar.sha256; \
    sha256sum -c /tmp/jar.sha256; rm -f /tmp/jar.sha256; \
    groupadd -g "${APP_GID}" ldap; \
    useradd -r -l -u "${APP_UID}" -g ldap -d /ldap -s /usr/sbin/nologin ldap; \
    chown -R ldap:ldap /ldap; \
    apt-get purge -y curl; apt-get autoremove -y; apt-get clean; rm -rf /var/lib/apt/lists/*

USER ldap
WORKDIR /ldap
EXPOSE ${LDAP_SERVER_PORT}

# JRE-only image (no curl/nc/wget) — probe the LDAP port via bash's /dev/tcp.
# HEALTHCHECK flag values are baked at build time (Docker does not expand
# variables in them); the CMD honours the LDAP_SERVER_PORT env at runtime.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/${LDAP_SERVER_PORT}' || exit 1

# Mount any directory at /ldap/ldif to import LDIFs at startup.
CMD ["java", "-jar", "/ldap/ldap-server.jar", "/ldap/ldif/"]
