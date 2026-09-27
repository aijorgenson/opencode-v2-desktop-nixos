#!/usr/bin/env bash
# Refresh sources.json from the OpenCode Desktop stable update API and verify
# the package still builds. No argument = latest stable. See README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_FILE="$SCRIPT_DIR/sources.json"
API_URL="https://opencode.ai/update/api/latest/desktop/opencode/"

prefetch() {
  local url="$1"
  nix store prefetch-file --json --hash-type sha256 "$url"
}

require_appimage() {
  local arch="$1"
  local url="$2"
  local version="$3"
  case "$url" in
    "https://opencode.ai/files/bin/${version}/"*.AppImage) ;;
    *)
      echo "Expected an AppImage for ${arch} under version ${version}, got: ${url}" >&2
      exit 1
      ;;
  esac
}

CURRENT_VERSION=$(jq -r '.version' "$SOURCES_FILE")
META=$(curl -fsSL "$API_URL")

NEW_VERSION=$(jq -r '.version' <<< "$META")
X64_URL=$(jq -r '.metadata.files["opencode-desktop-linux-x86_64.AppImage"].url' <<< "$META")
ARM_URL=$(jq -r '.metadata.files["opencode-desktop-linux-arm64.AppImage"].url' <<< "$META")

if [ -z "$NEW_VERSION" ] || [ "$NEW_VERSION" = "null" ] || [ -z "$X64_URL" ] || [ "$X64_URL" = "null" ] || [ -z "$ARM_URL" ] || [ "$ARM_URL" = "null" ]; then
  echo "Could not parse the OpenCode Desktop update API response." >&2
  exit 1
fi

require_appimage x86_64-linux "$X64_URL" "$NEW_VERSION"
require_appimage aarch64-linux "$ARM_URL" "$NEW_VERSION"

if [ "$NEW_VERSION" = "$CURRENT_VERSION" ]; then
  echo "Already up to date (${CURRENT_VERSION})."
  exit 0
fi

echo "Updating opencode-desktop: ${CURRENT_VERSION} -> ${NEW_VERSION}"
echo "  x86_64-linux: ${X64_URL}"
echo "  aarch64-linux: ${ARM_URL}"

echo "Prefetching x86_64 AppImage..."
X64_JSON=$(prefetch "$X64_URL")
X64_HASH=$(jq -r '.hash' <<< "$X64_JSON")

echo "Prefetching aarch64 AppImage..."
ARM_JSON=$(prefetch "$ARM_URL")
ARM_HASH=$(jq -r '.hash' <<< "$ARM_JSON")

jq -n \
  --arg version "$NEW_VERSION" \
  --arg x64_url "$X64_URL" \
  --arg x64_hash "$X64_HASH" \
  --arg arm_url "$ARM_URL" \
  --arg arm_hash "$ARM_HASH" \
  '{
    version: $version,
    sources: {
      "x86_64-linux": { url: $x64_url, hash: $x64_hash },
      "aarch64-linux": { url: $arm_url, hash: $arm_hash }
    }
  }' > "$SOURCES_FILE"

echo "Wrote ${SOURCES_FILE}"
echo "Building package to verify..."
nix build "${SCRIPT_DIR}#default" --no-link
RESULT_PATH=$(nix build "${SCRIPT_DIR}#default" --no-link --print-out-paths)
echo "Built: ${RESULT_PATH}"
echo
echo "sources.json now points at ${NEW_VERSION}. Review the diff before committing:"
echo "  git -C \"${SCRIPT_DIR}\" diff sources.json"
