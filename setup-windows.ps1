<#
  One-time setup of a portable Godot-for-OUYA + OUYA toolchain in .\tools
  Run from this folder:   setup-windows.cmd

  Installs (nothing system-wide):
    tools\godot-for-ouya\  Godot-for-OUYA 2.1.9 editor (github.com/bherdm/godot-for-ouya),
                           in self-contained mode: settings + export templates live in
                           tools\godot-for-ouya\editor_data\
    tools\jdk8\            Eclipse Temurin JDK 8 (jarsigner / keytool)
    tools\platform-tools\  Android adb
    tools\debug.keystore   Android debug signing key
  Configures:
    %USERPROFILE%\.android\adb_usb.ini    OUYA USB vendor id (0x2836)
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # makes Invoke-WebRequest much faster
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Root  = $PSScriptRoot
$Tools = Join-Path $Root 'tools'
$Dl    = Join-Path $Tools '_downloads'
New-Item -ItemType Directory -Force -Path $Tools, $Dl | Out-Null

# Checks a download really is what we expect: a zip ('PK') or a Windows .exe ('MZ')
function Test-Download([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    if ((Get-Item $Path).Length -lt 1024) { return $false }
    $fs = [IO.File]::OpenRead($Path)
    try { $b = New-Object byte[] 2; [void]$fs.Read($b, 0, 2) } finally { $fs.Dispose() }
    if ($Path -like '*.exe') { return ($b[0] -eq 0x4D -and $b[1] -eq 0x5A) }
    return ($b[0] -eq 0x50 -and $b[1] -eq 0x4B)
}

function Get-File([string]$Url, [string]$Name) {
    $p = Join-Path $Dl $Name
    if (Test-Download $p) { return $p }
    if (Test-Path $p) { Remove-Item $p -Force }   # broken earlier download
    Write-Host "  downloading $Name ..."
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & $curl.Source -fL --retry 3 -o "$p.part" $Url
        if ($LASTEXITCODE -ne 0) { throw "download failed: $Url" }
    } else {
        Invoke-WebRequest -Uri $Url -OutFile "$p.part" -UseBasicParsing
    }
    Move-Item "$p.part" $p -Force
    if (-not (Test-Download $p)) { throw "downloaded $Name is broken or not the expected file type ($Url)" }
    return $p
}

# Godot-for-OUYA: Godot 2.1 fork with OUYA export templates (GAME launcher category,
# ouya_icon, minSdk 16, SHA-1 signing). https://github.com/bherdm/godot-for-ouya
$G4O = 'https://github.com/bherdm/godot-for-ouya/releases/download/ouya-2.1.9-alpha'

# --- Godot-for-OUYA editor --------------------------------------------------
Write-Host '[1/6] Godot-for-OUYA 2.1.9 editor'
$GodotDir = Join-Path $Tools 'godot-for-ouya'
$GodotExe = Join-Path $GodotDir 'godot-for-ouya-64.exe'
New-Item -ItemType Directory -Force -Path $GodotDir | Out-Null
if (-not (Test-Path $GodotExe)) {
    $e = Get-File "$G4O/godot-for-ouya-64.exe" 'godot-for-ouya-2.1.9-64.exe'
    Copy-Item $e $GodotExe
    Unblock-File $GodotExe -ErrorAction SilentlyContinue   # avoid the "downloaded from the internet" prompt
}
# Self-contained mode: settings and templates go to editor_data\ next to the exe,
# so this setup doesn't touch (or clash with) any other Godot 2 on the PC
$Sc = Join-Path $GodotDir '._sc_'
if (-not (Test-Path $Sc)) { New-Item -ItemType File -Path $Sc | Out-Null }

# --- Export templates (Android only) ----------------------------------------
Write-Host '[2/6] Godot-for-OUYA Android export templates'
$GodotData = Join-Path $GodotDir 'editor_data'
$TplDir    = Join-Path $GodotData 'templates'
New-Item -ItemType Directory -Force -Path $TplDir | Out-Null
if (-not (Test-Path (Join-Path $TplDir 'android_debug.apk'))) {
    $tpz = Get-File "$G4O/godot-for-ouya-2.1.9-alpha-export-templates.tpz" 'godot-for-ouya-2.1.9-templates.tpz'
    $zip = [IO.Compression.ZipFile]::OpenRead($tpz)
    try {
        foreach ($e in $zip.Entries) {
            if ($e.FullName -like 'templates/android*' -or $e.FullName -eq 'templates/version.txt') {
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $TplDir $e.Name), $true)
            }
        }
    } finally { $zip.Dispose() }
}

