SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Tunables — override via the environment, e.g. `make build DOCKER_LOGIN=me`.
# Mirror scripts/set-env.sh; keep version pins in sync when bumping.
# ---------------------------------------------------------------------------
ACTIVEMQ_VER     ?= 6.2.6
IMAGE_NAME       ?= docker-activemq
APACHEDS_IMAGE   ?= apacheds-ad
APACHEDS_VER     ?= latest
SAMBA_IMAGE      ?= samba-ad
SAMBA_VER        ?= latest
OPENLDAP_IMAGE   ?= activemq-openldap:latest
HAWTIO_IMAGE     ?= activemq-hawtio:latest
DOCKER_LOGIN     ?=
DOCKER_REGISTRY  ?= docker.io
COMPOSE_FILE     ?= $(ACTIVEMQ_VER)/docker-compose.yml
TRIVY_SEVERITY   ?= CRITICAL,HIGH
# hadolint, trivy and mermaid-cli are consumed via `docker run` (pinned images),
# NOT installed as binaries — the documented "docker-run exception" to the mise
# version-manager policy (same as plantuml). `act` is the one mise-managed tool
# (see .mise.toml); it is only used by the local `make ci-run` target.
# renovate: datasource=docker depName=minlag/mermaid-cli
MERMAID_CLI_VERSION ?= 11.15.0
# renovate: datasource=docker depName=hadolint/hadolint
HADOLINT_VERSION ?= v2.14.0
# renovate: datasource=docker depName=aquasec/trivy
TRIVY_VERSION    ?= 0.70.0
# act runner image (catthehacker), pinned to a DATED (immutable) tag — the
# floating `act-22.04` tag is republished weekly. Bump by hand: list current
# dated tags at hub.docker.com/r/catthehacker/ubuntu/tags?name=act-22.04-
ACT_RUNNER_IMAGE ?= catthehacker/ubuntu:act-22.04-20260601

# Image reference: prefix with the DockerHub login when set, else build local.
ACTIVEMQ_IMAGE := $(if $(DOCKER_LOGIN),$(DOCKER_LOGIN)/,)$(IMAGE_NAME):$(ACTIVEMQ_VER)
SAMBA_IMAGE_REF := $(if $(DOCKER_LOGIN),$(DOCKER_LOGIN)/,)$(SAMBA_IMAGE):$(SAMBA_VER)
APACHEDS_IMAGE_REF := $(if $(DOCKER_LOGIN),$(DOCKER_LOGIN)/,)$(APACHEDS_IMAGE):$(APACHEDS_VER)
SAMBA_DOCKERFILE := samba/Dockerfile

.PHONY: help deps deps-act lint mermaid-lint static-check build build-samba build-openldap build-hawtio build-apacheds scan push up down logs test e2e e2e-samba e2e-apacheds \
        search-openldap search-apacheds clean ci ci-run renovate-validate

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make <target>\n\nTargets:\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

deps: ## Verify required local tooling is installed
	@command -v docker >/dev/null || { echo "docker not found"; exit 1; }
	@docker compose version >/dev/null 2>&1 || { echo "docker compose v2 not found"; exit 1; }

