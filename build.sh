#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PACKAGE="${ROOT}/package"

[ -f "${PACKAGE}/manifest" ] || {
  echo "package/manifest not found" >&2
  exit 1
}

APPNAME="$(grep -E '^appname[[:space:]]*=' "${PACKAGE}/manifest" | awk -F= '{print $2}' | xargs)"
VERSION="$(grep -E '^version[[:space:]]*=' "${PACKAGE}/manifest" | awk -F= '{print $2}' | xargs)"
PLATFORM="$(grep -E '^platform[[:space:]]*=' "${PACKAGE}/manifest" | awk -F= '{print $2}' | xargs)"

for binary in "${PACKAGE}"/app/server/fileadmin_*; do
  [ -f "${binary}" ] || {
    echo "Missing Linux binary: ${binary}" >&2
    echo "Build fileadmin_x86_64 and fileadmin_aarch64 first, or use the GitHub Actions workflow." >&2
    exit 1
  }
done

if command -v fnpack >/dev/null 2>&1; then
  FNPACK="fnpack"
elif [ -x "${ROOT}/fnpack" ]; then
  FNPACK="${ROOT}/fnpack"
elif [ -x "${ROOT}/fnpack.exe" ]; then
  FNPACK="${ROOT}/fnpack.exe"
else
  echo "fnpack not found. Download it from https://static2.fnnas.com/fnpack/" >&2
  exit 1
fi

echo "Packaging ${APPNAME} ${VERSION} (${PLATFORM})"
"${FNPACK}" build --directory "${PACKAGE}"

BUILT="$(find "${ROOT}" -maxdepth 2 -name '*.fpk' -type f | head -n 1)"
[ -n "${BUILT}" ] || {
  echo "fnpack did not produce a .fpk file" >&2
  exit 1
}

OUT="${ROOT}/${APPNAME}_${PLATFORM}_v${VERSION}.fpk"
mv "${BUILT}" "${OUT}"
sha256sum "${OUT}" >"${OUT}.sha256" 2>/dev/null || true
echo "Built ${OUT}"
