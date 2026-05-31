# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Description

A **runnable demo** (no application source code) showing how to wire Apache ActiveMQ 5.16.1 authentication and authorization to an LDAP directory. It supports three interchangeable directory backends — OpenLDAP, Apache DS (faking Microsoft Active Directory), and Samba AD — plus a secured Jetty web console. Everything is delivered as Docker images and `docker-compose` stacks; there is nothing to compile.

## Architecture

The core idea: ActiveMQ never owns its own user/role database. Authentication and authorization are both delegated to LDAP at runtime via two ActiveMQ plugins configured in `5.16.1/conf/activemq.xml`:

- `jaasAuthenticationPlugin configuration="LDAPLogin"` — authentication. The `LDAPLogin` realm is defined in `5.16.1/conf/login.config` (`org.apache.activemq.jaas.LDAPLoginModule`). An alternate `ldaptive`-based realm also lives in that file but is not the active one.
- `authorizationPlugin` with `cachedLDAPAuthorizationMap` — authorization. Queue/topic/temp permissions are read from LDAP group entries (`ou=Destination` subtree) and cached, refreshed on `refreshInterval`.

### The templating mechanism (most important thing to understand)

The config files are **not** the files the broker runs. `5.16.1/conf/activemq.xml` and `login.config` ship with literal `##### PLACEHOLDER #####` tokens (e.g. `##### LDAP_HOST #####`, `##### LDAP_QUEUE_SEARCH_BASE #####`). At container startup, `5.16.1/init.sh` (the Dockerfile `ENTRYPOINT`) runs a series of `sed -i` substitutions that replace each placeholder with the value of the corresponding environment variable, then starts the broker and tails its log.

Consequence: **to change broker LDAP wiring, edit the env vars (in `5.16.1/.env` / docker-compose `environment:`) and the placeholder tokens, never hardcode values into the `.xml`/`.config`.** A `.orig` copy of each templated file sits alongside it as a pristine reference. `init.sh` `cat`s both files to stdout on boot so the resolved config is visible in `docker logs`.

### LDAP directory tree (shared contract)

All backends serve the same base DN `dc=activemq,dc=apache,dc=org` with this structure (see the `.ldif` seed files):
- `ou=User,ou=ActiveMQ` — user entries (`uid=admin`, `uid=user`), authenticated by `userSearchMatching="(uid={0})"`.
- `ou=Group,ou=ActiveMQ` — role groups (`groupOfNames`, matched by `member=uid={1}`).
- `ou=Destination,ou=ActiveMQ` → `ou=Queue` / `ou=Topic` / `ou=Temp` — authorization entries; group membership grants admin/read/write on destinations.
- `cn=mqbroker,ou=Services,...` — the broker's own bind account.

Demo credentials throughout are `admin`/`admin` and `user`/`admin` (passwords are `{SHA}` hashes of `admin` in the LDIFs). These are intentional demo values, not secrets.

### Directory layout

- `5.16.1/` — the ActiveMQ broker image: `Dockerfile`, templated `conf/`, `bin/env`, `init.sh`, and the **primary** `docker-compose.yml` (OpenLDAP + ActiveMQ + phpLDAPadmin).
- `apacheds-ad/` — Apache DS backend stack (image `andriykalashnykov/apacheds-ad`, LDAP on host port `10389`). `ldif/users.ldif` adds Microsoft `sAMAccountName`/`memberOf` schema to mimic AD.
- `openldap/` — standalone OpenLDAP compose + seed LDIF, used by `scripts/start-openldap.sh`.
- `samba/` — Samba-as-AD domain controller (`Dockerfile` + provisioning scripts), an alternative to Apache DS.
- `scripts/` — operational helpers (see below); `scripts/lib.sh` holds the sourceable, unit-tested config-templating functions.
- `tests/templating.bats` — `bats` unit tests for `scripts/lib.sh` (the env→config substitution logic). Run via `make test`.
- `e2e/e2e-test.sh` — asserting end-to-end test of the LDAP authN/authZ contract against the composed stack. Run via `make e2e`.
- `.env.example` — committed source-of-truth defaults (LDAP/broker hosts, ports, demo creds, e2e tunables); sourced by `e2e/e2e-test.sh`.
- `.github/workflows/docker-image.yml` — CI (`name: CI`): matrix-builds both Dockerfiles + Trivy scan (report-only), `test` (bats), and `e2e` (compose authZ contract) jobs.

