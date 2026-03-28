# ke — macOS Keychain CLI for Developers

## Design Document

### Overview

`ke` is a developer-focused command-line tool that wraps macOS Keychain Services, providing ergonomic access to secrets for local development workflows. It fills the gap between the painfully verbose `security` command and full-featured cloud-backed tools like 1Password's `op`, SOPS, or HashiCorp Vault.

`ke` is not trying to replace those tools. It is the local-first, single-user, zero-infrastructure complement to them. A developer might use `ke` for their personal API keys and local dev credentials, SOPS for shared encrypted config files committed to a team repo, and `op` for the company password vault. These tools occupy different layers of the secrets management stack and compose naturally.

### Target Audience

Developers on macOS who want to stop putting API keys, tokens, and credentials in plaintext `.env` files, shell profiles, or config files. The tool should be useful both as a personal sharp tool and polished enough for broader adoption.

### Design Principles

The tool should be simple by default and powerful when needed. The most common operations (store a secret, retrieve a secret, run a command with secrets injected) should require minimal ceremony. More advanced features (custom keychains, per-entry keychain overrides, template injection) are available but never required.

Secrets should avoid touching disk whenever possible. The mapping file contains only names, not values. `ke run` injects secrets via environment variables without writing them to files. `ke inject` writes to stdout and supports FIFO-based delivery where the child process reads secrets through an in-memory pipe rather than a temp file.

The tool should embrace macOS platform capabilities rather than abstracting them away. Touch ID and system authentication gating come for free from Keychain Services. The dedicated keychain feature leverages macOS's native multi-keychain architecture. Entries created by `ke` are visible in Keychain Access.app.

---

## Implementation Language

Rust is the recommended implementation language for several reasons.

The `security-framework` crate provides well-maintained, idiomatic Rust bindings to macOS Security.framework, covering keychain operations, passwords, certificates, and keys. This is significantly better than the Go alternative, which would require either writing cgo bindings to Security.framework directly or shelling out to the `security` command (reducing `ke` to a fancier shell script).

Rust's ownership model provides meaningful advantages for secure memory handling. The `secrecy` crate wraps secret values in a type that zeroes memory on drop and prevents accidental logging or display via `Debug`/`Display` trait implementations. The `zeroize` crate provides the underlying trait for guaranteed zeroing. Memory can be pinned with `mlock` to prevent swapping to disk. These guarantees are enforced at compile time through the borrow checker.

Go's garbage collector moves objects around in memory, which means you cannot reliably zero a secret's original memory location. The GC may have already copied the data elsewhere. Working around this requires manually managed byte slices and avoiding Go's immutable string type, which fights the language's idioms.

In practice, `ke` is a short-lived CLI process where the window for secrets being resident in memory is small. The Rust advantages matter more as a foundation for doing things correctly than as a response to an immediate threat. The output is a single static binary with no runtime dependencies.

---

## Keychain Strategy

### Default Behavior

`ke` uses the login keychain by default. This is the keychain that is already unlocked when the user is logged in, already backed by Touch ID, and already visible in Keychain Access.app. This means someone can install `ke` and immediately start storing and retrieving secrets with zero setup.

### Custom Keychains

A `--keychain <name-or-path>` global flag allows targeting any keychain for any command. This enables reading secrets from other keychains (including ones created by other applications) and writing to dedicated keychains.

The `ke init [name]` command creates a new dedicated keychain. This is optional and serves users who want to separate their developer secrets from the login keychain's other contents (Wi-Fi passwords, app tokens, browser credentials, etc.). A dedicated keychain can be independently backed up, synced, or deleted without affecting system credentials.

### Authentication

Touch ID and system authentication gating are provided by Keychain Services automatically. The OS prompts the user when a secret is accessed. `ke` does not implement its own authentication layer. This is one of the key advantages of building on Keychain — hardware-backed authentication with no additional setup.

---

## Keychain Entry Structure and Namespacing

macOS generic password items have several fields. `ke` uses them as follows.

