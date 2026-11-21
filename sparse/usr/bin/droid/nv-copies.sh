#!/bin/sh
# Keep the Android container off the real MediaTek NV/calibration partitions.
#
# Sailfish runs without SELinux. Files the modem creates on the real nvdata,
# nvcfg, persist or protect1/2 would get no SELinux label, and HyperOS later
# denies ccci_mdinit access to them: the modem crashes at boot and the phone
# shows no SIM cards on Android. So the container gets copies on /userdata.
#
#   nv-copies.sh prepare   copy each partition to /userdata/<label>.img once
#   nv-copies.sh remount   after mount-android.sh: swap real mounts for copies

PARTS="nvcfg:/mnt/vendor/nvcfg nvdata:/mnt/vendor/nvdata persist:/mnt/vendor/persist protect1:/mnt/vendor/protect_f protect2:/mnt/vendor/protect_s"
OPTS="noatime,nosuid,nodev,noauto_da_alloc,commit=1,nodelalloc"

case "$1" in
prepare)
    for e in $PARTS; do
        label=${e%%:*}
        img=/userdata/$label.img
        dev=/dev/disk/by-partlabel/$label
        [ -f "$img" ] && continue
        [ -e "$dev" ] || continue
        echo "nv-copies: copying $label to $img"
        dd if="$dev" of="$img.tmp" bs=4M conv=fsync 2>/dev/null && mv "$img.tmp" "$img"
    done
    ;;
remount)
    for e in $PARTS; do
        label=${e%%:*}
        img=/userdata/$label.img
        [ -f "$img" ] || continue
        mps=${e#*:}
        [ "$label" = persist ] && mps="$mps /persist"
        for mp in $mps; do
            src=$(findmnt -n -o SOURCE --target "$mp" 2>/dev/null)
            [ "$(findmnt -n -o TARGET --target "$mp" 2>/dev/null)" = "$mp" ] || continue
            case "$src" in /dev/loop*) continue ;; esac
            echo "nv-copies: $mp: $src -> $img"
            umount "$mp" && mount -t ext4 -o loop,$OPTS "$img" "$mp"
        done
    done
    ;;
esac
exit 0
