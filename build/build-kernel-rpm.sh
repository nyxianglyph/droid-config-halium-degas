#!/bin/bash
# Build the kernel-adaptation-halium-degas RPM in a Fedora container, like its
# CI, but with clang and the build tools from a local Android kernel (Kleaf)
# checkout.
#
#   BUILD_TOOLS=<dir with the clang and build-tools prebuilts> build-kernel-rpm.sh
#
# Expects $WORK/kernel-adaptation-halium-degas (with its submodules). The RPM
# is written to $WORK/rpmbuild/RPMS; copy it to $WORK/localrepo.
set -euo pipefail
WORK=${WORK:-$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)}
BUILD_TOOLS=${BUILD_TOOLS:?set BUILD_TOOLS to the prebuilts directory}
CLANG_VERSION=${CLANG_VERSION:-clang-r487747c}
docker run --rm -v "$WORK:$WORK" -v "$BUILD_TOOLS:$BUILD_TOOLS" -w "$WORK/kernel-adaptation-halium-degas" fedora:41 bash -c "
  set -e
  dnf install -q -y git rpmdevtools glibc.i686 openssl-devel-engine nodejs glibc-devel elfutils-libelf-devel dwarves python3 >/dev/null
  dnf builddep -q -y rpm/kernel-adaptation-halium-degas.spec >/dev/null
  export BUILD_TOOLS=$BUILD_TOOLS CLANG_VERSION=$CLANG_VERSION
  source kernel-adaptation-simplified/setup-env.sh
  rpmbuild --build-in-place --define 'debug_package %{nil}' --define '_topdir $WORK/rpmbuild' \
    --bb rpm/kernel-adaptation-halium-degas.spec --buildroot=\$PWD/buildroot
  chown -R $(id -u):$(id -g) $WORK/rpmbuild linux/out buildroot 2>/dev/null || true
"
