# Migrate CI and Release Workflows to Reusable Workflows

Issue: #2

## Context

The CI and release workflows use inline job definitions. The `cboone/gh-actions` repository now provides reusable workflows for Rust CI, Rust releases, scrut testing, and GitHub Actions linting. The blocking issue (cboone/gh-actions#21) is now **closed**, meaning all four migration tasks are unblocked.

The `cboone/gh-actions` repository has tags `v1` and `v2`. The `scrut.yml` and `rust-ci.yml`/`rust-release.yml` workflows only exist at `@v2`, so all references must use `@v2` (not `@v1` as the issue text suggests). The existing `gitleaks.yml` and `trufflehog.yml` in this repo already use `@v2`.

## Decisions

- **Scope**: all four migrations (scrut, github-lint, rust-ci, rust-release)
- **Version tag**: `@v2` for all reusable workflow references
- **Archive naming**: switching to Rust target triples is acceptable (`x86_64-apple-darwin` / `aarch64-apple-darwin` instead of `darwin-amd64` / `darwin-arm64`)
- **Homebrew formula**: needs upstream improvements before release migration; filing issues on `cboone/gh-actions`
- **Sequencing**: file upstream issues first, then implement all four migrations together once fixes land

## Phase 1: File Upstream Issues (Now)

File three issues on `cboone/gh-actions` for Homebrew formula customization in `rust-release.yml`:

### Issue A: Support `homebrew-desc` input

The generated formula hardcodes `desc "${BINARY}"` (e.g., `desc "ke"`). A `homebrew-desc` input would allow callers to provide a descriptive string like "A developer-focused CLI for ergonomic macOS Keychain access".

### Issue B: Support `homebrew-depends-on` input

The generated formula has no `depends_on` declarations. macOS-only tools like `ke` need `depends_on :macos`. A `homebrew-depends-on` input (newline-delimited list) would let callers declare platform or library dependencies.

### Issue C: Support custom Homebrew test block

The generated formula uses `system bin/"ke", "--version"` for its test. Some formulas need more specific assertions (e.g., `assert_match version.to_s, shell_output("#{bin}/ke --version")`). A `homebrew-test` input would allow callers to provide a custom test block.

## Phase 2: Implement All Four Migrations (After Upstream Fixes)

### Change 1: Replace inline `test-scrut` job with `scrut.yml`

**File:** `.github/workflows/ci.yml`

Replace the `test-scrut` job (lines 150-181) with:

```yaml
  scrut:
    uses: cboone/gh-actions/.github/workflows/scrut.yml@v2
    with:
      scrut-setup-cmd: cargo build
      scrut-env: KE_BIN=./target/debug/ke
      scrut-test-dir: tests/scrut/
      runs-on: macos-latest
      timeout-minutes: 15
```

- Reusable workflow handles scrut installation with checksum verification
- `scrut-setup-cmd: cargo build` builds the binary (macOS runners have Rust pre-installed)
- `scrut-env` sets `KE_BIN`; the reusable workflow resolves `./` paths to absolute
- Job ID changes from `test-scrut` to `scrut`

### Change 2: Add GitHub Actions linting via `github-lint.yml`

**File:** `.github/workflows/ci.yml`

Add at the end of the jobs section:

```yaml
  github-lint:
    uses: cboone/gh-actions/.github/workflows/github-lint.yml@v2
```

- No inputs needed; defaults are appropriate
- Runs on ubuntu-latest (no macOS dependency)

### Change 3: Replace inline CI jobs with `rust-ci.yml`

**File:** `.github/workflows/ci.yml`

Replace the seven inline jobs (test, lint, format, build, deny, audit, typos) with:

```yaml
  ci:
    uses: cboone/gh-actions/.github/workflows/rust-ci.yml@v2
    with:
      runs-on: macos-latest
      use-nextest: true
      test-args: "--no-tests=warn"
      run-deny: true
      run-audit: true
      run-typos: true
```

- `runs-on: macos-latest` required for macOS Keychain API tests
- `use-nextest: true` + `test-args: "--no-tests=warn"` matches current test job
- `run-deny`, `run-audit`, `run-typos` enable checks that are off by default
- Defaults cover: `run-test`, `run-lint`, `run-format-check`, `clippy-args: "-D warnings"`
- The standalone `build` job is dropped (covered by test compilation)
- Each check runs as a separate job internally, preserving parallel execution

### Change 4: Replace inline release workflow with `rust-release.yml`

**File:** `.github/workflows/release.yml`

Replace the entire jobs section with:

```yaml
jobs:
  release:
    uses: cboone/gh-actions/.github/workflows/rust-release.yml@v2
    with:
      targets: >-
        [
          {"target": "x86_64-apple-darwin", "runner": "macos-latest"},
          {"target": "aarch64-apple-darwin", "runner": "macos-latest"}
        ]
      update-homebrew: true
      homebrew-tap: cboone/homebrew-tap
      homebrew-formula-path: Formula/ke.rb
      homebrew-desc: "A developer-focused CLI for ergonomic macOS Keychain access"
      homebrew-depends-on: ":macos"
      homebrew-test: |
        assert_match version.to_s, shell_output("#{bin}/ke --version")
    secrets:
      HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
```

Keep the existing top-level `on:`, `concurrency:`, and `permissions:` blocks.

Note: the `homebrew-desc`, `homebrew-depends-on`, and `homebrew-test` inputs depend on the upstream issues being resolved first.

Archive naming changes from `darwin-amd64`/`darwin-arm64` to Rust target triples (`x86_64-apple-darwin`/`aarch64-apple-darwin`). This is acceptable.

### Change 5: Delete the Formula template

**File:** `Formula/ke.rb`

Delete this file. The reusable workflow generates the formula from scratch, making the placeholder template obsolete.

## Commit Strategy

Three logical commits:

1. `chore: replace inline scrut job and add github-lint (#2)` - changes 1 and 2
2. `chore: replace inline Rust CI jobs with reusable workflow (#2)` - change 3
3. `chore: replace inline release with reusable workflow (#2)` - changes 4 and 5

## Files to Modify

- `.github/workflows/ci.yml` - replace inline jobs with reusable workflow calls
- `.github/workflows/release.yml` - replace inline release with reusable workflow call
- `Formula/ke.rb` - delete

## Verification

1. Push the branch and verify all CI jobs pass on the PR
2. Scrut: confirm the `scrut` job installs scrut, builds the binary, sets `KE_BIN`, and runs tests
3. GitHub lint: confirm actionlint runs and passes
4. Rust CI: confirm all checks (test, lint, format, deny, audit, typos) run as separate jobs
5. Release: can only be fully verified by creating a release tag; review syntax and inputs
