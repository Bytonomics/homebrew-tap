#!/bin/sh
# Pre-commit hook: ensure Formula/cld-gateway.rb matches the rendered template.
#
# Extracts the version from the checked-in formula, re-renders the template
# via render-formula.py (which fetches the manifest from GitHub releases),
# and fails if the output differs.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FORMULA="$REPO_ROOT/Formula/cld-gateway.rb"
RENDER_SCRIPT="$SCRIPT_DIR/render-formula.py"

if [ ! -f "$FORMULA" ]; then
  echo "Formula not found: $FORMULA" >&2
  exit 1
fi

if [ ! -f "$RENDER_SCRIPT" ]; then
  echo "Render script not found: $RENDER_SCRIPT" >&2
  exit 1
fi

# Extract version from the first URL in the formula
version="$(grep -m1 'cld-gateway-v[0-9]' "$FORMULA" | sed -E 's|.*cld-gateway-v([0-9]+\.[0-9]+\.[0-9]+[^/]*).*|\1|')"
if [ -z "$version" ]; then
  echo "Could not extract version from $FORMULA" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

rendered="$tmp_dir/cld-gateway.rb"

# Re-render the template (fetches manifest from GitHub releases)
python3 "$RENDER_SCRIPT" \
  --version "$version" \
  --output "$rendered"

# Compare
if diff -q "$rendered" "$FORMULA" >/dev/null 2>&1; then
  echo "Formula is up to date with template."
  exit 0
else
  echo "Formula/cld-gateway.rb is stale — does not match the rendered template." >&2
  echo "" >&2
  diff -u "$FORMULA" "$rendered" >&2 || true
  echo "" >&2
  echo "To fix: re-render with the same version and manifest, or update the formula." >&2
  exit 1
fi
