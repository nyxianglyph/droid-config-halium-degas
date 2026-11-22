# These and other macros are documented in ../droid-configs-device/droid-configs.inc
# Feel free to cleanup this file by removing comments, once you have memorised them ;)

%define device halium-degas
%define vendor xiaomi

%define vendor_pretty Xiaomi
%define device_pretty Xiaomi 14T

# Community HW adaptations need this
%define community_adaptation 1

%define out_of_image_files 1

%define disable_tools 1

# Sailfish OS is considered to-scale, if in the App Grid you get 4-in-a-row icons,
# and 2-in-a-row or 3-in-a-row app covers in the Home Screen, depending on
# how many apps are open.
# For 4-5.5" device screen sizes of 16:9 ratio, use this formula (hold portrait):
# pixel_ratio = 4.5/DiagonalDisplaySizeInches * HorizontalDisplayResolution/540
# Other screen sizes and ratios will require more trial-and-error.
# The formula gives 1.52 for the 6.67" 1220x2712 panel; at 1.5 text and icons
# were found too small in use, so the next step is used.
%define pixel_ratio 1.75

Provides: ofono-configs-binder
Provides: ofono-configs
Requires: droid-config-halium
AutoReqProv: no

%define ofono_enable_plugins bluez5,hfp_ag_bluez5
%define ofono_disable_plugins bluez4,dun_gw_bluez4,hfp_ag_bluez4,hfp_bluez4,dun_gw_bluez5,hfp_bluez5

# The community-adaptation template leaves the Halium release as a literal
# "%%{haliumRelease}" in the adaptation-halium repository URL, and the
# per-device OBS project it names for adaptation-community does not exist
# for this port (the device packages are built locally). Both made every
# repository refresh report errors.
%define additional_post_scripts \
sed -i 's|%%{haliumRelease}|14|' /usr/share/ssu/features.d/adaptation-community.ini || : \
rm -f /var/cache/ssu/features.ini || : \
ssu dr adaptation-community || : \
%{nil}

%include droid-configs-device/droid-configs.inc
%include patterns/patterns-sailfish-device-adaptation-halium-degas.inc
%include patterns/patterns-sailfish-device-configuration-halium-degas.inc

# IMPORTANT if you want to comment out any macros in your .spec, delete the %
# sign, otherwise they will remain defined! E.g.:
#define some_macro "I'll not be defined because I don't have % in front"

