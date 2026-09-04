# typed: false
# frozen_string_literal: true

require "etc"

class CldGateway < Formula
  desc "Anthropic-compatible HTTP proxy that routes to OpenAI"
  homepage "https://github.com/Bytonomics/cld-gateway"
  license "Elastic-2.0"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.3/cld-gateway-package-x86_64-apple-darwin.tar.gz"
      sha256 "8da46beb01a12b6c9abb28d7718453641ce5510896d8921f7219a576b5f2926b"
    end

    if Hardware::CPU.arm?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.3/cld-gateway-package-aarch64-apple-darwin.tar.gz"
      sha256 "438911ba997bdce55ca5cc4f6581345cdaba7ae4424f3faa6245961ee4a9369f"
    end
  end

  on_linux do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.3/cld-gateway-package-x86_64-unknown-linux-musl.tar.gz"
      sha256 "2ba0a699d4155ce1c11cb14ca645f5219de0e641909183b44353769b23f34cc1"
    end

    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v1.1.3/cld-gateway-package-aarch64-unknown-linux-musl.tar.gz"
      sha256 "904dfe621671ce26445d88ad4bf08ad60ee183e1e40669fa439a61baf51a2180"
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
