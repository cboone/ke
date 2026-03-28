# Implement --version flag with clap

Addresses [#3](https://github.com/cboone/ke/issues/3).

## Context

The bootstrap PR (#1) included a scrut test expecting `ke --version` to work. A manual `std::env::args()` workaround was added to make the test pass, but proper CLI argument parsing was deferred. This plan replaces the manual workaround with clap's derive API, establishing the foundation for the full subcommand architecture described in the design doc.

## Changes

### 1. Add clap dependency (`Cargo.toml`)

Add clap with the `derive` feature:

```toml
[dependencies]
clap = { version = "4", features = ["derive"] }
```

### 2. Replace manual arg parsing with clap (`src/main.rs`)

```rust
use clap::Parser;

/// A developer-focused CLI for ergonomic macOS Keychain access
#[derive(Parser)]
#[command(version)]
struct Cli {}

fn main() {
    let _cli = Cli::parse();
    println!("Hello, world!");
}
```

Key details:
- `#[command(version)]` pulls the version from `CARGO_PKG_VERSION` automatically
- The doc comment on `Cli` becomes the `about` text in `--help` output
- clap provides `--version`/`-V` and `--help`/`-h` by default
- The empty `Cli` struct is the extension point for future subcommands
- Default (no args) still prints "Hello, world!"

### No changes needed

- `tests/scrut/version.md`: `ke * (glob)` matches clap's `ke 0.1.0` output
- `tests/scrut/help.md`: `* (glob+)` matches clap's multi-line help output
- `deny.toml`: clap's dependency tree uses MIT/Apache-2.0, already in the allowlist

## Verification

1. `cargo build` compiles successfully
2. `make test-scrut` passes all 3 test cases (version, help, short help)
3. `cargo clippy -- -D warnings` reports no warnings
4. `cargo fmt -- --check` passes
5. `cargo deny check` passes with clap's license chain
6. `cargo nextest run` passes
