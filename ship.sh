#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${REPO_ROOT}"

APP_NAME="Virtual Overlay"
APP_BUNDLE="dist/${APP_NAME}.app"
MINIMUM_SYSTEM_VERSION="$(sed -nE 's/^[[:space:]]*\\.macOS\\(\\.v([0-9]+)\\).*/\\1.0/p' Package.swift | head -n 1)"
MINIMUM_SYSTEM_VERSION="${MINIMUM_SYSTEM_VERSION:-13.0}"
ALLOW_DIRTY=0
VERSION=""

usage() {
  echo "usage: ./ship.sh VERSION [--allow-dirty]" >&2
  echo "example: ./ship.sh 0.1.0" >&2
}

fail() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "${VERSION}" ]]; then
        usage
        fail "unexpected argument: $1"
      fi
      VERSION="$1"
      shift
      ;;
  esac
done

if [[ -z "${VERSION}" ]]; then
  usage
  fail "missing version argument"
fi

if [[ "${VERSION}" == v* ]]; then
  fail "version must not start with 'v'; use '${VERSION#v}'"
fi

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$ ]]; then
  fail "version must look like 0.1.0 or 0.1.0-rc1"
fi

for tool in git swift codesign xattr ditto shasum stat du; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    fail "${tool} is required"
  fi
done

if [[ -n "$(git status --porcelain)" ]]; then
  if [[ "${ALLOW_DIRTY}" -eq 1 ]]; then
    echo "warning: working tree is dirty; continuing because --allow-dirty was provided." >&2
  else
    echo "error: working tree is dirty. Commit or stash changes before shipping." >&2
    echo "       Use --allow-dirty only for local release-candidate verification." >&2
    git status --short >&2
    exit 1
  fi
fi

if git rev-parse -q --verify "refs/tags/v${VERSION}" >/dev/null || git rev-parse -q --verify "refs/tags/${VERSION}" >/dev/null; then
  fail "git tag v${VERSION} or ${VERSION} already exists"
fi

echo "Running tests..."
swift test

echo "Building release bundle for ${VERSION}..."
./bundle.sh "${VERSION}"

if [[ ! -d "${APP_BUNDLE}" ]]; then
  fail "expected app bundle at ${APP_BUNDLE}"
fi

echo "Verifying ad-hoc signature..."
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

echo "Clearing extended attributes..."
xattr -cr "${APP_BUNDLE}"

ZIP_PATH="dist/Virtual-Overlay-v${VERSION}.zip"
SHA_PATH="dist/Virtual-Overlay-v${VERSION}.sha256"
RELEASE_NOTES_PATH="dist/RELEASE_NOTES.md"

rm -f "${ZIP_PATH}" "${SHA_PATH}" "${RELEASE_NOTES_PATH}"

echo "Creating ${ZIP_PATH}..."
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

SHA256="$(shasum -a 256 "${ZIP_PATH}" | awk '{print $1}')"
printf "%s  %s\n" "${SHA256}" "$(basename "${ZIP_PATH}")" > "${SHA_PATH}"

{
  printf "# Virtual Overlay v%s\n\n" "${VERSION}"
  printf "## What's new\n\n"
  printf -- "- TODO: describe what changed in this release.\n\n"
  printf "## Install\n\n"
  printf "See the README for full install instructions. In short: download the ZIP, unzip it, drag \`Virtual Overlay.app\` to \`/Applications\`, then run:\n\n"
  printf "\`\`\`bash\n"
  printf "xattr -dr com.apple.quarantine \"/Applications/Virtual Overlay.app\"\n"
  printf "open \"/Applications/Virtual Overlay.app\"\n"
  printf "\`\`\`\n\n"
  printf "## SHA-256\n\n"
  printf "\`\`\`\n%s  %s\n\`\`\`\n\n" "${SHA256}" "$(basename "${ZIP_PATH}")"
  printf "## First launch\n\n"
  printf "Virtual Overlay uses private CoreGraphics / SkyLight APIs and cannot be notarized. Modern macOS blocks the old right-click → Open bypass for ad-hoc signed downloads; remove quarantine for this one app instead:\n\n"
  printf "\`\`\`bash\n"
  printf "xattr -dr com.apple.quarantine \"/Applications/Virtual Overlay.app\"\n"
  printf "open \"/Applications/Virtual Overlay.app\"\n"
  printf "\`\`\`\n\n"
  printf "After that, double-click launches normally.\n\n"
  printf "## Requirements\n\n"
  printf -- "- macOS %s+\n" "${MINIMUM_SYSTEM_VERSION}"
} > "${RELEASE_NOTES_PATH}"

ZIP_BYTES="$(stat -f%z "${ZIP_PATH}")"
SHA_BYTES="$(stat -f%z "${SHA_PATH}")"
NOTES_BYTES="$(stat -f%z "${RELEASE_NOTES_PATH}")"
ZIP_HUMAN="$(du -h "${ZIP_PATH}" | awk '{print $1}')"
SHA_HUMAN="$(du -h "${SHA_PATH}" | awk '{print $1}')"
NOTES_HUMAN="$(du -h "${RELEASE_NOTES_PATH}" | awk '{print $1}')"

echo
echo "Release artifact ready:"
echo "  App:   ${APP_BUNDLE}"
echo "  ZIP:   ${ZIP_PATH} (${ZIP_HUMAN}, ${ZIP_BYTES} bytes)"
echo "  SHA:   ${SHA_PATH} (${SHA_HUMAN}, ${SHA_BYTES} bytes)"
echo "  Notes: ${RELEASE_NOTES_PATH} (${NOTES_HUMAN}, ${NOTES_BYTES} bytes)"
echo "  SHA-256: ${SHA256}"
echo
echo "Suggested publish command:"
printf 'gh release create v%s \\\n' "${VERSION}"
printf '  "%s" \\\n' "${ZIP_PATH}"
printf '  "%s" \\\n' "${SHA_PATH}"
printf '  --title "Virtual Overlay v%s" \\\n' "${VERSION}"
printf '  --notes-file %s\n' "${RELEASE_NOTES_PATH}"
