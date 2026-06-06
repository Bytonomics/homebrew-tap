#!/usr/bin/env python3
"""Render the cld-gateway Homebrew formula from release checksums."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys
from textwrap import dedent
import time
from urllib.error import URLError
from urllib.request import urlopen
import re

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = REPO_ROOT / "Formula" / "cld-gateway.rb"
RELEASE_URL_TEMPLATE = (
    "https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v{version}"
)
ASSETS = {
    "aarch64-apple-darwin": "cld-gateway-package-aarch64-apple-darwin.tar.gz",
    "x86_64-apple-darwin": "cld-gateway-package-x86_64-apple-darwin.tar.gz",
    "aarch64-unknown-linux-musl": "cld-gateway-package-aarch64-unknown-linux-musl.tar.gz",
    "x86_64-unknown-linux-musl": "cld-gateway-package-x86_64-unknown-linux-musl.tar.gz",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
FETCH_TIMEOUT_SECONDS = 30
FETCH_RETRY_DELAYS_SECONDS = (1, 2, 4)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True, help="cld-gateway release version")
    parser.add_argument(
        "--manifest-file",
        type=Path,
        help="Optional local cld-gateway-package_SHA256SUMS fixture for CI or dry runs.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="Formula output path.",
    )
    return parser.parse_args()


def load_manifest(version: str, manifest_file: Path | None) -> str:
    if manifest_file is not None:
        return manifest_file.read_text(encoding="utf-8")

    url = f"{RELEASE_URL_TEMPLATE.format(version=version)}/cld-gateway-package_SHA256SUMS"
    errors: list[str] = []
    for attempt, delay in enumerate((*FETCH_RETRY_DELAYS_SECONDS, None), start=1):
        try:
            with urlopen(url, timeout=FETCH_TIMEOUT_SECONDS) as response:
                return response.read().decode("utf-8")
        except (TimeoutError, URLError, OSError) as exc:
            errors.append(f"attempt {attempt}: {exc}")
            if delay is None:
                joined_errors = "; ".join(errors)
                raise SystemExit(
                    f"Failed to fetch checksum manifest from {url}: {joined_errors}"
                ) from exc
            time.sleep(delay)

    raise SystemExit(f"Failed to fetch checksum manifest from {url}")


def parse_manifest(manifest: str) -> dict[str, str]:
    digests: dict[str, str] = {}
    for raw_line in manifest.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        parts = line.split(maxsplit=1)
        if len(parts) != 2:
            raise SystemExit(f"Invalid checksum manifest line: {raw_line!r}")
        digest, asset = parts
        asset = asset.lstrip("*")
        digests[asset] = digest.lower()
    return digests


def require_digest(digests: dict[str, str], asset: str) -> str:
    digest = digests.get(asset)
    if digest is None:
        raise SystemExit(f"Missing SHA256 digest for {asset}")
    if not SHA256_RE.fullmatch(digest):
        raise SystemExit(f"Invalid SHA256 digest for {asset}: {digest}")
    return digest


def render_formula(version: str, digests: dict[str, str]) -> str:
    base_url = RELEASE_URL_TEMPLATE.format(version=version)
    return dedent(
        f'''\
        # typed: false
        # frozen_string_literal: true

        class CldGateway < Formula
          desc "Anthropic-compatible HTTP proxy that routes to OpenAI"
          homepage "https://github.com/Bytonomics/cld-gateway"
          version "{version}"
          license "Elastic License 2.0"

          on_macos do
            if Hardware::CPU.intel?
              url "{base_url}/{ASSETS['x86_64-apple-darwin']}"
              sha256 "{require_digest(digests, ASSETS['x86_64-apple-darwin'])}"
            end

            if Hardware::CPU.arm?
              url "{base_url}/{ASSETS['aarch64-apple-darwin']}"
              sha256 "{require_digest(digests, ASSETS['aarch64-apple-darwin'])}"
            end
          end

          on_linux do
            if Hardware::CPU.intel? && Hardware::CPU.is_64_bit?
              url "{base_url}/{ASSETS['x86_64-unknown-linux-musl']}"
              sha256 "{require_digest(digests, ASSETS['x86_64-unknown-linux-musl'])}"
            end

            if Hardware::CPU.arm? && Hardware::CPU.is_64_bit?
              url "{base_url}/{ASSETS['aarch64-unknown-linux-musl']}"
              sha256 "{require_digest(digests, ASSETS['aarch64-unknown-linux-musl'])}"
            end
          end

          def install
            bin.install "bin/cld-gateway"
          end

          test do
            output = shell_output("#{bin}/cld-gateway invalid-command 2>&1", 1)
            assert_match "unknown command", output
          end
        end
        '''
    )


def main() -> int:
    args = parse_args()
    manifest = load_manifest(args.version, args.manifest_file)
    digests = parse_manifest(manifest)
    formula = render_formula(args.version, digests)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(formula, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
