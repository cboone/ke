# Bootstrap `ke` as a Rust CLI Project

## Context

`ke` is a developer-focused CLI that wraps macOS Keychain Services, providing ergonomic access to secrets for local development workflows. It fills the gap between the verbose `security` command and full-featured cloud-backed tools like 1Password's `op`. See `docs/design/ke-initial-design.md` for the full design document.

The repository has only minimal scaffolding (LICENSE, README, .gitignore) from its initial commit. It needs full project structure, CI, linters, secret scanning, community files, installers, and CLI tests to be production-ready. Since no Rust scaffolder plugin exists, Rust-specific setup will be done manually, with the remaining infrastructure handled by available plugins.

**Platform constraint**: `ke` is macOS-only (depends on Security.framework). CI and release workflows should target macOS runners. Release builds should cover `aarch64-apple-darwin` and `x86_64-apple-darwin` only (no Linux targets).

## Tool Status

| #    | Tool                      | Type    | Status         | What it does                                          |
| ---- | ------------------------- | ------- | -------------- | ----------------------------------------------------- |
| 0    | Rust scaffolding          | Manual  | Will run       | `cargo init`, Cargo.toml metadata, src/main.rs        |
| 0b   | Rust toolchain config     | Manual  | Will run       | `rust-toolchain.toml`, `.cargo/config.toml`           |
| 1    | `scaffold-new-repo`       | Command | Scoped down    | CHANGELOG, .gitignore merge, agent config             |
| 2    | `setup-ci`                | Command | Will run       | `.github/workflows/ci.yml`, Makefile                  |
| 2b   | Rust CI extras            | Manual  | Will run       | `cargo-deny`, `cargo-audit`, `cargo-nextest`, `typos` CI jobs |
| 3    | `setup-linters`           | Skill   | Will run       | EditorConfig, Prettier, markdownlint, rustfmt         |
| 4    | `setup-secret-scanning`   | Command | Will run       | Gitleaks + TruffleHog workflows                       |
| 5    | `add-community-files`     | Skill   | Will run       | CONTRIBUTING, CoC, SECURITY, PR template              |
| 6    | `setup-installers`        | Command | Will run       | Homebrew formula, install.sh, release workflow         |
| 7    | `add-scrut-cli-tests`     | Command | Will run       | Scrut CLI integration tests + CI job                  |
| 8    | Dependency automation     | Manual  | Will run       | `dependabot.yml` for Cargo dependency updates         |
| 9    | Changelog automation      | Manual  | Will run       | `git-cliff` config (`cliff.toml`)                     |
| --   | `scaffold-go-cli`         | --      | Not applicable | Go-specific                                           |
| --   | `scaffold-go-library`     | --      | Not applicable | Go-specific                                           |
| --   | `add-goreleaser-homebrew` | --      | Not applicable | Go-specific                                           |

## Execution Order

Steps 3 and 4 can run in parallel after step 2b. All others are sequential.

```
Step 0  (cargo init + metadata)
  v
Step 0b (rust-toolchain.toml, .cargo/config.toml)
  v
Step 1  (scaffold-new-repo, scoped down)
  v
Step 2  (setup-ci: CI workflow + Makefile)
  v
Step 2b (Rust CI extras: cargo-deny, cargo-audit, nextest, typos)
  |
  +--> Step 3 (setup-linters)        [parallel]
  +--> Step 4 (setup-secret-scanning) [parallel]
  v
Step 5  (add-community-files)
  v
Step 6  (setup-installers)
  v
Step 7  (add-scrut-cli-tests)
  v
Step 8  (dependabot.yml)
  v
Step 9  (git-cliff config)
```

## Step Details

### Step 0: Rust Scaffolding (Manual)

No Rust scaffolder plugin exists. Handle manually:

1. Run `cargo init` in the repo root (creates `Cargo.toml` and `src/main.rs`, respects existing `.git` and `.gitignore`).
2. Edit `Cargo.toml` metadata:
   - `name = "ke"`
   - `version = "0.1.0"`
   - `edition = "2024"`
   - `license = "MIT"`
   - `description = "A developer-focused CLI for ergonomic macOS Keychain access"`
   - `repository = "https://github.com/cboone/ke"`
   - `authors = ["Christopher Boone"]`
   - `categories = ["command-line-utilities"]`
   - `keywords = ["keychain", "secrets", "macos", "cli"]`
