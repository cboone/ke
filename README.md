# ke

A developer-focused CLI for ergonomic macOS Keychain access.

## Installation

### Homebrew

```bash
brew install cboone/tap/ke
```

### cargo install

```bash
cargo install --git https://github.com/cboone/ke
```

## Usage

```bash
ke set my-token              # Store a secret (interactive input)
ke get my-token              # Retrieve a secret
ke ls                        # List secrets
ke cp my-token               # Copy to clipboard (auto-clears)
ke run -- make serve         # Run a command with secrets injected
ke inject < config.tmpl      # Template injection
```

## License

[MIT](LICENSE)
