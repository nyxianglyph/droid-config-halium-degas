# droid-config-halium-degas

Device specific configuration for the Xiaomi 14T (`degas`, MediaTek
Dimensity 8300-Ultra `mt6897`) on Sailfish OS.

The device is named `halium-degas` because the port runs on a Halium 14 base
(the UBports Halium GSI system image in an LXC container), like the Volla Phone
Plinius port this repository is derived from
([droid-config-halium-ansuz](https://github.com/HelloVolla/droid-config-halium-ansuz)).

Related repositories:

- Kernel: [android_kernel_xiaomi_degas](https://github.com/nyxianglyph/android_kernel_xiaomi_degas)
  (`halium-6.1.157`, `sfos` flavour), packaged by
  [kernel-adaptation-halium-degas](https://github.com/nyxianglyph/kernel-adaptation-halium-degas)
- [droid-hal-version-halium-degas](https://github.com/nyxianglyph/droid-hal-version-halium-degas)
- Fingerprint daemon: [sailfish-fpd-community](https://github.com/nyxianglyph/sailfish-fpd-community/tree/gbinder-aidl),
  branch `gbinder-aidl`

## Base

- Stock firmware HyperOS `OS3.0.305.0.WNEIDXM` (Android 14 vendor). The stock
  `vendor`, `odm`, `vendor_dlkm`, `odm_dlkm` and `system_dlkm` partitions and
  the stock `vendor_boot` are used unchanged.
- Sailfish OS 5.2.0.22 with the `nemo:devel:hw:halium:14` middleware.
- The Sailfish root file system replaces `system_a` inside `super`; home is
  LUKS encrypted on `userdata`.

## Status (2026-11-22)

| Area | State |
|---|---|
| Boot, UI, touch | Works |
| Display | Works at 144 Hz |
| Cellular | Both SIMs register on LTE; calls and mobile data work |
| Call audio | Earpiece and speaker, volume adjustable |
| Media audio | Works |
| Vibration | Works |
| Fingerprint (under-display) | Enrolling and unlocking work |
| Camera | Opens and shows a picture; nothing further tested |
| Home encryption | Works |
| Wi-Fi, Bluetooth, GPS, NFC, sensors, SMS, video | Not verified |

## Known issues

- Browser: pages with heavy per-frame scripts stay slow. Gecko paints at
  72 Hz by default here (`usr/share/degas/gecko-prefs.js`); at 144 Hz such
  pages saturate the main thread.
- GPU frequency scaling: MediaTek's GED needs frame timing from Android's
  graphics stack, so the GPU would stay at its lowest frequency. A frequency
  floor is set instead (`usr/bin/droid/perf-tune.sh`), which costs power.
- Thermal: Xiaomi's thermal daemon caps the CPUs hard (down to about
  1.3 GHz) once the board sensor passes about 44 °C.
- `kernel.pid_max` must stay at 32768: the stock `mkp.ko` module panics the
  kernel on larger PIDs.
- Fingerprint: there is no on-screen marker for the sensor position (centre
  of the display, about 1.5 cm above the bottom edge), and the display has to
  be on. Templates are stored for Android user 0 only.
- Calls: a slight echo for the far end at full earpiece volume was reported
  once and not rechecked.

## What is device specific here

- `usr/bin/droid/mount-vendor.sh`: the vendor partitions are erofs.
- `usr/bin/droid/nv-copies.sh`: the modem's NV partitions are never mounted
  writable; copies on `userdata` are mounted instead.
- `usr/bin/droid/opcust-props.sh`: the modem verifies the IMEI signature
  against the product string HyperOS takes from the `opcust` partition; the
  same properties are read from there at boot.
- `etc/pulse`, `usr/bin/droid/call-volume-sync.sh`: call routing and the
  call volume index for the audio DSP.
- `etc/ngfd`, `usr/share/ngfd`: haptics through the ffmemless plugin; the
  Xiaomi vibrator HAL is masked because it blocks the driver.
- `usr/share/halium-overlay`: files bind mounted over the Android container
  (properties, 144 Hz display mode, fingerprint HAL init file).
