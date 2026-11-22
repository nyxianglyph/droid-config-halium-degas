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

## Download

Ready-made images (boot, init_boot, super, an empty userdata image and a
flash script in one archive): <https://t.me/nyxian_degas/21>

## Installing

The image build produces `boot.img`, `init_boot.img` and a `super.img` that
carries the Sailfish root file system together with the stock vendor
partitions. With an unlocked bootloader, in fastboot mode:

    fastboot flash boot_a boot.img
    fastboot flash boot_b boot.img
    fastboot flash init_boot_a init_boot.img
    fastboot flash init_boot_b init_boot.img
    fastboot flash super super.img
    fastboot set_active a

`userdata` has to be ext4 (the stock one is f2fs) and empty for a first
install:

- Do not use `fastboot reboot recovery`: these boot images have no recovery
  mode. The phone boots the normal system instead and keeps trying, which
  looks like a boot loop. `fastboot erase misc` clears it.
- Flashing a sparse ext4 image of the full partition size (235 GB) hangs the
  bootloader. Flash a small empty ext4 image instead (the releases carry an
  8 GiB one). `degas-grow-userdata.service` grows it to the partition size
  at boot, before the encryption setup creates the 200 GB home image.
  `fastboot format:ext4 userdata` also works where fastboot has its
  `mke2fs` next to it.
- If a new system was ever booted with an old `userdata`, delete
  `/etc/sailfish-device-encryption-community/config.ini` and reboot;
  otherwise it asks for a password for a home image that no longer exists.

A fresh install was checked on 2026-11-22: both SIMs, fingerprint
enrolling and unlocking, display scale and cutout came up without manual
changes. In that install the file system was still grown by hand; the
service was added afterwards and has only run as a no-op on a full-size
file system.

## Status (2026-11-22)

| Area | State |
|---|---|
| Boot, UI, touch | Works |
| Display | Works at 144 Hz; camera cutout and rounded corners are configured, UI scale 1.75 |
| Cellular | Both SIMs register on LTE; calls and mobile data work |
| Call audio | Earpiece and speaker, volume adjustable |
| Media audio | Works |
| Vibration | Works |
| Charging indicator | Works |
| USB | usb-moded works: developer mode (network and SSH), MTP and charging modes are offered; unplug/replug is handled |
| Fingerprint (under-display) | Enrolling and unlocking work |
| Camera | Works |
| Wi-Fi | Works |
| Bluetooth | Works |
| Flashlight | Works through [flashlight-sysfs](https://github.com/nyxianglyph/flashlight-sysfs) |
| GPS | Does not work: no fix outdoors either. The receiver runs, assistance data (EPO) downloads and the satellite list is filled, but every satellite reports zero signal. Cause not found |
| Home encryption | Works |
| NFC, sensors, SMS, video recording | Not verified |

## Known issues

- Browser: pages with heavy per-frame scripts stay slow. Gecko paints at
  72 Hz by default here (`usr/share/degas/gecko-prefs.js`); at 144 Hz such
  pages saturate the main thread.
  The same file locks the web content scale to 3.0 (407 px wide viewport);
  Sailfish's own choice for this resolution is 2.0, which makes sites serve
  tablet layouts.
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

## Where to continue

The port is published as it stands; these are the open ends, roughly by
how much is known about them.

- **GPS: no signal.** `geoclue-provider-hybris-binder` connects to the AIDL
  GNSS HAL, `mnld` runs, EPO assistance data downloads (after the CA
  certificate fix in `halium-setup-local.sh`) and the satellite list is filled
  with plausible elevation and azimuth, but every satellite has SNR 0 and
  `mnld` logs `PMTKAGC ... agc: 6` every second. The kernel driver opens both
  links (L1, L5) and switches the LNA pins to DSP control
  (`/sys/kernel/debug/pinctrl/pinctrl-handles`, device `18000000.gps`). Not
  checked: what stock HyperOS logs at the same place (AGC, SNR), the modem's
  blanking signal, the SCP low-power path (`/dev/gps2scp`), the clock for the
  GNSS RF. A stock capture of `logcat | grep -E "PMTKAGC|linux_gps_init"` and
  the `GDL` kernel lines would show where the two differ. SUPL does not work
  either: Android-side processes have no name resolution with a network id
  (no netd).
- **Fingerprint UI.** There is no marker for the sensor position in the
  enrolment pages and on the lock screen, and the finger does not wake the
  phone: the display has to be on. The daemon keeps one template store, for
  Android user 0.
- **Browser.** Heavy pages stay slow; a one second hitch when reversing the
  scroll direction on long pages was reported and not investigated.
- **GPU frequency scaling** is a fixed floor, not real DVFS. GED wants frame
  timestamps (`GED_BRIDGE_COMMAND_GPU_TIMESTAMP`) from the graphics stack;
  nothing sends them here.
- **Thermal policy** is Xiaomi's daemon with two scenarios switched by
  `perf-tune.sh`. It throttles hard above about 44 °C board temperature.
- **Not tested at all:** NFC, sensors (rotation, proximity, light), SMS, video
  recording, MTP file transfer, Bluetooth audio, tethering, dual SIM data
  switching, VoLTE.
- **Android apps.** Jolla's AppSupport is not available for community ports.
  Waydroid: the kernel has what it needs; the user space side was not set
  up (the vendor only offers an AIDL graphics allocator).
- **Updates.** The device packages are built locally and are not on OBS, so
  there is no over-the-air update path for them.

## Building

`build/` has the scripts used for this port. They expect the related
repositories checked out next to this one, and docker.

    build/build-sdk-rpm.sh droid-config-halium-degas rpm/droid-config-halium-degas.spec \
        "community-adaptation-devel ssu-kickstart-configuration qt5-qttools-kmap2qmap"
    build/build-sdk-rpm.sh droid-hal-version-halium-degas rpm/droid-hal-version-halium-degas.spec
    build/build-sdk-rpm.sh sailfish-fpd-community rpm/sailfish-fpd-community.spec \
        "libgbinder-devel glib2-devel qt5-qtcore-devel qt5-qtdbus-devel qt5-qmake desktop-file-utils"
    build/build-sdk-rpm.sh flashlight-sysfs rpm/flashlight-sysfs.spec "glib2-devel gcc make"
    BUILD_TOOLS=... build/build-kernel-rpm.sh
    STOCK=... LPMAKE=... build/create-image.sh

`create-image.sh` needs the stock partition images of HyperOS
`OS3.0.305.0.WNEIDXM` (`vendor_a`, `odm_a`, `vendor_dlkm_a`, `odm_dlkm_a`,
`system_dlkm_a`); they are packed into `super.img` unchanged. The scripts in
`build/` are the ones used here with the local paths replaced by variables;
in that form they have only been syntax checked.

Debugging access: enable developer mode in Settings and use SSH over USB
(`192.168.2.15`) or WLAN. The inherited passwordless telnet on USB was
removed.

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
