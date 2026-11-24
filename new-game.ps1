<#
  Create a new game from .\template
    new-game.cmd "Space Game"                         # -> games\space-game, asks for the package name
    new-game.cmd "Space Game" -Package com.me.space   # give the Android package name (no question)
    new-game.cmd "Space Game" -Path D:\dev\space-game # create it somewhere else

  The package name is the game's unique id on the OUYA (e.g. com.yourname.spacegame).
  Press Enter to take the suggestion, org.ouyadev.<game name>.
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
if (-not $Path) { $Path = Join-Path $OuyaRoot "games\$slug" }
if (Test-Path $Path) { throw "$Path already exists" }

# Package names of the games that already exist: a new game must not reuse one, or it
# would overwrite that game on the OUYA
$used = @{}
foreach ($dir in Get-ChildItem (Join-Path $OuyaRoot 'games') -Directory -ErrorAction SilentlyContinue) {
    $exp = Join-Path $dir.FullName 'export.cfg'
    if (-not (Test-Path $exp)) { continue }
    $m = Select-String -Path $exp -Pattern '^package/unique_name\s*=\s*"(.*)"' | Select-Object -First 1
    if ($m) { $used[$m.Matches[0].Groups[1].Value] = $dir.Name }
}

function Test-PackageName([string]$p) {
    if ($p -notmatch '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$') {
        return "'$p' is not a valid package name: use lowercase words with dots, e.g. com.yourname.spacegame"
    }
    if ($p -like 'com.godot.game*' -or $p -like 'org.godotengine.*') { return "'$p' is Godot's default - pick your own" }
    if ($used.Contains($p)) { return "'$p' is already used by games\$($used[$p])" }
    return $null
}

if ($Package) {
    $problem = Test-PackageName $Package
    if ($problem) { throw $problem }
} else {
    $suggest = 'org.ouyadev.' + ($slug -replace '-', '')
    Write-Host 'Package name: the unique id of the game on the OUYA, e.g. com.yourname.spacegame.'
    Write-Host "It can't change after you share the game."
    while (-not $Package) {
        $answer = (Read-Host "Package name [$suggest]").Trim()
        if (-not $answer) { $answer = $suggest }
        $problem = Test-PackageName $answer
        if ($problem) { Write-Host "  $problem" -ForegroundColor Yellow } else { $Package = $answer }
    }
}

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
Write-Host "  icons:   $Path\ouya_icon.png  (OUYA PLAY menu tile, 732x412)"
Write-Host "           $Path\icon.png       (square app icon, 192x192)"
Write-Host "           Both are placeholders - replace them with your own art."
Write-Host ''
Write-Host "Open it:  'Godot for OUYA.cmd' -> Import -> $Path\engine.cfg"
$arg = if ($Path -eq (Join-Path $OuyaRoot "games\$slug")) { $slug } else { "`"$Path`"" }
Write-Host "Build:    build.cmd $arg"
Write-Host "Deploy:   deploy.cmd $arg -Ip <ouya-ip>"
