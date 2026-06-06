# Bytonomics Homebrew Tap

Homebrew tap for installing `cld-gateway` from Bytonomics.

## Install

```sh
brew tap bytonomics/homebrew-tap
brew install cld-gateway
```

## What this tap installs

This tap installs the packaged `cld-gateway` release published from [`bytonomics/gateway`](https://github.com/bytonomics/gateway). The formula points at the release archive and checksum for a specific version.

## Update flow

At a high level:

- A new `cld-gateway` release is published from `bytonomics/gateway`.
- That release includes the packaged archive(s) and checksum(s).
- The gateway release workflow must dispatch a `version-updated` event to `bytonomics/homebrew-tap`.
- The tap workflow renders `Formula/cld-gateway.rb` from the published checksum manifest, validates it with Homebrew, and commits the update.
- If that automatic dispatch fails, trigger `manual-publish-formula-update.yml` in the tap repo and provide the release version.
