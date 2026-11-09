#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p "Morrow.app/Contents/MacOS" "Morrow.app/Contents/Resources" ../../work/swift-cache
cache_dir="$(cd ../../work/swift-cache && pwd -P)"
SWIFT_MODULECACHE_PATH="$cache_dir" \
CLANG_MODULE_CACHE_PATH="$cache_dir" \
swiftc -parse-as-library Morrow.swift -o "Morrow.app/Contents/MacOS/Morrow" \
  -framework SwiftUI -framework WebKit -framework AppKit -lcmark-gfm
cp Info.plist "Morrow.app/Contents/Info.plist"
cp Morrow.icns "Morrow.app/Contents/Resources/Morrow.icns"
xattr -cr "Morrow.app"
codesign --force --deep --sign - "Morrow.app"
echo "Built: $PWD/Morrow.app"
