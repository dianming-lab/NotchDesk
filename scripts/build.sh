#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
mkdir -p .build/local
swiftc -O -target arm64-apple-macos13.0 -module-cache-path "$CLANG_MODULE_CACHE_PATH" Sources/NotchDesk/*.swift -o .build/local/NotchDesk
STAGING=$(mktemp -d /private/tmp/NotchDesk-build.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/NotchDesk.app"
mkdir -p "$PWD/dist"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/NotchDesk.icns "$APP/Contents/Resources/NotchDesk.icns"
cp .build/local/NotchDesk "$APP/Contents/MacOS/NotchDesk"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NotchDesk</string>
<key>CFBundleIdentifier</key><string>local.dean.NotchDesk</string>
<key>CFBundleName</key><string>NotchDesk</string>
<key>CFBundleDisplayName</key><string>NotchDesk</string>
<key>CFBundleIconFile</key><string>NotchDesk</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.5</string>
<key>CFBundleVersion</key><string>6</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSDesktopFolderUsageDescription</key><string>在刘海下显示桌面文件，并把拖入的文件保存到桌面。</string>
</dict></plist>
PLIST
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
/usr/bin/ditto -c -k --keepParent --norsrc "$APP" "$PWD/dist/NotchDesk.zip"
printf '已生成：%s\n' "$PWD/dist/NotchDesk.zip"
