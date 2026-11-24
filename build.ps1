<#
  Build an OUYA APK in the Docker build container (Docker Desktop must be running).
    build.cmd                        # debug APK of games\hello-ouya -> build\hello-ouya-debug.apk
    build.cmd space-game             # games\space-game
    build.cmd C:\path\to\project     # any Godot 2.1 project folder
    build.cmd space-game -Release    # release APK (needs a release keystore in the game's export settings)
    build.cmd -Rebuild               # rebuild the Docker image first
    build.cmd space-game -SkipCheck  # build even if check.cmd finds errors
#>
param(
    [Parameter(Position = 0)][string]$Game,
    [string]$Out,
    [switch]$Release,
    [switch]$Rebuild,
    [switch]$SkipCheck
)
$ErrorActionPreference = 'Stop'
# (Defaults that use $PSScriptRoot are set here, not in param(): Windows PowerShell 5.1
#  can leave $PSScriptRoot empty while it binds parameters.)
if (-not $Out) { $Out = Join-Path $PSScriptRoot 'build' }
. (Join-Path $PSScriptRoot 'common.ps1')
$Image = 'ouya-godot2'
$g = Resolve-Game $Game

# Same checks as check.cmd (project only); stop on errors, show warnings
if (-not $SkipCheck) {
    & (Join-Path $PSScriptRoot 'check.ps1') $g.Dir -ProjectOnly -Quiet
    if ($LASTEXITCODE -ne 0) { throw "check found errors in $($g.Id) - fix them, or build anyway with -SkipCheck" }
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker not found. Install Docker Desktop (https://www.docker.com/products/docker-desktop/) and start it.'
}
# Native tools write normal messages to stderr; don't let PowerShell treat that as fatal
$ErrorActionPreference = 'Continue'
docker info *> $null
if ($LASTEXITCODE -ne 0) { throw 'Docker is installed but not running - start Docker Desktop first.' }

docker image inspect $Image *> $null
$haveImage = ($LASTEXITCODE -eq 0)
if ($Rebuild -or -not $haveImage) {
    Write-Host "Building Docker image $Image (first time takes a few minutes)..."
    docker build -t $Image (Join-Path $PSScriptRoot 'docker')
    if ($LASTEXITCODE -ne 0) { throw 'docker build failed' }
}

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$Out = (Resolve-Path $Out).Path
$Build = if ($Release) { 'release' } else { 'debug' }

Write-Host "Game: $($g.Id)  ($($g.Dir))  package $($g.Package)"
docker run --rm `
    -v "$($g.Dir):/project:ro" `
    -v "${Out}:/build" `
    -e "BUILD=$Build" -e "APK_NAME=$($g.Id)" `
    $Image
if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
