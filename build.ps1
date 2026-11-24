<#
  Build an OUYA APK in the Docker build container (Docker Desktop must be running).
    build.cmd                        # debug APK of games\virtual-controller -> build\virtual-controller-debug.apk
    build.cmd space-game             # games\space-game
    build.cmd C:\path\to\project     # any Godot 2.1 project folder
    build.cmd space-game -Release -Keystore C:\keys\mygames.keystore -Alias mygames
                                     # release APK signed with your own key (asks for its password)
    build.cmd space-game -Release    # same, with the keystore and alias saved in the game's export.cfg
    build.cmd -Rebuild               # rebuild the Docker image first
    build.cmd space-game -SkipCheck  # build even if check.cmd finds errors

  Release password: typed in when asked, or taken from $env:OUYA_KEYSTORE_PASS if that is set.
  The keystore and key must use the same password (keytool asks: press Enter for "same").
#>
param(
    [Parameter(Position = 0)][string]$Game,
    [string]$Out,
    [switch]$Release,
    [string]$Keystore,
    [string]$Alias,
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

# --- Release key ----------------------------------------------------------------
$keyArgs = @()
if ($Release) {
    # Not given on the command line? Use what the editor saved in export.cfg
    # (Export -> Android -> Keystore -> Release / Release User).
    $expPath = Join-Path $g.Dir 'export.cfg'
    if ((-not $Keystore -or -not $Alias) -and (Test-Path $expPath)) {
        foreach ($line in Get-Content $expPath) {
            if (-not $Keystore -and $line -match '^keystore/release\s*=\s*"(.+)"') { $Keystore = $Matches[1] }
            if (-not $Alias -and $line -match '^keystore/release_user\s*=\s*"(.+)"') { $Alias = $Matches[1] }
        }
    }
    $usage = "build.cmd $($g.Id) -Release -Keystore C:\keys\mygames.keystore -Alias mygames  (see HOWTO.md section 9)"
    if (-not $Keystore) { throw "A release build needs your own keystore: $usage" }
    if (-not (Test-Path $Keystore -PathType Leaf)) { throw "Keystore not found: $Keystore" }
    if (-not $Alias) { throw "Which key in the keystore? Add -Alias: $usage" }
    $Keystore = (Resolve-Path $Keystore).Path

    $pass = $env:OUYA_KEYSTORE_PASS
    if (-not $pass) {
        $secure = Read-Host "Password for $(Split-Path $Keystore -Leaf)" -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { $pass = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }
    if (-not $pass) { throw 'No keystore password given' }
    # Passed to docker by name only (-e NAME), so the password isn't on the command line
    $env:KEYSTORE_PASS = $pass
    $env:KEYSTORE_ALIAS = $Alias
    $keyArgs = @('-v', "${Keystore}:/keystore/release.keystore:ro", '-e', 'KEYSTORE_PASS', '-e', 'KEYSTORE_ALIAS')
}

try {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker not found. Install Docker Desktop (https://www.docker.com/products/docker-desktop/) and start it.'
    }
    # Native tools write normal messages to stderr; don't let PowerShell treat that as fatal
    $ErrorActionPreference = 'Continue'
    docker info *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker is installed but not running - start Docker Desktop first.' }

    # Rebuild the image when anything in docker\ changed since it was built
    $dockerDir = Join-Path $PSScriptRoot 'docker'
    $sha = [Security.Cryptography.SHA256]::Create()
    $all = (Get-ChildItem $dockerDir -File | Sort-Object Name | ForEach-Object {
        $_.Name + ':' + [BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($_.FullName)))
    }) -join ';'
    $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($all))) -replace '-', '').Substring(0, 16)

    $labels = docker image inspect --format '{{json .Config.Labels}}' $Image 2>$null
    $haveImage = ($LASTEXITCODE -eq 0)
    $builtHash = if ($haveImage -and $labels -and $labels -ne 'null') { ($labels | ConvertFrom-Json).'ouyadev.hash' } else { $null }
    if ($Rebuild -or -not $haveImage -or $builtHash -ne $hash) {
        if ($haveImage -and -not $Rebuild) { Write-Host "docker\ has changed - rebuilding Docker image $Image..." }
        else { Write-Host "Building Docker image $Image (first time takes a few minutes)..." }
        docker build --label "ouyadev.hash=$hash" -t $Image $dockerDir
        if ($LASTEXITCODE -ne 0) { throw 'docker build failed' }
    }

    New-Item -ItemType Directory -Force -Path $Out | Out-Null
    $Out = (Resolve-Path $Out).Path
    $Build = if ($Release) { 'release' } else { 'debug' }

    Write-Host "Game: $($g.Id)  ($($g.Dir))  package $($g.Package)"
    docker run --rm `
        -v "$($g.Dir):/project:ro" `
        -v "${Out}:/build" `
        @keyArgs `
        -e "BUILD=$Build" -e "APK_NAME=$($g.Id)" `
        $Image
    if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
} finally {
    Remove-Item Env:KEYSTORE_PASS, Env:KEYSTORE_ALIAS -ErrorAction SilentlyContinue
}