## Common Commands

All `scripts/*.sh` source `scripts/set-env.sh` for version pins (`ACTIVEMQ_VER`, `JETTY_VER`, `LDAPTIVE_VER`, image names, container names) and resolve their own directory, so they can be run from anywhere. They do **not** read `5.16.1/.env` — that file is consumed by docker-compose. The two files are independent sources of truth; keep version pins in sync when bumping.

A root `Makefile` wraps the common flows (`make help` lists them); the `scripts/*.sh` helpers below are what those targets call.

### Run the full stack (primary path)
```bash
make up                               # docker compose -f 5.16.1/docker-compose.yml up -d
# equivalently: cd 5.16.1 && docker compose up
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
./scripts/search-openldap.sh   # manual ldapsearch against OpenLDAP (port 389)
./scripts/search-apacheds.sh   # manual ldapsearch against Apache DS (port 10389)
```
`make e2e` ([`e2e/e2e-test.sh`](e2e/e2e-test.sh)) is the asserting authorization test: it produces as `admin`/`user` against queues they should and should not write to and asserts the outcomes (`admin`→`ADMINS.*` allowed, `user`→`USERS.*` allowed, `user`→`ADMINS.*` denied), exercising `cachedLDAPAuthorizationMap`. `scripts/test-activemq.sh` is the older, non-asserting exploration script (superseded by the e2e harness; kept for manual poking).

**Known startup behavior — authz cache warm-up (non-obvious):** `cachedLDAPAuthorizationMap` is cold for a short window after the broker starts (OpenLDAP may still be importing the LDIF; the map populates on first refresh). During that window **every** producer is denied on `topic://ActiveMQ.Advisory.Connection` — including `admin` — so an authz test that runs too early sees spurious denials. Once warm, the real per-destination matrix is enforced. `e2e/e2e-test.sh` polls `admin`→`queue://TEST` until it succeeds before asserting, and `make e2e` sets a short `LDAP_REFRESH_INTERVAL` (15s) so warm-up is fast and deterministic. The production default `LDAP_REFRESH_INTERVAL` is 300000ms (5 min) — see `5.16.1/.env`.

### Local (non-Docker) broker
`scripts/install-activemq-local.sh` downloads ActiveMQ to `/opt` and drops the Jetty/ldaptive jars in; `run-activemq-local.sh` / `stop-activemq-local.sh` manage it. These are an alternative to the container path and use `sudo`.

### CI locally
```bash
docker build ./5.16.1 --file ./5.16.1/Dockerfile --tag amq-test:local
```
This is exactly what the `docker-image.yml` workflow runs.

## Conventions & Gotchas

