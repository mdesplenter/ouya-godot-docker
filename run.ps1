<#
  Play-test a game on this PC with Godot-for-OUYA (no build, no OUYA needed).
    run.cmd                      # games\virtual-controller
    run.cmd space-game
    run.cmd space-game -Windowed # don't go fullscreen
  Any gamepad Windows sees works as the controller. Close the window or press Alt+F4 to quit.
#>
param(
    [Parameter(Position = 0)][string]$Game,
    [switch]$Windowed
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$Godot = Join-Path $PSScriptRoot 'tools\godot-for-ouya\godot-for-ouya-64.exe'
if (-not (Test-Path $Godot)) { throw 'Godot-for-OUYA not found - run setup-windows.cmd first.' }
$g = Resolve-Game $Game

$gargs = @('-path', $g.Dir)
if ($Windowed) { $gargs += '-w' }
Write-Host "Running $($g.Id) ..."
& $Godot @gargs
