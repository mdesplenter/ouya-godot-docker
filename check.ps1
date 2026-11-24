<#
  Check games against the OUYA's requirements and common mistakes.
    check.cmd                  # every game in games\
    check.cmd space-game       # one game (folder name under games\, or a path)
    check.cmd space-game -Quiet  # only show warnings and errors

  Checks the project (engine.cfg, export.cfg, ouya_icon.png, scripts) and, if it exists,
  the built APK in build\ (OUYA category, minSdk, SHA-1 signature, icon, ARM library).
  Exit code 1 if any game has errors.
#>
param(
    [Parameter(Position = 0)][string]$Game,
    [switch]$Quiet,
    [switch]$ProjectOnly   # skip the APK checks (used by build.cmd before building)
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:errors = 0; $script:warnings = 0
function Ok([string]$m)   { if (-not $Quiet) { Write-Host "  [ OK ] $m" -ForegroundColor Green } }
function Warn([string]$m) { $script:warnings++; Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Err([string]$m)  { $script:errors++;   Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Info([string]$m) { if (-not $Quiet) { Write-Host "         $m" -ForegroundColor DarkGray } }

# Reads key = "value" / key=value from a Godot 2 .cfg file: returns @{ 'section/key' = value }
function Read-Cfg([string]$Path) {
    $h = @{}; $sec = ''
    foreach ($line in Get-Content $Path) {
        $t = $line.Trim()
        if ($t -match '^\[(.+)\]$') { $sec = $Matches[1]; continue }
        if ($t -match '^([^=;#]+?)\s*=\s*(.*)$') {
            $k = $Matches[1].Trim(); $v = $Matches[2].Trim()
            if ($v -match '^"(.*)"$') { $v = $Matches[1] }
            $h["$sec/$k"] = $v
        }
    }
    return $h
}

function Get-PngSize([string]$Path) {
    $b = [IO.File]::ReadAllBytes($Path)
    if ($b.Length -lt 24 -or $b[0] -ne 0x89 -or $b[1] -ne 0x50 -or $b[2] -ne 0x4E -or $b[3] -ne 0x47) { return $null }
    $w = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
    $h = ([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
    return @($w, $h)
}

function Get-Md5([byte[]]$Bytes) {
    $md5 = [Security.Cryptography.MD5]::Create()
    try { return [BitConverter]::ToString($md5.ComputeHash($Bytes)) } finally { $md5.Dispose() }
}

# Minimal reader for Android's binary AndroidManifest.xml: returns the <uses-sdk> integer attributes
function Get-UsesSdk([byte[]]$d) {
    $res = @{}; $strings = @(); $pos = 8
    while ($pos + 8 -le $d.Length) {
        $type = [BitConverter]::ToUInt16($d, $pos); $hsize = [BitConverter]::ToUInt16($d, $pos + 2)
        $csize = [BitConverter]::ToUInt32($d, $pos + 4)
        if ($csize -eq 0) { break }
        if ($type -eq 0x0001) {
            $n = [BitConverter]::ToUInt32($d, $pos + 8); $flags = [BitConverter]::ToUInt32($d, $pos + 16)
            $sstart = [BitConverter]::ToUInt32($d, $pos + 20)
            for ($i = 0; $i -lt $n; $i++) {
                $p = $pos + $sstart + [BitConverter]::ToUInt32($d, $pos + $hsize + 4 * $i)
                if ($flags -band 0x100) {
                    $p += 1 + $(if ($d[$p] -band 0x80) { 1 } else { 0 })
                    $len = $d[$p]; $p++
                    $strings += [Text.Encoding]::UTF8.GetString($d, $p, $len)
                } else {
                    $len = [BitConverter]::ToUInt16($d, $p)
                    $strings += [Text.Encoding]::Unicode.GetString($d, $p + 2, $len * 2)
                }
            }
        } elseif ($type -eq 0x0102) {
            $name = [BitConverter]::ToUInt32($d, $pos + 20); $count = [BitConverter]::ToUInt16($d, $pos + 28)
            if ($strings[$name] -eq 'uses-sdk') {
                for ($i = 0; $i -lt $count; $i++) {
                    $a = $pos + 36 + $i * 20
                    $res[$strings[[BitConverter]::ToUInt32($d, $a + 4)]] = [BitConverter]::ToUInt32($d, $a + 16)
                }
            }
        }
        $pos += $csize
    }
    return $res
}

function Read-Entry($zip, [string]$name) {
    $e = $zip.GetEntry($name); if (-not $e) { return $null }
    $s = $e.Open(); $ms = New-Object IO.MemoryStream
    try { $s.CopyTo($ms); return $ms.ToArray() } finally { $s.Dispose(); $ms.Dispose() }
}

# Placeholder icons that new-game.cmd copies from template\
$templateIcon = Join-Path $OuyaRoot 'template\ouya_icon.png'
$templateIconMd5 = if (Test-Path $templateIcon) { Get-Md5 ([IO.File]::ReadAllBytes($templateIcon)) } else { '' }
$templateAppIcon = Join-Path $OuyaRoot 'template\icon.png'
$templateAppIconMd5 = if (Test-Path $templateAppIcon) { Get-Md5 ([IO.File]::ReadAllBytes($templateAppIcon)) } else { '' }
# Godot's own logo, which the exporter puts in res/drawable/icon.png when application/icon is not set
$godotAppIconMd5 = 'A4-9E-95-B5-53-6C-7F-9E-B7-08-7B-CD-80-42-1D-86'

function Test-Game($g) {
    Write-Host ''
    Write-Host "== $($g.Id)  ($($g.Dir))" -ForegroundColor Cyan
    $dir = $g.Dir

    # --- engine.cfg ---------------------------------------------------------
    $eng = Read-Cfg (Join-Path $dir 'engine.cfg')
    if ($eng['application/name']) { Ok "name: $($eng['application/name'])" } else { Warn 'engine.cfg has no application name' }
    $main = $eng['application/main_scene']
    if (-not $main) { Err 'engine.cfg has no main_scene - the game has nothing to start' }
    elseif (-not (Test-Path (Join-Path $dir ($main -replace '^res://', '')))) { Err "main_scene $main does not exist" }
    else { Ok "main scene: $main" }

    $w = $eng['display/width']; $h = $eng['display/height']
    if (-not $w -or -not $h) { Warn 'no display width/height set (Godot 2 default is 1024x600) - use 1280x720' }
    elseif (($w -eq '1280' -and $h -eq '720') -or ($w -eq '1920' -and $h -eq '1080')) { Ok "resolution: ${w}x${h}" }
    else { Warn "resolution ${w}x${h} - the OUYA outputs 720p/1080p; use 1280x720 or 1920x1080" }
    if ($eng['display/stretch_mode'] -in @('2d', 'viewport')) { Ok "stretch mode: $($eng['display/stretch_mode'])" }
    else { Warn 'display/stretch_mode not set to 2d or viewport - the game may not fill a 720p/1080p TV (OUYA review requires correct 720p display)' }

    # --- export.cfg ---------------------------------------------------------
    $expPath = Join-Path $dir 'export.cfg'
    $exp = if (Test-Path $expPath) { Read-Cfg $expPath } else { @{} }
    if (-not (Test-Path $expPath)) { Warn 'no export.cfg - package name and OUYA icon fall back to defaults' }

    $pkg = $exp['platform:Android/package/unique_name']
    if (-not $pkg) { Err "no package/unique_name in export.cfg - every game would install as '$($g.Package)'" }
    elseif ($pkg -notmatch '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$') { Err "package name '$pkg' is not valid (e.g. com.yourname.spacegame)" }
    elseif ($pkg -match '\$genname' -or $pkg -like 'com.godot.game*' -or $pkg -like 'org.godotengine.*') { Err "package name '$pkg' is Godot's default - games would overwrite each other on the OUYA" }
    elseif ($pkg -like 'org.ouyadev.*') { Ok "package: $pkg"; Info 'org.ouyadev.* is the toolkit default - use your own (com.yourname.game) before sharing' }
    else { Ok "package: $pkg" }

    if ($exp['platform:Android/package/name']) { Ok "app title: $($exp['platform:Android/package/name'])" }
    else { Info 'no package/name - the OUYA shows the project name' }

    # --- OUYA icon ----------------------------------------------------------
    $iconRes = $exp['platform:Android/package/ouya_icon']
    $iconPath = $null
    if ($iconRes) {
        if ($iconRes -notmatch '^res://') { Warn "package/ouya_icon '$iconRes' is not a res:// path - the Docker build can't use it" }
        else { $iconPath = Join-Path $dir ($iconRes -replace '^res://', '') }
    } elseif (Test-Path (Join-Path $dir 'ouya_icon.png')) {
        $iconPath = Join-Path $dir 'ouya_icon.png'
        Warn 'ouya_icon.png exists but export.cfg has no package/ouya_icon line - the editor export will ignore it. Add: package/ouya_icon="res://ouya_icon.png"'
    }
    if (-not $iconPath) { Warn 'no OUYA icon - the menu shows the Godot-for-OUYA default. Add a 732x412 ouya_icon.png and package/ouya_icon="res://ouya_icon.png" to export.cfg' }
    elseif (-not (Test-Path $iconPath)) { Err "OUYA icon $iconRes not found" }
    else {
        $size = Get-PngSize $iconPath
        if (-not $size) { Err "$(Split-Path $iconPath -Leaf) is not a PNG" }
        elseif ($size[0] -ne 732 -or $size[1] -ne 412) { Err "$(Split-Path $iconPath -Leaf) is $($size[0])x$($size[1]) - the OUYA requires exactly 732x412" }
        else {
            $md5 = Get-Md5 ([IO.File]::ReadAllBytes($iconPath))
            if ($md5 -eq $templateIconMd5) { Warn 'ouya_icon.png is still the template placeholder - replace it with your own art' }
            else { Ok 'OUYA icon: 732x412 PNG' }
        }
    }

    # --- App icon (application/icon in engine.cfg -> res/drawable/icon.png) ----
    # Square icon Android uses for the app itself (app lists, Make > Software, Android TV launchers).
    # Without it the APK carries the Godot logo.
    $appIconRes = $eng['application/icon']
    $appIconPath = $null
    if (-not $appIconRes) {
        Warn 'no app icon - Android shows the Godot logo for this app. Add a square icon.png (e.g. 192x192) and icon="res://icon.png" under [application] in engine.cfg'
    } elseif ($appIconRes -notmatch '^res://') {
        Warn "application/icon '$appIconRes' is not a res:// path"
    } else {
        $appIconPath = Join-Path $dir ($appIconRes -replace '^res://', '')
        if (-not (Test-Path $appIconPath)) { Err "app icon $appIconRes not found"; $appIconPath = $null }
        else {
            $size = Get-PngSize $appIconPath
            if (-not $size) { Err "$(Split-Path $appIconPath -Leaf) is not a PNG - the Android export needs a PNG app icon"; $appIconPath = $null }
            elseif ($size[0] -ne $size[1]) { Warn "app icon is $($size[0])x$($size[1]) - make it square (e.g. 192x192)" }
            elseif ($size[0] -lt 96) { Warn "app icon is only $($size[0])x$($size[1]) - use at least 96x96 (192x192 is best)" }
            elseif ((Get-Md5 ([IO.File]::ReadAllBytes($appIconPath))) -eq $templateAppIconMd5) { Warn 'icon.png is still the template placeholder - replace it with your own art' }
            else { Ok "app icon: $($size[0])x$($size[1]) PNG" }
        }
    }

    # --- Scripts: Godot 3/4 syntax that Godot 2.1 doesn't understand --------
    $patterns = [ordered]@{
        '\$[A-Za-z_"]'           = '$Node shorthand is Godot 3+ (use get_node("Node"))'
        '\)\s*->\s*\w+\s*:'      = 'typed return values (-> type) are Godot 3.1+'
        '^\s*@\w+'               = '@annotations are Godot 4'
        '_physics_process'       = '_physics_process is Godot 3+ (use _fixed_process + set_fixed_process(true))'
        '\bmove_and_(slide|collide)\b' = 'move_and_slide/move_and_collide are Godot 3+ (Godot 2.1: move() on KinematicBody2D)'
        '\bis\s+InputEvent'     = '"event is InputEventX" is Godot 3+ (Godot 2.1: event.type == InputEvent.KEY etc.)'
        '\bInputEventJoypad'     = 'InputEventJoypad* is Godot 3+ (Godot 2.1: InputEvent.JOYSTICK_BUTTON / JOYSTICK_MOTION)'
        '\bJOY_BUTTON_[A-Z]|\bJOY_AXIS_(LEFT|RIGHT|TRIGGER)|\bJOY_ANALOG_[LR][XY]\b' = 'Godot 3/4 joystick constant names (Godot 2.1: JOY_BUTTON_0.., JOY_AXIS_0.., JOY_ANALOG_0_X..)'
        '\bvar\s+\w+\s*:'      = 'typed variables (var x: int / var x :=) are Godot 3.1+'
        '\bawait\b'             = 'await is Godot 4 (Godot 2.1: yield)'
    }
    $scripts = Get-ChildItem $dir -Recurse -Include *.gd -File | Where-Object { $_.FullName -notmatch '\\\.' }
    $found = 0
    foreach ($s in $scripts) {
        $n = 0
        foreach ($line in Get-Content $s.FullName) {
            $n++
            $code = ($line -split '#', 2)[0]
            foreach ($p in $patterns.Keys) {
                if ($code -cmatch $p) {
                    $rel = $s.FullName.Substring($dir.Length + 1)
                    Warn "${rel}:$n $($patterns[$p])"; $found++; break
                }
            }
        }
    }
    if ($scripts.Count -and -not $found) { Ok "$($scripts.Count) script(s): no Godot 3/4-only syntax found" }

    # --- Secrets ------------------------------------------------------------
    $keys = Get-ChildItem $dir -Recurse -Include *.keystore, *.jks -File -ErrorAction SilentlyContinue
    foreach ($k in $keys) {
        $gi = Join-Path $dir '.gitignore'
        if (-not ((Test-Path $gi) -and (Select-String -Path $gi -Pattern 'keystore|\.jks' -Quiet))) {
            Warn "$($k.Name) is in the game folder but not in its .gitignore - don't commit signing keys"
        }
    }

    # --- Built APK ------------------------------------------------------------
    if ($ProjectOnly) { return }
    foreach ($kind in 'debug', 'release') {
        $apk = Join-Path $OuyaRoot "build\$($g.Id)-$kind.apk"
        if (-not (Test-Path $apk)) { continue }
        Write-Host "  -- build\$($g.Id)-$kind.apk" -ForegroundColor Cyan
        $newest = Get-ChildItem $dir -Recurse -File |
                  Where-Object { $_.FullName -notmatch '\\\.' -and $_.Extension -notin @('.md', '.txt') } |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($newest -and $newest.LastWriteTime -gt (Get-Item $apk).LastWriteTime) {
            Warn "APK is older than $($newest.Name) - rebuild to test your latest changes"
        }
        $zip = [IO.Compression.ZipFile]::OpenRead($apk)
        try {
            $man = Read-Entry $zip 'AndroidManifest.xml'
            if (-not $man) { Err 'APK has no AndroidManifest.xml'; continue }
            $text = [Text.Encoding]::Unicode.GetString($man)
            if ($text.Contains('tv.ouya.intent.category.GAME') -or $text.Contains('tv.ouya.intent.category.APP')) { Ok 'OUYA launcher category (shows under PLAY)' }
            else { Err 'no tv.ouya.intent.category.GAME - built with non-OUYA templates; it will only show under Make > Software (rebuild with build.cmd -Rebuild)' }
            if ($pkg -and -not $text.Contains($pkg)) { Warn "APK package doesn't match export.cfg ($pkg) - rebuild" }

            $sdk = Get-UsesSdk $man
            $min = $sdk['minSdkVersion']
            if ($null -eq $min) { Warn 'could not read minSdkVersion' }
            elseif ($min -le 16) { Ok "minSdkVersion $min (OUYA is API 16)" }
            else { Err "minSdkVersion $min - the OUYA (Android 4.1, API 16) can't install this" }

            $sf = $zip.Entries | Where-Object { $_.FullName -like 'META-INF/*.SF' } | Select-Object -First 1
            if (-not $sf) { Err 'APK is not signed' }
            else {
                $sfText = [Text.Encoding]::ASCII.GetString((Read-Entry $zip $sf.FullName))
                if ($sfText -match 'SHA-256-Digest') { Err 'signed with SHA-256 - the OUYA only accepts SHA-1' }
                elseif ($sfText -match 'SHA1-Digest') { Ok 'signed with SHA-1' }
                else { Warn 'unknown signature digest' }
            }

            if ($zip.GetEntry('lib/armeabi-v7a/libgodot_android.so')) { Ok 'ARM (armeabi-v7a) engine library' }
            else { Err 'no lib/armeabi-v7a/libgodot_android.so - the OUYA needs the ARM build' }

            $apkIcon = Read-Entry $zip 'res/drawable-xhdpi-v4/ouya_icon.png'
            if (-not $apkIcon) { Err 'APK has no res/drawable-xhdpi/ouya_icon.png' }
            elseif ($iconPath -and (Test-Path $iconPath) -and (Get-Md5 $apkIcon) -ne (Get-Md5 ([IO.File]::ReadAllBytes($iconPath)))) {
                Warn "APK's OUYA icon differs from $(Split-Path $iconPath -Leaf) - rebuild"
            } else { Ok 'OUYA icon in APK' }

            $apkAppIcon = Read-Entry $zip 'res/drawable/icon.png'
            if (-not $apkAppIcon) { Warn 'APK has no res/drawable/icon.png' }
            elseif ($appIconPath -and (Get-Md5 $apkAppIcon) -ne (Get-Md5 ([IO.File]::ReadAllBytes($appIconPath)))) {
                Warn "APK's app icon differs from $(Split-Path $appIconPath -Leaf) - rebuild"
            } elseif ((Get-Md5 $apkAppIcon) -eq $godotAppIconMd5) { Warn 'APK app icon is the Godot logo' }
            else { Ok 'app icon in APK' }
        } finally { $zip.Dispose() }
    }
}

# --- Which games ------------------------------------------------------------
if ($Game) { $games = @(Resolve-Game $Game) }
else {
    $games = Get-ChildItem (Join-Path $OuyaRoot 'games') -Directory |
             Where-Object { Test-Path (Join-Path $_.FullName 'engine.cfg') } |
             ForEach-Object { Resolve-Game $_.FullName }
}
foreach ($g in $games) { Test-Game $g }

Write-Host ''
$color = if ($script:errors) { 'Red' } elseif ($script:warnings) { 'Yellow' } else { 'Green' }
Write-Host "$(@($games).Count) game(s): $script:errors error(s), $script:warnings warning(s)" -ForegroundColor $color
if ($script:errors) { exit 1 } else { exit 0 }
