# Add Homebrew Tap Integration to Release Workflow

## Context

Issue #8 requests automating the Homebrew formula update on each release. Currently the release workflow builds Darwin binaries (amd64/arm64), generates checksums, and publishes a GitHub release. The local `Formula/ke.rb` has placeholder SHA256s and a basic test block. The goal is to add a third workflow job that pushes a real formula (with actual checksums) to `cboone/homebrew-tap` after each release, so `brew install cboone/tap/ke` works immediately.

## Plan

### Change 1: Update `Formula/ke.rb` local template

**File:** `Formula/ke.rb`

Two modifications:

1. Add a comment header marking this as the automation template (so contributors know not to manually update version/SHA256 values here)
2. Replace the test block's `system` call with the standard Homebrew `assert_match` pattern

Before:

```ruby
class Ke < Formula
  ...
  test do
    system bin/"ke", "--version"
  end
end
```

After:

```ruby
# Template for Homebrew tap automation.
# The release workflow generates the published formula from this structure.
# Do not manually update version, URLs, or SHA256 values here.
class Ke < Formula
  ...
  test do
    assert_match version.to_s, shell_output("#{bin}/ke --version")
  end
end
```

### Change 2: Add `update-tap` job to release workflow

**File:** `.github/workflows/release.yml`

Append a new `update-tap` job after `publish`. The workflow dependency chain becomes:

```text
build (macos-latest, matrix: amd64/arm64)
  v
publish (ubuntu-latest, needs: build)
  v
update-tap (ubuntu-latest, needs: publish)
```

The job has 4 steps:

**Step 1 - Extract version from tag:**
Strip `v` prefix from `GITHUB_REF_NAME` (e.g., `v0.1.0` becomes `0.1.0`). Store as step output.

**Step 2 - Download checksums from release:**
Use `gh release download` with `github.token` to fetch `checksums.txt` from the just-created release.

**Step 3 - Extract SHA256 values:**
Parse `checksums.txt` (format: `<hash>  <filename>`) to get the SHA256 for each architecture. Fail explicitly if either value is missing.

**Step 4 - Generate formula and push to tap:**

- Generate `Formula/ke.rb` using a heredoc with shell variable expansion for version and checksums. Ruby's `#{bin}` interpolation passes through unmodified since `#{}` is not shell syntax.
- Clone `cboone/homebrew-tap` using `HOMEBREW_TAP_TOKEN`
- Copy the generated formula into the tap
- Commit and push (skip if no changes, e.g., re-run for same version)

Key details:

- `mkdir -p tap-repo/Formula` handles the case where the tap has no `Formula/` directory yet
- `git diff --cached --quiet` prevents empty commits on re-runs
- Commit message format: `ke 0.1.0` (formula name + version)
- Bot identity: `github-actions[bot]`

### Manual setup (not automated, noted for user)

1. Create a fine-grained PAT scoped to `cboone/homebrew-tap` with `contents: write` permission
2. Add the token as repository secret `HOMEBREW_TAP_TOKEN` in `cboone/ke`

### Verification

1. Ensure `HOMEBREW_TAP_TOKEN` secret is configured before triggering
2. Tag `v0.1.0` and push to trigger the full pipeline
3. Confirm all three release jobs succeed (build, publish, update-tap)
4. Confirm `Formula/ke.rb` appears in `cboone/homebrew-tap` with real SHA256 values
5. Run `brew install cboone/tap/ke && ke --version`

## Critical files

- `.github/workflows/release.yml` (modify: add `update-tap` job)
- `Formula/ke.rb` (modify: test block + template comment)
