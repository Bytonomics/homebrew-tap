#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
script="$repo_root/.github/scripts/check-version.sh"
fixture_dir="$repo_root/.github/scripts/tests/data"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "ASSERTION FAILED: $message" >&2
    echo "expected: $expected" >&2
    echo "actual:   $actual" >&2
    exit 1
  fi
}

run_case() {
  local name="$1"
  local setup_fn="$2"
  local incoming_version="$3"
  local expected_should_update="$4"
  local expected_current_version="$5"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  mkdir -p "$tmpdir/Formula"
  "$setup_fn" "$tmpdir"

  local output
  output="$(cd "$tmpdir" && bash "$script" "$incoming_version")"

  local should_update current_version incoming
  should_update="$(printf '%s\n' "$output" | awk -F= '/^should_update=/{print $2}')"
  current_version="$(printf '%s\n' "$output" | awk -F= '/^current_version=/{print $2}')"
  incoming="$(printf '%s\n' "$output" | awk -F= '/^incoming_version=/{print $2}')"

  assert_eq "$expected_should_update" "$should_update" "$name: should_update"
  assert_eq "$expected_current_version" "$current_version" "$name: current_version"
  assert_eq "$incoming_version" "$incoming" "$name: incoming_version"
}

setup_missing_formula() {
  local tmpdir="$1"
  : > "$tmpdir/Formula/.keep"
}

setup_version_010() {
  local tmpdir="$1"
  cp "$fixture_dir/formula-version-0.1.0.rb" "$tmpdir/Formula/cld-gateway.rb"
}

setup_version_020() {
  local tmpdir="$1"
  cp "$fixture_dir/formula-version-0.2.0.rb" "$tmpdir/Formula/cld-gateway.rb"
}

setup_malformed_formula() {
  local tmpdir="$1"
  cp "$fixture_dir/formula-no-version.rb" "$tmpdir/Formula/cld-gateway.rb"
}

setup_bootstrap_formula() {
  local tmpdir="$1"
  cp "$fixture_dir/formula-bootstrap-placeholder.rb" "$tmpdir/Formula/cld-gateway.rb"
}

main() {
  run_case "missing formula" setup_missing_formula "0.1.0" "true" ""
  run_case "bootstrap formula without version" setup_bootstrap_formula "0.1.0" "true" ""
  run_case "same version" setup_version_010 "0.1.0" "true" "0.1.0"
  run_case "newer version" setup_version_010 "0.2.0" "true" "0.1.0"
  run_case "older version" setup_version_020 "0.1.0" "false" "0.2.0"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  mkdir -p "$tmpdir/Formula"
  setup_malformed_formula "$tmpdir"

  local stdout_file="$tmpdir/check-version.out"
  local stderr_file="$tmpdir/check-version.err"

  if (cd "$tmpdir" && bash "$script" "0.1.0") >"$stdout_file" 2>"$stderr_file"; then
    echo "ASSERTION FAILED: malformed formula should have failed" >&2
    exit 1
  fi

  if ! grep -q "Could not extract version" "$stderr_file"; then
    echo "ASSERTION FAILED: malformed formula error message missing" >&2
    cat "$stderr_file" >&2
    exit 1
  fi

  echo "check-version.sh tests passed"
}

main "$@"
