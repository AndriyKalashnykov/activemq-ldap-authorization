# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Description

A **runnable demo** (no application source code) showing how to wire Apache ActiveMQ 5.19.6 authentication and authorization to an LDAP directory. It supports three interchangeable directory backends — OpenLDAP, Apache DS (faking Microsoft Active Directory), and Samba AD — plus a secured Jetty web console. Everything is delivered as Docker images and `docker-compose` stacks; there is nothing to compile.

## Architecture

The core idea: ActiveMQ never owns its own user/role database. Authentication and authorization are both delegated to LDAP at runtime via two ActiveMQ plugins configured in `5.19.6/conf/activemq.xml`:

- `jaasAuthenticationPlugin configuration="LDAPLogin"` — authentication. The `LDAPLogin` realm is defined in `5.19.6/conf/login.config` (`org.apache.activemq.jaas.LDAPLoginModule`). The **Jetty web console** authenticates against the **same** `LDAPLogin` realm (`5.19.6/conf/jetty.xml` `JAASLoginService`, `roleClassNames=org.apache.activemq.jaas.GroupPrincipal`) — broker and console share one LDAP login module.
- `authorizationPlugin` with `cachedLDAPAuthorizationMap` — authorization. Queue/topic/temp permissions are read from LDAP group entries (`ou=Destination` subtree) and cached, refreshed on `refreshInterval`.

### The templating mechanism (most important thing to understand)

The config files are **not** the files the broker runs. `5.19.6/conf/activemq.xml` and `login.config` ship with literal `##### PLACEHOLDER #####` tokens (e.g. `##### LDAP_HOST #####`, `##### LDAP_QUEUE_SEARCH_BASE #####`). At container startup, `5.19.6/init.sh` (the Dockerfile `ENTRYPOINT`) runs a series of `sed -i` substitutions that replace each placeholder with the value of the corresponding environment variable, then starts the broker and tails its log.

Consequence: **to change broker LDAP wiring, edit the env vars (in `5.19.6/.env` / docker-compose `environment:`) and the placeholder tokens, never hardcode values into the `.xml`/`.config`.** A `.orig` copy of each templated file sits alongside it as a pristine reference. `init.sh` `cat`s both files to stdout on boot so the resolved config is visible in `docker logs`.

### LDAP directory tree (shared contract)

All backends serve the same base DN `dc=activemq,dc=apache,dc=org` with this structure (see the `.ldif` seed files):
- `ou=User,ou=ActiveMQ` — user entries (`uid=admin`, `uid=user`), authenticated by `userSearchMatching="(uid={0})"`.
- `ou=Group,ou=ActiveMQ` — role groups (`groupOfNames`, matched by `member=uid={1}`).
- `ou=Destination,ou=ActiveMQ` → `ou=Queue` / `ou=Topic` / `ou=Temp` — authorization entries; group membership grants admin/read/write on destinations.
- `cn=mqbroker,ou=Services,...` — the broker's own bind account.

Demo credentials throughout are `admin`/`admin` and `user`/`admin` (passwords are `{SHA}` hashes of `admin` in the LDIFs). These are intentional demo values, not secrets.

### Directory layout

