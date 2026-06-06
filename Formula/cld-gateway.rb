# typed: false
# frozen_string_literal: true

# This bootstrap formula is intentionally non-installable until the first
# cld-gateway GitHub release publishes real package archives and checksums.
# The tap workflows rewrite this file from render-formula.py once that manifest
# exists.
class CldGateway < Formula
  desc "Anthropic-compatible HTTP proxy that routes requests through the ChatGPT/Codex backend"
  homepage "https://github.com/Bytonomics/cld-gateway"
  license "Apache-2.0"

  def install
    odie <<~ERROR
      This formula is populated by the bytonomics/homebrew-tap release workflows after a cld-gateway release is published.
      Publish cld-gateway first, then run the tap update workflow to render archive URLs and SHA256 values.
    ERROR
  end
end
