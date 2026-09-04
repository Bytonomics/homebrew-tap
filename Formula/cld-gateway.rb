# typed: false
# frozen_string_literal: true

require "etc"

class CldGateway < Formula
  desc "Anthropic-compatible HTTP proxy that routes to OpenAI"
  homepage "https://github.com/Bytonomics/cld-gateway"
  license "Elastic-2.0"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.1/cld-gateway-package-x86_64-apple-darwin.tar.gz"
      sha256 "1b959f358b9c242a081fc82716d1c9c28cefb7a107cdf012c221fe624086f6ae"
    end

    if Hardware::CPU.arm?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.1/cld-gateway-package-aarch64-apple-darwin.tar.gz"
      sha256 "5d134c0e03d58a7cf81991ce4c6daaf264c6c938a668dda25412ad0b0753f492"
    end
  end

  on_linux do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.1/cld-gateway-package-x86_64-unknown-linux-musl.tar.gz"
      sha256 "781964e2ba3cc782463f49b4e783fab5f97a528c071c99a77c4a71b93fe3937a"
    end

    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.1/cld-gateway-package-aarch64-unknown-linux-musl.tar.gz"
      sha256 "3b03493f4d5e10a1cb2b064d12cd35205a36e274ab5ce67e1992f52f48e8138f"
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

      ⚠️  ==================================================== ⚠️
      ⚠️   REQUIRED NEXT STEP - run this now:                  ⚠️
      ⚠️                                                       ⚠️
      ⚠️     cld-gateway-sh setup                               ⚠️
      ⚠️  ==================================================== ⚠️

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
