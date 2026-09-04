# typed: false
# frozen_string_literal: true

require "etc"

class CldGateway < Formula
  desc "Anthropic-compatible HTTP proxy that routes to OpenAI"
  homepage "https://github.com/Bytonomics/cld-gateway"
  license "Elastic-2.0"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.2/cld-gateway-package-x86_64-apple-darwin.tar.gz"
      sha256 "c8483362d78f7e9a085fd96f11c93c6d00296b10bf3fbc1eff2054c63143fd62"
    end

    if Hardware::CPU.arm?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.2/cld-gateway-package-aarch64-apple-darwin.tar.gz"
      sha256 "8c525a1012920145ef1830bcc80c4bb69c58f023a8cb73de66b0a0c19f877e79"
    end
  end

  on_linux do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.2/cld-gateway-package-x86_64-unknown-linux-musl.tar.gz"
      sha256 "8d4dcbf061893a7bc2de67a554753d7ee1513e100500600cacc2042edc8d8544"
    end

    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.2/cld-gateway-package-aarch64-unknown-linux-musl.tar.gz"
      sha256 "14046a4ede6ad2372b43748f26af6b98199a1353b4044e1d0bac1b9d0b60b6fd"
    end
  end

  def install
    bin.install "bin/cld-gateway"
    bin.install "bin/cld-gateway-sh"
    bin.install "bin/cldg"
    bin.install "bin/clddg"
    pkgshare.install "config.yml", "settings.json"
    libexec.install "homebrew/post_install.py"
    libexec.install "commands"
  end

  service do
    user_home = Pathname(Etc.getpwuid(Process.uid).dir)
    run [opt_bin/"cld-gateway", "serve"]
    environment_variables GATEWAY_CONFIG_PATH: (user_home/".gateway/config.yml").to_s
  end

  def caveats
    user_home = Pathname(Etc.getpwuid(Process.uid).dir)
    <<~EOS
      ⚠️  REQUIRED — run this now:

          cld-gateway-sh setup

      Setup installs runtime config to:
        #{user_home/".gateway/config.yml"}

      Setup installs Claude settings for the wrapper to:
        #{user_home/".claude_gateway/settings.json"}

      Existing shared Claude Code entries from ~/.claude will be symlinked into ~/.claude_gateway when missing.

      The cldg and clddg wrappers shell out to `claude`.
      Make sure the `claude` executable is already available on your PATH.
    EOS
  end

  test do
    output = shell_output("#{bin}/cld-gateway invalid-command 2>&1", 1)
    assert_match "unknown command", output
  end
end
