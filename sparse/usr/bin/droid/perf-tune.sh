#!/bin/sh
# Performance settings Android's framework would normally provide.
#
# GPU: MediaTek's GED DVFS is frame based and gets its frame timing from
# Android's graphics stack. Under Sailfish that information never arrives and
# the GPU stays at its lowest OPP (265 MHz) even at 98 % load: the UI and the
# browser stutter. Set a floor instead (OPP 47 = 601 MHz, which is also the
# ceiling of Xiaomi's thermal profiles above 35 C). The GPU is still power
# gated when idle.
# Do not touch the other /sys/kernel/ged/hal nodes from here: writing
# force_loading_base reboots the phone.
#
# CPU: nothing marks foreground tasks here (no top-app cgroup, no power HAL
# boosts), so the session and the compositor get a utilization floor and are
# flagged latency sensitive.

GPU_FLOOR_OPP=47
UCLAMP_MIN=30

i=0
while [ ! -e /sys/kernel/ged/hal/custom_boost_gpu_freq ] && [ $i -lt 30 ]; do sleep 1; i=$((i+1)); done
[ -e /sys/kernel/ged/hal/custom_boost_gpu_freq ] && echo $GPU_FLOOR_OPP > /sys/kernel/ged/hal/custom_boost_gpu_freq

# The "interactive" cgroup appears when the user session starts.
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
exit 0
