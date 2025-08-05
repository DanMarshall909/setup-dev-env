# Quick VM Test Script for Windows
# Simple version for VirtualBox VMs

param(
    [string]$VMName = "pop-os",
    [string]$Snapshot = "clean",
    [string]$VMHost = "localhost",
    [int]$Port = 2222,
    [string]$User = "dan"
)

Write-Host "=== VM Installation Test Script ===" -ForegroundColor Cyan
Write-Host "VM: $VMName" -ForegroundColor White
Write-Host "Snapshot: $Snapshot" -ForegroundColor White
Write-Host "Target: $User@${VMHost}:$Port" -ForegroundColor White
Write-Host ""

# Step 1: Rollback VM
Write-Host "Step 1: Rolling back VM to snapshot..." -ForegroundColor Yellow
& VBoxManage controlvm $VMName poweroff 2>$null
Start-Sleep -Seconds 2
& VBoxManage snapshot $VMName restore $Snapshot
Write-Host "✓ Snapshot restored" -ForegroundColor Green

# Step 2: Start VM
Write-Host "Step 2: Starting VM..." -ForegroundColor Yellow
& VBoxManage startvm $VMName --type headless
Write-Host "✓ VM started" -ForegroundColor Green

# Step 3: Wait for boot
Write-Host "Step 3: Waiting for VM to boot (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Wait for SSH
Write-Host -NoNewline "Waiting for SSH..."
$attempts = 0
while ($attempts -lt 30) {
    $testConnection = ssh -q -o ConnectTimeout=2 -o StrictHostKeyChecking=no -p $Port "$User@$VMHost" "exit" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " Ready!" -ForegroundColor Green
        break
    }
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 5
    $attempts++
}

if ($attempts -eq 30) {
    Write-Host " Timeout!" -ForegroundColor Red
    exit 1
}

# Step 4: Run installation
Write-Host "Step 4: Running installation..." -ForegroundColor Yellow
ssh -p $Port "$User@$VMHost" 'curl -sSL https://raw.githubusercontent.com/danmarshall909/setup-dev-env/master/install.sh | bash'

# Step 5: Collect logs
Write-Host "Step 5: Collecting logs..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "vm-logs" -Force | Out-Null
scp -P $Port -r "$User@${VMHost}:~/.local/share/setup-dev-env/logs/*" "vm-logs/" 2>$null

Write-Host "✅ Test completed!" -ForegroundColor Green
Write-Host "Logs saved in: vm-logs\" -ForegroundColor Cyan

# Show summary if available
if (Test-Path "vm-logs\latest-summary.log") {
    Write-Host ""
    Write-Host "=== Installation Summary ===" -ForegroundColor Cyan
    Get-Content "vm-logs\latest-summary.log"
}