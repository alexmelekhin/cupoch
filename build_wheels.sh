#!/usr/bin/env bash
# Build one cupoch wheel per CUDA architecture via the project Dockerfile.
#
# Each arch is exported to its own directory (dist/sm_<arch>/) on purpose:
# the wheel filename does not encode the CUDA arch, so a shared dest would
# silently overwrite previous builds.
#
# Usage:
#   ./build_wheels.sh                       # default archs: 80 86 89 90
#   ./build_wheels.sh 86 89                 # only the given archs
#   CUDA_VERSION=12.9.0 PYTHON_VERSION=3.11 ./build_wheels.sh
set -euo pipefail

# Repo root = the directory holding this script (and the Dockerfile).
cd "$(dirname "$0")"

ARCHS=("$@")
if [ ${#ARCHS[@]} -eq 0 ]; then
    ARCHS=(80 86 89 90)
fi

CUDA_VERSION="${CUDA_VERSION:-12.8.0}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"

echo "CUDA image   : ${CUDA_VERSION}"
echo "Python       : ${PYTHON_VERSION}"
echo "Architectures: ${ARCHS[*]}"
echo

for arch in "${ARCHS[@]}"; do
    dest="dist/sm_${arch}"
    echo "==> Building wheel for sm_${arch} -> ${dest}/"
    DOCKER_BUILDKIT=1 docker build \
        --build-arg CUDA_VERSION="${CUDA_VERSION}" \
        --build-arg PYTHON_VERSION="${PYTHON_VERSION}" \
        --build-arg CUDA_ARCHITECTURES="${arch}" \
        --output "type=local,dest=${dest}" \
        .
done

echo
echo "Done. Wheels:"
for arch in "${ARCHS[@]}"; do
    ls -1 "dist/sm_${arch}"/*.whl 2>/dev/null || echo "  (missing for sm_${arch})"
done
