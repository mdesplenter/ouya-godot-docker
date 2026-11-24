# Notice

This game is a Godot 2.1 port of the OUYA SDK example **Html5/VirtualController** from
<https://github.com/ouya/ouya-sdk-examples> (commit `854422922fa2c8700d13c9c4b6ecfed756b56355`).

Copyright (C) 2012-2015 OUYA, Inc.

- **`controller/*.png`**: controller images, unchanged copies of
  `Html5/VirtualController/web_archive/*.png`.
- **`ouya_icon.png`**: `Html5/VirtualController/customization/res/drawable-xhdpi/ouya_icon.png`,
  scaled from 960×540 to the 732×412 the OUYA launcher requires.
- **`main.gd`**: rewritten in GDScript, based on the layout and logic of
  `Html5/VirtualController/web_archive/index.html`.

OUYA, Inc. published its example code in that repository under the **Apache License,
Version 2.0** (see the headers of its source files, e.g.
`AdobeAir/OuyaNativeExtension/Build/java/src/main/java/tv/ouya/sdk/MainActivity.java`).
The repository has no top-level license file, and the image files carry no license of their
own. They're used here under the same Apache License 2.0 as the rest of OUYA's example.
A copy of the license is in [`LICENSE-APACHE-2.0.txt`](LICENSE-APACHE-2.0.txt).

"OUYA" is a trademark of its owner. This project is not affiliated with or endorsed by
OUYA, Inc. or Razer.
