#Requires -Version 5.1
<#
.SYNOPSIS
    Automates System76 Pop!_OS VM creation in VirtualBox on Windows

.DESCRIPTION
    This PowerShell script automates the complete setup of a VirtualBox VM for System76 Pop!_OS installation,
    including downloading the ISO, creating the VM, configuring settings, and starting the installation.

.PARAMETER VMName
    Name for the virtual machine (default: "System76-PopOS")

.PARAMETER Memory
    Memory allocation in MB (default: 4096)

.PARAMETER DiskSize
    Virtual disk size in MB (default: 20480 - 20GB)

.PARAMETER ISOPath
    Custom path for the ISO file (default: Downloads folder)

.PARAMETER DryRun
    Show what would be done without executing

.EXAMPLE
    .\Setup-System76VM.ps1

.EXAMPLE
    .\Setup-System76VM.ps1 -VMName "MyPopOS" -Memory 8192 -DiskSize 40960

.EXAMPLE
    .\Setup-System76VM.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [string]$VMName = "System76-PopOS",
    [int]$Memory = 4096,
    [int]$DiskSize = 20480,
    [string]$ISOPath = "$env:USERPROFILE\Downloads\pop-os_22.04_amd64_intel_40.iso",
    [switch]$DryRun
)

# Configuration
$VMType = "Linux"
$VMVersion = "Ubuntu_64"
$ISOUrl = "https://iso.pop-os.org/22.04/amd64/intel/40/pop-os_22.04_amd64_intel_40.iso"
$VBoxManagePath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

# Initialize error handling
$ErrorActionPreference = "Stop"

function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    switch ($Type) {
        "Info" { Write-Host "[INFO] $Message" -ForegroundColor Green }
        "Warn" { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
        "Error" { Write-Host "[ERROR] $Message" -ForegroundColor Red }
        "Success" { Write-Host "[SUCCESS] $Message" -ForegroundColor Cyan }
    }
}

