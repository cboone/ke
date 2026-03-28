.PHONY: test lint fmt format format-check lint-md lint-actions build deny audit typos test-scrut test-scrut-update test-all changelog clean help

test: ## Run tests (cargo nextest, falls back to cargo test)
	@command -v cargo-nextest >/dev/null 2>&1 && cargo nextest run || cargo test

lint: ## Run clippy
	cargo clippy -- -D warnings

fmt: ## Check formatting
	cargo fmt -- --check

build: ## Build the project
	cargo build

deny: ## Check dependencies for license and vulnerability issues
	cargo deny check

audit: ## Audit dependencies for known vulnerabilities
	cargo audit

typos: ## Check for typos in source code
	typos

format: ## Format with Prettier
	prettier --write .

format-check: ## Check formatting with Prettier
	prettier --check .

lint-md: ## Lint Markdown files
	npx markdownlint-cli2 "**/*.md"

lint-actions: ## Lint GitHub Actions workflows
	actionlint

test-scrut: build ## Run scrut CLI tests
	@echo "Running scrut CLI tests..."
	@if ! command -v scrut >/dev/null 2>&1; then \
		echo "scrut not installed. Install from https://github.com/facebookincubator/scrut"; \
		exit 1; \
	fi
	KE_BIN="$(CURDIR)/target/debug/ke" scrut test tests/scrut/

test-scrut-update: build ## Update scrut test expectations
	KE_BIN="$(CURDIR)/target/debug/ke" scrut update --replace --assume-yes tests/scrut/

test-all: test test-scrut ## Run all tests (unit + scrut)

changelog: ## Generate CHANGELOG.md from conventional commits
	git cliff -o CHANGELOG.md

clean: ## Remove build artifacts
	cargo clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'