# --- JDK 8 ------------------------------------------------------------------
Write-Host '[3/6] JDK 8 (Temurin)'
$Jdk = Join-Path $Tools 'jdk8'
if (-not (Test-Path (Join-Path $Jdk 'bin\jarsigner.exe'))) {
    # Pinned to 8u492: the 8u512 Windows zip on GitHub is a broken 1.8 KB upload
    $link = 'https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_windows_hotspot_8u492b09.zip'
    $z = Get-File $link 'temurin8u492-win64.zip'
    $tmp = Join-Path $Tools '_jdk_tmp'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive -Path $z -DestinationPath $tmp -Force
    $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (Test-Path $Jdk) { Remove-Item $Jdk -Recurse -Force }
    Move-Item $inner.FullName $Jdk
    Remove-Item $tmp -Recurse -Force
}
$Jarsigner = Join-Path $Jdk 'bin\jarsigner.exe'
$Keytool   = Join-Path $Jdk 'bin\keytool.exe'

# --- adb --------------------------------------------------------------------
Write-Host '[4/6] Android platform-tools (adb)'
$Adb = Join-Path $Tools 'platform-tools\adb.exe'
if (-not (Test-Path $Adb)) {
    $z = Get-File 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' 'platform-tools.zip'
    Expand-Archive -Path $z -DestinationPath $Tools -Force
}
# Let adb recognise the OUYA over USB
$AndroidDir = Join-Path $env:USERPROFILE '.android'
New-Item -ItemType Directory -Force -Path $AndroidDir | Out-Null
$UsbIni = Join-Path $AndroidDir 'adb_usb.ini'
if (-not ((Test-Path $UsbIni) -and (Select-String -Path $UsbIni -Pattern '0x2836' -Quiet))) {
    Add-Content -Path $UsbIni -Value '0x2836'
}

# --- Debug keystore ---------------------------------------------------------
Write-Host '[5/6] Debug keystore'
$Keystore = Join-Path $Tools 'debug.keystore'
if (-not (Test-Path $Keystore)) {
    # keytool warns on stderr about SHA-1 (which the OUYA needs); with
    # ErrorActionPreference=Stop Windows PowerShell would treat that as fatal
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $Keytool -genkeypair -noprompt -keystore $Keystore -storetype JKS `
        -storepass android -keypass android -alias androiddebugkey `
        -keyalg RSA -keysize 2048 -sigalg SHA1withRSA -validity 10000 `
        -dname 'CN=Android Debug,O=Android,C=US' 2>&1 | Out-Null
    $ErrorActionPreference = $old
    if (-not (Test-Path $Keystore)) { throw 'keytool failed to create the debug keystore' }
}

# --- Editor settings --------------------------------------------------------
Write-Host '[6/6] Editor settings'
$Settings = Join-Path $GodotData 'editor_settings.tres'
if (-not (Test-Path $Settings)) {
    # Start the editor once (project manager) so it writes its default settings file
    Write-Host '  starting the editor once to create its settings (it closes by itself)...'
    $p = Start-Process -FilePath $GodotExe -PassThru
    for ($i = 0; $i -lt 30 -and -not (Test-Path $Settings); $i++) { Start-Sleep -Seconds 1 }
    Start-Sleep -Seconds 2
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
}
if (-not (Test-Path $Settings)) {
    Set-Content -Path $Settings -Encoding UTF8 -Value "[gd_resource type=`"EditorSettings`" format=1]`n`n[resource]`n"
} else {
    Copy-Item $Settings "$Settings.bak" -Force
}
function Fwd([string]$p) { return $p -replace '\\', '/' }
$want = [ordered]@{
    'android/adb'                 = (Fwd $Adb)
    'android/jarsigner'           = (Fwd $Jarsigner)
    'android/debug_keystore'      = (Fwd $Keystore)
    'android/debug_keystore_user' = 'androiddebugkey'
    'android/debug_keystore_pass' = 'android'
}
$lines = [System.Collections.Generic.List[string]](Get-Content $Settings)
foreach ($k in $want.Keys) {
    $line = "$k = `"$($want[$k])`""
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].StartsWith("$k = ")) { $idx = $i; break } }
    if ($idx -ge 0) { $lines[$idx] = $line } else { $lines.Add($line) }
}
[IO.File]::WriteAllLines($Settings, $lines)   # UTF-8 without BOM

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Write-Host "  Editor:     double-click 'Godot for OUYA.cmd' and import games\hello-ouya\engine.cfg"
Write-Host '  New game:   new-game.cmd "My Game"'
Write-Host '  Play-test:  run.cmd hello-ouya                (on this PC)'
Write-Host '  Build:      build.cmd hello-ouya              (Docker)'
Write-Host '  Deploy:     deploy.cmd hello-ouya -Ip <ouya-ip>'
Write-Host '  More:       see HOWTO.md'