The **service** field (`-s`) stores the user-facing secret name. When a user runs `ke set api-token value`, the service is set to `api-token`.

The **account** field (`-a`) is set to the fixed string `ke`. This serves as a namespace discriminator, allowing `ke ls` to filter for only the entries that `ke` created, without picking up Wi-Fi passwords, browser credentials, and other items in the login keychain.

The **label** field (`-l`) is set to a human-readable string like `api-token (ke)` so entries are identifiable when browsing Keychain Access.app visually.

The **password** field (`-w`) stores the actual secret value.

The **comment** field (`-j`) is available for future use (metadata, tags, etc.) but is not used in v1.

### Accessing Non-ke Entries

By default, `ke get` and `ke ls` are scoped to entries where the account field is `ke`. A `--any` flag drops this filter, allowing `ke` to read secrets stored by other applications. This makes `ke` useful as a general-purpose Keychain query tool when needed, while keeping the default behavior clean and focused.

For `ke ls`, the `--all` flag shows all generic password entries in the target keychain regardless of who created them.

### Secret Naming Conventions

Valid secret names match the pattern `[a-zA-Z0-9._-]+`. This means alphanumeric characters, hyphens, underscores, and dots are permitted. Spaces, slashes, and special shell characters are not allowed. This keeps names safe to use unquoted in shell contexts and unambiguous in the reference syntax.

Names are case-sensitive, matching the underlying Keychain behavior. `My-Token` and `my-token` are distinct entries.

Examples of valid names: `stripe-live-key`, `db.password`, `OPENAI_API_KEY`, `github-token.personal`.

---

## Reference Syntax

The reference syntax is what appears in environment variables and templates to indicate "resolve this from Keychain."

The syntax is `ke://name`, for example `ke://stripe-live-key` or `ke://OPENAI_API_KEY`. This mirrors the `op://vault/item/field` convention from 1Password CLI, making it familiar to developers who have used `op`. It is clearly a URI-style reference rather than a shell variable expansion, which avoids confusion with `${VAR}` syntax.

In mapping files, the reference prefix is not needed because the context makes it clear that values are keychain entry names.

For inline environment variable scanning, `ke run` looks for values matching the `ke://` prefix in the current environment and resolves them. For example, if a user's shell profile contains `export DATABASE_URL='ke://local-postgres-url'`, running `ke run -- make serve` will resolve that reference before launching the subprocess.

---

## Mapping File

The mapping file is a committable, non-secret file that lives in a project directory and declares which environment variables should be populated from which Keychain entries. It contains only names, never values. This is what makes it safe to commit to version control.

### Supported Formats

YAML is the default format. TOML, JSON, and dotenv (`.env`) formats are also supported. The file is detected by name and extension during directory walking.

### File Names and Discovery

`ke run` searches for a mapping file by walking up from the current working directory to the filesystem root, stopping at the first match. The search order within each directory is: `.ke.yaml`, `.ke.yml`, `.ke.toml`, `.ke.json`, `.ke.env`. A `--env-file <path>` flag overrides discovery and points to a specific file.

### YAML Format (Default)

```yaml
# .ke.yaml

# Optional: specify a default keychain for all entries in this file.
# If omitted, the login keychain (or the global config default) is used.
keychain: login

env:
  # Simple form: env var name -> keychain entry name
  STRIPE_KEY: stripe-live-key
  DATABASE_URL: local-postgres-url
  OPENAI_API_KEY: openai-api-key

  # Extended form: per-entry keychain override
  LEGACY_DB_PASSWORD:
    name: old-db-cred
    keychain: legacy-app
```

The `keychain` top-level key sets the default keychain for all entries in the file. Individual entries can override this with the extended map form.

> **Future consideration:** A shorthand for the common case where the env var name and keychain entry name are identical (e.g., `OPENAI_API_KEY` mapping to a keychain entry also called `OPENAI_API_KEY`). One option is to allow null/tilde values (`OPENAI_API_KEY: ~`) to mean "use the key name as the entry name." This is deferred for now in favor of explicit mappings.

