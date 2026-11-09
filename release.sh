#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

: "${MORROW_APP_IDENTITY:?Set MORROW_APP_IDENTITY to your Developer ID Application certificate name}"
: "${MORROW_INSTALLER_IDENTITY:?Set MORROW_INSTALLER_IDENTITY to your Developer ID Installer certificate name}"
: "${MORROW_NOTARY_PROFILE:?Set MORROW_NOTARY_PROFILE to a notarytool keychain profile name}"

if ! security find-identity -v -p codesigning | grep -Fq "$MORROW_APP_IDENTITY"; then
  echo "Developer ID Application certificate not found in the keychain." >&2
  exit 1
fi

if ! security find-identity -v -p basic | grep -Fq "$MORROW_INSTALLER_IDENTITY"; then
  echo "Developer ID Installer certificate not found in the keychain." >&2
  exit 1
fi

zsh build.sh

# Replace the local test signature with a distributable Developer ID signature.
codesign --force --sign "$MORROW_APP_IDENTITY" --options runtime --timestamp Morrow.app
codesign --verify --deep --strict --verbose=2 Morrow.app

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Morrow.app/Contents/Info.plist)
pkgbuild --component Morrow.app \
  --install-location /Applications \
  --identifier nl.codex.morrow \
  --version "$version" \
  --sign "$MORROW_INSTALLER_IDENTITY" \
  Morrow.pkg

pkgutil --check-signature Morrow.pkg
xcrun notarytool submit Morrow.pkg --keychain-profile "$MORROW_NOTARY_PROFILE" --wait
xcrun stapler staple Morrow.pkg
xcrun stapler validate Morrow.pkg
spctl --assess --type install --verbose=2 Morrow.pkg
shasum -a 256 Morrow.pkg
echo "Ready to upload: $PWD/Morrow.pkg"
