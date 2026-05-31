# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Description

A **runnable demo** (no application source code) showing how to wire Apache ActiveMQ 6.2.6 authentication and authorization to an LDAP directory. It supports three interchangeable directory backends — OpenLDAP, Apache DS (faking Microsoft Active Directory), and Samba AD — plus a secured Jetty web console. Everything is delivered as Docker images and `docker-compose` stacks; there is nothing to compile.

## Architecture

The core idea: ActiveMQ never owns its own user/role database. Authentication and authorization are both delegated to LDAP at runtime via two ActiveMQ plugins configured in `6.2.6/conf/activemq.xml`:

- `jaasAuthenticationPlugin configuration="LDAPLogin"` — authentication. The `LDAPLogin` realm is defined in `6.2.6/conf/login.config` (`org.apache.activemq.jaas.LDAPLoginModule`). The **Jetty web console** authenticates against the **same** `LDAPLogin` realm (`6.2.6/conf/jetty.xml` `JAASLoginService`, `roleClassNames=org.apache.activemq.jaas.GroupPrincipal`) — broker and console share one LDAP login module.
- `authorizationPlugin` with `cachedLDAPAuthorizationMap` — authorization. Queue/topic/temp permissions are read from LDAP group entries (`ou=Destination` subtree) and cached, refreshed on `refreshInterval`.

### The templating mechanism (most important thing to understand)

The config files are **not** the files the broker runs. `6.2.6/conf/activemq.xml` and `login.config` ship with literal `##### PLACEHOLDER #####` tokens (e.g. `##### LDAP_HOST #####`, `##### LDAP_QUEUE_SEARCH_BASE #####`). At container startup, `6.2.6/init.sh` (the Dockerfile `ENTRYPOINT`) runs a series of `sed -i` substitutions that replace each placeholder with the value of the corresponding environment variable, then starts the broker and tails its log.

Consequence: **to change broker LDAP wiring, edit the env vars (in `6.2.6/.env` / docker-compose `environment:`) and the placeholder tokens, never hardcode values into the `.xml`/`.config`.** A `.orig` copy of each templated file sits alongside it as a pristine reference. `init.sh` `cat`s both files to stdout on boot so the resolved config is visible in `docker logs`.

### LDAP directory tree (shared contract)

All backends serve the same base DN `dc=activemq,dc=apache,dc=org` with this structure (see the `.ldif` seed files):
- `ou=User,ou=ActiveMQ` — user entries (`uid=admin`, `uid=user`), authenticated by `userSearchMatching="(uid={0})"`.
- `ou=Group,ou=ActiveMQ` — role groups (`groupOfNames`, matched by `member=uid={1}`).
- `ou=Destination,ou=ActiveMQ` → `ou=Queue` / `ou=Topic` / `ou=Temp` — authorization entries; group membership grants admin/read/write on destinations.
- `cn=mqbroker,ou=Services,...` — the broker's own bind account.

Demo credentials throughout are `admin`/`admin` and `user`/`admin` (passwords are `{SHA}` hashes of `admin` in the LDIFs). These are intentional demo values, not secrets.

### Directory layout