### TOML Format

```toml
# .ke.toml

keychain = "login"

[env]
STRIPE_KEY = "stripe-live-key"
DATABASE_URL = "local-postgres-url"
OPENAI_API_KEY = "openai-api-key"
```

### JSON Format

```json
{
  "keychain": "login",
  "env": {
    "STRIPE_KEY": "stripe-live-key",
    "DATABASE_URL": "local-postgres-url",
    "OPENAI_API_KEY": "openai-api-key"
  }
}
```

### Dotenv Format

```bash
# .ke.env

# KEY=keychain-entry-name
STRIPE_KEY=stripe-live-key
DATABASE_URL=local-postgres-url
OPENAI_API_KEY=openai-api-key
```

The dotenv format follows the standard `.env` conventions: `KEY=VALUE` pairs, `#` for comments, optional quoting of values, blank lines ignored. The `export` prefix is accepted and ignored. There is no mechanism for per-entry keychain overrides or a file-level keychain setting in this format; the global default applies. This format exists for familiarity and ease of adoption, not for full feature coverage.

---

## Commands

### `ke set <name> [value]`

Store a secret in Keychain. If `value` is provided as an argument, it is used directly. If omitted, `ke` reads the value from stdin. The stdin path is the recommended approach for sensitive values, as it avoids exposing the secret in shell history and the process list.

Upsert by default: if an entry with the given name already exists, it is updated. A `--no-overwrite` flag causes the command to error if the entry already exists, for use cases where accidental overwrites must be prevented.

```bash
# Direct value (appears in shell history and ps — use with caution)
ke set my-token sk_live_abc123

# From stdin (recommended for sensitive values)
echo "sk_live_abc123" | ke set my-token

# Interactive input (no echo)
ke set my-token
Enter value: ****

# Pipe from a generator
openssl rand -base64 32 | ke set session-secret

# From clipboard
pbpaste | ke set my-token
```

### `ke get <name>`

Retrieve a secret and print it to stdout with no trailing newline. This makes it maximally composable with pipes, subshells, and other tools.

```bash
# Print to terminal
ke get my-token

# Capture in a variable
export API_KEY=$(ke get my-api-key)

# Pipe to another command
ke get deploy-key | ssh-add -

# Read a non-ke entry from the login keychain
ke get --any github.com
```

### `ke rm <name>`

Delete a secret from Keychain. Prompts for confirmation by default, since deletion is irreversible. A `--force` or `-f` flag skips the prompt for scripted use.

```bash
ke rm old-api-key
# Delete 'old-api-key'? [y/N]: y

ke rm -f old-api-key
# Deleted immediately
```

### `ke ls [pattern]`

List entries in the active keychain. By default, only entries created by `ke` (where account is `ke`) are shown. Output is plain text, one entry name per line, sorted alphabetically, making it greppable and pipeable.

An optional `pattern` argument filters by substring match. The `--all` flag drops the `ke` namespace filter and shows all generic password entries in the keychain. The `--json` flag outputs structured metadata (name, creation date, modification date, keychain).

```bash
ke ls                    # All ke-managed entries
ke ls stripe             # Entries containing "stripe"
ke ls --all              # All generic passwords in the keychain
ke ls --json             # Structured output for scripting
```

### `ke cp <name>`

Copy a secret to the system clipboard and auto-clear after a configurable timeout. The default timeout is 15 seconds and is configurable via the `--timeout` flag or the global config file.

The clipboard is only cleared if it still contains the secret that `ke` placed there. If the user has copied something else in the meantime, the clipboard is left alone. This prevents the annoying case where an unrelated clipboard operation gets nuked by the timer.

```bash
ke cp my-token                 # Copy, clear after 15s
ke cp my-token --timeout 30    # Copy, clear after 30s
ke cp my-token --timeout 0     # Copy, never auto-clear
```

### `ke run [flags] -- <command> [args...]`

