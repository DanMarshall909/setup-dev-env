# VM Installation Test Script for Windows
# Supports VirtualBox, VMware, and Hyper-V

param(
    [Parameter(Position=0)]
    [string]$VMName = "pop-os-test",
    
    [Parameter(Position=1)]
    [string]$SnapshotName = "clean-install",
    
    [Parameter(Position=2)]
    [ValidateSet("VirtualBox", "VMware", "HyperV")]
    [string]$VMType = "VirtualBox",
    
    [Parameter(Position=3)]
    [string]$VMUser = "dan",
    
    [Parameter(Position=4)]
    [string]$VMHost = "localhost",
    
    [Parameter(Position=5)]
    [int]$SSHPort = 2222,
    
    [Parameter()]
    [ValidateSet("oneliner", "clone", "local")]
    [string]$InstallMethod = "oneliner",
    
    [Parameter()]
    [string]$LocalPath = $PWD.Path,
    
    [Parameter()]
    [switch]$DryRun,
    
    [Parameter()]
    [switch]$Help
)

# Show help
if ($Help) {
    @"
VM Installation Test Script

Usage: .\Test-VMInstall.ps1 [options]

Parameters:
    -VMName         VM name (default: pop-os-test)
    -SnapshotName   Snapshot name (default: clean-install)
    -VMType         VM type: VirtualBox, VMware, HyperV (default: VirtualBox)
    -VMUser         VM username (default: dan)
    -VMHost         VM hostname or IP (default: localhost)
    -SSHPort        SSH port (default: 2222)
    -InstallMethod  Install method: oneliner, clone, local (default: oneliner)
    -LocalPath      Local path for sync (default: current directory)
    -DryRun         Show what would be done without executing
    -Help           Show this help message

Examples:
    # Test with VirtualBox VM
    .\Test-VMInstall.ps1 -VMName ubuntu-test -SnapshotName fresh-install

    # Test with local code sync
    .\Test-VMInstall.ps1 -InstallMethod local -LocalPath C:\code\setup-dev-env

    # Test with Hyper-V
    .\Test-VMInstall.ps1 -VMType HyperV -VMName pop-os-vm
"@
    exit 0
}

# Colors and logging
$script:LogFile = "vm-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param($Message, $Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    Add-Content -Path $script:LogFile -Value $logMessage
}

function Write-Success { Write-Log $args[0] "Green" }
function Write-Info { Write-Log $args[0] "Cyan" }
function Write-Warning { Write-Log $args[0] "Yellow" }
function Write-Error { Write-Log $args[0] "Red" }

# VM Control Functions
function Restore-VirtualBoxVM {
    Write-Info "Rolling back VirtualBox VM '$VMName' to snapshot '$SnapshotName'..."
    
    # Power off VM if running
    & VBoxManage controlvm $VMName poweroff 2>$null
    Start-Sleep -Seconds 2
    
    # Restore snapshot
    & VBoxManage snapshot $VMName restore $SnapshotName
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to restore snapshot"
    }
    
    Write-Info "Starting VM..."
    & VBoxManage startvm $VMName --type headless
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start VM"
    }
    
    Write-Info "Waiting for VM to boot..."
    Start-Sleep -Seconds 30
}

function Restore-VMwareVM {
    Write-Info "Rolling back VMware VM '$VMName' to snapshot '$SnapshotName'..."
    
    # Find vmrun.exe
    $vmrun = "${env:ProgramFiles(x86)}\VMware\VMware Workstation\vmrun.exe"
    if (-not (Test-Path $vmrun)) {
        $vmrun = "${env:ProgramFiles}\VMware\VMware Workstation\vmrun.exe"
    }
    
    & $vmrun -T ws revertToSnapshot $VMName $SnapshotName
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to restore snapshot"
    }
    
    Write-Info "Starting VM..."
    & $vmrun -T ws start $VMName nogui
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start VM"
    }
    
    Write-Info "Waiting for VM to boot..."
    Start-Sleep -Seconds 30
}

function Restore-HyperVVM {
    Write-Info "Rolling back Hyper-V VM '$VMName' to snapshot '$SnapshotName'..."
    
    # Requires running as Administrator
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "Hyper-V operations require Administrator privileges"
    }
    
    # Stop VM if running
    Stop-VM -Name $VMName -Force -ErrorAction SilentlyContinue
    
    # Restore snapshot
    Restore-VMSnapshot -Name $SnapshotName -VMName $VMName -Confirm:$false
    
    Write-Info "Starting VM..."
    Start-VM -Name $VMName
    
    Write-Info "Waiting for VM to boot..."
    Start-Sleep -Seconds 30
}

