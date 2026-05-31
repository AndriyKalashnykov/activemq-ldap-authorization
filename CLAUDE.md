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
- `scripts/` — operational helpers (see below).
- `.github/workflows/docker-image.yml` — CI: builds `./5.16.1` Dockerfile only (no push, no test).

## Common Commands

All `scripts/*.sh` source `scripts/set-env.sh` for version pins (`ACTIVEMQ_VER`, `JETTY_VER`, `LDAPTIVE_VER`, image names, container names) and resolve their own directory, so they can be run from anywhere. They do **not** read `5.16.1/.env` — that file is consumed by docker-compose. The two files are independent sources of truth; keep version pins in sync when bumping.

A root `Makefile` wraps the common flows (`make help` lists them); the `scripts/*.sh` helpers below are what those targets call.

### Run the full stack (primary path)
```bash
make up                               # docker compose -f 5.16.1/docker-compose.yml up -d
# equivalently: cd 5.16.1 && docker compose up
```
- ActiveMQ web console: http://127.0.0.1:8161/admin/ (login `admin`/`admin`)
- phpLDAPadmin: https://localhost:6443/ (Login DN `cn=admin,dc=activemq,dc=apache,dc=org`, password `admin`)
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

### Verify LDAP / smoke-test authorization
```bash
./scripts/search-openldap.sh     # ldapwhoami + ldapsearch against OpenLDAP (port 389)
./scripts/search-apacheds.sh     # same against Apache DS (port 10389)
./scripts/test-activemq.sh       # produce messages as admin/user to allowed & denied destinations
```
`test-activemq.sh` is the closest thing to an authorization test: it `docker exec`s the broker's CLI producer as different users against queues/topics they should and should not be able to write to, exercising the `cachedLDAPAuthorizationMap` rules.

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
- The improvement backlog (upgrades for ActiveMQ, Jetty, ldaptive, the LDAP admin images, and JDK) is tracked below.

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.

## Improvement Backlog

- [ ] Upgrade ActiveMQ from 5.16.1 to latest 5.x or 6.x (major migration)
- [ ] Upgrade Jetty libraries from 9.4.35 to latest 9.4.x or 10.x+
- [ ] Upgrade ldaptive from 1.2.4 to latest 2.x (major migration)
- [ ] Replace osixia/openldap:1.5.0 with a maintained alternative (bitnami/openldap or similar)
- [ ] Replace osixia/phpldapadmin:0.9.0 with a maintained alternative
- [ ] Replace ldapaccountmanager/lam:7.4 with latest version
- [ ] Upgrade eclipse-temurin base from JDK 8 to JDK 11+ when ActiveMQ supports it
