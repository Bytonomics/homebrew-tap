# typed: false
# frozen_string_literal: true

require "etc"

class CldGateway < Formula
  desc "Anthropic-compatible HTTP proxy that routes to OpenAI"
  homepage "https://github.com/Bytonomics/cld-gateway"
  license "Elastic-2.0"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.1/cld-gateway-package-x86_64-apple-darwin.tar.gz"
      sha256 "2ce0b0fcb603b31a6126a2bffec0855b5d5d1d20850aa723a1976935d71513ba"
    end

    if Hardware::CPU.arm?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.1/cld-gateway-package-aarch64-apple-darwin.tar.gz"
      sha256 "a2f99aee763d43a9486417de66d7cbb35ca48e587a1bc4e7c63fb0c6d694aa76"
    end
  end

  on_linux do
    if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.1/cld-gateway-package-x86_64-unknown-linux-musl.tar.gz"
      sha256 "3008d32532c8e65f5307ba7bb0cff3a82a0c6b298b89d77001ff0cf2992809c2"
    end

    if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
      url "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v0.1.1/cld-gateway-package-aarch64-unknown-linux-musl.tar.gz"
      sha256 "e3a1838913c57df4fbd927d6016cd5435c7e485672feabc8b5daa5d9c72b9330"
    end
  end

  def install
    bin.install "bin/cld-gateway"
    pkgshare.install "config.yml", "settings.json"

    (bin/"cldg").write <<~SH
      #!/bin/sh
      exec claude --settings "$HOME/.claude_codex/settings.json" "$@"
    SH

    (bin/"clddg").write <<~SH
      #!/bin/sh
      exec "#{opt_bin}/cldg" --dangerously-skip-permissions "$@"
    SH

    chmod 0555, bin/"cldg"
    chmod 0555, bin/"clddg"
  end

  def post_install
    user_home = Pathname(Etc.getpwuid(Process.uid).dir)
    gateway_home = user_home/".gateway"
    claude_home = user_home/".claude"
    claude_codex_path = user_home/".claude_codex"
    gateway_config = gateway_home/"config.yml"
    shared_claude_entries = %w[
      .claude.json
      CLAUDE.md
      agents
      commands
      debug
      docs
      downloads
      history.jsonl
      hookify.block-direct-go-commands.local.md
      hookify.block-git-add-all.local.md
      hookify.block-no-verify-commit.local.md
      hooks
      ide
      output-styles
      plans
      plugins
      projects
      session-env
      shell-snapshots
      skills
      statusline-command.sh
      todos
      universal_instructions.md
    ]

    gateway_home.mkpath
    if claude_codex_path.exist?
      if !claude_codex_path.directory? && !claude_codex_path.symlink?
        odie "Expected ~/.claude_codex to be a directory or symlink"
      end
    else
      claude_codex_path.mkpath
    end

    gateway_config.write((pkgshare/"config.yml").read)
    (claude_codex_path/"settings.json").write((pkgshare/"settings.json").read)
    odie "Expected ~/.claude to exist as a directory" unless claude_home.directory?

    shared_claude_entries.each do |entry_name|
      source = claude_home/entry_name
      target = claude_codex_path/entry_name
      source_present = source.exist? || source.symlink?
      next unless source_present
      next if target.exist? || target.symlink?

      File.symlink(source.to_s, target.to_s)
    end
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
