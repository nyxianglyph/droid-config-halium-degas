#!/bin/bash
# Build a device package in the Sailfish Platform SDK (aarch64 sb2 target).
# Build requirements are not installed (--nodeps): the Halium device packages
# only list middleware there to record its versions. Extra packages the build
# really needs are given as the third argument.
#
#   build-sdk-rpm.sh <repo dir> <spec, relative to it> ["packages to install"]
#
# The RPMs end up in $WORK/localrepo. WORK defaults to the directory that
# holds this repository's checkout.
set -euo pipefail
WORK=${WORK:-$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)}
SDK=${SDK:-coderus/sailfishos-platform-sdk:5.0.0.43}
TARGET=${TARGET:-SailfishOS-5.0.0.43-aarch64}
repo=$(readlink -f "$1") spec=$2; shift 2; pkgs="$*"
mkdir -p "$WORK/localrepo"
docker run --rm -v "$repo:$repo:ro" -v "$WORK/localrepo:/out" "$SDK" bash -c "
  set -e
  mkdir -p ~/work && cp -a $repo ~/work/src && cd ~/work/src
  mb2 -t $TARGET build-init
  [ -z \"$pkgs\" ] || mb2 -t $TARGET build-shell --maintain zypper -n ar -f -G http://repo.sailfishos.org/obs/nemo:/devel:/hw:/halium:/14/sailfish_latest_aarch64/ halium14
  [ -z \"$pkgs\" ] || mb2 -t $TARGET build-shell --maintain zypper -n --gpg-auto-import-keys ref halium14
  [ -z \"$pkgs\" ] || mb2 -t $TARGET build-shell --maintain zypper -n in $pkgs
  mb2 -t $TARGET build-shell rpmbuild --build-in-place --nodeps \
     --define \"_topdir \$HOME/work/rpmbuild\" --define 'debug_package %{nil}' -bb $spec
  cp -v ~/work/rpmbuild/RPMS/*/*.rpm /out/
"
