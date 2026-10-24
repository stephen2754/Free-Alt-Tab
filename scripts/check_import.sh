#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
cat > "$test_dir/main.swift" <<'SWIFT'
import Foundation
let count = try PreferencesImportChecks.run()
print("Settings import checks passed (\(count) assertions).")
SWIFT
xcrun swiftc -swift-version 5 \
  src/preferences/import/PreferencesImport.swift \
  src/preferences/import/PreferencesImportTests.swift \
  "$test_dir/main.swift" -o "$test_dir/check-import"
"$test_dir/check-import"
