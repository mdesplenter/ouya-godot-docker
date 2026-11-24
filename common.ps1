# Shared helpers, dot-sourced by build.ps1 / deploy.ps1 / new-game.ps1

$OuyaRoot = $PSScriptRoot

# A game is a Godot 2.1 project folder (has engine.cfg). Accepts a folder name under
# .\games\ or any path. Returns Dir, Id (folder name, used for the APK name) and Package.
function Resolve-Game([string]$Game) {
    if (-not $Game) { $Game = 'hello-ouya' }
    if (Test-Path (Join-Path $Game 'engine.cfg')) {
        $dir = (Resolve-Path $Game).Path
    } else {
        $cand = Join-Path $OuyaRoot "games\$Game"
        if (-not (Test-Path (Join-Path $cand 'engine.cfg'))) {
            $known = (Get-ChildItem (Join-Path $OuyaRoot 'games') -Directory -ErrorAction SilentlyContinue |
                      Where-Object { Test-Path (Join-Path $_.FullName 'engine.cfg') }).Name -join ', '
            throw "Game '$Game' not found. Games in .\games: $known"
        }
        $dir = (Resolve-Path $cand).Path
    }
    $id = Split-Path $dir -Leaf

    $pkg = $null
    $exp = Join-Path $dir 'export.cfg'
    if (Test-Path $exp) {
        $m = Select-String -Path $exp -Pattern '^package/unique_name\s*=\s*"(.*)"' | Select-Object -First 1
        if ($m) { $pkg = $m.Matches[0].Groups[1].Value }
    }
    if (-not $pkg) {
        # Godot 2.1 default: org.godotengine.<project name, lowercased, letters/digits only>
        $m = Select-String -Path (Join-Path $dir 'engine.cfg') -Pattern '^name\s*=\s*"(.*)"' | Select-Object -First 1
        $gen = ($m.Matches[0].Groups[1].Value.ToLower() -replace '[^a-z0-9_]', '')
        $pkg = "org.godotengine.$gen"
    }
    [pscustomobject]@{ Dir = $dir; Id = $id; Package = $pkg }
}
