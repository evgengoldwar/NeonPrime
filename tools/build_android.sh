#!/usr/bin/env bash
# Builds a signed Android APK without the Android SDK.
#
#   tools/build_android.sh <path-to-godot-4.7-binary> [preset]
#
# Presets: "Android" (arm64 + armv7, default) or "Android arm64" (smaller APK
# for 64-bit phones only).
#
# Needs: Godot 4.7 export templates installed (android_release.apk),
# Java 17+, curl. Output: build/NeonPrime.apk (APK Signature Scheme v2).
#
# Godot only checks that an SDK *path* exists when exporting an unsigned
# APK, so a stub SDK is created; signing is done with apksig from Maven Central.
set -euo pipefail

GODOT="${1:?usage: tools/build_android.sh <godot-binary> [preset]}"
PRESET="${2:-Android}"
OUT="NeonPrime.apk"
[ "$PRESET" = "Android arm64" ] && OUT="NeonPrime-arm64.apk"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK_DIR:-$ROOT/build/.tools}"
mkdir -p "$WORK/out" "$ROOT/build"

# 1. Stub Android SDK so the Godot export validation passes.
SDK="$WORK/stub-sdk"
mkdir -p "$SDK/platform-tools" "$SDK/build-tools/35.0.0"
printf '#!/bin/sh\nexit 1\n' > "$SDK/platform-tools/adb"
printf '#!/bin/sh\nexit 1\n' > "$SDK/build-tools/35.0.0/apksigner"
chmod +x "$SDK/platform-tools/adb" "$SDK/build-tools/35.0.0/apksigner"
SETTINGS="$(ls "$HOME"/.config/godot/editor_settings-4*.tres 2>/dev/null | head -1 || true)"
if [ -z "$SETTINGS" ]; then
	"$GODOT" --headless --path "$ROOT" --quit >/dev/null 2>&1 || true
	SETTINGS="$(ls "$HOME"/.config/godot/editor_settings-4*.tres | head -1)"
fi
if grep -q '^export/android/android_sdk_path' "$SETTINGS"; then
	sed -i "s#^export/android/android_sdk_path = .*#export/android/android_sdk_path = \"$SDK\"#" "$SETTINGS"
else
	echo "export/android/android_sdk_path = \"$SDK\"" >> "$SETTINGS"
fi

# 2. Export the unsigned APK.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT" --export-release "$PRESET" "$ROOT/build/NeonPrime-unsigned.apk"

# 3. Sign it with apksig (v2).
JAR="$WORK/apksig.jar"
if ! unzip -tq "$JAR" >/dev/null 2>&1; then
	for delay in 2 4 8 16; do
		curl -sSL -o "$JAR" https://repo1.maven.org/maven2/com/android/tools/build/apksig/2.3.0/apksig-2.3.0.jar || true
		unzip -tq "$JAR" >/dev/null 2>&1 && break
		sleep "$delay"
	done
fi
javac -cp "$JAR" -d "$WORK/out" "$ROOT/tools/ApkSign.java"
java --add-exports java.base/sun.security.x509=ALL-UNNAMED \
	--add-exports java.base/sun.security.pkcs=ALL-UNNAMED \
	--add-exports java.base/sun.security.util=ALL-UNNAMED \
	-cp "$JAR:$WORK/out" ApkSign "$ROOT/tools/neonprime-debug.p12" neonprime neonprime \
	"$ROOT/build/NeonPrime-unsigned.apk" "$ROOT/build/$OUT"
rm -f "$ROOT/build/NeonPrime-unsigned.apk"
echo "Done: build/$OUT"
