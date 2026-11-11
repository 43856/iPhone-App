#!/bin/bash
# Packt die gebaute App in eine .ipa-Datei für Sideloadly.
# Die App wird "ad hoc" mit den Entitlements (App Group) signiert,
# damit Sideloadly beim echten Signieren weiß, welche Rechte die App braucht.
set -euo pipefail

APP="build/Build/Products/Release-iphoneos/KIAssistent.app"
APPEX="$APP/PlugIns/BroadcastExtension.appex"

test -d "$APP" || { echo "App nicht gefunden: $APP"; exit 1; }

if [ -d "$APPEX" ]; then
  codesign --force --sign - --entitlements BroadcastExtension/BroadcastExtension.entitlements "$APPEX"
fi
codesign --force --sign - --entitlements App/KIAssistent.entitlements "$APP"

echo "Entitlements der App:"
codesign -d --entitlements - "$APP" || true

rm -rf build/ipa
mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/
(cd build/ipa && zip -qry ../KIAssistent.ipa Payload)
ls -lh build/KIAssistent.ipa
