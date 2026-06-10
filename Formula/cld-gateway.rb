# typed: false
# frozen_string_literal: true

require "etc"

class CldGateway < Formula
  desc "Anthropic-compatible HTTP proxy that routes to OpenAI"
  homepage "https://github.com/Bytonomics/cld-gateway"
  license "Elastic-2.0"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.3/cld-gateway-package-x86_64-apple-darwin.tar.gz"
      sha256 "b0e5ddfea09aba8a19c3a0c4d9ae8c94a4d76f0ebbb522756598604538ed7714"
    end

    if Hardware::CPU.arm?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.3/cld-gateway-package-aarch64-apple-darwin.tar.gz"
      sha256 "03a436addea73fd2cb07778bfe78485a233dc774fcf7003a358fb79fafaaac70"
    end
  end

  on_linux do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.3/cld-gateway-package-x86_64-unknown-linux-musl.tar.gz"
      sha256 "e9ef3459ea25a82ed1155894b81a3a53ab265f88ff7239a90a9bc4f2390f1c0d"
    end

    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.3/cld-gateway-package-aarch64-unknown-linux-musl.tar.gz"
      sha256 "cbe489cf9125b4d9a2bf6eb848c9eb2a1a0cba23a016fd885b8681be39203f74"
    end
  end

  def install
    bin.install "bin/cld-gateway"
    bin.install "bin/cld-gateway-sh"
    bin.install "bin/cldg"
    bin.install "bin/clddg"
    pkgshare.install "config.yml", "settings.json"
    (pkgshare/"commands"/"codex").install "commands/codex/status.md"
    libexec.install "homebrew/post_install.py"
  end

  service do
    user_home = Pathname(Etc.getpwuid(Process.uid).dir)
    run [opt_bin/"cld-gateway", "serve"]
    environment_variables GATEWAY_CONFIG_PATH: (user_home/".gateway/config.yml").to_s
  end

  def caveats
    user_home = Pathname(Etc.getpwuid(Process.uid).dir)
    <<~EOS
      After running `cld-gateway-sh setup`, runtime config will be installed to:
        #{user_home/".gateway/config.yml"}

      After running `cld-gateway-sh setup`, Claude settings for the wrapper will be installed to:
        #{user_home/".claude_gateway/settings.json"}

      Existing shared Claude Code entries from ~/.claude will be symlinked into ~/.claude_gateway when missing.

      After installation, run `cld-gateway-sh setup` to complete user-home configuration.

      The cldg and clddg wrappers shell out to `claude`.
      Make sure the `claude` executable is already available on your PATH.
    EOS
  end

  test do
    output = shell_output("#{bin}/cld-gateway invalid-command 2>&1", 1)
    assert_match "unknown command", output
  end
end
