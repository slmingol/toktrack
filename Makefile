.DEFAULT_GOAL := help

PODMAN          := $(shell command -v podman 2>/dev/null)
DOCKER          := $(shell command -v docker 2>/dev/null)
DOCKER_COMPOSE  := $(shell command -v docker-compose 2>/dev/null)

ifdef PODMAN
  RUNTIME := podman
else ifdef DOCKER
  RUNTIME := docker
else
  $(error Neither docker nor podman found in PATH)
endif

ifdef DOCKER_COMPOSE
  COMPOSE := docker-compose
else
  COMPOSE := $(RUNTIME) compose
endif

GHCR_OWNER ?= slmingol
GHCR_IMAGE  := ghcr.io/$(GHCR_OWNER)/toktrack:latest

.PHONY: check fmt clippy test build release setup docker-build docker-pull docker-run docker-report _ensure-image help

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Dev"
	@echo "  check        fmt + clippy + test (pre-commit)"
	@echo "  fmt          Format code"
	@echo "  clippy       Lint (warnings = errors)"
	@echo "  test         Run tests"
	@echo "  build        Build debug binary"
	@echo "  release      Build release binary"
	@echo "  setup        Configure git hooks"
	@echo ""
	@echo "Container (docker or podman, auto-detected)"
	@echo "  docker-build  Build image locally"
	@echo "  docker-pull   Pull image from GHCR explicitly"
	@echo "  docker-run    Launch TUI (GHCR if available, local build fallback). ARGS= for extra flags"
	@echo "  docker-report CLI report mode (GHCR if available, local build fallback). ARGS= for extra flags"

# Run all checks (used by pre-commit)
check: fmt-check clippy test

# Format code
fmt:
	cargo fmt --all

# Check formatting without modifying
fmt-check:
	cargo fmt --all -- --check

# Run clippy
clippy:
	cargo clippy --all-targets --all-features -- -D warnings

# Run tests
test:
	cargo test

# Build debug
build:
	cargo build

# Build release
release:
	cargo build --release

# Docker/Podman: build image locally (tags as GHCR image name)
docker-build:
	$(COMPOSE) build

# Pull GHCR image explicitly
docker-pull:
	$(RUNTIME) pull $(GHCR_IMAGE)

# Ensure image is available: local cache → GHCR pull → local build
_ensure-image:
	@$(RUNTIME) image inspect $(GHCR_IMAGE) >/dev/null 2>&1 \
	    || $(RUNTIME) pull $(GHCR_IMAGE) 2>/dev/null \
	    || (echo "[toktrack] GHCR unavailable, building locally..." && $(COMPOSE) build --quiet)

# Docker/Podman: run TUI (interactive). Pass extra args via ARGS=: make docker-run ARGS=weekly
docker-run: _ensure-image
	@$(RUNTIME) run --rm -it \
	    -e TERM=$(TERM) \
	    -e COLORTERM=$(COLORTERM) \
	    -v $(HOME)/.claude:/root/.claude:ro \
	    -v $(HOME)/.codex:/root/.codex:ro \
	    -v $(HOME)/.gemini:/root/.gemini:ro \
	    -v $(HOME)/.local/share/opencode:/root/.local/share/opencode:ro \
	    -v $(HOME)/.toktrack:/root/.toktrack \
	    $(GHCR_IMAGE) $(ARGS)

# Docker/Podman: run CLI report (non-interactive). Pass extra args via ARGS=
docker-report: _ensure-image
	@$(RUNTIME) run --rm \
	    -e TERM=$(TERM) \
	    -e COLORTERM=$(COLORTERM) \
	    -v $(HOME)/.claude:/root/.claude:ro \
	    -v $(HOME)/.codex:/root/.codex:ro \
	    -v $(HOME)/.gemini:/root/.gemini:ro \
	    -v $(HOME)/.local/share/opencode:/root/.local/share/opencode:ro \
	    -v $(HOME)/.toktrack:/root/.toktrack \
	    $(GHCR_IMAGE) report $(ARGS)

# Setup git hooks
setup:
	git config core.hooksPath .githooks
	@echo "Git hooks configured!"
