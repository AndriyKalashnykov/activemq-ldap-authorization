[![CI](https://github.com/AndriyKalashnykov/activemq-ldap-authorization/actions/workflows/docker-image.yml/badge.svg?branch=master)](https://github.com/AndriyKalashnykov/activemq-ldap-authorization/actions/workflows/docker-image.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/activemq-ldap-authorization.svg?style=flat&label=hits&color=33CD56)](https://hits.sh/github.com/AndriyKalashnykov/activemq-ldap-authorization/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/activemq-ldap-authorization)

# ActiveMQ LDAP Authentication and Authorization

Reference demo of delegating **Apache ActiveMQ 5.19.6** authentication and per-destination authorization to LDAP instead of a local user file. The **runtime surface** swaps between three directory backends — OpenLDAP, Apache DS (Microsoft AD mimic), and Samba AD — drives the broker's JAAS `LDAPLoginModule` and `cachedLDAPAuthorizationMap` from env-templated config, and secures the Jetty web console; the **delivery surface** adds a `bats` unit suite for the templating logic, an asserting Docker-Compose e2e (the full authN/authZ matrix), and a GitHub Actions pipeline that builds both Dockerfiles with a Trivy CVE scan, on Renovate-managed pins.

```mermaid
C4Context
    title ActiveMQ LDAP Authentication and Authorization

    Person(client, "Messaging client", "Produces/consumes over OpenWire, AMQP, STOMP, MQTT")
    Person(operator, "Operator", "Browses and manages the directory")

    System(amq, "ActiveMQ Broker", "JAAS LDAPLoginModule (authN) + cachedLDAPAuthorizationMap (authZ); secured Jetty console")
    System_Ext(ldap, "LDAP Directory", "OpenLDAP / Apache DS / Samba AD: users, groups, per-destination ACLs")
    System_Ext(ui, "phpLDAPadmin / LAM", "LDAP web admin UI")

    Rel(client, amq, "Connect, produce/consume", "authenticated")
    Rel(amq, ldap, "Bind + authorize", "LDAP/LDAPS")
    Rel(operator, ui, "Manage entries", "HTTPS")
    Rel(ui, ldap, "Read/write", "LDAP")
```

## Table of Contents

- [Tech Stack](#tech-stack)
- [How it works](#how-it-works)
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Web consoles](#web-consoles)
- [LDAP backends](#ldap-backends)
- [Verifying authentication & authorization](#verifying-authentication--authorization)
- [Configuration](#configuration)
- [Make targets](#make-targets)
- [CI/CD](#cicd)
- [License](#license)

## Tech Stack

| Component | Technology |
|-----------|------------|
| Message broker | Apache ActiveMQ 5.19.6 (`andriykalashnykov/docker-activemq:5.19.6`) |
| Broker runtime | `eclipse-temurin:11-jre` (Java 11) |
| Web console auth | Jetty 9.4.58 (`jetty-jaas`, `jetty-security`, `jetty-util`); JAAS delegated to ActiveMQ's `LDAPLoginModule` |
| Directory (default) | OpenLDAP — `osixia/openldap:1.5.0` |
| Directory (AD mimic) | Apache DS — `andriykalashnykov/apacheds-ad` |
| Directory (AD) | Samba AD domain controller — `ubuntu:24.04` base |
| LDAP admin UI | phpLDAPadmin — `phpldapadmin/phpldapadmin:2.3.11` (maintained leenooks v2; HTTP on :8080) |
| LDAP account manager | LAM — `ghcr.io/ldapaccountmanager/lam:9.5` (standalone `openldap/` stack) |
| Orchestration | Docker Compose v2 |

## How it works

ActiveMQ never owns its own user/role database. Two broker plugins, configured in [`5.19.6/conf/activemq.xml`](5.19.6/conf/activemq.xml), delegate to LDAP at runtime:

- **Authentication** — `jaasAuthenticationPlugin` using the `LDAPLogin` realm defined in [`5.19.6/conf/login.config`](5.19.6/conf/login.config) (`org.apache.activemq.jaas.LDAPLoginModule`).
- **Authorization** — `authorizationPlugin` with a `cachedLDAPAuthorizationMap` that reads queue/topic/temp permissions from LDAP group entries and refreshes them on an interval.
- **Web console** — the Jetty admin console ([`5.19.6/conf/jetty.xml`](5.19.6/conf/jetty.xml)) authenticates against the **same** `LDAPLogin` realm via a `JAASLoginService`; LDAP group `cn`s map to the `users`/`admins` console roles. Both the broker and the console share one LDAP login module.

The shipped `activemq.xml` and `login.config` are **templates**: they contain `##### PLACEHOLDER #####` tokens that the container entrypoint ([`5.19.6/init.sh`](5.19.6/init.sh)) rewrites from environment variables (`LDAP_HOST`, `LDAP_QUEUE_SEARCH_BASE`, …) at startup. To change the LDAP wiring, set the env vars — never hardcode values into the config files.

## Quick Start

Start the default stack — OpenLDAP + ActiveMQ + phpLDAPadmin:

```bash
make up                       # or: docker compose -f 5.19.6/docker-compose.yml up
```

Then open the [web consoles](#web-consoles). Stop everything with `make down`.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose v2](https://docs.docker.com/compose/install/) (`docker compose`)
- `make` (optional, for the convenience targets below)

## Architecture

The [C4 context diagram](#activemq-ldap-authentication-and-authorization) above shows the system boundary. All backends serve the same base DN `dc=activemq,dc=apache,dc=org`:

| Entry | Purpose |
|-------|---------|
| `ou=User,ou=ActiveMQ` | User entries (`uid=admin`, `uid=user`), matched by `(uid={0})` for login |
| `ou=Group,ou=ActiveMQ` | Role groups (`groupOfNames`), matched by `member=uid={1}` |
| `ou=Destination,ou=ActiveMQ` → `ou=Queue` / `ou=Topic` / `ou=Temp` | Authorization entries — group membership grants admin/read/write on destinations |
| `cn=mqbroker,ou=Services,...` | The broker's own bind account |

## Web consoles

| Console | URL | Credentials |
|---------|-----|-------------|
| ActiveMQ admin | http://127.0.0.1:8161/admin/ | login `admin` / password `admin` |
| phpLDAPadmin | http://localhost:6443/ | Login DN `cn=admin,dc=activemq,dc=apache,dc=org` / password `admin` |

> The `admin`/`admin` and `user`/`admin` credentials are intentional demo values (the LDIFs store `{SHA}` hashes of `admin`), not secrets.

## LDAP backends

The default stack uses OpenLDAP. Two alternative directory backends are provided:

```bash
# Apache DS (mimics Microsoft AD; LDAP on host port 10389)
cd apacheds-ad && docker compose up

# Samba AD domain controller
cd samba
docker build -t dev-ad -f Dockerfile .
docker run --name dev-ad --hostname ak --privileged -p 636:636 \
  -e SMB_ADMIN_PASSWORD='admin123!' \
  -v "$PWD/:/opt/ad-scripts" -v "$PWD/samba-data:/var/lib/samba" dev-ad
```

For Apache DS, log in to phpLDAPadmin with DN `cn=mqbroker,ou=Services,ou=ActiveMQ,dc=activemq,dc=apache,dc=org` / password `admin`.

## Verifying authentication & authorization

```bash
make test                # bats unit tests for the init.sh config-templating logic
make e2e                 # bring up the stack, assert the LDAP authN/authZ contract, tear down
make search-openldap     # manual: ldapwhoami + ldapsearch against OpenLDAP (port 389)
make search-apacheds     # manual: same against Apache DS (port 10389)
```

`make e2e` ([`e2e/e2e-test.sh`](e2e/e2e-test.sh)) is the asserting end-to-end test. It composes the OpenLDAP + ActiveMQ stack and verifies, with pass/fail assertions:

- the broker boots and config templating fully resolved (no leftover `##### … #####` placeholders);
- authentication rejects invalid credentials;
- the **authorization matrix** is enforced — `admin` may write `ADMINS.*`, `user` may write `USERS.*`, and `user` is **denied** `ADMINS.*` — exercising the `cachedLDAPAuthorizationMap` rules;
- the LDAP seed (users, groups, memberships) is present.

> The harness waits for the `cachedLDAPAuthorizationMap` to warm up before asserting: immediately after startup the cache is cold (OpenLDAP may still be importing the LDIF) and every producer is transiently denied on the advisory topic. `make e2e` sets a short `LDAP_REFRESH_INTERVAL` so warm-up is fast and deterministic.

## Configuration

Operator-tunable values live in two files (keep version pins in sync between them):

- [`5.19.6/.env`](5.19.6/.env) — consumed by `docker-compose`: LDAP DNs/search bases, ports, JVM/store sizing, log rotation.
- [`scripts/set-env.sh`](scripts/set-env.sh) — consumed by the helper scripts: version pins (`ACTIVEMQ_VER`, `JETTY_VER`, `LDAPTIVE_VER`), image and container names, and the (commented-out) `DOCKER_LOGIN` / `DOCKER_PWD` DockerHub credentials used by `make push`.

## Make targets

| Target | Description |
|--------|-------------|
| `make help` | List all targets |
| `make build` | Build the ActiveMQ broker image |
| `make build-samba` | Build the Samba AD image |
| `make scan` | Trivy CVE scan of the built broker image |
| `make push` | Push the broker image (needs `DOCKER_LOGIN` + `DOCKER_PWD` in env) |
| `make up` / `make down` / `make logs` | Manage the default Compose stack |
| `make test` | Unit tests (bats — config templating) |
| `make e2e` | Bring up stack + assert the LDAP authN/authZ contract |
| `make ci` | Local pipeline: lint + test + build + scan |

## CI/CD

GitHub Actions ([`CI`](.github/workflows/docker-image.yml)) runs on every push and pull request to `master`:

| Job | What it does |
|-----|--------------|
| `build` | Matrix-builds both Dockerfiles (`5.19.6/`, `samba/`), each followed by a Trivy CVE scan |
| `test` | `bats` unit tests for the config-templating logic |
| `e2e` | Builds the broker image, composes the OpenLDAP + ActiveMQ stack, and asserts the LDAP authN/authZ matrix |

The Trivy scan is **report-only** (`exit-code: 0`): the base image and ActiveMQ-bundled transitive deps carry CVEs tracked in [`CLAUDE.md`](CLAUDE.md)'s upgrade backlog. No repository secrets are required. Dependency pins (Jetty via Maven, the Docker images, and GitHub Actions) are kept current by [Renovate](https://docs.renovatebot.com/). A weekly [`Cleanup old workflow runs`](.github/workflows/cleanup-runs.yml) workflow prunes old runs and caches.

## License

Released under the [MIT License](LICENSE).