3. Verify with `cargo build`.

### Step 0b: Rust Toolchain and Cargo Config (Manual)

Create toolchain and cargo configuration files:

1. **`rust-toolchain.toml`**: Pin the toolchain channel and set MSRV.
   ```toml
   [toolchain]
   channel = "stable"
   components = ["clippy", "rustfmt"]
   ```
2. **`.cargo/config.toml`**: Set default build target to the host macOS triple and any useful defaults.
   ```toml
   [build]
   # Default target for macOS-only project
   # target = "aarch64-apple-darwin"  # Uncomment to pin; omit to use host default

   [target.aarch64-apple-darwin]
   rustflags = ["-C", "link-arg=-framework", "-C", "link-arg=Security"]

   [target.x86_64-apple-darwin]
   rustflags = ["-C", "link-arg=-framework", "-C", "link-arg=Security"]
   ```

Note: The Security framework linking flags may not be needed if the `security-framework` crate handles this via its build script. Verify during implementation and remove if unnecessary.

### Step 1: scaffold-new-repo (Scoped Down)

LICENSE, README, and .gitignore already exist. Only generate:

- `CHANGELOG.md` (Keep a Changelog template)
- `.gitignore` merge (add common entries: `.DS_Store`, `.env`, `.env.*`, agent config ignores, `*.pem`, `*.key`, etc.)
- Agent config files: `AGENTS.md`, `CLAUDE.md` (symlink to AGENTS.md), `.claude/settings.json`, `.github/copilot-instructions.md`
- `docs/plans/done/.gitkeep`

Read command file and follow its workflow for the scoped-down subset.

### Step 2: setup-ci

Read command file and follow workflow. Rust CI template includes:

- `.github/workflows/ci.yml` with jobs: test, lint, format, build
- `Makefile` with targets: test, lint, fmt, build, clean, help

### Step 2b: Rust CI Extras (Manual)

Add Rust-specific CI jobs and configs that the `setup-ci` plugin does not cover:

1. **`deny.toml`** (cargo-deny config): License auditing, vulnerability scanning, duplicate dependency detection.
   ```toml
   [advisories]
   vulnerability = "deny"
   unmaintained = "warn"

   [licenses]
   unlicensed = "deny"
   allow = ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "Unicode-3.0"]

   [bans]
   multiple-versions = "warn"
   wildcards = "allow"

   [sources]
   unknown-registry = "deny"
   unknown-git = "deny"
   ```
2. **CI workflow additions** (append to `.github/workflows/ci.yml`):
   - `deny` job: `cargo install cargo-deny && cargo deny check`
   - `audit` job: `cargo install cargo-audit && cargo audit`
   - `typos` job: uses `crate-ci/typos@v1` action
   - Update existing `test` job to use `cargo-nextest`: `cargo install cargo-nextest && cargo nextest run`
3. **`typos.toml`** (typos config): Minimal config with project-specific word allowlist.
   ```toml
   [default.extend-words]
   # Add project-specific terms here
   ke = "ke"
   ```
4. **Makefile additions**:
   - `deny` target: `cargo deny check`
   - `audit` target: `cargo audit`
   - `typos` target: `typos`
   - Update `test` target to use `cargo nextest run` (with fallback note in comments for `cargo test`)

### Step 3: setup-linters

Invoke via Skill tool. Full scope (no Rust scaffolder ran). Expected configs:

- `rustfmt.toml`
- `.editorconfig`
- `.prettierrc.json` + `.prettierignore`
- `.markdownlint-cli2.jsonc`

### Step 4: setup-secret-scanning

Read command file and follow workflow. Creates:

- `.github/workflows/gitleaks.yml`
- `.github/workflows/trufflehog.yml`

### Step 5: add-community-files

Invoke via Skill tool. Creates:

- `CONTRIBUTING.md` (with Cargo/Make commands)
- `CODE_OF_CONDUCT.md` (Contributor Covenant)
- `.github/SECURITY.md`
- `.github/PULL_REQUEST_TEMPLATE.md`

### Step 6: setup-installers

Read command file and follow workflow. Creates:

