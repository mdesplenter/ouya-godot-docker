<#
  Install and launch a built game on the OUYA with adb.
    deploy.cmd                                  # virtual-controller over USB
    deploy.cmd space-game -Ip 192.168.1.50      # over the network (adb port 5555)
    deploy.cmd space-game -Ip 192.168.1.50 -Logcat
    deploy.cmd space-game -Release
    deploy.cmd space-game -Ip 192.168.1.50 -Clean   # uninstall first (new icon, or debug <-> release key)
    deploy.cmd -Apk some.apk -Package com.example.thing
#>
param(
    [Parameter(Position = 0)][string]$Game,
    [string]$Ip,
    [string]$Apk,
    [string]$Package,
    [switch]$Release,
    [switch]$Clean,
    [switch]$Logcat
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$Adb = Join-Path $PSScriptRoot 'tools\platform-tools\adb.exe'
if (-not (Test-Path $Adb)) { throw 'adb not found - run setup-windows.cmd first.' }

if (-not $Apk -or -not $Package) {
    $g = Resolve-Game $Game
    $kind = if ($Release) { 'release' } else { 'debug' }
    if (-not $Apk)     { $Apk = Join-Path $PSScriptRoot "build\$($g.Id)-$kind.apk" }
    if (-not $Package) { $Package = $g.Package }
}
if (-not (Test-Path $Apk)) { throw "APK not found: $Apk - run build.cmd first." }

$ErrorActionPreference = 'Continue'   # adb prints normal messages to stderr
$target = @()
if ($Ip) {
    & $Adb connect "${Ip}:5555" | Write-Host
    $target = @('-s', "${Ip}:5555")
}

& $Adb @target wait-for-device
if ($Clean) {
    # Also clears the OUYA's cached menu tile, and removes the game's saved data
    Write-Host "Uninstalling $Package ..."
    & $Adb @target uninstall $Package | Write-Host
}
Write-Host "Installing $Apk ..."
$result = (& $Adb @target install -r $Apk 2>&1 | ForEach-Object { "$_" }) -join "`n"
Write-Host $result
if ($result -match 'INCONSISTENT_CERTIFICATES|signatures do not match') {
    throw "The OUYA has $Package signed with a different key (debug and release builds use different keys). Run again with -Clean to uninstall it first (this deletes the game's saved data)."
}
if ($LASTEXITCODE -ne 0 -or $result -notmatch 'Success') { throw 'adb install failed' }

Write-Host "Launching $Package ..."
& $Adb @target shell monkey -p $Package -c android.intent.category.LAUNCHER 1 | Out-Null

if ($Logcat) {
    Write-Host 'Showing game log (Ctrl+C to stop)...'
    & $Adb @target logcat -c
    & $Adb @target logcat -s godot:V GodotEngine:V AndroidRuntime:E
}
