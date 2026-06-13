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

# Pinned, reproducible release artifact. LDAP_SERVER_RELEASE is an *immutable*
# release tag in the ldap-server repo (a dated snapshot, NOT the mutable
# `latest` tag — `latest` is re-uploaded on every upstream rebuild, which would
# silently break the SHA256 gate below). The SHA256 pins the exact jar. To bump
# to a newer ldap-server build: cut a new immutable dated release there, then
# bump both values here together.
ARG LDAP_SERVER_RELEASE=2026-06-04
ARG LDAP_SERVER_JAR_SHA256=3c24360c8a5b8c93f48a3c9831261eed3430251b0b4fb0bd42f8072af6bd141a
ARG LDAP_SERVER_PORT=10389
ARG APP_UID=10389
ARG APP_GID=10389

ENV LDAP_SERVER_PORT=${LDAP_SERVER_PORT}

# apt upgrade clears base CVEs (the CI Trivy scan is a blocking gate); curl
# fetches the pinned release jar and is purged afterwards. The sha256sum -c
# gate fails the build if the pinned immutable tag's artifact ever changes
# (a tripwire against tag tampering / a wrong SHA bump).
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
    useradd -l -u "${APP_UID}" -g ldap -d /ldap -s /usr/sbin/nologin ldap; \
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
