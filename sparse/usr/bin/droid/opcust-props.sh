#!/bin/sh
# Apply the Xiaomi opcust property overlay to the Android container.
#
# HyperOS init overrides a few properties from the per-device "opcust"
# partition: etc/carrier.prop, limited to the keys listed in
# etc/carrier_prop_white_keys_list. One of them is ro.product.vendor.name.
# The modem asks the AP for that property (ccci_rpcd,
# IPC_RPC_QUERY_AP_SYS_PROPERTY) when it verifies its signed critical data
# (cpuid + IMEI1 + IMEI2). With the plain vendor build.prop value the
# signature does not verify: +ENVSIGERR, vendor.ril.imei.check=fail, and the
# modem refuses to switch the radio on.
#
# The Halium init has no such hook, so this script appends the whitelisted
# opcust properties to a copy of prop.halium and binds it over the one in the
# container. Run from halium-setup-local.sh, before the container starts.
#
#   opcust-props.sh          mount opcust read-only, generate and bind
#   opcust-props.sh <dir>    print the result for an opcust tree at <dir>

STATIC=${STATIC:-/usr/share/halium-overlay/system/etc/prop.halium}
TARGET=/android/system/etc/prop.halium
OUT=/run/droid-hal/prop.halium
DEV=/dev/disk/by-partlabel/opcust
MNT=/run/droid-hal/opcust

opcust_props() {
    props=$1/etc/carrier.prop
    keys=$1/etc/carrier_prop_white_keys_list
    [ -f "$props" ] && [ -f "$keys" ] || return 0
    tr -d '\r' < "$keys" | while read -r key _; do
        case "$key" in
            ''|\#*) continue ;;
            # set by the bootloader before any property file is read
            ro.boot.*) continue ;;
        esac
        tr -d '\r' < "$props" | awk -F= -v k="$key" '$1 == k { print; exit }'
    done
}

if [ -n "$1" ]; then
    cat "$STATIC"
    echo
    echo "# From opcust etc/carrier.prop (opcust-props.sh)"
    opcust_props "$1"
    exit 0
fi

[ -e "$DEV" ] || { echo "opcust-props: no opcust partition"; exit 0; }
mkdir -p "$MNT"
mount -o ro "$DEV" "$MNT" || { echo "opcust-props: cannot mount $DEV"; exit 0; }
extra=$(opcust_props "$MNT")
umount "$MNT"

if [ -z "$extra" ]; then
    echo "opcust-props: no whitelisted properties found"
    exit 0
fi

{
    cat "$STATIC"
    echo
    echo "# From opcust etc/carrier.prop (opcust-props.sh)"
    echo "$extra"
} > "$OUT"
echo "opcust-props: $(echo "$extra" | wc -l) properties: $(echo "$extra" | cut -d= -f1 | tr '\n' ' ')"
# The target is itself a bind of the packaged prop.halium on the shared root
# mount. Make it private first, or this bind propagates back onto the
# packaged file (which then cannot be replaced by a package update).
mount --make-private "$TARGET"
mount -o bind "$OUT" "$TARGET"
