#!/usr/bin/env python3
"""Render the cld-gateway Homebrew formula from release checksums."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
import re
import time
from urllib.error import URLError
from urllib.request import urlopen

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = REPO_ROOT / 'Formula' / 'cld-gateway.rb'
DEFAULT_TEMPLATE = REPO_ROOT / '.github' / 'scripts' / 'templates' / 'cld-gateway.rb.erb'
RELEASE_URL_TEMPLATE = (
    'https://github.com/Bytonomics/cld-gateway/releases/download/cld-gateway-v{version}'
)
ASSETS = {
    'aarch64-apple-darwin': 'cld-gateway-package-aarch64-apple-darwin.tar.gz',
    'x86_64-apple-darwin': 'cld-gateway-package-x86_64-apple-darwin.tar.gz',
    'aarch64-unknown-linux-musl': 'cld-gateway-package-aarch64-unknown-linux-musl.tar.gz',
    'x86_64-unknown-linux-musl': 'cld-gateway-package-x86_64-unknown-linux-musl.tar.gz',
}
SHA256_RE = re.compile(r'^[0-9a-f]{64}$')
FETCH_TIMEOUT_SECONDS = 30
FETCH_RETRY_DELAYS_SECONDS = (1, 2, 4)
CLAUDE_CODEX_SHARED_ENTRIES = (
    '.claude.json',
    'CLAUDE.md',
    'agents',
    'commands',
    'debug',
    'docs',
    'downloads',
    'history.jsonl',
    'hookify.block-direct-go-commands.local.md',
    'hookify.block-git-add-all.local.md',
    'hookify.block-no-verify-commit.local.md',
    'hooks',
    'ide',
    'output-styles',
    'plans',
    'plugins',
    'projects',
    'session-env',
    'shell-snapshots',
    'skills',
    'statusline-command.sh',
    'todos',
    'universal_instructions.md',
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True, help='cld-gateway release version')
    parser.add_argument(
        '--manifest-file',
        type=Path,
        help='Optional local cld-gateway-package_SHA256SUMS fixture for CI or dry runs.',
    )
    parser.add_argument(
        '--template',
        type=Path,
        default=DEFAULT_TEMPLATE,
        help='Formula template path.',
    )
    parser.add_argument(
        '--output',
        type=Path,
        default=DEFAULT_OUTPUT,
        help='Formula output path.',
    )
    return parser.parse_args()


def load_manifest(version: str, manifest_file: Path | None) -> str:
    if manifest_file is not None:
        return manifest_file.read_text(encoding='utf-8')

    url = f'{RELEASE_URL_TEMPLATE.format(version=version)}/cld-gateway-package_SHA256SUMS'
    errors: list[str] = []
    for attempt, delay in enumerate((*FETCH_RETRY_DELAYS_SECONDS, None), start=1):
        try:
            with urlopen(url, timeout=FETCH_TIMEOUT_SECONDS) as response:
                return response.read().decode('utf-8')
        except (TimeoutError, URLError, OSError) as exc:
            errors.append(f'attempt {attempt}: {exc}')
            if delay is None:
                joined_errors = '; '.join(errors)
                raise SystemExit(
                    f'Failed to fetch checksum manifest from {url}: {joined_errors}'
                ) from exc
            time.sleep(delay)

    raise SystemExit(f'Failed to fetch checksum manifest from {url}')


def parse_manifest(manifest: str) -> dict[str, str]:
    digests: dict[str, str] = {}
    for raw_line in manifest.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        parts = line.split(maxsplit=1)
        if len(parts) != 2:
            raise SystemExit(f'Invalid checksum manifest line: {raw_line!r}')
        digest, asset = parts
        asset = asset.lstrip('*')
        digests[asset] = digest.lower()
    return digests


def require_digest(digests: dict[str, str], asset: str) -> str:
    digest = digests.get(asset)
    if digest is None:
        raise SystemExit(f'Missing SHA256 digest for {asset}')
    if not SHA256_RE.fullmatch(digest):
        raise SystemExit(f'Invalid SHA256 digest for {asset}: {digest}')
    return digest


def build_template_context(version: str, digests: dict[str, str]) -> dict[str, object]:
    base_url = RELEASE_URL_TEMPLATE.format(version=version)
    macos_intel_asset = ASSETS['x86_64-apple-darwin']
    macos_arm_asset = ASSETS['aarch64-apple-darwin']
    linux_intel_asset = ASSETS['x86_64-unknown-linux-musl']
    linux_arm_asset = ASSETS['aarch64-unknown-linux-musl']

    return {
        'version': version,
        'base_url': base_url,
        'macos_intel_url': f'{base_url}/{macos_intel_asset}',
        'macos_intel_sha256': require_digest(digests, macos_intel_asset),
        'macos_arm_url': f'{base_url}/{macos_arm_asset}',
        'macos_arm_sha256': require_digest(digests, macos_arm_asset),
        'linux_intel_url': f'{base_url}/{linux_intel_asset}',
        'linux_intel_sha256': require_digest(digests, linux_intel_asset),
        'linux_arm_url': f'{base_url}/{linux_arm_asset}',
        'linux_arm_sha256': require_digest(digests, linux_arm_asset),
        'shared_claude_entries': list(CLAUDE_CODEX_SHARED_ENTRIES),
    }


def load_template(template_path: Path) -> str:
    try:
        return template_path.read_text(encoding='utf-8')
    except OSError as exc:
        raise SystemExit(f'Failed to read formula template {template_path}: {exc}') from exc


def render_template(template_path: Path, context: dict[str, object]) -> str:
    template_text = load_template(template_path)
    ruby_program = '''
require 'erb'
require 'json'

template = ARGV.fetch(0)
context = JSON.parse(STDIN.read)
renderer = Object.new
context.each do |key, value|
  renderer.instance_variable_set("@#{key}", value)
  renderer.define_singleton_method(key) { instance_variable_get("@#{key}") }
end
renderer.define_singleton_method(:get_binding) { binding }
print ERB.new(template, trim_mode: '-').result(renderer.get_binding)
'''
    try:
        result = subprocess.run(
            ['ruby', '-e', ruby_program, template_text],
            input=json.dumps(context),
            text=True,
            capture_output=True,
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.strip()
        raise SystemExit(f'Failed to render formula template {template_path}: {stderr}') from exc
    return result.stdout


def render_formula(
    version: str,
    digests: dict[str, str],
    template_path: Path = DEFAULT_TEMPLATE,
) -> str:
    context = build_template_context(version, digests)
    return render_template(template_path, context)


def main() -> int:
    args = parse_args()
    manifest = load_manifest(args.version, args.manifest_file)
    digests = parse_manifest(manifest)
    formula = render_formula(args.version, digests, args.template)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(formula, encoding='utf-8')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
