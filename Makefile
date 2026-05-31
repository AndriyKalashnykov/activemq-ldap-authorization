SHELL := /bin/bash
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
# renovate: datasource=docker depName=minlag/mermaid-cli
MERMAID_CLI_VERSION ?= 11.15.0

# Image reference: prefix with the DockerHub login when set, else build local.
ACTIVEMQ_IMAGE := $(if $(DOCKER_LOGIN),$(DOCKER_LOGIN)/,)$(IMAGE_NAME):$(ACTIVEMQ_VER)
SAMBA_IMAGE_REF := $(if $(DOCKER_LOGIN),$(DOCKER_LOGIN)/,)$(SAMBA_IMAGE):$(SAMBA_VER)
SAMBA_DOCKERFILE := samba/Dockerfile

.PHONY: help deps lint mermaid-lint build build-samba build-openldap build-hawtio scan push up down logs test e2e e2e-samba \
        search-openldap search-apacheds clean ci renovate-validate

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make <target>\n\nTargets:\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

deps: ## Verify required local tooling is installed
	@command -v docker >/dev/null || { echo "docker not found"; exit 1; }
	@docker compose version >/dev/null 2>&1 || { echo "docker compose v2 not found"; exit 1; }

lint: ## Lint the Dockerfiles with hadolint
	hadolint $(ACTIVEMQ_VER)/Dockerfile $(SAMBA_DOCKERFILE) openldap/Dockerfile hawtio/Dockerfile

mermaid-lint: ## Validate the README Mermaid diagram(s) via minlag/mermaid-cli
	@# Default entrypoint already supplies -p /puppeteer-config.json (--no-sandbox).
	@# Repo mounted read-only; render into the mermaidcli user's own home (writable;
	@# mmdc writes per-chart SVGs to cwd) and discard it — we only gate on parse success.
	@docker run --rm -e PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
		-v "$$PWD:/data:ro" -w /home/mermaidcli \
		minlag/mermaid-cli:$(MERMAID_CLI_VERSION) -i /data/README.md -o /home/mermaidcli/out.md

build: ## Build the ActiveMQ broker image ($(ACTIVEMQ_VER)/Dockerfile)
	DOCKER_BUILDKIT=1 docker build -f $(ACTIVEMQ_VER)/Dockerfile -t $(ACTIVEMQ_IMAGE) $(ACTIVEMQ_VER)

build-samba: ## Build the Samba AD domain-controller image
	DOCKER_BUILDKIT=1 docker build -f $(SAMBA_DOCKERFILE) -t $(SAMBA_IMAGE_REF) samba

build-openldap: ## Build the OpenLDAP image (Symas packages; openldap/Dockerfile)
	DOCKER_BUILDKIT=1 docker build -t $(OPENLDAP_IMAGE) openldap

build-hawtio: ## Build the hawtio console image (Tomcat 11 + hawtio; hawtio/Dockerfile)
	DOCKER_BUILDKIT=1 docker build -t $(HAWTIO_IMAGE) hawtio

scan: ## Scan the built broker image for CRITICAL/HIGH CVEs
	trivy image --severity $(TRIVY_SEVERITY) --ignore-unfixed --exit-code 1 $(ACTIVEMQ_IMAGE)

push: ## Push the broker image (needs DOCKER_LOGIN + DOCKER_PWD in env)
	@test -n "$(DOCKER_LOGIN)" || { echo "DOCKER_LOGIN is required"; exit 1; }
	@test -n "$$DOCKER_PWD"     || { echo "DOCKER_PWD is required";   exit 1; }
	printf '%s' "$$DOCKER_PWD" | docker login -u "$(DOCKER_LOGIN)" --password-stdin $(DOCKER_REGISTRY)
	docker push $(ACTIVEMQ_IMAGE)

up: ## Start the OpenLDAP + ActiveMQ + phpLDAPadmin stack (detached)
	docker compose -f $(COMPOSE_FILE) up -d

down: ## Stop the stack and remove its containers
	docker compose -f $(COMPOSE_FILE) down

logs: ## Tail the stack logs
	docker compose -f $(COMPOSE_FILE) logs -f

test: ## Run bats unit tests (config-templating logic in scripts/lib.sh)
	@if command -v bats >/dev/null 2>&1; then bats tests/; else npx --yes bats tests/; fi

e2e: ## Bring up the stack, assert the LDAP authN/authZ contract, tear down
	@LDAP_REFRESH_INTERVAL=15000 docker compose -f $(COMPOSE_FILE) up -d
	@./e2e/e2e-test.sh; rc=$$?; docker compose -f $(COMPOSE_FILE) down -v; exit $$rc

e2e-samba: build-samba ## Provision the Samba AD DC and assert it serves LDAP (needs --privileged)
	@SAMBA_IMAGE_REF="$(SAMBA_IMAGE_REF)" ./e2e/e2e-samba.sh

search-openldap: ## ldapsearch against the running OpenLDAP backend
	./scripts/search-openldap.sh

search-apacheds: ## ldapsearch against the running Apache DS backend
	./scripts/search-apacheds.sh

clean: ## Remove the locally built broker image
	-docker rmi -f $(ACTIVEMQ_IMAGE)

renovate-validate: ## Validate renovate.json against the Renovate schema
	npx --yes --package renovate -- renovate-config-validator

ci: lint mermaid-lint test build scan ## Local CI pipeline: lint, mermaid-lint, bats unit tests, build, scan
