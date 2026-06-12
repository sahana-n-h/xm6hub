#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT}/build/libmdr"
VENDOR="${ROOT}/vendor/SonyHeadphonesClient"

mkdir -p "${BUILD_DIR}"

cmake -S "${VENDOR}" -B "${BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DMDR_ENABLE_CODEGEN=OFF \
  -DCMAKE_OSX_ARCHITECTURES="${ARCHS:-$(uname -m)}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"

cmake --build "${BUILD_DIR}" --target mdr -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

echo "libmdr built at ${BUILD_DIR}/libmdr/src/libmdr.a"
