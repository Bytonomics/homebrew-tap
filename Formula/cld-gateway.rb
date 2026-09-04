# typed: false
# frozen_string_literal: true

require "etc"

class CldGateway < Formula
  desc "Anthropic-compatible HTTP proxy that routes to OpenAI"
  homepage "https://github.com/Bytonomics/cld-gateway"
  license "Elastic-2.0"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.4/cld-gateway-package-x86_64-apple-darwin.tar.gz"
      sha256 "bbe9ae9a5b3e5cbe9aac985e7069f8ba13f4c40de2b50c668b0866ddb3b31ec4"
    end

    if Hardware::CPU.arm?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.4/cld-gateway-package-aarch64-apple-darwin.tar.gz"
      sha256 "117867fbe1f7a6a1a9eb6037f61d0596d0e91a7192db6abaabf1a1a5399e7b9c"
    end
  end

  on_linux do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.4/cld-gateway-package-x86_64-unknown-linux-musl.tar.gz"
      sha256 "910c668968ee3db33b5972dac01c20a0707daef6c67423da4d6116e61864d826"
    end

    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.4/cld-gateway-package-aarch64-unknown-linux-musl.tar.gz"
      sha256 "680c5dd90efff54550508f56517d9052c457f449312c4ef796bebc26a46110a3"
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
