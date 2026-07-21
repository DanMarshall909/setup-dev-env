#Requires -Version 5.1
<#
.SYNOPSIS
    Windows equivalent of setup.sh - installs the same dev-environment tools via winget + npm.

.DESCRIPTION
    Reproduces, end to end, the install performed for this repo's Linux modules, mapped to
    Windows package IDs. Reads all configurable values from configs/windows-setup.json so you
    can tweak the package list / git identity without touching the script.

    Steps:
      1. Verify winget is available
      2. Configure Git (name, email, defaultBranch, pull.rebase, autocrlf)
      3. Install CLI dev-tools (ripgrep, fd, bat, fzf, yq, jq, duf, HTTPie, tldr, gdu, 7-Zip, Vim,
         Git, GitHub CLI, VS Code)
      4. Install Node.js LTS + global npm packages (typescript, ts-node, nodemon, prettier, eslint, @types/node)
      5. Install the .NET SDK
      6. Install heavy IDE/platform packages (Docker Desktop, JetBrains Rider, Visual Studio Enterprise)
      7. (optional) winget upgrade --all + npm update -g

    The script is idempotent: winget skips packages already at the latest version, and re-running
    is safe. Some installers request elevation (UAC) - approve the prompts when they appear.

.PARAMETER SkipHeavy
    Skip Docker Desktop, JetBrains Rider and Visual Studio Enterprise (the large, slow installs).

.PARAMETER SkipNode
    Skip Node.js and the global npm packages.

.PARAMETER Upgrade
    After installing, run 'winget upgrade --all' and 'npm update -g' to bring everything to latest.

.PARAMETER ConfigPath
    Path to the JSON config. Defaults to configs/windows-setup.json next to this script.

.EXAMPLE
    ./setup-windows.ps1
    Full install using the bundled config.

.EXAMPLE
    ./setup-windows.ps1 -SkipHeavy -Upgrade
    Install the lightweight tooling only, then upgrade everything to latest.
#>
[CmdletBinding()]
param(
    [switch]$SkipHeavy,
    [switch]$SkipNode,
    [switch]$Upgrade,
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'configs\windows-setup.json')
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
function Write-Info    { param($m) Write-Host "[INFO]  $m"    -ForegroundColor Cyan }
function Write-Ok      { param($m) Write-Host "[OK]    $m"    -ForegroundColor Green }
function Write-Warn    { param($m) Write-Host "[WARN]  $m"    -ForegroundColor Yellow }
function Write-Err     { param($m) Write-Host "[ERROR] $m"    -ForegroundColor Red }
function Write-Section { param($m) Write-Host "`n=== $m ===" -ForegroundColor Magenta }

# Re-read PATH from the machine + user scopes so tools installed earlier in this run resolve
# without opening a new shell.
function Update-SessionPath {
    $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $npm     = Join-Path $env:APPDATA 'npm'
    $env:Path = (@($machine, $user, $npm) | Where-Object { $_ }) -join ';'
}