- `5.19.6/` — the ActiveMQ broker image: `Dockerfile`, templated `conf/`, `bin/env`, `init.sh`, and the **primary** `docker-compose.yml` (OpenLDAP + ActiveMQ + phpLDAPadmin).
- `apacheds-ad/` — Apache DS backend stack (image `andriykalashnykov/apacheds-ad`, LDAP on host port `10389`). `ldif/users.ldif` adds Microsoft `sAMAccountName`/`memberOf` schema to mimic AD.
- `openldap/` — standalone OpenLDAP compose + seed LDIF, used by `scripts/start-openldap.sh`.
- `samba/` — Samba-as-AD domain controller (`ubuntu:26.04` `Dockerfile` + provisioning scripts), an alternative to Apache DS. The scripts (`samba-ad-setup.sh`/`samba-ad-run.sh`) are **bind-mounted** at runtime into `/opt/ad-scripts`, not baked into the image.
- `scripts/` — operational helpers (see below); `scripts/lib.sh` holds the sourceable, unit-tested config-templating functions.
- `tests/templating.bats` — `bats` unit tests for `scripts/lib.sh` (the env→config substitution logic). Run via `make test`.
- `e2e/e2e-test.sh` — asserting end-to-end test of the LDAP authN/authZ contract against the composed stack. Run via `make e2e`.
- `e2e/e2e-samba.sh` — asserting e2e for the Samba AD DC: provisions the DC (`--privileged`), then asserts LDAP/LDAPS/Kerberos/GC ports listen, the domain is provisioned, and an authenticated LDAPS search returns the Administrator entry. Run via `make e2e-samba`.
- `.env.example` — committed source-of-truth defaults (LDAP/broker hosts, ports, demo creds, Samba realm/admin-password, e2e tunables); sourced by both e2e scripts.
- `.github/workflows/docker-image.yml` — CI (`name: CI`): matrix-builds both Dockerfiles + Trivy scan (report-only), `test` (bats + mermaid-lint), `e2e` (compose authZ contract), and `e2e-samba` (Samba AD DC serves LDAP) jobs.

## Common Commands

All `scripts/*.sh` source `scripts/set-env.sh` for version pins (`ACTIVEMQ_VER`, `JETTY_VER`, `LDAPTIVE_VER`, image names, container names) and resolve their own directory, so they can be run from anywhere. They do **not** read `5.19.6/.env` — that file is consumed by docker-compose. The two files are independent sources of truth; keep version pins in sync when bumping.

A root `Makefile` wraps the common flows (`make help` lists them); the `scripts/*.sh` helpers below are what those targets call.

### Run the full stack (primary path)
```bash
make up                               # docker compose -f 5.19.6/docker-compose.yml up -d
# equivalently: cd 5.19.6 && docker compose up
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

**Known startup behavior — authz cache warm-up (non-obvious):** `cachedLDAPAuthorizationMap` is cold for a short window after the broker starts (OpenLDAP may still be importing the LDIF; the map populates on first refresh). During that window **every** producer is denied on `topic://ActiveMQ.Advisory.Connection` — including `admin` — so an authz test that runs too early sees spurious denials. Once warm, the real per-destination matrix is enforced. `e2e/e2e-test.sh` polls `admin`→`queue://TEST` until it succeeds before asserting, and `make e2e` sets a short `LDAP_REFRESH_INTERVAL` (15s) so warm-up is fast and deterministic. The production default `LDAP_REFRESH_INTERVAL` is 300000ms (5 min) — see `5.19.6/.env`.

### Local (non-Docker) broker
`scripts/install-activemq-local.sh` downloads ActiveMQ to `/opt` and drops the Jetty jars in; `run-activemq-local.sh` / `stop-activemq-local.sh` manage it. These are an alternative to the container path and use `sudo`.

### CI locally
```bash
docker build ./5.19.6 --file ./5.19.6/Dockerfile --tag amq-test:local
```
This is exactly what the `docker-image.yml` workflow runs.

## Conventions & Gotchas

