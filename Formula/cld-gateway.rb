# typed: false
# frozen_string_literal: true

require "etc"

class CldGateway < Formula
  desc "Anthropic-compatible HTTP proxy that routes to OpenAI"
  homepage "https://github.com/Bytonomics/cld-gateway"
  license "Elastic-2.0"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.2/cld-gateway-package-x86_64-apple-darwin.tar.gz"
      sha256 "9dd58767d5f787425bc6f439c4ab3b2def7b8e45691ffe7d33f7465bd1847821"
    end

    if Hardware::CPU.arm?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.2/cld-gateway-package-aarch64-apple-darwin.tar.gz"
      sha256 "760f04bd10e82064c6f0121a73e57370066b85ab4644ee186de028d4a668ec31"
    end
  end

  on_linux do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.2/cld-gateway-package-x86_64-unknown-linux-musl.tar.gz"
      sha256 "394f9df75c6ea74f05bea8b81b529a7918b23933ae882d378a53bce2359b3809"
    end

    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.2/cld-gateway-package-aarch64-unknown-linux-musl.tar.gz"
      sha256 "1a7f945cb165944f6ecfb8534e15055806ea3cdc3f13e53488e5d8aa1b45eb24"
    end
  end

  def install
    bin.install "bin/cld-gateway"
    bin.install "bin/cldg"
    bin.install "bin/clddg"
    pkgshare.install "config.yml", "settings.json"
    libexec.install "homebrew/post_install.py"
  end

  def post_install
    user_home = Pathname(Etc.getpwuid(Process.uid).dir)
    gateway_config_src = pkgshare/"config.yml"
    settings_json_src = pkgshare/"settings.json"

    system(opt_libexec/"post_install.py", user_home.to_s, gateway_config_src.to_s, settings_json_src.to_s)
  end

  service do
    user_home = Pathname(Etc.getpwuid(Process.uid).dir)
    run [opt_bin/"cld-gateway", "serve"]
    environment_variables GATEWAY_CONFIG_PATH: (user_home/".gateway/config.yml").to_s
  end

  def caveats
    user_home = Pathname(Etc.getpwuid(Process.uid).dir)
    <<~EOS
      Runtime config was installed to:
        #{user_home/".gateway/config.yml"}

      Claude settings for the wrapper were installed to:
        #{user_home/".claude_codex/settings.json"}

      Existing shared Claude Code entries from ~/.claude are symlinked into ~/.claude_codex when missing.

      The cldg and clddg wrappers shell out to `claude`.
      Make sure the `claude` executable is already available on your PATH.
    EOS
  end

  test do
    output = shell_output("#{bin}/cld-gateway invalid-command 2>&1", 1)
    assert_match "unknown command", output
  end
end
