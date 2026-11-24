#!/bin/bash
# Exports the Godot 2.1 project mounted at /project to /build/<name>-<build>.apk
#   BUILD=debug (default) | release     APK_NAME=game (default)
# Release builds need a release keystore set in the project's Android export settings.
set -e
BUILD="${BUILD:-debug}"
APK_NAME="${APK_NAME:-game}"
TIMEOUT="${EXPORT_TIMEOUT:-600}"
OUT="/build/${APK_NAME}-${BUILD}.apk"
WORK=/tmp/work

[ -f /project/engine.cfg ] || { echo "No engine.cfg in /project - mount your Godot 2.1 project there." >&2; exit 1; }
mkdir -p /build; rm -f "$OUT"

# Build from a copy: keeps the editor's cache files out of your project, and drops
# display/fullscreen, which crashes Godot under a headless X server (Android is
# fullscreen anyway).
rm -rf "$WORK"; cp -a /project "$WORK"
sed -i '/^fullscreen *= *true/d' "$WORK/engine.cfg"

# OUYA launcher icon (732x412): the 2.1.4 exporter doesn't know Godot-for-OUYA's
# package/ouya_icon setting, so put the game's icon straight into the templates.
ICON=$(sed -n 's/^package\/ouya_icon *= *"res:\/\/\(.*\)"/\1/p' "$WORK/export.cfg" 2>/dev/null | head -1)
[ -z "$ICON" ] && [ -f "$WORK/ouya_icon.png" ] && ICON=ouya_icon.png
if [ -n "$ICON" ] && [ -f "$WORK/$ICON" ]; then
  dims=$(od -An -tu1 -j16 -N8 "$WORK/$ICON" | awk '{print $3*256+$4 "x" $7*256+$8}')
  [ "$dims" != "732x412" ] && echo "Warning: $ICON is $dims - the OUYA expects 732x412."
  T=$(mktemp -d); mkdir -p "$T/res/drawable-xhdpi-v4"; cp "$WORK/$ICON" "$T/res/drawable-xhdpi-v4/ouya_icon.png"
  for apk in "$HOME/.godot/templates/android_debug.apk" "$HOME/.godot/templates/android_release.apk"; do
    (cd "$T" && zip -q -0 "$apk" res/drawable-xhdpi-v4/ouya_icon.png)
  done
  echo "OUYA icon: $ICON ($dims)"
else
  echo "Warning: no ouya_icon.png - the OUYA launcher will show the Godot-for-OUYA default icon."
fi

FLAG=-export_debug; [ "$BUILD" = release ] && FLAG=-export
echo "Exporting ($BUILD) -> $OUT"

xvfb-run -a godot -path "$WORK" $FLAG "Android" "$OUT" > /tmp/godot.log 2>&1 &
XPID=$!

# Godot 2.1 keeps running after a command-line export; stop it once the APK is signed.
ok=0
for ((i=0; i<TIMEOUT; i++)); do
  sleep 1
  if [ -s "$OUT" ] && ! pgrep -x jarsigner >/dev/null && ! pgrep -f 'sun.security.tools.jarsigner' >/dev/null \
     && unzip -l "$OUT" 2>/dev/null | grep -qE 'META-INF/.*\.SF'; then
    sleep 2; ok=1; break
  fi
  kill -0 $XPID 2>/dev/null || break
done
pkill -f "godot -path $WORK" 2>/dev/null || true
wait $XPID 2>/dev/null || true

grep -vE '^(ALSA|XIO|Xlib)' /tmp/godot.log | grep -iE 'error|fail|jarsigner' || true
if [ $ok != 1 ]; then
  echo "Export failed (no signed APK). Godot log:" >&2; grep -v ALSA /tmp/godot.log | tail -30 >&2; exit 1
fi

unzip -p "$OUT" 'META-INF/*.SF' | grep -q 'SHA1-Digest' && echo "Signed: SHA-1 (OUYA compatible)"
echo "Done: $OUT ($(du -h "$OUT" | cut -f1))"
