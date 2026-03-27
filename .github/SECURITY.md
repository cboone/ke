# Security Policy

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via GitHub's private vulnerability reporting:

1. Go to the repository's **Security** tab (in the top navigation bar, next to Issues/Pull Requests)
1. Click "Report a vulnerability" in the left sidebar under Advisories
1. Fill out the form with details

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Acknowledgment:** Within 24 hours
- **Initial assessment:** Within 48 hours
- **Resolution target:** Depends on severity, but as soon as possible

### What Qualifies as a Security Issue

- Credential or secret exposure through environment variables, process lists, or log output
- Keychain entry access without proper authentication prompts
- Secret data written to disk unexpectedly (temp files, swap, logs)
- Injection vulnerabilities (command injection via secret names or values)
- Path traversal in mapping file resolution
- FIFO or temp file race conditions in `ke inject`
- Sensitive data exposure in error messages or debug output

### Out of Scope

- Issues in upstream dependencies (report to them directly)
- Issues requiring physical access to the machine
- Social engineering attacks
- macOS Keychain vulnerabilities (report to Apple)
