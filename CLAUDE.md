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
- `apacheds-ad/` — Apache DS (AD-mimic) backend stack. `Dockerfile` runs the `ldap-server.jar` release of the companion repo `github.com/AndriyKalashnykov/ldap-server` (a kwart/ldap-server fork; `Main-Class com.github.kwart.ldap.LdapServer`) on `eclipse-temurin:25-jre`, pinned by an **immutable dated release tag** (`LDAP_SERVER_RELEASE`, e.g. `2026-06-04`) **and** SHA256, importing LDIFs from `/ldap/ldif`. **Do not pin the mutable `latest` release tag** — its asset is re-uploaded on every upstream rebuild, which silently breaks the SHA256 gate (this happened: the `latest` jar was re-uploaded 2026-06-04, one day after the SHA was pinned, breaking the build until it was re-pinned to the immutable `2026-06-04` release). To bump: cut a new immutable dated release in `ldap-server`, then bump `LDAP_SERVER_RELEASE` + `LDAP_SERVER_JAR_SHA256` together. The pin is manually managed (not Renovate-tracked), like the ActiveMQ tarball. LDAP on host port `10389`; the partition is rooted at `ou=ActiveMQ,...` (no `dc=activemq` root entry) and requires an authenticated bind (anonymous bind disabled). `ldif/users.ldif` adds Microsoft `sAMAccountName`/`memberOf` schema to mimic AD. Built by `make build-apacheds`; the 5th image in the CI `docker` matrix (Trivy-clean once `/usr/bin/pebble` is removed).
- `openldap/` — standalone OpenLDAP compose + seed LDIF, used by `scripts/start-openldap.sh`.
- `samba/` — Samba-as-AD domain controller (`ubuntu:26.04` `Dockerfile` + provisioning scripts), an alternative to Apache DS. The scripts (`samba-ad-setup.sh`/`samba-ad-run.sh`) are **bind-mounted** at runtime into `/opt/ad-scripts`, not baked into the image.
- `hawtio/` — standalone hawtio management console (`Dockerfile` = Tomcat 11 + hawtio 5.x WAR on Java 25; `docker-entrypoint.sh` templates `login.config`). LDAP-secured via the **same** `LDAPLogin` realm as the broker (`activemq-jaas` + `slf4j-api` jars added to Tomcat's classpath for `LDAPLoginModule`+`GroupPrincipal`). Connects to the broker's LDAP-secured Jolokia (`/api/jolokia`) via hawtio's Connect tab. A service in the primary compose (host port 8090).
- `scripts/` — operational helpers (see below); `scripts/lib.sh` holds the sourceable, unit-tested config-templating functions.
- `tests/templating.bats` — `bats` unit tests for `scripts/lib.sh` (the env→config substitution logic). Run via `make test`.
- `e2e/e2e-test.sh` — asserting end-to-end test of the LDAP authN/authZ contract against the composed stack. Run via `make e2e`.
- `e2e/e2e-samba.sh` — asserting e2e for the Samba AD DC: provisions the DC (`--privileged`), then asserts LDAP/LDAPS/Kerberos/GC ports listen, the domain is provisioned, and an authenticated LDAPS search returns the Administrator entry. Run via `make e2e-samba`.
- `e2e/e2e-apacheds.sh` — asserting e2e for the Apache DS (AD-mimic) image: runs it with the AD seed, then asserts LDAP serves, an authenticated `mqbroker` bind reads the directory, the Microsoft `sAMAccountName` schema is served, and the full seed (49 entries) loaded. The LDAP client runs in a throwaway `alpine`+`openldap-clients` container sharing the server's netns (the apacheds image is JRE-only). Run via `make e2e-apacheds`.
- `.env.example` — committed source-of-truth defaults (LDAP/broker hosts, ports, demo creds, Samba realm/admin-password, e2e tunables); sourced by both e2e scripts.
- `.github/workflows/ci.yml` — CI (`name: CI`). Jobs: `changes` (`dorny/paths-filter` — doc-only changes skip the heavy jobs; CLAUDE.md/Makefile/configs re-included), `static-check` (`make static-check`: hadolint + README mermaid-lint), `docker` (matrix-builds the **five** Dockerfiles `6.2.6/`, `samba/`, `openldap/`, `hawtio/`, `apacheds-ad/` + **blocking** Trivy scan, `exit-code: '1'`; samba/openldap/hawtio/apacheds clean, broker waives one residual in `.trivyignore`), `test` (bats), `e2e` (compose authZ contract for queues+topics + console/hawtio LDAP login + Jolokia), `e2e-samba` (Samba AD DC serves LDAP), `e2e-apacheds` (Apache DS serves the AD seed), and `ci-pass` (single aggregate required check). Fail-fast `needs:` ordering; actions SHA-pinned.
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
Both images now have committed Dockerfiles (`apacheds-ad/Dockerfile` was added 2026-06-03; it bundles the externally-built `ldap-server.jar`). Prefer the Makefile targets (`make build`, `make build-apacheds`, …) over `build.sh` for individual images.

### Test layers
```bash
make test                # unit: bats over scripts/lib.sh config-templating logic
make e2e                 # e2e: compose up → assert LDAP authN/authZ matrix (queues+topics) + Jolokia → tear down
make e2e-samba           # e2e: build + provision the Samba AD DC → assert it serves LDAP → tear down
make e2e-apacheds        # e2e: build + run the Apache DS image → assert it serves the AD seed → tear down
./scripts/search-openldap.sh   # manual ldapsearch against OpenLDAP (port 389)
./scripts/search-apacheds.sh   # manual ldapsearch against Apache DS (port 10389)
```
`make e2e` ([`e2e/e2e-test.sh`](e2e/e2e-test.sh)) is the asserting authorization test: it produces as `admin`/`user` against queues they should and should not write to and asserts the outcomes (`admin`→`ADMINS.*` allowed, `user`→`USERS.*` allowed, `user`→`ADMINS.*` denied), exercising `cachedLDAPAuthorizationMap` (for both queues and topics), plus the console/hawtio LDAP logins and the broker's LDAP-secured Jolokia endpoint. `scripts/poke-activemq.sh` is the older, non-asserting exploration script (superseded by the e2e harness; kept for manual poking).

**Known startup behavior — authz cache warm-up (non-obvious):** `cachedLDAPAuthorizationMap` is cold for a short window after the broker starts (OpenLDAP may still be importing the LDIF; the map populates on first refresh). During that window **every** producer is denied on `topic://ActiveMQ.Advisory.Connection` — including `admin` — so an authz test that runs too early sees spurious denials. Once warm, the real per-destination matrix is enforced. `e2e/e2e-test.sh` polls `admin`→`queue://TEST` until it succeeds before asserting, and `make e2e` sets a short `LDAP_REFRESH_INTERVAL` (15s) so warm-up is fast and deterministic. The production default `LDAP_REFRESH_INTERVAL` is 300000ms (5 min) — see `6.2.6/.env`.

### Local (non-Docker) broker
`scripts/install-activemq-local.sh` downloads ActiveMQ to `/opt` and drops the Jetty jars in; `run-activemq-local.sh` / `stop-activemq-local.sh` manage it. These are an alternative to the container path and use `sudo`.

### CI locally
```bash
docker build ./6.2.6 --file ./6.2.6/Dockerfile --tag amq-test:local
```
This is exactly what the `ci.yml` workflow runs.

## Conventions & Gotchas

- **Version pins live in two places**: `scripts/set-env.sh` (for scripts) and `6.2.6/Dockerfile` + `6.2.6/.env` (for the image/compose). The `Dockerfile` also pins a `SHA512_VAL` checksum for the ActiveMQ tarball — bumping `ACTIVEMQ_VER` requires updating that hash or the build fails the checksum gate.
- **Jetty (11.0.26) ships bundled with ActiveMQ 6.2.6** — including `jetty-jaas` (in `lib/web/`), which the web console's `JAASLoginService` needs. No Jetty overlay jar is curled (5.19.6 had to overlay `jetty-jaas`; 6.x bundles it). `JETTY_VER` (in `set-env.sh`) is kept aligned with the broker's bundled Jetty (`activemq-parent` pom `jetty-version`) for reference + Renovate tracking.
- **Web-console symlink gotcha (`jetty.xml` `aliasChecks`)**: `ACTIVEMQ_HOME` (`/opt/activemq`) is a symlink to `/opt/apache-activemq-$ACTIVEMQ_VER`. Jetty refuses to serve `WEB-INF/*` resolved through a symlink, so the console webapp's Spring context fails to load `/WEB-INF/webconsole-embedded.xml` → HTTP 503. The `/admin` and `/api` WebAppContexts carry an `org.eclipse.jetty.server.handler.AllowSymLinkAliasChecker` to allow it. Ref: AMQ-7341. On Jetty 11 (6.2.6) this class logs a deprecation warning (replacement: `org.eclipse.jetty.server.SymlinkAllowedResourceAliasChecker`) but still works — verified by the e2e console login. Do not remove it.
- **Jetty-11 `pathSpec` gotcha (`jetty.xml`)**: Jetty 11 enforces the Servlet spec strictly, so the 5.19.6/Jetty-9.4 comma-list `pathSpec="/*,/api/*,/admin/*,*.jsp"` is rejected at startup ("Servlet Spec 12.2 violation: glob '*' can only exist at end of prefix"). The securityConstraintMapping uses `pathSpec="/"` (the catch-all, matching stock 6.2.6).
- The base image is `eclipse-temurin:25-jre` (Java 25 LTS). ActiveMQ 6.2.6 *requires* Java 17 (`requireJavaVersion [17,)` + `target` = 17 in its parent pom); Java 25 satisfies it. Verified by the full e2e auth/authz contract (14/14) on the `25.0.3_9-jre` base. The Dockerfile installs `curl` explicitly because the `:25` base (Ubuntu 24.04) dropped it.
- **Logging (`init.sh` runs `activemq console`; no extra config needed)**: ActiveMQ 6.x logs via **Log4j2** (`conf/log4j2.properties`) — a Console appender → **stdout** (so `docker logs` shows broker logs) plus a `RollingFile` → `data/activemq.log`. `init.sh` ends with `exec activemq console` (foreground, the broker as the container's main process — the same `CMD` the official `apache/activemq-classic` image uses), not the old `activemq start && tail -f` daemonize-then-tail anti-pattern. No bespoke logging config is warranted; JSON layout (Log4j2 `JsonTemplateLayout`) is available for log aggregation but unnecessary for a demo.
- **`logQuery`/fabric8 bean removed (gone since ActiveMQ 5.17, absent in 6.x)**: the stock `activemq.xml` historically carried `<bean id="logQuery" class="io.fabric8.insight.log.log4j.Log4jLogQuery"/>` (a JMX MBean exposing logs to the console). **fabric8-insight was Log4j-1.x-only and was dropped in the 5.17 Log4j2 migration** (AMQ-8604: the insight-log jars present in 5.16.4 are gone from 5.17.1+), so keeping the bean throws `ClassNotFoundException` at startup. It is correctly omitted (matches the stock 6.2.6 `activemq.xml`); there is **no built-in replacement** for the console log-view, and upstream fabric8.io is archived (Nov 2025) — rely on `docker logs` (stdout).
- **Samba AD on Ubuntu 26.04 — explicit AD-DC packages (`samba/Dockerfile`)**: 26.04 stopped pulling the AD-DC pieces in transitively via `samba` (they were present on 24.04), so each is named explicitly: `samba-ad-dc` (the `/usr/sbin/samba` daemon — else "samba: command not found"), `samba-ad-provision` (AD DS schema — else "AD_DS_Attributes…v1903.ldf not found"), `samba-dsdb-modules` (DSDB ldb modules — else "Unable to load modules for secrets.ldb"), `samba-vfs-modules` (sysvol). `ldap-utils` is added for the e2e's over-the-wire LDAPS assertion. Provisioning needs `--privileged` (sysvol NT-ACL xattrs) on any base, not a 26.04 quirk. Guarded by `make e2e-samba`.
- **Static analysis (`make static-check` = `make lint` + `make mermaid-lint`)**: `make lint` hadolints all five Dockerfiles via a pinned `hadolint/hadolint` image (`.hadolint.yaml` sets `failure-threshold: error`, so `DL3008` apt-pin advisories don't fail); `make mermaid-lint` validates the README C4 Mermaid diagram via a pinned `minlag/mermaid-cli` image. `make static-check` is the composite gate run by the CI `static-check` job and by `make ci`. `make ci-run` runs the act-runnable jobs (`static-check` + `test`) locally.
- **Tooling pins**: `hadolint`, `trivy` and `mermaid-cli` are consumed via pinned `docker run` images (Renovate-tracked `# renovate:` Makefile pins — the docker-run exception to the mise policy, since this repo has no language toolchain). `act` is the one mise-managed tool — pinned in **`.mise.toml`** (`aqua:nektos/act`, tracked by Renovate's native mise manager) and used only by the local `make ci-run`; CI never runs `act`, so no job needs `jdx/mise-action`.
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

_Last updated 2026-06-13. ActiveMQ is intentionally **not** Renovate-tracked — bumping it requires updating `SHA512_VAL` in `6.2.6/Dockerfile` for the new tarball AND re-aligning `JETTY_VER` to the broker's bundled Jetty (`activemq-parent` pom `jetty-version`). The `apacheds-ad` `ldap-server.jar` pin is likewise manually managed — pinned to an **immutable dated release tag** (not the mutable `latest`); bump `LDAP_SERVER_RELEASE` + `LDAP_SERVER_JAR_SHA256` together against a freshly-cut immutable release. Jetty (Maven), the Docker/tool images, and Actions ARE Renovate-managed. Migration history (ActiveMQ 5.16.1→5.19.6→6.2.6, OpenLDAP osixia→self-built Symas, the Trivy blocking gate, the hawtio console, the committed `apacheds-ad/Dockerfile`, and the 2026-06-13 switch of the `ldap-server.jar` pin from the mutable `latest` tag to the immutable `2026-06-04` release) lives in git history and the sections above; only genuinely-deferred items are listed below._

- [ ] **Jetty 12 / future ActiveMQ line.** The lone remaining CVE waiver (`jetty-http` CVE-2026-2332) needs Jetty 12, which ActiveMQ Classic 6.2.x does not bundle. Revisit when an ActiveMQ line ships Jetty 12.
