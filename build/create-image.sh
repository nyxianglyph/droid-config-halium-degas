#!/bin/bash
# Build a Sailfish OS image for the Xiaomi 14T (halium-degas) from the local
# device packages, then pack a flashable super.img that carries the Sailfish
# root file system as system_a plus the stock vendor, odm and dlkm partitions.
#
#   STOCK=<dir> LPMAKE=<path> create-image.sh [release] [devel|testing]
#
# Needs:
#   $WORK/localrepo/   the device RPMs (see build-sdk-rpm.sh, build-kernel-rpm.sh)
#   $STOCK/            vendor_a.img odm_a.img vendor_dlkm_a.img odm_dlkm_a.img
#                      system_dlkm_a.img of the stock firmware the port is based
#                      on (HyperOS OS3.0.305.0.WNEIDXM), dumped from the phone's
#                      /dev/block/mapper or unpacked from its super image
#   $LPMAKE            lpmake from the Android build tools
#   docker with the Sailfish Platform SDK image
#
# WORK defaults to the directory that holds this repository's checkout.
set -euo pipefail

WORK=${WORK:-$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)}
STOCK=${STOCK:?set STOCK to the directory with the stock partition images}
LPMAKE=${LPMAKE:-lpmake}
RELEASE=${1:-5.2.0.22}
VERSION=${2:-devel}
DEVICE=halium-degas
ARCH=aarch64
SDK=${SDK:-coderus/sailfishos-platform-sdk:5.0.0.43}
OUT=$WORK/images/sfe-$DEVICE-$RELEASE

mkdir -p "$WORK/images" "$WORK/mic-tmp"
rm -rf "$OUT"

# Kickstart from the freshly built ssu-kickstarts package
KSDIR=$WORK/mic-tmp/ks
rm -rf "$KSDIR"; mkdir -p "$KSDIR"
bsdtar -xf "$(ls -t "$WORK"/localrepo/droid-config-$DEVICE-ssu-kickstarts-*.rpm | head -1)" -C "$KSDIR"
KS=$KSDIR/usr/share/kickstarts/Jolla-@RELEASE@-$DEVICE-$VERSION-@ARCH@.ks

RELEASEMAJMIN=$(echo "$RELEASE" | cut -d . -f 1-2)

docker run --rm --privileged -u root \
    -v "$WORK/localrepo:/share/repo" -v "$WORK:$WORK" "$SDK" bash -c "
  set -e
  zypper -n in createrepo_c >/dev/null
  createrepo_c -q /share/repo
  mic create loop --arch=$ARCH \
    --tokenmap=ARCH:$ARCH,RELEASE:$RELEASE,RELEASEMAJMIN:$RELEASEMAJMIN,EXTRA_NAME:,DEVICEMODEL:$DEVICE \
    --record-pkgs=name,url \
    --cachedir=$WORK/mic-tmp/cache \
    --outdir=$OUT '$KS'
  chown -R $(id -u):$(id -g) $OUT /share/repo
"

ROOT=$OUT/root.img
[ -f "$ROOT" ] || { echo "mic produced no root.img"; ls -la "$OUT"; exit 1; }

# super.img: Sailfish root as system_a, stock partitions next to it.
# The Halium ramdisk maps them with parse-android-dynparts; mount-android.sh
# and the Android container find vendor_a, odm_a, ... under /dev/mapper.
mib=$((2**20))
super_size=$((9216*mib))
group_size=$((super_size - 4*mib))
args=()
for p in vendor_a odm_a vendor_dlkm_a odm_dlkm_a system_dlkm_a; do
    sz=$(stat -c %s "$STOCK/$p.img")
    args+=(--partition "$p:readonly:$sz:main" --image "$p=$STOCK/$p.img")
done
root_size=$(stat -c %s "$ROOT")
"$LPMAKE" --metadata-size 65536 --metadata-slots 2 --sparse \
    --super-name super --device "super:$super_size" --group "main:$group_size" \
    --partition "system_a:none:$root_size:main" --image "system_a=$ROOT" \
    "${args[@]}" --output "$OUT/super.img"

cp "$(dirname "$(readlink -f "$0")")/../sparse/boot/flash.sh" "$OUT/" 2>/dev/null || true
ls -la "$OUT"