- `Formula/ke.rb` (Homebrew formula, macOS-only: `aarch64-apple-darwin`, `x86_64-apple-darwin`)
- `install.sh` (shell install script, macOS-only)
- `.github/workflows/release.yml` (release workflow targeting macOS runners only, no Linux targets)
- README installation section update (Homebrew, install.sh, `cargo install`)

### Step 7: add-scrut-cli-tests

Read command file and follow workflow. Creates:

- `tests/scrut/help.md` and `tests/scrut/version.md` (starter tests)
- Makefile additions: `test-scrut`, `test-scrut-update`, `test-all`
- CI workflow update: `test-scrut` job

Note: starter tests will contain placeholder output until `--help` and `--version` are implemented (e.g., via `clap`).

### Step 8: Dependency Automation (Manual)

Create `.github/dependabot.yml` for automated Cargo dependency update PRs:

```yaml
version: 2
updates:
  - package-ecosystem: "cargo"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "deps"
    labels:
      - "dependencies"
    open-pull-requests-limit: 10

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "ci"
    labels:
      - "ci"
```

This covers both Cargo dependencies and GitHub Actions version updates.

### Step 9: Changelog Automation (Manual)

Set up `git-cliff` for automated changelog generation from conventional commits:

1. **`cliff.toml`**: Configuration file for git-cliff.
   ```toml
   [changelog]
   header = "# Changelog\n\nAll notable changes to this project will be documented in this file.\n"
   body = """
   ## [{{ version | trim_start_matches(pat="v") }}] - {{ timestamp | date(format="%Y-%m-%d") }}
   {% for group, commits in commits | group_by(attribute="group") %}
   ### {{ group | upper_first }}
   {% for commit in commits %}
   - {{ commit.message | upper_first }}{% if commit.breaking %} (**BREAKING**){% endif %}\
   {% endfor %}
   {% endfor %}
   """
   trim = true

   [git]
   conventional_commits = true
   filter_unconventional = true
   commit_parsers = [
     { message = "^feat", group = "Features" },
     { message = "^fix", group = "Bug fixes" },
     { message = "^doc", group = "Documentation" },
     { message = "^perf", group = "Performance" },
     { message = "^refactor", group = "Refactoring" },
     { message = "^style", group = "Style" },
     { message = "^test", group = "Testing" },
     { message = "^chore", group = "Miscellaneous" },
     { message = "^ci", group = "CI" },
     { message = "^deps", group = "Dependencies" },
   ]
   ```
2. **Makefile addition**: `changelog` target running `git cliff -o CHANGELOG.md`.
3. **Release workflow integration**: Add a step to the release workflow (from step 6) that runs `git cliff` to generate release notes.

## Key Considerations

- **macOS-only**: CI workflows must use `macos-latest` runners (not `ubuntu-latest`). Release builds target only `aarch64-apple-darwin` and `x86_64-apple-darwin`. The setup-ci and setup-installers tools may default to Linux runners, so their output must be reviewed and adjusted.
- **Makefile is modified by 5 steps** (2, 2b, 3, 7, 9): each step adds non-overlapping targets, but verify no naming conflicts.
- **CI workflow is modified by 3 steps** (2, 2b, 7): base jobs from step 2, Rust-specific jobs from step 2b, scrut job from step 7.
- **README is modified by 2 steps** (1, 6): step 1 may expand structure, step 6 adds installation section.
- **Scrut test placeholders**: The starter `--help` and `--version` tests will need updating once `clap` is added and real output is available. Run `make test-scrut-update` at that point.
- **`.cargo/config.toml` linking flags**: The `security-framework` crate's build script likely handles Security.framework linking automatically. Verify during step 0b and remove manual rustflags if redundant.
- **cargo-nextest vs cargo test**: If `cargo-nextest` is used in CI and Makefile, keep `cargo test` as a documented fallback for contributors who don't have nextest installed locally.

## Verification

After all steps complete:

1. `cargo build` succeeds
2. `make test`, `make lint`, `make fmt` all pass
3. `cargo deny check` passes (no license or advisory issues)
4. `cargo audit` passes (no known vulnerabilities)
5. `typos` passes (no typos detected)
6. All workflow YAML files are valid
7. Run `/lint-and-fix` to clean up any initial linting issues
8. Commit the scaffolding and push to verify CI passes
