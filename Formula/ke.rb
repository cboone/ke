# Template for Homebrew tap automation.
# The release workflow generates the published formula from this structure.
# Do not manually update version, URLs, or SHA256 values here.
class Ke < Formula
  desc "A developer-focused CLI for ergonomic macOS Keychain access"
  homepage "https://github.com/cboone/ke"
  version "0.1.0"
  license "MIT"

  depends_on :macos

  on_intel do
    url "https://github.com/cboone/ke/releases/download/v0.1.0/ke-0.1.0-darwin-amd64.tar.gz"
    sha256 "SHA256_FOR_DARWIN_AMD64"
  end

  on_arm do
    url "https://github.com/cboone/ke/releases/download/v0.1.0/ke-0.1.0-darwin-arm64.tar.gz"
    sha256 "SHA256_FOR_DARWIN_ARM64"
  end

  def install
    bin.install "ke"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ke --version")
  end
end
