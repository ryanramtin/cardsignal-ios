#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${1:-com.appgumbo.rarecheck}"
PROFILE_DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"
XCODE_PROFILE_DIR="${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

profile_dirs=()
[[ -d "$PROFILE_DIR" ]] && profile_dirs+=("$PROFILE_DIR")
[[ -d "$XCODE_PROFILE_DIR" ]] && profile_dirs+=("$XCODE_PROFILE_DIR")
[[ "${#profile_dirs[@]}" -gt 0 ]] || fail "Missing provisioning profile directories: $PROFILE_DIR and $XCODE_PROFILE_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

matches=()
seen_profiles=()

while IFS= read -r -d '' profile; do
  plist="$TMP_DIR/$(basename "$profile").plist"
  if ! security cms -D -i "$profile" > "$plist" 2>/dev/null; then
    continue
  fi

  app_identifier="$(/usr/libexec/PlistBuddy -c "Print Entitlements:application-identifier" "$plist" 2>/dev/null || true)"
  profile_name="$(/usr/libexec/PlistBuddy -c "Print Name" "$plist" 2>/dev/null || basename "$profile")"
  [[ -n "$app_identifier" ]] && seen_profiles+=("$profile_name -> $app_identifier")
  [[ "$app_identifier" == *".${BUNDLE_ID}" ]] || continue

  matches+=("$profile_name")
done < <(find "${profile_dirs[@]}" -name '*.mobileprovision' -print0)

if [[ "${#matches[@]}" -eq 0 ]]; then
  if [[ "${#seen_profiles[@]}" -gt 0 ]]; then
    printf 'Installed profiles checked:\n' >&2
    printf '  %s\n' "${seen_profiles[@]}" >&2
  fi
  fail "No installed explicit provisioning profile for ${BUNDLE_ID}"
fi

printf 'PASS: %s provisioning profile is installed: %s\n' "$BUNDLE_ID" "${matches[0]}"
