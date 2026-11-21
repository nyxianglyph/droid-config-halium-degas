#!/bin/sh
# HyperOS ships vendor (and odm, *_dlkm) as erofs in super. mount-android.sh
# falls back to "mount -t ext4" for a vendor partition that is not in the DT
# fstab, which fails here. Mount it with the detected type first;
# mount-android.sh then sees /vendor mounted and goes on with the fstab.
mountpoint -q /vendor && exit 0
slot=$(grep -o 'androidboot\.slot_suffix = ".."' /proc/bootconfig 2>/dev/null | cut -d '"' -f2)
dev=/dev/mapper/vendor${slot:-_a}
[ -e "$dev" ] || dev=/dev/mapper/vendor
[ -e "$dev" ] || exit 0
type=$(blkid -o value -s TYPE "$dev")
echo "mount-vendor: mounting $dev ($type) as /vendor"
mount -t "${type:-ext4}" -o ro "$dev" /vendor
