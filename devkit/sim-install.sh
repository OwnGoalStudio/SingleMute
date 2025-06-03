#!/bin/sh

if [ -z "$THEOS_DEVICE_SIMULATOR" ]; then
  exit 0
fi

cd "$(dirname "$0")"/.. || exit

TWEAK_NAMES="SingleMute"

for TWEAK_NAME in $TWEAK_NAMES; do
  sudo rm -f "/opt/simject/$TWEAK_NAME.dylib"
  sudo cp -v "$THEOS_OBJ_DIR/$TWEAK_NAME.dylib" "/opt/simject/$TWEAK_NAME.dylib"
  sudo codesign -f -s - "/opt/simject/$TWEAK_NAME.dylib"
  sudo cp -v "$PWD/$TWEAK_NAME.plist" "/opt/simject/$TWEAK_NAME.plist"
done

BUNDLE_NAMES="SingleMutePrefs"

sudo mkdir -p /opt/simject/PreferenceBundles
sudo mkdir -p /opt/simject/PreferenceLoader/Preferences
for BUNDLE_NAME in $BUNDLE_NAMES; do
  sudo rm -rf "/opt/simject/PreferenceBundles/$BUNDLE_NAME.bundle"
  sudo cp -rv "$THEOS_OBJ_DIR/$BUNDLE_NAME.bundle" "/opt/simject/PreferenceBundles/$BUNDLE_NAME.bundle"
  sudo codesign -f -s - "/opt/simject/PreferenceBundles/$BUNDLE_NAME.bundle"
  sudo cp -rv "$PWD/$BUNDLE_NAME/layout/Library/PreferenceLoader/Preferences/$BUNDLE_NAME" /opt/simject/PreferenceLoader/Preferences/
done

resim