# Install a single winget package. Returns $true on success (installed or already present).
function Install-WingetPackage {
    param([string]$Id, [string]$Name)
    $label = if ($Name) { "$Name ($Id)" } else { $Id }
    Write-Info "Installing $label"
    winget install --exact --id $Id --source winget `
        --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
    $code = $LASTEXITCODE
    # 0 = installed; -1978335189 (0x8A15002B) = no applicable upgrade / already installed
    if ($code -eq 0 -or $code -eq -1978335189) {
        Write-Ok "$label"
        return $true
    }
    Write-Warn "$label - winget exit code $code"
    return $false
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
Write-Section 'Preflight'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Err "winget (App Installer) not found. Install it from the Microsoft Store, then re-run."
    exit 1
}
Write-Ok "winget $(winget --version)"

if (-not (Test-Path $ConfigPath)) {
    Write-Err "Config file not found: $ConfigPath"
    exit 1
}
$cfg = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
Write-Ok "Loaded config: $ConfigPath"

$failures = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------------------
# 1. Git configuration
# ---------------------------------------------------------------------------
Write-Section 'Configuring Git'
if (Get-Command git -ErrorAction SilentlyContinue) {
    git config --global user.name         $cfg.git.user.name
    git config --global user.email        $cfg.git.user.email
    git config --global init.defaultBranch $cfg.git.init.defaultBranch
    git config --global pull.rebase       ($cfg.git.pull.rebase.ToString().ToLower())
    git config --global core.autocrlf     ($cfg.git.core.autocrlf.ToString().ToLower())
    Write-Ok "git configured for $($cfg.git.user.name) <$($cfg.git.user.email)>"
} else {
    Write-Warn "git not on PATH yet; it is in the CLI tools list and will be configured on the next run."
}

# ---------------------------------------------------------------------------
# 2. CLI dev-tools
# ---------------------------------------------------------------------------
Write-Section 'Installing CLI dev-tools'
foreach ($tool in $cfg.cliTools) {
    if (-not (Install-WingetPackage -Id $tool.id -Name $tool.name)) { $failures.Add($tool.id) }
}

# ---------------------------------------------------------------------------
# 3. Node.js + global npm packages
# ---------------------------------------------------------------------------
if (-not $SkipNode) {
    Write-Section 'Installing Node.js + npm globals'
    if (-not (Install-WingetPackage -Id $cfg.node.id -Name 'Node.js LTS')) { $failures.Add($cfg.node.id) }

    Update-SessionPath
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $pkgs = @($cfg.node.globalPackages)
        Write-Info "npm install -g $($pkgs -join ' ')"
        npm install -g @pkgs
        if ($LASTEXITCODE -eq 0) { Write-Ok "Global npm packages installed" }
        else { Write-Warn "npm global install exit code $LASTEXITCODE"; $failures.Add('npm-globals') }
    } else {
        Write-Warn "npm not resolvable in this session; open a new terminal and re-run to install globals."
        $failures.Add('npm-globals')
    }
} else {
    Write-Info "Skipping Node.js (-SkipNode)"
}

# ---------------------------------------------------------------------------
# 4. .NET SDK
# ---------------------------------------------------------------------------
Write-Section 'Installing .NET SDK'
if (-not (Install-WingetPackage -Id $cfg.dotnet.id -Name $cfg.dotnet.name)) { $failures.Add($cfg.dotnet.id) }

# ---------------------------------------------------------------------------
# 5. Heavy IDE / platform installs
# ---------------------------------------------------------------------------
if (-not $SkipHeavy) {
    Write-Section 'Installing IDEs / platforms (large downloads)'
    foreach ($h in $cfg.heavy) {
        if (-not (Install-WingetPackage -Id $h.id -Name $h.name)) { $failures.Add($h.id) }
        if ($h.note) { Write-Info $h.note }
    }
} else {
    Write-Info "Skipping Docker/Rider/Visual Studio (-SkipHeavy)"
}

# ---------------------------------------------------------------------------
# 6. Optional upgrade pass
# ---------------------------------------------------------------------------
if ($Upgrade) {
    Write-Section 'Upgrading everything to latest'
    winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --disable-interactivity
    if (-not $SkipNode) {
        Update-SessionPath
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            npm install -g npm@latest
            npm update -g
            Write-Ok "npm + global packages updated"
        }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Section 'Summary'
if ($failures.Count -eq 0) {
    Write-Ok "All requested installs completed."
} else {
    Write-Warn "Completed with issues on: $($failures -join ', ')"
}

Write-Host ""
Write-Info "Notes:"
Write-Host "  - Open a NEW terminal so freshly-installed tools appear on PATH."
Write-Host "  - HTTPie.HTTPie is the desktop GUI app; for the 'http' CLI run: pip install httpie (needs Python)."
Write-Host "  - Docker Desktop may require a reboot (WSL2/virtualization) before 'docker' works."
Write-Host "  - JetBrains Rider and Visual Studio need a sign-in/license on first launch."
