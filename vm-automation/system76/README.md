# System76 Pop!_OS VM Automation

PowerShell script that automates the complete setup of a VirtualBox VM for System76 Pop!_OS installation on Windows.

## Quick Start

```powershell
# Basic usage
.\Setup-System76VM.ps1

# Custom configuration
.\Setup-System76VM.ps1 -VMName "MyPopOS" -Memory 8192 -DiskSize 40960

# Preview what will be done
.\Setup-System76VM.ps1 -DryRun
```

## Requirements

- Windows PowerShell 5.1 or later
- VirtualBox installed and `VBoxManage.exe` in PATH
- Internet connection for ISO download
- At least 6GB free disk space

## What It Does

1. **Validates Environment** - Checks VirtualBox installation
2. **Downloads ISO** - Gets latest Pop!_OS 22.04 LTS ISO (~3GB)
3. **Creates VM** - Configures optimal settings for Pop!_OS
4. **Enables EFI Boot** - Required for Pop!_OS installation
5. **Attaches Storage** - Creates 20GB virtual disk
6. **Mounts ISO** - Prepares for installation
7. **Starts VM** - Opens VirtualBox GUI for installation

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `VMName` | `System76-PopOS` | Virtual machine name |
| `Memory` | `4096` | RAM allocation in MB |
| `DiskSize` | `20480` | Virtual disk size in MB (20GB) |
| `ISOPath` | `Downloads\pop-os...iso` | ISO file location |
| `DryRun` | `false` | Preview mode only |

## Installation Steps

After running the script:

1. VM boots from Pop!_OS ISO automatically
2. Select "Install Pop!_OS" 
3. Choose language and keyboard layout
4. Create user account and set password
5. Select installation drive (the 20GB virtual disk)
6. Wait for installation to complete
7. Reboot and remove ISO when prompted

## Post-Installation

Install VirtualBox Guest Additions for better performance:
1. In VM menu: **Devices > Insert Guest Additions CD Image**
2. Run the installer in Pop!_OS
3. Reboot for full functionality

## Troubleshooting

**Script fails to find VirtualBox:**
- Install VirtualBox from https://www.virtualbox.org/
- Ensure `VBoxManage.exe` is in your PATH

**Low screen resolution:**
- Adjust display settings during installation
- Minimum recommended: 1024x768

**VM won't boot:**
- Ensure EFI is enabled (script does this automatically)
- Check BIOS virtualization settings on host machine

**Slow performance:**
- Increase memory allocation: `-Memory 8192`
- Install Guest Additions after Pop!_OS installation