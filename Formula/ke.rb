# Template for Homebrew tap automation.
# The release workflow substitutes VERSION_PLACEHOLDER and SHA256 placeholders
# at release time using this file as the source of truth.
# Do not manually update placeholder values here.
class Ke < Formula
  desc "A developer-focused CLI for ergonomic macOS Keychain access"
  homepage "https://github.com/cboone/ke"
  version "VERSION_PLACEHOLDER"
  license "MIT"

  depends_on :macos

  on_intel do
    url "https://github.com/cboone/ke/releases/download/vVERSION_PLACEHOLDER/ke-VERSION_PLACEHOLDER-darwin-amd64.tar.gz"
    sha256 "SHA256_FOR_DARWIN_AMD64"
  end

  on_arm do
    url "https://github.com/cboone/ke/releases/download/vVERSION_PLACEHOLDER/ke-VERSION_PLACEHOLDER-darwin-arm64.tar.gz"
    sha256 "SHA256_FOR_DARWIN_ARM64"
  end

  def install
    bin.install "ke"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ke --version")
  end
end
