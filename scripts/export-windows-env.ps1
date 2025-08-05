# Windows Development Environment Export Script
# This script exports your current development environment setup

$exportPath = "$env:USERPROFILE\Desktop\windows-dev-setup-export"
New-Item -ItemType Directory -Force -Path $exportPath | Out-Null

Write-Host "Exporting Windows Development Environment..." -ForegroundColor Green

# 1. Export installed applications via Windows Package Manager (winget)
Write-Host "`nExporting Winget packages..." -ForegroundColor Yellow
winget export -o "$exportPath\winget-packages.json" --accept-source-agreements

# 2. Export traditional installed programs
Write-Host "`nExporting installed programs..." -ForegroundColor Yellow
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
                 HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*,
                 HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
    Where-Object { $_.DisplayName -ne $null } |
    Sort-Object DisplayName |
    Export-Csv -Path "$exportPath\installed-programs.csv" -NoTypeInformation

# 3. Export Microsoft Store apps
Write-Host "`nExporting Microsoft Store apps..." -ForegroundColor Yellow
Get-AppxPackage | Select-Object Name, PackageFullName, Version |
    Export-Csv -Path "$exportPath\store-apps.csv" -NoTypeInformation

# 4. Export VS Code extensions (if installed)
if (Get-Command code -ErrorAction SilentlyContinue) {
    Write-Host "`nExporting VS Code extensions..." -ForegroundColor Yellow
    code --list-extensions | Out-File "$exportPath\vscode-extensions.txt"
}

# 5. Export Visual Studio extensions (if installed)
$vswhereExe = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhereExe) {
    Write-Host "`nExporting Visual Studio information..." -ForegroundColor Yellow
    & $vswhereExe -all -format json | Out-File "$exportPath\visual-studio-installations.json"
}

# 6. Export JetBrains Toolbox apps (if installed)
$jetbrainsPath = "$env:LOCALAPPDATA\JetBrains\Toolbox"
if (Test-Path $jetbrainsPath) {
    Write-Host "`nExporting JetBrains Toolbox apps..." -ForegroundColor Yellow
    Get-ChildItem -Path "$jetbrainsPath\apps" -Directory | 
        Select-Object Name | 
        Export-Csv -Path "$exportPath\jetbrains-apps.csv" -NoTypeInformation
}

# 7. Export environment variables
Write-Host "`nExporting environment variables..." -ForegroundColor Yellow
Get-ChildItem Env: | 
    Where-Object { $_.Name -notlike "PROCESSOR*" -and $_.Name -notlike "USERDOMAIN*" } |
    Select-Object Name, Value |
    Export-Csv -Path "$exportPath\environment-variables.csv" -NoTypeInformation

# 8. Export PATH entries
Write-Host "`nExporting PATH entries..." -ForegroundColor Yellow
$env:Path -split ';' | Where-Object { $_ -ne "" } | 
    Out-File "$exportPath\path-entries.txt"

# 9. Check for common development tools
Write-Host "`nChecking for development tools..." -ForegroundColor Yellow
$devTools = @{
    "Node.js" = { node --version }
    "npm" = { npm --version }
    "yarn" = { yarn --version }
    "pnpm" = { pnpm --version }
    "Python" = { python --version }
    "pip" = { pip --version }
    "Git" = { git --version }
    "Docker" = { docker --version }
    "dotnet" = { dotnet --version }
    "PowerShell Core" = { pwsh --version }
    "Rust" = { rustc --version }
    "Go" = { go version }
    "Java" = { java -version 2>&1 }
    "Maven" = { mvn --version }
    "Gradle" = { gradle --version }
}

$toolVersions = @{}
foreach ($tool in $devTools.GetEnumerator()) {
    try {
        $version = & $tool.Value 2>&1
        if ($LASTEXITCODE -eq 0) {
            $toolVersions[$tool.Key] = $version | Out-String
        }
    } catch {
        # Tool not installed
    }
}
$toolVersions | ConvertTo-Json | Out-File "$exportPath\dev-tools-versions.json"

# 10. Export installed SDKs
Write-Host "`nExporting .NET SDKs..." -ForegroundColor Yellow
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    dotnet --list-sdks | Out-File "$exportPath\dotnet-sdks.txt"
    dotnet --list-runtimes | Out-File "$exportPath\dotnet-runtimes.txt"
}

# 11. Export browser information (for extensions)
Write-Host "`nNote: Browser extensions need to be exported manually:" -ForegroundColor Yellow
Write-Host "  - Chrome: chrome://extensions/" -ForegroundColor Cyan
Write-Host "  - Firefox: about:addons" -ForegroundColor Cyan
Write-Host "  - Edge: edge://extensions/" -ForegroundColor Cyan

# Create summary
Write-Host "`nCreating summary..." -ForegroundColor Yellow
@"
Windows Development Environment Export Summary
Generated: $(Get-Date)

Files created:
- winget-packages.json: Package manager installed apps
- installed-programs.csv: All installed programs
- store-apps.csv: Microsoft Store apps
- vscode-extensions.txt: VS Code extensions (if applicable)
- visual-studio-installations.json: Visual Studio info (if applicable)
- jetbrains-apps.csv: JetBrains IDEs (if applicable)
- environment-variables.csv: System environment variables
- path-entries.txt: PATH variable entries
- dev-tools-versions.json: Development tools and versions
- dotnet-sdks.txt: .NET SDKs (if applicable)
- dotnet-runtimes.txt: .NET Runtimes (if applicable)

Next steps:
1. Review the exported files
2. Note any browser extensions you want to replicate
3. List any specific Rider plugins you use
4. Note any Windows-specific tools you rely on
"@ | Out-File "$exportPath\README.txt"

Write-Host "`n✅ Export complete! Files saved to: $exportPath" -ForegroundColor Green
Write-Host "Please review the files and let me know what you find!" -ForegroundColor Green

# Open the export folder
explorer.exe $exportPath