deps-act: ## Install act (via mise; version pinned in .mise.toml) for `make ci-run`
	@command -v mise >/dev/null 2>&1 || { echo "Installing mise..."; curl -fsSL https://mise.run | sh; }
	@mise install

lint: deps ## Lint the Dockerfiles with hadolint (pinned image)
	docker run --rm -i -v "$$PWD:/repo:ro" -w /repo hadolint/hadolint:$(HADOLINT_VERSION) \
		hadolint $(ACTIVEMQ_VER)/Dockerfile $(SAMBA_DOCKERFILE) openldap/Dockerfile hawtio/Dockerfile apacheds-ad/Dockerfile

mermaid-lint: deps ## Validate the README Mermaid diagram(s) via minlag/mermaid-cli
	@# Default entrypoint already supplies -p /puppeteer-config.json (--no-sandbox).
	@# Repo mounted read-only; render into the mermaidcli user's own home (writable;
	@# mmdc writes per-chart SVGs to cwd) and discard it — we only gate on parse success.
	@docker run --rm -e PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
		-v "$$PWD:/data:ro" -w /home/mermaidcli \
		minlag/mermaid-cli:$(MERMAID_CLI_VERSION) -i /data/README.md -o /home/mermaidcli/out.md

build: deps ## Build the ActiveMQ broker image ($(ACTIVEMQ_VER)/Dockerfile)
	DOCKER_BUILDKIT=1 docker build -f $(ACTIVEMQ_VER)/Dockerfile -t $(ACTIVEMQ_IMAGE) $(ACTIVEMQ_VER)

build-samba: deps ## Build the Samba AD domain-controller image
	DOCKER_BUILDKIT=1 docker build -f $(SAMBA_DOCKERFILE) -t $(SAMBA_IMAGE_REF) samba

build-openldap: deps ## Build the OpenLDAP image (Symas packages; openldap/Dockerfile)
	DOCKER_BUILDKIT=1 docker build -t $(OPENLDAP_IMAGE) openldap

build-hawtio: deps ## Build the hawtio console image (Tomcat 11 + hawtio; hawtio/Dockerfile)
	DOCKER_BUILDKIT=1 docker build -t $(HAWTIO_IMAGE) hawtio

build-apacheds: deps ## Build the Apache DS (AD-mimic) LDAP image (apacheds-ad/Dockerfile)
	DOCKER_BUILDKIT=1 docker build -t $(APACHEDS_IMAGE_REF) apacheds-ad

scan: deps ## Scan the built broker image for CRITICAL/HIGH CVEs (pinned Trivy image; mirrors the CI gate)
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		-v "$$PWD/.trivyignore:/.trivyignore:ro" aquasec/trivy:$(TRIVY_VERSION) \
		image --severity $(TRIVY_SEVERITY) --ignore-unfixed --ignorefile /.trivyignore --exit-code 1 $(ACTIVEMQ_IMAGE)

push: ## Push the broker image (needs DOCKER_LOGIN + DOCKER_PWD in env)
	@test -n "$(DOCKER_LOGIN)" || { echo "DOCKER_LOGIN is required"; exit 1; }
	@test -n "$${DOCKER_PWD:-}" || { echo "DOCKER_PWD is required";   exit 1; }
	printf '%s' "$${DOCKER_PWD:-}" | docker login -u "$(DOCKER_LOGIN)" --password-stdin $(DOCKER_REGISTRY)
	docker push $(ACTIVEMQ_IMAGE)

up: ## Start the OpenLDAP + ActiveMQ + phpLDAPadmin stack (detached)
	docker compose -f $(COMPOSE_FILE) up -d

down: ## Stop the stack and remove its containers
	docker compose -f $(COMPOSE_FILE) down

logs: ## Tail the stack logs
	docker compose -f $(COMPOSE_FILE) logs -f

test: deps ## Run bats unit tests (config-templating logic in scripts/lib.sh)
	@if command -v bats >/dev/null 2>&1; then bats tests/; else npx --yes bats tests/; fi

e2e: deps ## Bring up the stack, assert the LDAP authN/authZ contract, tear down
	@LDAP_REFRESH_INTERVAL=15000 docker compose -f $(COMPOSE_FILE) up -d
	@./e2e/e2e-test.sh; rc=$$?; docker compose -f $(COMPOSE_FILE) down -v; exit $$rc

e2e-samba: build-samba ## Provision the Samba AD DC and assert it serves LDAP (needs --privileged)
	@SAMBA_IMAGE_REF="$(SAMBA_IMAGE_REF)" ./e2e/e2e-samba.sh

e2e-apacheds: build-apacheds ## Build the Apache DS image and assert it serves the AD-schema seed over LDAP
	@APACHEDS_IMAGE_REF="$(APACHEDS_IMAGE_REF)" ./e2e/e2e-apacheds.sh

search-openldap: ## ldapsearch against the running OpenLDAP backend
	./scripts/search-openldap.sh

search-apacheds: ## ldapsearch against the running Apache DS backend
	./scripts/search-apacheds.sh

clean: ## Remove the locally built broker image
	-docker rmi -f $(ACTIVEMQ_IMAGE)

renovate-validate: ## Validate renovate.json against the Renovate schema
	npx --yes --package renovate -- renovate-config-validator

static-check: deps lint mermaid-lint ## Composite static gate: hadolint + README Mermaid lint
	@echo "Static check passed."

ci: deps static-check test build scan ## Local CI pipeline: static-check, bats unit tests, build, scan

ci-run: deps-act ## Run the act-runnable CI jobs (static-check + test) locally via nektos/act
	@# Only the static-check (hadolint) and test (bats + mermaid-lint) jobs run
	@# under act. The docker (matrix build + Trivy), e2e, e2e-samba and
	@# e2e-apacheds jobs need real Docker / --privileged and are skipped here.
	@# `act` runs via mise (pinned in .mise.toml).
	mise exec -- act push -W .github/workflows/docker-image.yml -j static-check -P ubuntu-latest=$(ACT_RUNNER_IMAGE)
	mise exec -- act push -W .github/workflows/docker-image.yml -j test -P ubuntu-latest=$(ACT_RUNNER_IMAGE)
