#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <incoming-version>" >&2
  exit 1
fi

incoming_version="$1"
formula_path="./Formula/cld-gateway.rb"
current_version=""
should_update="true"
release_tag_prefix="cld-gateway-v"

compare_versions() {
  python3 - "$1" "$2" <<'PY'
from __future__ import annotations
import re
import sys

SEMVER_RE = re.compile(
    r"^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)"
    r"(?:-(?P<pre>[0-9A-Za-z.-]+))?$"
)


def parse(version: str) -> tuple[int, int, int, tuple[int, str, int]]:
    match = SEMVER_RE.match(version)
    if match is None:
        raise SystemExit(f"Unsupported version format: {version}")

    major = int(match.group("major"))
    minor = int(match.group("minor"))
    patch = int(match.group("patch"))
    pre = match.group("pre")
    if pre is None:
        pre_key = (1, "", 0)
    else:
        label, _, suffix = pre.partition(".")
        suffix_number = int(suffix) if suffix.isdigit() else 0
        pre_key = (0, label, suffix_number)
    return major, minor, patch, pre_key


current = parse(sys.argv[1])
incoming = parse(sys.argv[2])
if incoming > current:
    print("incoming-newer")
elif incoming == current:
    print("incoming-same")
else:
    print("incoming-older")
PY
}

if [[ -f "$formula_path" ]]; then
  current_version="$(awk -v tag_prefix="$release_tag_prefix" -F '"' '
    /^[[:space:]]*version "/ {
      print $2
      exit
    }
    /^[[:space:]]*url "/ {
      url = $2
      marker = "/releases/download/" tag_prefix
      marker_pos = index(url, marker)
      if (marker_pos > 0) {
        remainder = substr(url, marker_pos + length(marker))
        slash_pos = index(remainder, "/")
        if (slash_pos > 1) {
          print substr(remainder, 1, slash_pos - 1)
          exit
        }
      }
    }
  ' "$formula_path")"

  if [[ -z "$current_version" ]]; then
    if grep -q "This formula is populated by the bytonomics/homebrew-tap release workflows" "$formula_path"; then
      # Bootstrap placeholder formula before the first real release: no version yet,
      # but the incoming release should populate the formula.
      printf 'should_update=%s\ncurrent_version=%s\nincoming_version=%s\n' \
        "true" \
        "" \
        "$incoming_version"
      exit 0
    fi

    echo "Could not extract version from $formula_path" >&2
    exit 1
  fi

  comparison="$(compare_versions "$current_version" "$incoming_version")"
  case "$comparison" in
    incoming-newer)
      should_update="true"
      ;;
    incoming-same)
      should_update="true"
      ;;
    incoming-older)
      should_update="false"
      ;;
    *)
      echo "Unexpected version comparison result: $comparison" >&2
      exit 1
      ;;
  esac
fi

printf 'should_update=%s\ncurrent_version=%s\nincoming_version=%s\n' \
  "$should_update" \
  "$current_version" \
  "$incoming_version"
