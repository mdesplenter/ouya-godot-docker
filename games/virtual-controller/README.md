# Virtual Controller (Godot-for-OUYA 2.1)

Port of the OUYA SDK example `Html5/VirtualController`
(https://github.com/mdesplenter/ouya-sdk-examples). It shows up to 4 controllers
in a 2x2 grid. Every button you press lights up on the image, the sticks move, and
the stick and trigger values are shown below each controller.

## Install into the toolkit

```bat
new-game.cmd "Virtual Controller"
```

Copy the contents of this folder into `games\virtual-controller\` and overwrite
`main.tscn`, `main.gd` and `ouya_icon.png`. Keep the `engine.cfg` and `export.cfg`
created by `new-game.cmd`.

```bat
run.cmd virtual-controller -Windowed
build.cmd virtual-controller
deploy.cmd virtual-controller -Ip <ouya-ip> -Logcat
```

## Button mapping (Godot-for-OUYA)

Godot-for-OUYA has a built-in mapping for the "OUYA Game Controller", so you can use
Godot's standard constants in your own games:

| OUYA | Godot |
|---|---|
| O | `JOY_BUTTON_0` |
| A | `JOY_BUTTON_1` |
| U | `JOY_BUTTON_2` |
| Y | `JOY_BUTTON_3` |
| L1 / R1 | `JOY_L` / `JOY_R` |
| L2 / R2 | `JOY_L2` / `JOY_R2` (digital; axis 6 / 7 becomes 0 or 1) |
| L3 / R3 | `JOY_L3` / `JOY_R3` |
| D-pad | `JOY_DPAD_UP/DOWN/LEFT/RIGHT` |
| MENU | `JOY_START` (press and release arrive together, so use `_input`, not polling) |
| Left stick | axis 0 (X), 1 (Y) |
| Right stick | axis 2 (X), 3 (Y) |

**Right stick:** Godot-for-OUYA's built-in mapping uses raw axes 6/7 for the right stick,
which is one axis off on some consoles. `main.gd` replaces the mapping at start-up
(`OUYA_RIGHT_X` / `OUYA_RIGHT_Y`, now 5 and 6). **Raw mode** (hold L1 + R1 and press Y)
shows the raw Android axis and button numbers, so you can check which ones are right.
Copy `ouya_mapping()` and the `add_joy_mapping` call into your own games.

Player number = Godot device index = the order in which controllers first send input.

## Credits

Port of the OUYA SDK example `Html5/VirtualController`, Copyright (C) 2012-2015 OUYA, Inc.
The controller images are unchanged copies from that example. OUYA published its example
code under the Apache License 2.0, and the images are used under the same license: see
[NOTICE.md](NOTICE.md) and [LICENSE-APACHE-2.0.txt](LICENSE-APACHE-2.0.txt).