- `6.2.6/` — the ActiveMQ broker image: `Dockerfile`, templated `conf/`, `bin/env`, `init.sh`, and the **primary** `docker-compose.yml` (OpenLDAP + ActiveMQ + phpLDAPadmin).
- `apacheds-ad/` — Apache DS backend stack (image `andriykalashnykov/apacheds-ad`, LDAP on host port `10389`). `ldif/users.ldif` adds Microsoft `sAMAccountName`/`memberOf` schema to mimic AD.
- `openldap/` — standalone OpenLDAP compose + seed LDIF, used by `scripts/start-openldap.sh`.
- `samba/` — Samba-as-AD domain controller (`ubuntu:26.04` `Dockerfile` + provisioning scripts), an alternative to Apache DS. The scripts (`samba-ad-setup.sh`/`samba-ad-run.sh`) are **bind-mounted** at runtime into `/opt/ad-scripts`, not baked into the image.
- `hawtio/` — standalone hawtio management console (`Dockerfile` = Tomcat 11 + hawtio 5.x WAR on Java 25; `docker-entrypoint.sh` templates `login.config`). LDAP-secured via the **same** `LDAPLogin` realm as the broker (`activemq-jaas` + `slf4j-api` jars added to Tomcat's classpath for `LDAPLoginModule`+`GroupPrincipal`). Connects to the broker's LDAP-secured Jolokia (`/api/jolokia`) via hawtio's Connect tab. A service in the primary compose (host port 8090).
- `scripts/` — operational helpers (see below); `scripts/lib.sh` holds the sourceable, unit-tested config-templating functions.
- `tests/templating.bats` — `bats` unit tests for `scripts/lib.sh` (the env→config substitution logic). Run via `make test`.
- `e2e/e2e-test.sh` — asserting end-to-end test of the LDAP authN/authZ contract against the composed stack. Run via `make e2e`.
- `e2e/e2e-samba.sh` — asserting e2e for the Samba AD DC: provisions the DC (`--privileged`), then asserts LDAP/LDAPS/Kerberos/GC ports listen, the domain is provisioned, and an authenticated LDAPS search returns the Administrator entry. Run via `make e2e-samba`.
- `.env.example` — committed source-of-truth defaults (LDAP/broker hosts, ports, demo creds, Samba realm/admin-password, e2e tunables); sourced by both e2e scripts.
- `.github/workflows/docker-image.yml` — CI (`name: CI`): matrix-builds the four Dockerfiles (`6.2.6/`, `samba/`, `openldap/`, `hawtio/`) + **blocking** Trivy scan (`exit-code: '1'`; samba/openldap/hawtio clean, broker waives one residual in `.trivyignore`), `test` (bats + mermaid-lint), `e2e` (compose authZ contract + broker & hawtio LDAP login), and `e2e-samba` (Samba AD DC serves LDAP) jobs.
- `.trivyignore` — one documented waiver: `jetty-http` CVE-2026-2332 (ActiveMQ 6.2.6 bundles Jetty 11.0.26; the fix is Jetty 12 only — a future ActiveMQ line). The 4 Spring CVEs 5.19.6 carried were cleared by the 6.2.6 migration, so they are NOT waived.

## Common Commands

All `scripts/*.sh` source `scripts/set-env.sh` for version pins (`ACTIVEMQ_VER`, `JETTY_VER`, image names, container names) and resolve their own directory, so they can be run from anywhere. They do **not** read `6.2.6/.env` — that file is consumed by docker-compose. The two files are independent sources of truth; keep version pins in sync when bumping.

A root `Makefile` wraps the common flows (`make help` lists them); the `scripts/*.sh` helpers below are what those targets call.

### Run the full stack (primary path)
```bash
make up                               # docker compose -f 6.2.6/docker-compose.yml up -d
# equivalently: cd 6.2.6 && docker compose up
```
- ActiveMQ web console: http://127.0.0.1:8161/admin/ (login `admin`/`admin`)
- phpLDAPadmin: http://localhost:6443/ (Login DN `cn=admin,dc=activemq,dc=apache,dc=org`, password `admin`) — maintained leenooks v2, serves HTTP on :8080
- Broker ports: openwire 61616, AMQP 5672, STOMP 61613, MQTT 1883, WS 61614.

### Apache DS backend instead of OpenLDAP
```bash
cd apacheds-ad && docker-compose up   # LDAP on host port 10389
```

### Build & push images
```bash
./scripts/build.sh      # builds docker-activemq:$ACTIVEMQ_VER and apacheds-ad:latest
./scripts/push.sh       # docker login + push (set DOCKER_LOGIN / DOCKER_PWD in set-env.sh first)
```
Note: `build.sh` builds `apacheds-ad` from a `Dockerfile` that is **not** committed to the repo — that step only works locally if the file exists.

### Test layers
```bash
make test                # unit: bats over scripts/lib.sh config-templating logic
make e2e                 # e2e: compose up → assert LDAP authN/authZ matrix → tear down
make e2e-samba           # e2e: build + provision the Samba AD DC → assert it serves LDAP → tear down
./scripts/search-openldap.sh   # manual ldapsearch against OpenLDAP (port 389)
./scripts/search-apacheds.sh   # manual ldapsearch against Apache DS (port 10389)
```
`make e2e` ([`e2e/e2e-test.sh`](e2e/e2e-test.sh)) is the asserting authorization test: it produces as `admin`/`user` against queues they should and should not write to and asserts the outcomes (`admin`→`ADMINS.*` allowed, `user`→`USERS.*` allowed, `user`→`ADMINS.*` denied), exercising `cachedLDAPAuthorizationMap`. `scripts/test-activemq.sh` is the older, non-asserting exploration script (superseded by the e2e harness; kept for manual poking).

**Known startup behavior — authz cache warm-up (non-obvious):** `cachedLDAPAuthorizationMap` is cold for a short window after the broker starts (OpenLDAP may still be importing the LDIF; the map populates on first refresh). During that window **every** producer is denied on `topic://ActiveMQ.Advisory.Connection` — including `admin` — so an authz test that runs too early sees spurious denials. Once warm, the real per-destination matrix is enforced. `e2e/e2e-test.sh` polls `admin`→`queue://TEST` until it succeeds before asserting, and `make e2e` sets a short `LDAP_REFRESH_INTERVAL` (15s) so warm-up is fast and deterministic. The production default `LDAP_REFRESH_INTERVAL` is 300000ms (5 min) — see `6.2.6/.env`.

### Local (non-Docker) broker
`scripts/install-activemq-local.sh` downloads ActiveMQ to `/opt` and drops the Jetty jars in; `run-activemq-local.sh` / `stop-activemq-local.sh` manage it. These are an alternative to the container path and use `sudo`.

### CI locally
```bash
docker build ./6.2.6 --file ./6.2.6/Dockerfile --tag amq-test:local
```
This is exactly what the `docker-image.yml` workflow runs.

## Conventions & Gotchas

- **Version pins live in two places**: `scripts/set-env.sh` (for scripts) and `6.2.6/Dockerfile` + `6.2.6/.env` (for the image/compose). The `Dockerfile` also pins a `SHA512_VAL` checksum for the ActiveMQ tarball — bumping `ACTIVEMQ_VER` requires updating that hash or the build fails the checksum gate.
- **Jetty (11.0.26) ships bundled with ActiveMQ 6.2.6** — including `jetty-jaas` (in `lib/web/`), which the web console's `JAASLoginService` needs. No Jetty overlay jar is curled (5.19.6 had to overlay `jetty-jaas`; 6.x bundles it). `JETTY_VER` (in `set-env.sh`) is kept aligned with the broker's bundled Jetty (`activemq-parent` pom `jetty-version`) for reference + Renovate tracking.
- **Web-console symlink gotcha (`jetty.xml` `aliasChecks`)**: `ACTIVEMQ_HOME` (`/opt/activemq`) is a symlink to `/opt/apache-activemq-$ACTIVEMQ_VER`. Jetty refuses to serve `WEB-INF/*` resolved through a symlink, so the console webapp's Spring context fails to load `/WEB-INF/webconsole-embedded.xml` → HTTP 503. The `/admin` and `/api` WebAppContexts carry an `org.eclipse.jetty.server.handler.AllowSymLinkAliasChecker` to allow it. Ref: AMQ-7341. On Jetty 11 (6.2.6) this class logs a deprecation warning (replacement: `org.eclipse.jetty.server.SymlinkAllowedResourceAliasChecker`) but still works — verified by the e2e console login. Do not remove it.
- **Jetty-11 `pathSpec` gotcha (`jetty.xml`)**: Jetty 11 enforces the Servlet spec strictly, so the 5.19.6/Jetty-9.4 comma-list `pathSpec="/*,/api/*,/admin/*,*.jsp"` is rejected at startup ("Servlet Spec 12.2 violation: glob '*' can only exist at end of prefix"). The securityConstraintMapping uses `pathSpec="/"` (the catch-all, matching stock 6.2.6).
- The base image is `eclipse-temurin:25-jre` (Java 25 LTS). ActiveMQ 6.2.6 *requires* Java 17 (`requireJavaVersion [17,)` + `target` = 17 in its parent pom); Java 25 satisfies it. Verified by the full e2e auth/authz contract (14/14) on the `25.0.3_9-jre` base. The Dockerfile installs `curl` explicitly because the `:25` base (Ubuntu 24.04) dropped it.
- **Logging (`init.sh` runs `activemq console`; no extra config needed)**: ActiveMQ 6.x logs via **Log4j2** (`conf/log4j2.properties`) — a Console appender → **stdout** (so `docker logs` shows broker logs) plus a `RollingFile` → `data/activemq.log`. `init.sh` ends with `exec activemq console` (foreground, the broker as the container's main process — the same `CMD` the official `apache/activemq-classic` image uses), not the old `activemq start && tail -f` daemonize-then-tail anti-pattern. No bespoke logging config is warranted; JSON layout (Log4j2 `JsonTemplateLayout`) is available for log aggregation but unnecessary for a demo.
- **`logQuery`/fabric8 bean removed (gone since ActiveMQ 5.17, absent in 6.x)**: the stock `activemq.xml` historically carried `<bean id="logQuery" class="io.fabric8.insight.log.log4j.Log4jLogQuery"/>` (a JMX MBean exposing logs to the console). **fabric8-insight was Log4j-1.x-only and was dropped in the 5.17 Log4j2 migration** (AMQ-8604: the insight-log jars present in 5.16.4 are gone from 5.17.1+), so keeping the bean throws `ClassNotFoundException` at startup. It is correctly omitted (matches the stock 6.2.6 `activemq.xml`); there is **no built-in replacement** for the console log-view, and upstream fabric8.io is archived (Nov 2025) — rely on `docker logs` (stdout).
- **Samba AD on Ubuntu 26.04 — explicit AD-DC packages (`samba/Dockerfile`)**: 26.04 stopped pulling the AD-DC pieces in transitively via `samba` (they were present on 24.04), so each is named explicitly: `samba-ad-dc` (the `/usr/sbin/samba` daemon — else "samba: command not found"), `samba-ad-provision` (AD DS schema — else "AD_DS_Attributes…v1903.ldf not found"), `samba-dsdb-modules` (DSDB ldb modules — else "Unable to load modules for secrets.ldb"), `samba-vfs-modules` (sysvol). `ldap-utils` is added for the e2e's over-the-wire LDAPS assertion. Provisioning needs `--privileged` (sysvol NT-ACL xattrs) on any base, not a 26.04 quirk. Guarded by `make e2e-samba`.
- The [Upgrade Backlog](#upgrade-backlog) below tracks the deferred upgrades (ActiveMQ + the CVE driver, Jetty, the LDAP admin images, JDK).

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.

## Upgrade Backlog

_Last updated 2026-05-31. ActiveMQ is intentionally **not** Renovate-tracked — bumping it requires updating `SHA512_VAL` in `6.2.6/Dockerfile` for the new tarball AND re-aligning `JETTY_VER` to the broker's bundled Jetty (`activemq-parent` pom `jetty9-version`). Jetty (Maven), the Docker images, and Actions ARE Renovate-managed. Landed 2026-05-31 (see git history): ActiveMQ 5.16.1→5.19.6 (Java 8→11, clears CVE-2023-46604 OpenWire RCE), Jetty→9.4.58, phpLDAPadmin→leenooks v2, LAM→GHCR 9.5, **ldaptive removed** (the Jetty web console now authenticates via ActiveMQ's own `LDAPLoginModule`; fixed a Jetty-9.4 symlink-alias 503 with `AllowSymLinkAliasChecker`). Then **ActiveMQ 5.19.6→6.2.6** (Jakarta, Spring 6.2.x, Jetty 11.0.26, Java 17 floor): version dir `5.19.6/`→`6.2.6/`, bundled `jetty-jaas` (overlay dropped), Jetty-11 `pathSpec` fix, OpenLDAP migrated osixia→self-built Symas image, Trivy a blocking gate (cleared 4 of the 5 EOL CVEs via Spring 6.2.x; one residual — `jetty-http` CVE-2026-2332, Jetty-12-only fix — waived in `.trivyignore`)._

- [x] **OpenLDAP migrated off the unmaintained `osixia/openldap:1.5.0` to a self-built Symas image (2026-05-31).** `openldap/Dockerfile` is a minimal `debian:bookworm-slim` + Symas's maintained OpenLDAP packages (`repo.symas.com`, slapd 2.6.x — Symas is the OpenLDAP steward); `openldap/docker-entrypoint.sh` provisions the suffix (derived from `LDAP_DOMAIN`) + admin and `slapadd`s the seed (which reuses non-unique `cn=admin/read/write` groups across destination OUs — a bare slapd accepts this; only a `unique` overlay would reject it). Spike findings that drove this: `symas/openldap` still not on Docker Hub (re-verified 404); `bitnami`/`bitnamilegacy` paywalled/frozen (Broadcom Aug 2025); **`nfrastack/openldap` reproducibly fails its `10-openldap` init** on current stable+prerelease images (the "sudo-init fragility", confirmed) — so a build-from-Symas-packages image is the cleanest maintained path. Verified: standalone import (50 entries, 9 dup `cn=admin`, mqbroker authz read + user authN bind) and full `make e2e` 14/14; image passes the blocking Trivy scan.
- [x] **Jetty overlay trimmed to `jetty-jaas` only (2026-05-31).** Verified the stock 5.19.6 distribution already bundles `jetty-util` + `jetty-security` in `lib/web/`; only `jetty-jaas` (which alone contains `org.eclipse.jetty.jaas.JAASLoginService`) is genuinely missing. The Dockerfile now overlays just that one jar — removing the duplicate-jar / cross-jar version-skew risk.
- [x] **CI Trivy scan is BLOCKING (`exit-code: '1'`, 2026-05-31).** Removable findings are deleted outright — the dormant `lib/camel` jars (no `<camelContext>`) and Canonical's `pebble` Go binary baked into the bases (8 Go-stdlib CVEs each); samba/openldap apt-upgrade their bases and scan clean. The 6.2.6 migration cleared the 4 EOL **Spring** CVEs (Spring 6.2.x is a patched line); the one residual — `jetty-http` CVE-2026-2332 (6.2.6 bundles Jetty 11, fix is Jetty-12-only) — is waived in `.trivyignore`. Down from 5 broker waivers to 1. The gate hard-fails on any **new fixable** CVE.
- [x] **ActiveMQ 6.x migration — LANDED (5.19.6→6.2.6, 2026-05-31).** Deep-researched + spiked + proven before shipping: config ported cleanly (`jaasAuthenticationPlugin`/`LDAPLoginModule`/`cachedLDAPAuthorizationMap`/`JAASLoginService`+`GroupPrincipal` all unchanged across the versions), the only real config delta was the Jetty-11 `pathSpec` (see Gotchas), `jetty-jaas` is now bundled (overlay dropped), base stays `temurin:25` (≥ 6.x's Java-17 floor). Verified `make e2e` 14/14 before merge. CVE effect: cleared the 4 EOL Spring CVEs (Spring 6.2.x); `jetty-http` CVE-2026-2332 persists (6.2.6 bundles Jetty 11 — fix is Jetty-12-only, a future ActiveMQ line) and stays waived.
- [ ] **Jetty 12 / future ActiveMQ line.** The lone remaining CVE waiver (`jetty-http` CVE-2026-2332) needs Jetty 12, which ActiveMQ Classic 6.2.x does not bundle. Revisit when an ActiveMQ line ships Jetty 12.
