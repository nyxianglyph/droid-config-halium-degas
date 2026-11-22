#!/bin/sh
# Pass the call volume to the MediaTek audio HAL as a volume index.
#
# On the Xiaomi 14T the speech path runs in the audio DSP and the vendor
# speech library takes its loudness from a volume level (0..10, 11 steps on
# HyperOS). Android's MediaTek audio policy sends it with
#   volumeStreamType=0;volumeDevice=<device>;volumeIndex=<n>
# on every voice call volume change. PulseAudio only calls set_voice_volume(),
# which this HAL ignores in that path: the level stays at 0, the earpiece is
# very quiet and the volume keys do nothing.
#
# This watches PulseAudio and, while the droid card is in a voicecall profile,
# sends the index for the current call volume and output port through the
# droid sink's "droid.parameter." property hook.

SINK=sink.primary_output
STEPS=10
last=""
flip=0

send() {
    # The hook only fires when the property value changes; alternate between
    # two equivalent spellings so a repeated level is sent again.
    if [ "$flip" = 0 ]; then
        value="0;volumeDevice=$1;volumeIndex=$2"; flip=1
    else
        value="0;volumeIndex=$2;volumeDevice=$1"; flip=0
    fi
    pacmd update-sink-proplist "$SINK" "droid.parameter.volumeStreamType=\"$value\"" >/dev/null 2>&1
}

update() {
    profile=$(pactl list cards 2>/dev/null | awk '/Active Profile:/ { print $3; exit }')
    case "$profile" in
        voicecall*) ;;
        *) last=""; return ;;
    esac

    port=$(pactl list sinks 2>/dev/null | awk -v s="$SINK" '$1 == "Name:" { f = ($2 == s) } f && /Active Port:/ { print $3; exit }')
    case "$port" in
        output-earpiece) dev=1 ;;
        output-speaker) dev=2 ;;
        output-wired_headset) dev=4 ;;
        output-wired_headphone) dev=8 ;;
        output-bluetooth_sco|output-sco_headset|output-sco_carkit) dev=32 ;;
        *) dev=2 ;;
    esac

    # Volume of the call control stream (media.role = phone), raw 0..65536.
    raw=$(pactl list sink-inputs 2>/dev/null | awk '
        /^Sink Input #/ { vol = "" }
        $1 == "Volume:" { vol = $3 }
        /media.role = "phone"/ { if (vol != "") { print vol; exit } }')
    [ -n "$raw" ] || return

    # PulseAudio volumes are cubic; the UI steps are linear.
    index=$(awk -v r="$raw" -v n="$STEPS" 'BEGIN { l = (r / 65536) ^ 3; i = int(l * n + 0.5); if (i > n) i = n; print i }')

    cur="$dev:$index"
    [ "$cur" = "$last" ] && return
    last=$cur
    send "$dev" "$index"
}

update
pactl subscribe 2>/dev/null | while read -r line; do
    case "$line" in
        *"on card"*|*"on sink"*) update ;;
    esac
done