Resolve secrets and launch a subprocess with those secrets available as environment variables. Secrets are resolved from up to three sources, merged in this precedence order (highest first):

1. The project mapping file (`.ke.yaml` etc., found via directory walking or `--env-file`)
2. Inline `ke://` references in the current environment variables
3. Global config env mappings (`~/.config/ke/config.yaml`)

The resolved secrets are merged into the current environment (additive, not replacing). The subprocess is launched with the augmented environment.

The `--` separator is required to disambiguate `ke` flags from the child command's flags.

**Subprocess modes:**

By default, the child command runs as a subprocess. `ke` forwards signals (SIGINT, SIGTERM, SIGHUP) to the child and exits with the child's exit code.

The `--exec` flag uses `execvp` to replace the `ke` process with the child command, mirroring SOPS's `--same-process` behavior. This is preferred when running servers, containers, or anything managed by a process supervisor, because the child inherits `ke`'s PID and signal handling works naturally without a forwarding layer.

**Error handling:**

If a referenced secret cannot be found in Keychain, `ke run` fails hard by default — it refuses to launch the subprocess and names the specific missing entry in the error message. This prevents confusing downstream runtime errors from missing credentials. The `--allow-missing` flag overrides this behavior, launching the subprocess with missing entries unset.

If Touch ID is denied or the keychain is locked and the user cancels the password prompt, `ke` exits cleanly with a clear error message.

If no mapping file is found and no `ke://` references exist in the environment, `ke run` launches the command with the current environment unchanged (a no-op passthrough).

```bash
# Using a project mapping file
ke run -- make serve

# Using --exec for a server process
ke run --exec -- node server.js

# Pointing to a specific mapping file
ke run --env-file ./config/.ke.yaml -- docker compose up

# Allowing missing secrets
ke run --allow-missing -- pytest
```

### `ke inject [flags]`

Read a template from stdin, resolve all `ke://` references in the text, and write the result to stdout. This handles cases where a tool insists on reading secrets from a config file rather than the environment.

The same error handling applies as `ke run`: missing references cause a hard failure by default, with `--allow-missing` leaving unresolvable references in place.

`ke inject` is format-agnostic. It performs simple text substitution on any input, whether YAML, JSON, INI, TOML, XML, or plain text.

**FIFO-based file delivery:**

For cases where a child process needs to read secrets from a file path rather than stdin, `ke inject` supports a `--exec-file` mode that mirrors SOPS's `exec-file` behavior. In this mode, `ke` resolves the template, creates a FIFO (named pipe), writes the resolved content to the FIFO, and passes the FIFO path to the child command via a `{}` placeholder. The data exists only in kernel memory buffers and can only be read once by the child process. Secrets never touch disk.

A `--no-fifo` flag falls back to a traditional temporary file (securely deleted on process exit) for cases where the child process needs to seek or re-read the file.

```bash
# Basic template injection to stdout
ke inject < config.yaml.tmpl > config.yaml

# Piped to a command
ke inject < docker-compose.tmpl | docker compose -f - up

# FIFO-based file delivery (secrets never touch disk)
ke inject --exec-file config.tmpl -- ./my-server --config {}

# Fallback to temp file when the child needs to re-read
ke inject --exec-file --no-fifo config.tmpl -- ./my-server --config {}
```

### `ke info <name>`

Display metadata about an entry without revealing the secret value. Shows which keychain the entry is in, when it was created, when it was last modified, the label, and whether it was created by `ke` or another application. Useful for debugging without the risk of the secret value appearing in terminal scrollback or logs.

```bash
ke info stripe-live-key
# Name:      stripe-live-key
# Keychain:  login
# Created:   2025-01-15 09:30:00
# Modified:  2025-03-20 14:15:00
# Origin:    ke
```

### `ke init [name]`

Create a dedicated keychain. If `name` is provided, the keychain is created with that name. If omitted, a default name (e.g., `ke`) is used. The keychain file is created at `~/Library/Keychains/<name>.keychain-db`. This command is optional and exists for users who want to separate their developer secrets from the login keychain.

