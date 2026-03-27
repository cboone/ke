#!/usr/bin/env bash
set -euo pipefail

# Install ke from GitHub Releases.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cboone/ke/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/cboone/ke/main/install.sh | bash -s -- --version v1.0.0

REPO="cboone/ke"
BINARY="ke"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"

# This tool is macOS-only.
if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'Error: %s is only available for macOS.\n' "${BINARY}" >&2
  exit 1
fi

OS="darwin"

# Parse arguments.
VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

# Determine the latest version if not specified.
if [[ -z "${VERSION}" ]]; then
  VERSION="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' || true)"
  if [[ -z "${VERSION}" ]]; then
    printf 'Error: could not determine latest version.\n' >&2
    exit 1
  fi
fi

# Detect architecture.
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64)  ARCH="amd64" ;;
  arm64)   ARCH="arm64" ;;
  *)
    printf 'Unsupported architecture: %s\n' "${ARCH}" >&2
    exit 1
    ;;
esac

# Download.
TARBALL="${BINARY}-${VERSION#v}-${OS}-${ARCH}.tar.gz"
URL="https://github.com/${REPO}/releases/download/${VERSION}/${TARBALL}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

printf 'Downloading %s %s for %s/%s...\n' "${BINARY}" "${VERSION}" "${OS}" "${ARCH}"
curl -fsSL -o "${TMPDIR}/${TARBALL}" "${URL}"

# Verify checksum if checksums file exists.
CHECKSUMS_URL="https://github.com/${REPO}/releases/download/${VERSION}/checksums.txt"
if curl -fsSL -o "${TMPDIR}/checksums.txt" "${CHECKSUMS_URL}" 2>/dev/null; then
  printf 'Verifying checksum...\n'
  EXPECTED="$(awk -v t="${TARBALL}" '$0 ~ t { print $1 }' "${TMPDIR}/checksums.txt")"
  if [[ -n "${EXPECTED}" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then
      ACTUAL="$(sha256sum "${TMPDIR}/${TARBALL}" | awk '{ print $1 }')"
    elif command -v shasum >/dev/null 2>&1; then
      ACTUAL="$(shasum -a 256 "${TMPDIR}/${TARBALL}" | awk '{ print $1 }')"
    else
      printf 'Warning: no sha256 tool found, skipping checksum verification.\n' >&2
      ACTUAL="${EXPECTED}"
    fi
    if [[ "${ACTUAL}" != "${EXPECTED}" ]]; then
      printf 'Checksum mismatch: expected %s, got %s\n' "${EXPECTED}" "${ACTUAL}" >&2
      exit 1
    fi
    printf 'Checksum verified.\n'
  fi
fi

# Extract and install.
if tar -tzf "${TMPDIR}/${TARBALL}" | grep -qE '(^/|(^|/)\.\\.(/|$))'; then
  printf 'Error: archive contains unsafe paths, refusing to install.\n' >&2
  exit 1
fi
EXTRACT_DIR="${TMPDIR}/extract"
mkdir -p "${EXTRACT_DIR}"
tar -xzf "${TMPDIR}/${TARBALL}" -C "${EXTRACT_DIR}"
mkdir -p "${INSTALL_DIR}"
install -m 755 "${EXTRACT_DIR}/${BINARY}" "${INSTALL_DIR}/${BINARY}"

printf 'Installed %s to %s/%s\n' "${BINARY}" "${INSTALL_DIR}" "${BINARY}"

# Check if INSTALL_DIR is in PATH.
case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    printf '\nNote: %s is not in your PATH.\n' "${INSTALL_DIR}"
    # shellcheck disable=SC2016
    printf 'Add it with: export PATH="%s:${PATH}"\n' "${INSTALL_DIR}"
    ;;
esac
