#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
xcrun swiftc -O \
  -framework ApplicationServices -framework CoreGraphics \
  "$repo_root/src/logic/events/WindowCaptureExclusionTestable.swift" \
  "$repo_root/docs/issues/44/classifier-tests.swift" \
  -o "$tmp_dir/classifier-tests"
"$tmp_dir/classifier-tests"
