#!/bin/sh
# Grow the userdata file system to the size of its partition.
#
# The bootloader hangs for minutes on a sparse ext4 image of the full
# partition (235 GB), so installs flash a small empty file system. It has to
# be full size before the encryption setup creates the 200 GB home image.
# resize2fs works on the mounted file system and does nothing when the size
# already matches.
dev=$(awk '$2 == "/userdata" && $3 == "ext4" { print $1; exit }' /proc/mounts)
[ -n "$dev" ] || exit 0
resize2fs "$dev" || true
