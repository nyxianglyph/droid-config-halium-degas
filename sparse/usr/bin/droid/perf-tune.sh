#!/bin/sh
# Performance settings Android's framework would normally provide.
#
# GPU: MediaTek's GED DVFS is frame based and gets its frame timing from
# Android's graphics stack. Under Sailfish that information never arrives and
# the GPU stays at its lowest OPP (265 MHz) even at 98 % load. A floor is set
# instead; the GPU is still power gated when idle.
# Only custom_boost_gpu_freq is used here; the other /sys/kernel/ged/hal nodes
# were not validated on this phone.
#
# Thermal: Xiaomi's mi_thermald gets no scenario from a framework and stays in
# its default profile, which caps the GPU at OPP 47 (601 MHz) and the CPUs at
# 1.4/2.3/2.4 GHz from 35 C board temperature on. At 601 MHz the GPU cannot
# fill the 144 Hz panel (about 125 fps, uneven). While the phone is cool this
# script selects the "nolimits" scenario and a 740 MHz floor (about 140 fps);
# once the board sensor reaches WARM it hands control back to the default
# profile until the phone has cooled to COOL again. mi_thermald's own limits
# of the nolimits profile (GPU at 48 C, CPU at 53 C) stay in place as a
# backstop.
#
# CPU: nothing marks foreground tasks here (no top-app cgroup, no power HAL
# boosts), so the session and the compositor get a utilization floor and are
# flagged latency sensitive.

GED=/sys/kernel/ged/hal/custom_boost_gpu_freq
TM=/sys/class/thermal/thermal_message
FLOOR_NORMAL=47      # 601 MHz
FLOOR_PERF=40        # 740 MHz
SCONFIG_NORMAL=-1    # mi_thermald default
SCONFIG_PERF=6       # nolimits
WARM=43000
COOL=40000
UCLAMP_MIN=30

# Gecko reads default preferences from its versioned install directory; copy
# ours into whichever version is installed. A symlink does not work: the
# application sandbox hides /usr/share/degas.
for d in /usr/lib64/xulrunner-qt5-*/; do
    [ -d "$d" ] || continue
    mkdir -p "${d}defaults/pref"
    rm -f "${d}defaults/pref/degas.js"
    cp /usr/share/degas/gecko-prefs.js "${d}defaults/pref/degas.js"
done

i=0
while [ ! -e $GED ] && [ $i -lt 30 ]; do sleep 1; i=$((i+1)); done
[ -e $GED ] || exit 0
# The "interactive" cgroup appears when the user session starts.
(
    i=0
    while [ $i -lt 120 ]; do
        done_all=1
        for g in user.slice interactive; do
            d=/sys/fs/cgroup/cpu/$g
            if [ -e $d/cpu.uclamp.min ]; then
                echo $UCLAMP_MIN > $d/cpu.uclamp.min
                echo 1 > $d/cpu.uclamp.latency_sensitive
            else
                done_all=0
            fi
        done
        [ $done_all = 1 ] && break
        sleep 2; i=$((i+1))
    done
) &

# GED forgets the floor whenever the display is turned off (it goes back to
# 64, the lowest OPP, and the UI then runs at about 100 fps on 265 MHz). The
# wanted floor is kept in a file; it is written again as soon as mce reports
# the display on, and checked on every pass of the loop below.
WANT=/run/degas-gpu-floor
set_floor() {
    echo $1 > $WANT
    echo $1 > $GED
}
apply_floor() {
    w=$(cat $WANT 2>/dev/null)
    [ -n "$w" ] && [ "$(head -n 1 $GED 2>/dev/null)" != "$w" ] && echo $w > $GED
}
set_floor $FLOOR_NORMAL

(
    dbus-monitor --system "type='signal',interface='com.nokia.mce.signal',member='display_status_ind'" 2>/dev/null |
    while read -r line; do
        case "$line" in *'string "on"'*) apply_floor ;; esac
    done
) &

have_thermal=0
[ -e $TM/sconfig ] && [ -e $TM/board_sensor_temp ] && have_thermal=1

mode=normal
while :; do
    if [ $have_thermal = 1 ]; then
        t=$(cat $TM/board_sensor_temp 2>/dev/null)
        case "$t" in
        ''|*[!0-9]*) ;;
        *)
            if [ $mode = normal ] && [ "$t" -le $COOL ]; then
                echo $SCONFIG_PERF > $TM/sconfig
                set_floor $FLOOR_PERF
                mode=perf
            elif [ $mode = perf ] && [ "$t" -ge $WARM ]; then
                echo $SCONFIG_NORMAL > $TM/sconfig
                set_floor $FLOOR_NORMAL
                mode=normal
            fi
            ;;
        esac
    fi
    apply_floor
    sleep 5
done
