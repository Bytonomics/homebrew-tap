#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  validate-formula.sh [-v] current
  validate-formula.sh [-v] fixture
  validate-formula.sh [-v] release <version>
EOF
}

verbose=0
if [[ $# -gt 0 && "$1" == "-v" ]]; then
  verbose=1
  shift
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

mode="$1"
shift

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture_manifest="$repo_root/.github/scripts/tests/data/cld-gateway-package_SHA256SUMS"
homebrew_repo="$(brew --repository)"
tap_parent="$homebrew_repo/Library/Taps/bytonomics"
tap_path="$tap_parent/homebrew-tap"
tap_formula="bytonomics/tap/cld-gateway"
workspace_root="$(mktemp -d)"
backup_root="$(mktemp -d)"
workspace="$workspace_root/homebrew-tap"
backup_tap_path="$backup_root/homebrew-tap"
had_existing_tap="false"
tap_replaced="false"
render_args=()

cleanup() {
  local exit_code=$?
  set +e
  trap - EXIT HUP INT TERM

  if [[ "$tap_replaced" == "true" ]]; then
    if [[ -L "$tap_path" && "$(readlink "$tap_path")" == "$workspace" ]]; then
      rm -f "$tap_path"
    elif [[ -e "$tap_path" || -L "$tap_path" ]]; then
      echo "Refusing to remove unexpected Homebrew tap path during cleanup: $tap_path" >&2
      echo "Original tap backup, if any, is at: $backup_tap_path" >&2
      rm -rf "$workspace_root"
      exit "$exit_code"
    fi

    if [[ "$had_existing_tap" == "true" && -e "$backup_tap_path" ]]; then
      mkdir -p "$tap_parent"
      mv "$backup_tap_path" "$tap_path"
    fi
  fi

  rm -rf "$workspace_root"
  if [[ -d "$backup_root" ]]; then
    rmdir "$backup_root"
  fi
  exit "$exit_code"
}
trap cleanup EXIT HUP INT TERM

case "$mode" in
  current)
    if [[ $# -ne 0 ]]; then
      usage >&2
      exit 1
    fi
    ;;
  fixture)
    if [[ $# -ne 0 ]]; then
      usage >&2
      exit 1
    fi
    render_args=(
      --version 0.1.0
      --manifest-file "$fixture_manifest"
    )
    ;;
  release)
    if [[ $# -ne 1 ]]; then
      usage >&2
      exit 1
    fi
    render_args=(
      --version "$1"
    )
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

mkdir -p "$workspace"
cp -R \
  "$repo_root/.github" \
  "$repo_root/Formula" \
  "$repo_root/LICENSE" \
  "$repo_root/README.md" \
  "$workspace/"

mkdir -p "$tap_parent"
if [[ -e "$tap_path" || -L "$tap_path" ]]; then
  had_existing_tap="true"
  mv "$tap_path" "$backup_tap_path"
fi
ln -s "$workspace" "$tap_path"
tap_replaced="true"

(
  cd "$workspace"
  bash .github/scripts/tests/check-version.sh
  if [[ "$mode" != "current" ]]; then
    python3 .github/scripts/render-formula.py \
      "${render_args[@]}" \
      --output Formula/cld-gateway.rb
  fi
  ruby -c Formula/cld-gateway.rb
  brew style Formula/cld-gateway.rb
  if [[ "$verbose" == "1" ]]; then
    cat Formula/cld-gateway.rb
  fi
  HOMEBREW_NO_INSTALL_FROM_API=1 brew audit --strict --online "$tap_formula"
)
