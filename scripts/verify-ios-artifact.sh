#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-}"
EXPECTED_BUNDLE_ID="${2:-com.appgumbo.rarecheck}"
EXPECTED_DISPLAY_NAME="${3:-PokeRareCheck}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -n "$APP_PATH" ]] || fail "Usage: $0 /path/to/App.app [bundle-id] [display-name]"
[[ -d "$APP_PATH" ]] || fail "Missing .app bundle: $APP_PATH"
[[ -f "$APP_PATH/Info.plist" ]] || fail "Missing Info.plist"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print $1" "$APP_PATH/Info.plist" 2>/dev/null || true
}

BUNDLE_ID="$(plist_value CFBundleIdentifier)"
DISPLAY_NAME="$(plist_value CFBundleDisplayName)"
DB_PATH="$APP_PATH/rarecheck_card_index_seed.json"

[[ "$BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] || fail "Expected bundle $EXPECTED_BUNDLE_ID, found $BUNDLE_ID"
[[ "$DISPLAY_NAME" == "$EXPECTED_DISPLAY_NAME" ]] || fail "Expected display name $EXPECTED_DISPLAY_NAME, found $DISPLAY_NAME"
[[ -f "$APP_PATH/PrivacyInfo.xcprivacy" ]] || fail "Missing root PrivacyInfo.xcprivacy"
[[ -f "$DB_PATH" ]] || fail "Missing embedded Pokemon DB seed: rarecheck_card_index_seed.json"

DB_BYTES="$(wc -c < "$DB_PATH" | tr -d ' ')"
[[ "$DB_BYTES" -gt 1000000 ]] || fail "Embedded Pokemon DB seed is unexpectedly small: ${DB_BYTES} bytes"

if grep -R -I -q -E "com\\.ryanramtin|com\\.ryancramtin" "$APP_PATH"; then
  fail "Artifact contains stale personal bundle marker"
fi

if grep -R -I -q "Searching Pokemon DB 0s" "$APP_PATH"; then
  fail "Artifact still contains stale zero-second DB search copy"
fi

echo "PASS: PokeRareCheck artifact is AppGumbo-scoped with embedded local DB ($BUNDLE_ID)"
