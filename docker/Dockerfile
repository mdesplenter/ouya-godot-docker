# Headless build container: produces SHA-1-signed APKs for the OUYA (Android 4.1 / API 16).
#   - exporter: official Godot 2.1.4 Linux editor (Godot-for-OUYA has no Linux build),
#     run under Xvfb
#   - templates: Godot-for-OUYA 2.1.9 Android templates (OUYA GAME category, ouya_icon,
#     minSdk 16). 2.1.4 and 2.1.9 share the same pack/scene/GDScript bytecode formats.
#
#   docker build -t ouya-godot2 docker
#   docker run --rm -v "<project>:/project" -v "<out>:/build" ouya-godot2
#
FROM eclipse-temurin:8-jdk-jammy

ARG GODOT_VERSION=2.1.4
ARG GODOT_DL=https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable
ARG G4O_TPZ=https://github.com/bherdm/godot-for-ouya/releases/download/ouya-2.1.9-alpha/godot-for-ouya-2.1.9-alpha-export-templates.tpz

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip zip xvfb xauth procps \
        libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libxext6 \
        libgl1 libglu1-mesa libasound2 libpulse0 libudev1 libfreetype6 \
        adb \
    && rm -rf /var/lib/apt/lists/*

# Godot 2.1.4 editor (x11 build, run under Xvfb) + Godot-for-OUYA Android templates.
# A pristine copy of the templates stays in /opt/templates; each build copies them to
# ~/.godot/templates and puts the game's ouya_icon.png in.
RUN mkdir -p /opt/godot /opt/templates /root/.godot/templates \
 && curl -fL -o /tmp/godot.zip "${GODOT_DL}_x11.64.zip" \
 && unzip -q /tmp/godot.zip -d /opt/godot \
 && mv /opt/godot/Godot_v${GODOT_VERSION}-stable_x11.64 /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot \
 && curl -fL -o /tmp/templates.tpz "${G4O_TPZ}" \
 && unzip -q -j /tmp/templates.tpz 'templates/android*' 'templates/version.txt' -d /opt/templates \
 && cp /opt/templates/android_*.apk /root/.godot/templates/ \
 && echo "templates: Godot-for-OUYA $(cat /opt/templates/version.txt)" \
 && rm -f /tmp/godot.zip /tmp/templates.tpz

# Debug keystore (JKS, SHA1withRSA) – the OUYA rejects SHA-256 signatures
RUN keytool -genkeypair -noprompt -keystore /root/.godot/debug.keystore -storetype JKS \
        -storepass android -keypass android -alias androiddebugkey \
        -keyalg RSA -keysize 2048 -sigalg SHA1withRSA -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US"

COPY jarsigner-ouya /usr/local/bin/jarsigner-ouya
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/jarsigner-ouya /usr/local/bin/entrypoint.sh

# Let the editor create its settings once, then point the Android exporter at our tools
RUN mkdir -p /tmp/p && printf '[application]\nname="init"\n' > /tmp/p/engine.cfg \
 && (xvfb-run -a timeout 25 godot -path /tmp/p -e || true) \
 && S=$(ls /root/.godot/editor_settings*.tres 2>/dev/null | head -1) \
 && if [ -z "$S" ]; then S=/root/.godot/editor_settings.tres; \
      printf '[gd_resource type="EditorSettings" format=1]\n\n[resource]\n\n' > "$S"; fi \
 && for kv in 'android/adb=/usr/bin/adb' \
              'android/jarsigner=/usr/local/bin/jarsigner-ouya' \
              'android/debug_keystore=/root/.godot/debug.keystore' \
              'android/debug_keystore_user=androiddebugkey' \
              'android/debug_keystore_pass=android'; do \
      k=${kv%%=*}; v=${kv#*=}; \
      if grep -q "^$k = " "$S"; then sed -i "s|^$k = .*|$k = \"$v\"|" "$S"; \
      else echo "$k = \"$v\"" >> "$S"; fi; \
    done \
 && grep '^android/' "$S" && rm -rf /tmp/p

WORKDIR /project
VOLUME ["/project", "/build"]
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