function Test-VirtualBox {
    Write-ColoredOutput "Checking VirtualBox installation..." "Info"
    
    if (!(Test-Path $VBoxManagePath)) {
        Write-ColoredOutput "VirtualBox not found at: $VBoxManagePath" "Error"
        Write-ColoredOutput "Please install VirtualBox from https://www.virtualbox.org/wiki/Downloads" "Error"
        return $false
    }
    
    try {
        $vboxVersion = & $VBoxManagePath --version 2>$null
        Write-ColoredOutput "VirtualBox found: $vboxVersion" "Success"
        return $true
    }
    catch {
        Write-ColoredOutput "Failed to run VBoxManage: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Get-PopOSISO {
    param([string]$Path)
    
    if (Test-Path $Path) {
        Write-ColoredOutput "ISO file already exists: $Path" "Info"
        return $true
    }
    
    Write-ColoredOutput "Downloading Pop!_OS ISO..." "Info"
    
    # Ensure download directory exists
    $downloadDir = Split-Path $Path -Parent
    if (!(Test-Path $downloadDir)) {
        New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    }
    
    try {
        # Use Invoke-WebRequest with progress
        $ProgressPreference = 'Continue'
        Invoke-WebRequest -Uri $ISOUrl -OutFile $Path -UseBasicParsing
        Write-ColoredOutput "ISO downloaded successfully" "Success"
        return $true
    }
    catch {
        Write-ColoredOutput "Failed to download ISO: $($_.Exception.Message)" "Error"
        return $false
    }
}

function New-System76VM {
    param(
        [string]$Name,
        [int]$MemoryMB,
        [int]$DiskSizeMB
    )
    
    Write-ColoredOutput "Creating VM: $Name" "Info"
    
    try {
        # Check if VM already exists
        $existingVMs = & $VBoxManagePath list vms 2>$null
        if ($existingVMs -match "`"$Name`"") {
            Write-ColoredOutput "VM '$Name' already exists. Removing it first..." "Warn"
            & $VBoxManagePath unregistervm $Name --delete 2>$null
        }
        
        # Create VM
        & $VBoxManagePath createvm --name $Name --ostype $VMVersion --register
        Write-ColoredOutput "VM created successfully" "Success"
        
        # Configure memory
        & $VBoxManagePath modifyvm $Name --memory $MemoryMB
        Write-ColoredOutput "Memory configured: $MemoryMB MB" "Info"
        
        # Enable EFI (critical for Pop!_OS)
        & $VBoxManagePath modifyvm $Name --firmware efi
        Write-ColoredOutput "EFI boot enabled" "Info"
        
        # Configure graphics and performance
        & $VBoxManagePath modifyvm $Name --vram 128
        & $VBoxManagePath modifyvm $Name --graphicscontroller vmsvga
        & $VBoxManagePath modifyvm $Name --accelerate3d on
        & $VBoxManagePath modifyvm $Name --boot1 dvd --boot2 disk --boot3 none --boot4 none
        
        # Network configuration
        & $VBoxManagePath modifyvm $Name --nic1 nat
        
        # Audio configuration
        & $VBoxManagePath modifyvm $Name --audio dsound --audiocontroller ac97
        
        Write-ColoredOutput "VM configuration completed" "Success"
        return $true
    }
    catch {
        Write-ColoredOutput "Failed to create VM: $($_.Exception.Message)" "Error"
        return $false
    }
}

function New-VirtualDisk {
    param(
        [string]$VMName,
        [int]$SizeMB
    )
    
    Write-ColoredOutput "Creating virtual hard disk ($SizeMB MB)" "Info"
    
    try {
        # Get VM folder path
        $vmFolder = "$env:USERPROFILE\VirtualBox VMs\$VMName"
        $diskPath = "$vmFolder\$VMName.vdi"
        
        # Create storage controller
        & $VBoxManagePath storagectl $VMName --name "SATA Controller" --add sata --controller IntelAhci
        
        # Create virtual hard disk
        & $VBoxManagePath createhd --filename $diskPath --size $SizeMB --format VDI
        
        # Attach hard disk to VM
        & $VBoxManagePath storageattach $VMName --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $diskPath
        
        Write-ColoredOutput "Virtual hard disk created and attached" "Success"
        return $true
    }
    catch {
        Write-ColoredOutput "Failed to create virtual disk: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Mount-ISO {
    param(
        [string]$VMName,
        [string]$ISOPath
    )
    
    Write-ColoredOutput "Attaching Pop!_OS ISO to VM" "Info"
    
    try {
        # Create IDE controller for DVD
        & $VBoxManagePath storagectl $VMName --name "IDE Controller" --add ide 2>$null
        
        # Attach ISO
        & $VBoxManagePath storageattach $VMName --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium $ISOPath
        
        Write-ColoredOutput "ISO attached successfully" "Success"
        return $true
    }
    catch {
        Write-ColoredOutput "Failed to attach ISO: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Start-System76VM {
    param([string]$VMName)
    
    Write-ColoredOutput "Starting VM: $VMName" "Info"
    
    try {
        & $VBoxManagePath startvm $VMName --type gui
        
        Write-ColoredOutput "VM started successfully!" "Success"
        Write-Host ""
        Write-ColoredOutput "Next steps:" "Info"
        Write-Host "1. The VM should boot from the Pop!_OS ISO"
        Write-Host "2. Follow the installation wizard"
        Write-Host "3. Adjust display resolution to at least 1024x768 if needed"
        Write-Host "4. Complete the Pop!_OS installation"
        Write-Host "5. After installation, install VirtualBox Guest Additions for better performance"
        Write-Host "   - In VM menu: Devices > Insert Guest Additions CD Image"
        
        return $true
    }
    catch {
        Write-ColoredOutput "Failed to start VM: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Show-DryRun {
    Write-ColoredOutput "DRY RUN MODE - Showing what would be executed:" "Warn"
    Write-Host ""
    Write-Host "1. Check VirtualBox installation"
    Write-Host "2. Download Pop!_OS ISO to: $ISOPath"
    Write-Host "3. Create VM: $VMName"
    Write-Host "   - Memory: $Memory MB"
    Write-Host "   - Disk: $DiskSize MB"
    Write-Host "   - OS Type: $VMVersion"
    Write-Host "4. Configure EFI boot mode (required for Pop!_OS)"
    Write-Host "5. Configure graphics and performance settings"
    Write-Host "6. Create and attach virtual hard disk"
    Write-Host "7. Attach Pop!_OS ISO"
    Write-Host "8. Start VM for installation"
}

# Main execution
function Main {
    Write-ColoredOutput "Starting System76 Pop!_OS VM Setup Automation" "Info"
    Write-Host "VM Name: $VMName | Memory: $Memory MB | Disk: $DiskSize MB" -ForegroundColor Cyan
    Write-Host ""
    
    if ($DryRun) {
        Show-DryRun
        return
    }
    
    # Step 1: Check VirtualBox
    if (!(Test-VirtualBox)) {
        return
    }
    
    # Step 2: Download ISO
    if (!(Get-PopOSISO -Path $ISOPath)) {
        return
    }
    
    # Step 3: Create VM
    if (!(New-System76VM -Name $VMName -MemoryMB $Memory -DiskSizeMB $DiskSize)) {
        return
    }
    
    # Step 4: Create virtual disk
    if (!(New-VirtualDisk -VMName $VMName -SizeMB $DiskSize)) {
        return
    }
    
    # Step 5: Attach ISO
    if (!(Mount-ISO -VMName $VMName -ISOPath $ISOPath)) {
        return
    }
    
    # Step 6: Start VM
    if (!(Start-System76VM -VMName $VMName)) {
        return
    }
    
    Write-Host ""
    Write-ColoredOutput "Setup completed successfully!" "Success"
}

# Execute main function
try {
    Main
}
catch {
    Write-ColoredOutput "Script execution failed: $($_.Exception.Message)" "Error"
    exit 1
}