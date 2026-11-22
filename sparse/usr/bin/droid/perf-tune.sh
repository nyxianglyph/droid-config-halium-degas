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

i=0
while [ ! -e $GED ] && [ $i -lt 30 ]; do sleep 1; i=$((i+1)); done
[ -e $GED ] || exit 0
echo $FLOOR_NORMAL > $GED

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

[ -e $TM/sconfig ] && [ -e $TM/board_sensor_temp ] || exit 0

mode=normal
while :; do
    t=$(cat $TM/board_sensor_temp 2>/dev/null)
    case "$t" in ''|*[!0-9]*) sleep 5; continue ;; esac
    if [ $mode = normal ] && [ "$t" -le $COOL ]; then
        echo $SCONFIG_PERF > $TM/sconfig
        echo $FLOOR_PERF > $GED
        mode=perf
    elif [ $mode = perf ] && [ "$t" -ge $WARM ]; then
        echo $SCONFIG_NORMAL > $TM/sconfig
        echo $FLOOR_NORMAL > $GED
        mode=normal
    fi
    sleep 5
done
