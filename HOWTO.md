# HOWTO: Making OUYA games with Godot on Windows

This toolkit gives you a ready-to-use setup for making games for the **OUYA** console with
**[Godot-for-OUYA](https://github.com/bherdm/godot-for-ouya)**, a Godot 2.1 fork with
OUYA export templates. You get a portable editor, a Docker container that builds APKs with
one command, and scripts to play-test on your PC and install on the console.

Nothing is installed system-wide. Everything except Docker Desktop lives in this folder.

---

## 1. What you need

| | |
|---|---|
| Windows 10 or 11 (64-bit) | The scripts use Windows PowerShell 5.1, which is built in |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | For one-command builds. Optional if you only export from the editor |
| An OUYA with ADB turned on | In the OUYA's development settings under **Manage → System** |
| ~1 GB disk space | Editor, Java, Android templates, adb |

The `.cmd` files run their matching PowerShell scripts with `-ExecutionPolicy Bypass`, so you
don't need to change Windows' script settings.

## 2. One-time setup

```bat
git clone <this repo> OuyaDev
cd OuyaDev
setup-windows.cmd
```

`setup-windows.cmd` downloads into `tools\`:

- **Godot-for-OUYA 2.1.9** editor and its Android export templates (`tools\godot-for-ouya\`),
  set up in *self-contained* mode: its settings and templates live in
  `tools\godot-for-ouya\editor_data\`, separate from any other Godot on your PC
- **Temurin JDK 8** (`tools\jdk8\`). The editor uses its `jarsigner` to sign APKs
- **Android platform-tools** (`tools\platform-tools\adb.exe`)
- a **debug keystore** (`tools\debug.keystore`)

It points the editor's settings at adb, jarsigner and the keystore, and registers the OUYA's
USB id with adb. The editor opens for a few seconds during setup and closes by itself.
That's expected. If Windows SmartScreen warns about the editor, choose **More info → Run anyway**
(the Godot-for-OUYA builds aren't code-signed).

You can run it again at any time. It skips anything that's already in place.

Then start Docker Desktop and build the example once. This also builds the Docker image,
which takes a few minutes the first time:

```bat
build.cmd virtual-controller
```

## 3. Make a game

```bat
new-game.cmd "Space Game"
```

This creates `games\space-game\` from `template\` with:

- `engine.cfg`: project settings (1280×720, fullscreen) and the app icon (`icon="res://icon.png"`)
- `export.cfg`: Android **package name** (the one you typed in), app title and OUYA icon
- `ouya_icon.png`: the **732×412** tile the OUYA shows in its menu. Replace the placeholder
  with your own art (same size)
- `icon.png`: the square **app icon** (192×192) Android uses for the app itself (app lists,
  Make → Software). Without it the APK carries the Godot logo. Replace the placeholder too.
  To use another file, change `icon=` under `[application]` in `engine.cfg` (in the editor:
  Scene → Project Settings → application → icon)
- `main.tscn` + `main.gd`: a starter scene that shows controller button and axis numbers.
  It already sets the OUYA controller mapping (`ouya_mapping()`, see section 7), so keep the
  `Input.add_joy_mapping(ouya_mapping(), true)` line in your main scene's `_ready()`

It asks for the **package name**: the game's unique id on the console, like
`com.yourname.spacegame`. Two games with the same package name overwrite each other on the
OUYA, and you can't change it after you share the game. Press Enter to take the suggestion,
`org.ouyadev.spacegame`.
`new-game.cmd` refuses names that aren't valid, are Godot's default, or are already used by
another game in `games\`. To skip the question, give it on the command line:

```bat
new-game.cmd "Space Game" -Package com.yourname.spacegame
```

Your games don't have to live inside this folder:

```bat
new-game.cmd "Space Game" -Path D:\dev\space-game
build.cmd D:\dev\space-game
```

**Tip:** give each game its own git repo (`cd games\space-game` and `git init`). The toolkit
repo ignores everything in `games\` except the example.

## 4. Edit and play-test

Double-click **`Godot for OUYA.cmd`**, click **Import**, and pick your game's `engine.cfg`.

Godot-for-OUYA is Godot 2.1, so the Godot 2.1 docs apply:
<https://docs.godotengine.org/en/2.1/>. Version 2.1 uses GDScript 1, so most tutorials for
Godot 3 or 4 won't work as-is.

For day-to-day play-testing, run the game on your PC. It's instant and needs no build:

```bat
run.cmd space-game              :: fullscreen, like on the OUYA
run.cmd space-game -Windowed
```

Or press **F5** in the editor. Any gamepad Windows recognises works, but its button numbers may
differ from the OUYA controller's, so check input on the real console.

Use the OUYA itself (sections 5–6) for anything Android-specific: controller mapping,
performance on the Tegra 3, and whether the APK installs and starts.

> **Why no emulator?** Godot's Android builds are 32-bit ARM only. The only matching Android 4.1
> emulator image is ARM, and Android's emulator dropped support for it in 2018. Running it
> needs a 2016-era emulator with slow full-CPU emulation and unreliable OpenGL ES 2 support,
> and it doesn't emulate the OUYA controller. The PC plus a real OUYA is faster and more accurate.

## 5. Check and build

`check.cmd` checks a game against the OUYA's requirements (section 8) and common mistakes:

```bat
check.cmd                       :: every game in games\
check.cmd space-game
check.cmd space-game -Quiet     :: only warnings and errors
```

It looks at:
- **the project**: `main_scene`, 720p/1080p resolution and stretch mode, a unique package
  name, `ouya_icon.png` (present, PNG, exactly 732×412, not still the placeholder), the
  app icon from `application/icon` (set, square PNG, at least 96×96, not still the placeholder)
- **the scripts**: Godot 3/4-only syntax that Godot 2.1 can't run (`$Node`, typed variables,
  `_physics_process`, `move_and_slide`, …)
- **the built APK** in `build\`, if there is one: OUYA launcher category, minSdk 16, SHA-1
  signature, ARM engine library, the right OUYA icon and app icon, and whether it's older than
  your changes

`build.cmd` runs the project checks first and stops on errors (warnings don't stop it):

```bat
build.cmd space-game            :: -> build\space-game-debug.apk
build.cmd space-game -SkipCheck :: build even if the check finds errors
build.cmd -Rebuild              :: rebuild the Docker image from scratch
```

When you change anything in `docker\`, the next build rebuilds the Docker image by itself.

The build prints which OUYA icon it used and checks the signature
(`Signed: SHA-1 (OUYA compatible)`).

You can also export from the editor: **Export → Android**. The paths are already set up.
If **Windows Defender** blocks the export, add an exclusion for the temporary export file
(Virus & threat protection settings). This is a known Godot-for-OUYA issue.

## 6. Run it on the OUYA

Find the OUYA's IP address in its network settings (or in your router), then:

```bat
deploy.cmd space-game -Ip 192.168.1.50 -Logcat
```

This installs the APK, starts the game, and shows Godot's log output (`print()` included).
Press **Ctrl+C** to stop the log. Without `-Ip` it uses USB.

The game shows up in the OUYA's **PLAY** menu with its `ouya_icon.png`. The OUYA keeps the
menu tile of the first install: after changing the icon, deploy once with `-Clean`, which
uninstalls the game first (and deletes its saved data).

## 7. Controller input

Godot-for-OUYA has a built-in controller mapping for the **"OUYA Game Controller"**
(`main/input_default.cpp`, matched on the device name). It turns the raw Android button and
axis numbers into Godot's standard `JOY_*` constants, so the same code also works with an
XInput pad on the PC. **But on this OUYA it's one axis off for the right stick, and it treats
the triggers as on/off buttons.** Replace it at start-up with the measured raw numbers:

```gdscript
const OUYA_GUID = "4f5559412047616d6520436f6e74726f"   # "OUYA Game Contro" in hex

func _ready():
    var m = OUYA_GUID + ",OUYA Game Controller"
    m += ",leftx:a1,lefty:a3,rightx:a5,righty:a6,lefttrigger:a7,righttrigger:a8"
    m += ",a:b0,b:b1,x:b2,y:b3,leftshoulder:b9,rightshoulder:b10,leftstick:b7,rightstick:b8"
    m += ",dpup:b11,dpdown:b12,dpleft:b13,dpright:b14,start:b-86,"
    Input.add_joy_mapping(m, true)
```

With that mapping:

| OUYA | Raw (Android) | Godot |
|---|---|---|
| O / A / U / Y | b0 / b1 / b2 / b3 | `JOY_BUTTON_0` / `1` / `2` / `3` |
| L1 / R1 | b9 / b10 | `JOY_L` / `JOY_R` |
| L3 / R3 | b7 / b8 | `JOY_L3` / `JOY_R3` |
| D-pad up / down / left / right | b11 / b12 / b13 / b14 | `JOY_DPAD_UP` / `DOWN` / `LEFT` / `RIGHT` |
| MENU | b-86 | `JOY_START`. Press and release arrive together: catch it in `_input`, polling misses it |
| Left stick X / Y | a1 / a3 | axis 0 / 1 (`JOY_ANALOG_0_X` / `_Y`) |
| Right stick X / Y | a5 / a6 (built-in mapping: a6 / a7, wrong) | axis 2 / 3 (`JOY_ANALOG_1_X` / `_Y`) |
| L2 / R2 | a7 / a8, -1..1 (also b15 / b16 at full press) | axis 6 / 7, 0..1 (`JOY_ANALOG_L2` / `R2`); `JOY_L2` / `JOY_R2` past halfway |

Raw axis numbers come from sorting the controller's Android motion ranges, so they can differ
per firmware. The **Virtual Controller** test game (`games\virtual-controller`, a port of the
OUYA SDK's `Html5/VirtualController` example) has a raw mode to check them: hold **L1 + R1**
and press **Y**.

The device index (player number) is the order in which controllers first send input.
Unmapped raw buttons and axes are dropped. Stock Godot 2.1 only reads joystick axes 0–7;
Godot-for-OUYA raises that to 13.

## 8. OUYA requirements (from the OUYA developer docs)

What the OUYA needs from an app, and how this toolkit covers it:

| Requirement | Covered by |
|---|---|
| Min Android version **API 16 (4.1)** | Godot-for-OUYA templates (`minSdkVersion 16`) |
| Launcher intent category **`tv.ouya.intent.category.GAME`** (or `.APP`), or it won't appear under PLAY | Godot-for-OUYA templates |
| Icon **`res/drawable-xhdpi/ouya_icon.png`**, exactly **732×412** | `ouya_icon.png` in your game. The build warns if the size is wrong |
| SHA-1 APK signatures | Godot-for-OUYA signs with SHA-1. The Docker build forces it too |
| Works at **720p** (reviewers test on 720p TVs) | Template uses 1280×720 with `stretch_mode="2d"` |
| Release key **kept safe**. Updates must be signed with the same key | See section 9 |

The docs also mention a **320×180 "leanback" icon** (`res/drawable/icon.png`). That's only for
the Android TV launcher on newer devices (Forge TV), not for the OUYA itself.

## 9. Release builds

Debug builds are signed with the shared debug key. To make a build for other people, create
your own key once. Keep it safe, because you can't update your game without it. **Never
commit it**: `*.keystore` is git-ignored.

```bat
tools\jdk8\bin\keytool -genkeypair -keystore C:\keys\mygames.keystore -storetype JKS ^
  -alias mygames -keyalg RSA -keysize 2048 -sigalg SHA1withRSA -validity 10000
```

keytool asks for a keystore password, your name and so on, and then for the key password:
**press Enter to use the same password**. The build only works when both passwords are the same.
Put the keystore outside your game folder, and back up the file and its password.

Build a release APK from the command line:

```bat
build.cmd space-game -Release -Keystore C:\keys\mygames.keystore -Alias mygames
```

It asks for the keystore password and writes `build\space-game-release.apk`. The build prints
the certificate it signed with (`Certificate: CN=...`), so you can check it's your key and not
the debug key. The password is never saved: the build passes it only to a throw-away copy of
`export.cfg` inside the container. To avoid the prompt (in a script, for example), set
`$env:OUYA_KEYSTORE_PASS` first.

**Per game:** if you set the release keystore and user (alias) in the editor
(**Export → Android → Keystore**), they're saved in the game's `export.cfg`, and
`build.cmd space-game -Release` uses them, so you don't have to type `-Keystore` and `-Alias`
every time. Leave the editor's password field empty: `check.cmd` warns if
`export.cfg` contains a password, because that file goes into git.

Install it on the OUYA:

```bat
deploy.cmd space-game -Ip 192.168.1.50 -Release -Clean
```

Debug and release builds are signed with different keys, and Android won't update an app with
an APK signed by another key. `-Clean` uninstalls the game first. This deletes its saved data.
You only need it when you switch between debug and release.

You can still export from the editor instead: set the keystore, alias and password there,
then export with debugging turned off.

## 10. Troubleshooting

| Problem | Fix |
|---|---|
| `Docker is installed but not running` | Start Docker Desktop and wait until it says it's running |
| `adb devices` shows nothing over USB | Use `-Ip` over the network instead. Or, in Device Manager, assign the Google USB driver to the OUYA |
| Install fails with a certificate/signature error | The APK wasn't SHA-1 signed. Build with `build.cmd`, or re-run setup so the editor uses the bundled JDK |
| Game isn't in PLAY | Run `check.cmd <game>`: it reads the APK. Built with the old templates? `build.cmd <game> -Rebuild`. Older builds show under **Make → Software** |
| Black screen or crash on start | `deploy.cmd <game> -Ip <ip> -Logcat` and look for errors |
| Editor export blocked | Windows Defender. See section 5 |
| Setup failed partway | Fix the cause and run `setup-windows.cmd` again. It resumes |

## 11. How it works

- **Why Godot 2.1?** Godot 3+ needs OpenGL ES 3, which the OUYA's Tegra 3 doesn't have. Stock
  Godot 2.1 releases after 2.1.4 require Android 4.3 (API 18), while the OUYA runs 4.1 (API 16).
- **Godot-for-OUYA** ([bherdm/godot-for-ouya](https://github.com/bherdm/godot-for-ouya),
  built on [ville2304's OUYA branch](https://github.com/ville2304/godot/commits/ouya)) is
  Godot 2.1 with the OUYA changes made: minSdk 16, SHA-1 signing, the GAME launcher
  category, an `ouya_icon` export setting, more joystick axes, and Google Play code removed.
- **The Docker build** (`docker/`) is Ubuntu + Temurin JDK 8 + a Godot 2.1 Linux editor running
  under a virtual display (Xvfb). Godot-for-OUYA has no Linux editor, so the container uses the
  official **Godot 2.1.4** Linux editor as the exporter, together with the
  **Godot-for-OUYA 2.1.9** Android templates. Both versions use the same pack, scene and GDScript
  bytecode formats. The exporter doesn't know the `ouya_icon` setting, so `entrypoint.sh` puts
  your game's `ouya_icon.png` into the templates before exporting. It also removes
  `fullscreen=true` from the copy it builds (that setting crashes Godot without a real display;
  Android is fullscreen anyway), and stops Godot once the signed APK exists. Godot 2.1 doesn't
  exit by itself after a command-line export.
- **Pinned downloads.** Godot-for-OUYA comes from its GitHub release `ouya-2.1.9-alpha`, the
  Linux exporter from the official `godotengine/godot-builds` releases. The Windows JDK is
  pinned to Temurin **8u492** because the 8u512 Windows zip on GitHub is a broken upload.
- **No OUYA SDK.** The templates don't include the OUYA ODK, so there are no in-app purchases.

## Layout

```
setup-windows.cmd   one-time setup (downloads into tools\)
new-game.cmd        create a game from template\
check.cmd           check games against the OUYA requirements
run.cmd             play-test a game on this PC
build.cmd           build an APK in Docker      -> build\<game>-debug.apk
deploy.cmd          install + run on the OUYA
Godot for OUYA.cmd  open the editor
*.ps1               the scripts behind the .cmd files (common.ps1 = shared helpers)
docker\             build container: Dockerfile, entrypoint.sh, jarsigner-ouya
template\           starting point for new games
games\virtual-controller\  example game: shows every button and stick of up to 4 controllers
tools\, build\      created locally, git-ignored
```

## Credits

- [Godot Engine](https://godotengine.org) (MIT)
- [Godot-for-OUYA](https://github.com/bherdm/godot-for-ouya) by bherdm, based on the OUYA work
  of [Ville Laine (ville2304)](https://github.com/ville2304/godot)
- OUYA requirements: the [OUYA developer docs](https://github.com/mdesplenter/ouya-docs)