```bash
ke init                # Creates ~/Library/Keychains/ke.keychain-db
ke init project-x      # Creates ~/Library/Keychains/project-x.keychain-db
```

### `ke completion <shell>`

Generate shell completion scripts for zsh, bash, and fish. For zsh and fish, completions dynamically query `ke ls` to offer entry names as tab-completable arguments for `ke get`, `ke cp`, `ke rm`, and `ke info`.

```bash
# Zsh (add to .zshrc)
eval "$(ke completion zsh)"

# Bash (add to .bashrc)
eval "$(ke completion bash)"

# Fish (add to config.fish)
ke completion fish | source
```

### `ke doctor`

Check the environment for common issues: is the default keychain accessible, can `ke` authenticate, are there any mapping file syntax errors in the current project directory. Useful for debugging setup problems.

### `ke version`

Print the version and build information.

### `ke help [command]`

Print help text for all commands or a specific command.

---

## Global Flags

The following flags are available on all commands.

`--keychain <name-or-path>` targets a specific keychain instead of the default. Accepts either a keychain name (resolved under `~/Library/Keychains/`) or a full path.

`--json` produces structured JSON output where applicable (primarily `ke ls` and `ke info`).

`--verbose` or `-v` enables debug output showing which keychain is being queried, which entries are being resolved, how the mapping file was found, etc. Useful when `ke run` isn't loading what you expect.

`--config <path>` overrides the global config file location.

---

## Global Configuration

Located at `~/.config/ke/config.yaml` by default, respecting `XDG_CONFIG_HOME` if set. This holds user-level defaults.

```yaml
# ~/.config/ke/config.yaml

defaults:
  # Default keychain to use when --keychain is not specified.
  # "login" is the default if this is omitted entirely.
  keychain: login

  # Seconds before ke cp auto-clears the clipboard.
  clipboard_timeout: 15

# Secrets that should always be available via ke run,
# regardless of which project you're in.
# These are merged as the lowest-precedence layer.
env:
  OPENAI_API_KEY: openai-api-key
  ANTHROPIC_API_KEY: anthropic-api-key
  GITHUB_TOKEN: github-personal-token
```

The global `env` section acts as a base layer. The per-project mapping file merges on top, with project-level entries taking precedence on conflicts. This means API keys for LLM services, personal GitHub tokens, and other user-level secrets can live in global config without being repeated in every project.

---

## Security Considerations and Best Practices

These concerns apply to `ke` and to every similar tool (SOPS, `op`, `pass`, etc.). They should be clearly documented in the tool's help text and README.

### Command-Line Arguments and Shell History

Passing a secret as a command-line argument (e.g., `ke set name value`) exposes it in two ways: the process list (`ps aux` shows the full command) and shell history (`.zsh_history`, `.bash_history`).

The recommended practice is to provide values via stdin: pipe from another command, paste interactively, or redirect from a process substitution. `ke set` should emit a warning to stderr if it detects a value argument on the command line, suggesting stdin instead.

```bash
# Avoid this (appears in history and process list)
ke set my-secret 'p@ssw0rd'

# Prefer this (stdin, no history exposure)
echo 'p@ssw0rd' | ke set my-secret

# Or interactive input (no echo to terminal)
ke set my-secret
```

Some shells respect a leading space as "don't record this command" (zsh's `HIST_IGNORE_SPACE` option, bash's `HISTCONTROL=ignorespace`), but `ke` cannot control this behavior. The documentation should mention this as an additional mitigation.

### Environment Variable Exposure

Environment variables injected by `ke run` are accessible to other processes running as the same user. On Linux, `/proc/<pid>/environ` is readable. On macOS there is no `/proc` filesystem, but environment variables are still accessible through other means (e.g., `ps eww`).

Runtime injection via environment variables is a meaningful improvement over plaintext files on disk, but it is not a complete security boundary. This is an inherent limitation shared by SOPS `exec-env`, `op run`, and every tool that uses environment variables as a transport mechanism. `ke` should document this clearly.

