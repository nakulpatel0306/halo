#!/bin/zsh
# Builds Halo.app into build/. Pass --install to copy it to /Applications and launch it.
set -euo pipefail
cd "${0:A:h}/.."

# Release builds pass the tag, e.g. HALO_VERSION=v1.0.0.
VERSION=${HALO_VERSION:-v1.0.0}
VERSION=${VERSION#v}
APP=build/Halo.app

rm -rf $APP
mkdir -p $APP/Contents/{MacOS,Resources}

if [[ -n "${HALO_UNIVERSAL:-}" ]]; then
  # Releases run on Intel and Apple silicon. Building each architecture and
  # joining them with lipo needs only the Command Line Tools, not Xcode.
  BINARIES=()
  for ARCH in arm64 x86_64; do
    swift build -c release --triple $ARCH-apple-macosx14.0
    BINARIES+=("$(swift build -c release --triple $ARCH-apple-macosx14.0 --show-bin-path)/Halo")
  done
  lipo -create $BINARIES -output $APP/Contents/MacOS/Halo
else
  swift build -c release
  cp "$(swift build -c release --show-bin-path)/Halo" $APP/Contents/MacOS/Halo
fi

if [[ ! -f build/AppIcon.icns ]]; then
  swift scripts/make-icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns $APP/Contents/Resources/AppIcon.icns

cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Halo</string>
  <key>CFBundleDisplayName</key><string>Halo</string>
  <key>CFBundleIdentifier</key><string>dev.nakulpatel.halo</string>
  <key>CFBundleExecutable</key><string>Halo</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Halo reads which files are selected in Finder so it can show actions for them.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough to run locally. macOS ties Accessibility permission
# to the signature, so after a rebuild you may need to re-enable Halo there.
codesign --force --sign - $APP
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Halo 2>/dev/null || true
  # Opening the new copy before the old one has quit fails with error -600.
  while pgrep -x Halo >/dev/null; do sleep 0.2; done
  rm -rf /Applications/Halo.app
  cp -R $APP /Applications/Halo.app
  open /Applications/Halo.app
  echo "Installed to /Applications/Halo.app"
fi
