#!/bin/bash
# One-command local build: FileAdmin source -> Linux binaries -> fnOS .fpk
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SOURCE="${FILEADMIN_SRC:-${ROOT}/../fileAdmin}"
VERSION="$(grep -E '^version[[:space:]]*=' "${ROOT}/package/manifest" | awk -F= '{print $2}' | xargs)"
FNPACK="${ROOT}/fnpack"

if [ ! -f "${SOURCE}/go.mod" ]; then
  echo "FileAdmin source not found: ${SOURCE}" >&2
  echo "Clone FileAdmin next to this repository, or set FILEADMIN_SRC=/path/to/fileAdmin." >&2
  exit 1
fi

case "$(uname -s):$(uname -m)" in
  Linux:x86_64) FNPACK_URL="https://static2.fnnas.com/fnpack/fnpack-1.2.3-linux-amd64" ;;
  Linux:aarch64|Linux:arm64) FNPACK_URL="https://static2.fnnas.com/fnpack/fnpack-1.2.3-linux-arm64" ;;
  Darwin:x86_64) FNPACK_URL="https://static2.fnnas.com/fnpack/fnpack-1.2.3-darwin-amd64" ;;
  Darwin:arm64) FNPACK_URL="https://static2.fnnas.com/fnpack/fnpack-1.2.3-darwin-arm64" ;;
  *)
    echo "Unsupported host: $(uname -s) $(uname -m)" >&2
    exit 1
    ;;
esac

if [ ! -x "${FNPACK}" ]; then
  echo "Downloading fnpack..."
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --retry 3 -o "${FNPACK}" "${FNPACK_URL}"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "${FNPACK}" "${FNPACK_URL}"
  else
    echo "curl or wget is required to download fnpack" >&2
    exit 1
  fi
  chmod +x "${FNPACK}"
fi

echo "Building FileAdmin ${VERSION} from ${SOURCE}"
mkdir -p "${ROOT}/package/app/server"

for pair in amd64:x86_64 arm64:aarch64; do
  arch="${pair%%:*}"
  suffix="${pair##*:}"
  (
    cd "${SOURCE}"
    CGO_ENABLED=0 GOOS=linux GOARCH="${arch}" \
      go build -trimpath \
      -ldflags "-s -w -X main.version=v${VERSION}" \
      -o "${ROOT}/package/app/server/fileadmin_${suffix}" \
      ./cmd/fileadmin
  )
done

chmod +x "${ROOT}/package/app/server/fileadmin_"*
echo "Running fnpack..."
"${FNPACK}" build --directory "${ROOT}/package"

BUILT="$(find "${ROOT}" -maxdepth 2 -name '*.fpk' -type f | head -n 1)"
[ -n "${BUILT}" ] || {
  echo "fnpack did not produce a .fpk file" >&2
  exit 1
}
OUT="${ROOT}/fileadmin_all_v${VERSION}.fpk"
mv "${BUILT}" "${OUT}"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${OUT}" >"${OUT}.sha256"
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "${OUT}" >"${OUT}.sha256"
fi
echo "Built ${OUT}"