# Wait for SSH
function Wait-ForSSH {
    Write-Info "Waiting for SSH to be available..."
    $maxAttempts = 30
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            # Test SSH connection
            $result = ssh -q -o ConnectTimeout=5 -o StrictHostKeyChecking=no `
                          -p $SSHPort "$VMUser@$VMHost" "exit" 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "SSH connection established"
                return $true
            }
        }
        catch {
            # Connection failed, continue waiting
        }
        
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 5
        $attempt++
    }
    
    Write-Host ""
    Write-Error "SSH connection timeout after $maxAttempts attempts"
    return $false
}

# Installation methods
function Invoke-OnelineInstall {
    Write-Info "Running one-liner installation..."
    
    $installCommand = @'
curl -sSL https://raw.githubusercontent.com/danmarshall909/setup-dev-env/master/install.sh | bash
'@
    
    ssh -p $SSHPort "$VMUser@$VMHost" $installCommand
}

function Invoke-CloneInstall {
    Write-Info "Running clone-based installation..."
    
    $installCommand = @'
git clone https://github.com/danmarshall909/setup-dev-env.git
cd setup-dev-env
./setup.sh all
'@
    
    ssh -p $SSHPort "$VMUser@$VMHost" $installCommand
}

function Invoke-LocalInstall {
    Write-Info "Syncing local code to VM..."
    
    # Create directory on VM
    ssh -p $SSHPort "$VMUser@$VMHost" "mkdir -p ~/setup-dev-env"
    
    # Sync files using scp (excluding .git and logs)
    # Note: This is simplified - for full rsync functionality, use WSL or install rsync on Windows
    Write-Warning "Using scp for file transfer (rsync not available on Windows)"
    
    # Copy all files except .git
    Get-ChildItem -Path $LocalPath -Recurse -File | 
        Where-Object { $_.FullName -notmatch '\.git|logs|\.log$' } |
        ForEach-Object {
            $relativePath = $_.FullName.Substring($LocalPath.Length + 1).Replace('\', '/')
            $remoteDir = Split-Path -Parent $relativePath
            
            if ($remoteDir) {
                ssh -p $SSHPort "$VMUser@$VMHost" "mkdir -p ~/setup-dev-env/$remoteDir" 2>$null
            }
            
            scp -P $SSHPort $_.FullName "${VMUser}@${VMHost}:~/setup-dev-env/$relativePath" 2>$null
        }
    
    Write-Info "Running local installation..."
    ssh -p $SSHPort "$VMUser@$VMHost" "cd ~/setup-dev-env && ./setup.sh all"
}

# Collect logs
function Get-VMLogs {
    Write-Info "Collecting installation logs from VM..."
    
    $logDir = "vm-logs-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    
    # Copy logs
    scp -P $SSHPort -r "${VMUser}@${VMHost}:~/.local/share/setup-dev-env/logs/*" "$logDir/" 2>$null
    
    Write-Success "Logs collected in: $logDir"
    
    # Show summary if available
    $summaryFile = Join-Path $logDir "latest-summary.log"
    if (Test-Path $summaryFile) {
        Write-Host ""
        Write-Host "=== Installation Summary ===" -ForegroundColor Cyan
        Get-Content $summaryFile
    }
    
    return $logDir
}

# Main execution
function Main {
    Write-Host "VM Installation Test Script" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Info "VM: $VMName ($VMType)"
    Write-Info "Snapshot: $SnapshotName"
    Write-Info "Method: $InstallMethod"
    Write-Info "Target: $VMUser@$VMHost:$SSHPort"
    Write-Host ""
    
    if ($DryRun) {
        Write-Warning "DRY RUN MODE - showing what would be done:"
        Write-Host "1. Rollback $VMType VM '$VMName' to snapshot '$SnapshotName'"
        Write-Host "2. Start VM and wait for SSH"
        Write-Host "3. Run $InstallMethod installation"
        Write-Host "4. Collect logs"
        return
    }
    
    try {
        # Rollback VM
        switch ($VMType) {
            "VirtualBox" { Restore-VirtualBoxVM }
            "VMware" { Restore-VMwareVM }
            "HyperV" { Restore-HyperVVM }
            default { throw "Unknown VM type: $VMType" }
        }
        
        # Wait for SSH
        if (-not (Wait-ForSSH)) {
            throw "Failed to establish SSH connection"
        }
        
        # Run installation
        switch ($InstallMethod) {
            "oneliner" { Invoke-OnelineInstall }
            "clone" { Invoke-CloneInstall }
            "local" { Invoke-LocalInstall }
            default { throw "Unknown install method: $InstallMethod" }
        }
        
        # Wait for installation to complete
        Write-Info "Waiting for installation to complete..."
        Start-Sleep -Seconds 10
        
        # Collect logs
        $logDir = Get-VMLogs
        
        Write-Success "Test completed successfully!"
        Write-Host ""
        Write-Host "Logs saved in: $logDir" -ForegroundColor Green
        Write-Host "Full log: $script:LogFile" -ForegroundColor Green
        
    }
    catch {
        Write-Error "Test failed: $_"
        exit 1
    }
}

# Run main function
Main