- **Version pins live in two places**: `scripts/set-env.sh` (for scripts) and `5.19.6/Dockerfile` + `5.19.6/.env` (for the image/compose). The `Dockerfile` also pins a `SHA512_VAL` checksum for the ActiveMQ tarball — bumping `ACTIVEMQ_VER` requires updating that hash or the build fails the checksum gate.
- **Jetty `jetty-jaas`/`jetty-security`/`jetty-util` (9.4.58, matching ActiveMQ 5.19.6's bundled Jetty 9.4.x) jars** are curl'd from Maven Central at image-build time into the broker's `lib/` — needed for the Jetty web console's `JAASLoginService`. `JETTY_VER` must track the broker's bundled Jetty (`activemq-parent` pom `jetty9-version`). (ldaptive was removed — the console now uses ActiveMQ's own `LDAPLoginModule`.)
- **Web-console symlink gotcha (`jetty.xml` `aliasChecks`)**: `ACTIVEMQ_HOME` (`/opt/activemq`) is a symlink to `/opt/apache-activemq-$ACTIVEMQ_VER`. Jetty 9.4 (ActiveMQ 5.17+) refuses to serve `WEB-INF/*` resolved through a symlink, so the console webapp's Spring context fails to load `/WEB-INF/webconsole-embedded.xml` → HTTP 503 (masked for years by the older ldaptive realm's class-load 500). The `/admin` and `/api` WebAppContexts in `jetty.xml` carry an `org.eclipse.jetty.server.handler.AllowSymLinkAliasChecker` to allow it. Ref: AMQ-7341. Do not remove it.
- The base image is `eclipse-temurin:25-jre` (Java 25 LTS). ActiveMQ 5.19.6 only *requires* Java 11 (`source`/`target` = 11 in its parent pom; the Java-8 javadoc URL in that pom is a stale link, not the compile target) but runs cleanly on Java 25 — verified by the full e2e auth/authz contract (14/14) on the `25.0.3_9-jre` base. The Dockerfile installs `curl` explicitly because the `:25` base (Ubuntu 24.04) dropped it, whereas the old `:11-jre` (Jammy) base shipped it.
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

_Last updated 2026-05-31. ActiveMQ is intentionally **not** Renovate-tracked — bumping it requires updating `SHA512_VAL` in `5.19.6/Dockerfile` for the new tarball AND re-aligning `JETTY_VER` to the broker's bundled Jetty (`activemq-parent` pom `jetty9-version`). Jetty (Maven), the Docker images, and Actions ARE Renovate-managed. Landed 2026-05-31 (see git history): ActiveMQ 5.16.1→5.19.6 (Java 8→11, clears CVE-2023-46604 OpenWire RCE), Jetty→9.4.58, phpLDAPadmin→leenooks v2, LAM→GHCR 9.5, **ldaptive removed** (the Jetty web console now authenticates via ActiveMQ's own `LDAPLoginModule`; fixed a Jetty-9.4 symlink-alias 503 with `AllowSymLinkAliasChecker`)._

- [ ] **OpenLDAP stays on `osixia/openldap:1.5.0` — no clean maintained drop-in exists (deep-researched 2026-05-31).** The demo's authz tree deliberately reuses non-unique `cn=admin`/`cn=read`/`cn=write` permission groups under every destination, which **requires a bare `slapd`** — every modern *curated* image rejects it. Verdicts: `symas/openldap` not published on Docker Hub (404); `bitnami`/`bitnamilegacy` dead/frozen (Broadcom Aug 2025); `nfrastack`/tiredofit halts on sudo-init fragility (host + CI risk); `vegardit/openldap` (maintained) enforces a `unique` cn overlay → 22 constraint violations; `lldap`/`glauth` can't model the schema; `389ds` is a different server (major migration). Revisit if Symas publishes a Docker Hub image, or build from `Symas/containers` as a dedicated task.
- [ ] Reconsider the **Jetty overlay-jar pattern** — `jetty-{jaas,security,util}` are curled into `lib/` at `JETTY_VER`, coupling them to the broker's internals. ActiveMQ 5.19.6 already bundles Jetty 9.4.58; check whether any of the three are now redundant and overlay only what the distribution lacks (`jetty-jaas`).
- [ ] CI Trivy scan stays **report-only** (`exit-code: '0'`). The 5.19.6 upgrade cleared the actively-exploited RCE (CVE-2023-46604) and all base-OS + ActiveMQ-core-jar CVEs, but ~14 fixable HIGH/CRITICAL remain in ActiveMQ-**bundled transitive jars** (`camel-core 2.25.4`, `spring 5.3.39`, `jetty-http 9.4.58`) + a base-image Go stdlib binary — none is the RCE, none is fixable without overriding ActiveMQ's own bundled jars (fragile) or a base-image refresh. Triage + override these before flipping the gate to `'1'`.