For higher-stakes environments, the `ke inject --exec-file` mode with FIFO-based delivery offers a stronger guarantee: the secret data exists only in kernel pipe buffers and can only be read once.

### Keychain Access Control

When the `security` command (or any process using Security.framework) accesses a keychain entry, macOS may prompt the user to allow access. Once the user allows a process (e.g., Terminal.app or iTerm2) with "Always Allow," any future process launched from that terminal can access the entry without further prompting. Users should understand that "Always Allow" for their terminal application grants broad access to all processes launched from that terminal.

For higher-security secrets, users may want to create a dedicated keychain (via `ke init`) that locks after a timeout, requiring re-authentication to access.

### Secrets in Config Files

`ke inject` writes resolved secrets to stdout, which may end up on disk if redirected to a file. This is sometimes necessary (some tools insist on reading a config file), but the resulting file contains plaintext secrets and should be treated accordingly: exclude from version control, restrict file permissions, and delete when no longer needed.

The FIFO-based `--exec-file` mode avoids this concern entirely by never writing secrets to disk.

---

## Relationship to Other Tools

### vs. the macOS `security` command

`ke` is a high-level wrapper around the same Keychain Services that `security` provides. The `security` command is powerful but extremely verbose — storing and retrieving a simple password requires remembering multiple flags and field names. `ke` provides an ergonomic interface for the most common operations while adding developer workflow features (mapping files, `ke run`, `ke inject`) that `security` does not offer.

### vs. 1Password CLI (`op`)

`op` is a cloud-backed, multi-user tool that talks to 1Password's servers. It offers team management, vault sharing, service accounts, and integration with 1Password's desktop app. `ke` is a local-only, single-user tool that talks to macOS Keychain. The developer workflow features (`ke run`, `ke inject`, reference syntax) are intentionally modeled on `op`'s patterns, but `ke` requires no account, no subscription, no cloud connectivity, and no additional software beyond macOS itself. `ke` handles personal/local secrets; `op` handles team/shared secrets.

### vs. SOPS

SOPS encrypts files at rest, using cloud KMS (AWS, GCP, Azure) or local keys (age, PGP) as the access control layer. The encrypted file is the source of truth and can be committed to version control and shared with teammates. `ke` uses macOS Keychain as the source of truth, with no encrypted files. SOPS is for shared secrets in repos; `ke` is for personal secrets on your Mac. They complement each other naturally. A developer might use `ke` for their personal API keys in local development and SOPS for the team's shared staging credentials in the repo.

### vs. Existing Keychain Wrappers (`ks`, `sec`, etc.)

Several shell script wrappers exist that simplify `security` command syntax. `ke` goes beyond these by adding the mapping file concept (a committable manifest of which secrets a project needs), the `ke run` subprocess launcher with multi-source secret resolution, the `ke inject` template engine with FIFO-based file delivery, clipboard integration with auto-clear, and structured output. It is also a compiled binary with proper signal handling, error reporting, and shell completion rather than a shell script.

---

## Out of Scope

The following are explicitly not planned for the initial version.

**Secret generation.** Use `openssl rand`, `/dev/urandom`, `uuidgen`, or any other generator and pipe the output to `ke set`. Composability with existing tools is preferred over reimplementing generation.

**Multi-user or team sharing.** That is what SOPS, `op`, Vault, Doppler, and similar tools are for. `ke` is a single-user, single-machine tool.

**Cross-platform support.** `ke` is a macOS Keychain tool by design. It depends on Security.framework and macOS-specific Keychain behavior.

**Multiple backends or cloud KMS integration.** `ke` is not a universal secrets broker. Tools like `teller` and `infisical` already handle multi-backend aggregation.

**Richer item types beyond generic passwords.** Internet passwords, certificates, and keys may be added later but are out of scope for the initial version.

**An edit command (`ke edit`)** that opens a secret in `$EDITOR` for modification. This raises security concerns around temp files and is deferred. It may be revisited later with an in-memory or FIFO-based approach.
