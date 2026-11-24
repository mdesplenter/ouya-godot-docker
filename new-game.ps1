<#
  Create a new game from .\template
    new-game.cmd "Space Game"                         # -> games\space-game, package org.ouyadev.spacegame
    new-game.cmd "Space Game" -Package com.me.space   # choose the Android package name
    new-game.cmd "Space Game" -Path D:\dev\space-game # create it somewhere else
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Name,
    [string]$Package,
    [string]$Path
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$slug = ($Name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
if (-not $slug) { throw "Can't make a folder name from '$Name'" }
if (-not $Package) { $Package = 'org.ouyadev.' + ($slug -replace '-', '') }
if ($Package -notmatch '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$') {
    throw "'$Package' is not a valid Android package name (e.g. com.yourname.spacegame)"
}
if (-not $Path) { $Path = Join-Path $OuyaRoot "games\$slug" }
if (Test-Path $Path) { throw "$Path already exists" }

New-Item -ItemType Directory -Force -Path $Path | Out-Null
Copy-Item (Join-Path $OuyaRoot 'template\*') $Path -Recurse
foreach ($f in 'engine.cfg', 'export.cfg') {
    $p = Join-Path $Path $f
    $t = [IO.File]::ReadAllText($p).Replace('__NAME__', $Name.Replace('"', "'")).Replace('__PACKAGE__', $Package)
    [IO.File]::WriteAllText($p, $t)
}
Set-Content -Path (Join-Path $Path '.gitignore') -Encoding ASCII -Value ".fscache`r`n*.apk`r`n"

Write-Host "Created $Path"
Write-Host "  name:    $Name"
Write-Host "  package: $Package"
Write-Host "  icon:    $Path\ouya_icon.png  (placeholder - replace with your own 732x412 PNG)"
Write-Host ''
Write-Host "Open it:  'Godot for OUYA.cmd' -> Import -> $Path\engine.cfg"
$arg = if ($Path -eq (Join-Path $OuyaRoot "games\$slug")) { $slug } else { "`"$Path`"" }
Write-Host "Build:    build.cmd $arg"
Write-Host "Deploy:   deploy.cmd $arg -Ip <ouya-ip>"