- **Version pins live in two places**: `scripts/set-env.sh` (for scripts) and `5.16.1/Dockerfile` + `5.16.1/.env` (for the image/compose). The `Dockerfile` also pins a `SHA512_VAL` checksum for the ActiveMQ tarball — bumping `ACTIVEMQ_VER` requires updating that hash or the build fails the checksum gate.
- **Jetty (9.4.35) and ldaptive (1.2.4) jars** are curl'd from Maven Central at image-build time into the broker's `lib/` (see `Dockerfile` lines 36–39) — they are not part of the stock ActiveMQ distribution and are needed for the JAAS/LDAP web-console auth.
- The base image is `eclipse-temurin:8-jre` — ActiveMQ 5.16.1 requires Java 8.
- The [Upgrade Backlog](#upgrade-backlog) below tracks the deferred upgrades (ActiveMQ + the CVE driver, Jetty, ldaptive, the LDAP admin images, JDK).

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

_Last analyzed 2026-05-30 (`/upgrade-analysis`). ActiveMQ is intentionally **not** Renovate-tracked — bumping it requires updating `SHA512_VAL` in `5.16.1/Dockerfile` for the new tarball. Jetty/ldaptive (Maven) + the Docker images + Actions ARE Renovate-managed._

- [ ] **🔴 SECURITY: upgrade ActiveMQ off 5.16.1 — vulnerable to CVE-2023-46604 (OpenWire RCE, CVSS 10.0, actively exploited).** Minimal fix: **5.16.7** (stays on Java 8, drop-in apart from `SHA512_VAL`). Better: **5.19.6** (latest 5.x, needs Java 11+) or **6.2.5** (latest 6.x, needs Java 17+). Also clears CVE-2024-32114 (web-console default auth). Bumping ActiveMQ couples to the Jetty/ldaptive overlay jars + the JDK base — treat as one change.
- [ ] Upgrade Jetty overlay jars from 9.4.35.v20201120 → 9.4.57.v20241219 (last 9.4.x; multiple CVEs since 9.4.35). Align to whatever Jetty the chosen ActiveMQ release bundles rather than pinning independently. Renovate proposes 9.4.x; major (10/11/12) is disabled in `renovate.json`.
- [ ] Upgrade ldaptive 1.2.4 → 2.4.1 (API-breaking major; do it with the ActiveMQ upgrade). Renovate opens the PR via the Maven custom manager.
- [ ] Reconsider the **Jetty/ldaptive overlay-jar pattern** — it couples three independently-pinned versions to ActiveMQ internals. Prefer the broker's bundled Jetty + only overlay ldaptive.
- [ ] **OpenLDAP stays on `osixia/openldap:1.5.0` — no clean maintained drop-in exists (deep-researched 2026-05-31).** The demo's authz tree deliberately reuses non-unique `cn=admin`/`cn=read`/`cn=write` permission groups under every destination, which **requires a bare `slapd`** — every modern *curated* image rejects it. Verdicts: `symas/openldap` not published on Docker Hub (404); `bitnami`/`bitnamilegacy` dead/frozen (Broadcom Aug 2025); `nfrastack`/tiredofit halts on sudo-init fragility (host + CI risk); `vegardit/openldap` (maintained) enforces a `unique` cn overlay → 22 constraint violations; `lldap`/`glauth` can't model the schema; `389ds` is a different server (major migration). Revisit if Symas publishes a Docker Hub image, or build from `Symas/containers` as a dedicated task.
- [x] **DONE (2026-05-31): phpLDAPadmin `osixia/phpldapadmin:0.9.0` → `phpldapadmin/phpldapadmin:2.3.11`** (maintained leenooks v2) across all three compose files + `scripts/start-openldap.sh`. Console is now **HTTP on :8080** (mapped to host :6443/:6543), not the old built-in HTTPS:443.
- [x] **DONE (2026-05-31): LAM upgraded `ldapaccountmanager/lam:7.4` → `ghcr.io/ldapaccountmanager/lam:9.5`** in the `openldap/` stack (Docker Hub image frozen at 8.3/2023; maintained image moved to GHCR). Vestigial `LAM_*` vars removed from `5.16.1/.env` (no LAM service there).
- [ ] Upgrade `eclipse-temurin:8-jre` → JDK 11+/17 — tied to the ActiveMQ upgrade (5.17+ needs Java 11, 6.x needs Java 17). Java 8 is the floor forcing the old broker.
- [ ] Once ActiveMQ + Jetty are current, flip the CI Trivy scan `exit-code` from `'0'` (report-only) to `'1'` so it becomes a blocking gate (`.github/workflows/docker-image.yml`).
