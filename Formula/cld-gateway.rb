# typed: false
# frozen_string_literal: true

require "etc"

class CldGateway < Formula
  desc "Anthropic-compatible HTTP proxy that routes to OpenAI"
  homepage "https://github.com/Bytonomics/cld-gateway"
  license "Elastic-2.0"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.5/cld-gateway-package-x86_64-apple-darwin.tar.gz"
      sha256 "251368f5581c4291e76dc54ed4a60f85a6906f621f629d2efdcb7b002e150e8d"
    end

    if Hardware::CPU.arm?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.5/cld-gateway-package-aarch64-apple-darwin.tar.gz"
      sha256 "bbb78cca657e048373c9e7b7708dd09f953665245ad04afe546a8574ff03bee8"
    end
  end

  on_linux do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.5/cld-gateway-package-x86_64-unknown-linux-musl.tar.gz"
      sha256 "fb131b980306ad9975e224aa9c28aa36c92dfb027ee95e30162b632b5a31d1c6"
    end

    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.5/cld-gateway-package-aarch64-unknown-linux-musl.tar.gz"
      sha256 "06891463c27277654f7b835e4dd6b7ef050477df1de5ed0079448d580c624caf"
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
