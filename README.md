# OuyaDev: Godot toolkit for the OUYA

Make games for the OUYA console on Windows with
[Godot-for-OUYA](https://github.com/bherdm/godot-for-ouya) (a Godot 2.1 fork with OUYA export
templates). You get a portable editor, PC play-testing, one-command APK builds in Docker, and
one-command install on the console.

```bat
setup-windows.cmd                         :: once: editor, templates, JDK 8, adb, keystore
new-game.cmd "Space Game"                 :: games\space-game from the template
run.cmd space-game                        :: play-test on this PC
check.cmd space-game                      :: check OUYA requirements (icon, package, APK, ...)
build.cmd space-game                      :: -> build\space-game-debug.apk (Docker)
deploy.cmd space-game -Ip <ouya-ip> -Logcat
```

Edit games with **`Godot for OUYA.cmd`** (Import → the game's `engine.cfg`).

Games come out ready for the OUYA: Android 4.1 compatible, SHA-1 signed, listed under
**PLAY** with your own 732×412 `ouya_icon.png`.

👉 Full guide: **[HOWTO.md](HOWTO.md)**: setup, making and building games, controller input,
the OUYA's requirements, release signing, troubleshooting, and how it all works.

Requires Windows 10/11, [Docker Desktop](https://www.docker.com/products/docker-desktop/)
(for `build.cmd`), and an OUYA with ADB enabled.
