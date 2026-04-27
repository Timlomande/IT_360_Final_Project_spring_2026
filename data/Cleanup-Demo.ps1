#Requires -RunAsAdministrator
<#
.SYNOPSIS
    USBTrace Demo Cleanup
    Removes all fake artifacts created by Setup-Demo.ps1
    Run this AFTER your demo is complete.
#>

Write-Host ""
Write-Host "  USBTrace - Demo Cleanup" -ForegroundColor Cyan
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

Write-Host "  [1/2] Removing fake registry entry..." -ForegroundColor Yellow
try {
    $classPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\Disk&Ven_SanDisk&Prod_Ultra&Rev_1.00"
    if (Test-Path $classPath) {
        Remove-Item -Path $classPath -Recurse -Force -ErrorAction Stop
        Write-Host "        Removed." -ForegroundColor Green
    } else {
        Write-Host "        Not found, skipping." -ForegroundColor DarkGray
    }
} catch {
    Write-Host "        Error: $_" -ForegroundColor Red
}

Write-Host "  [2/2] Removing fake event log source..." -ForegroundColor Yellow
try {
    if ([System.Diagnostics.EventLog]::SourceExists("USBTrace-Demo")) {
        Remove-EventLog -Source "USBTrace-Demo" -ErrorAction Stop
        Write-Host "        Removed." -ForegroundColor Green
    } else {
        Write-Host "        Not found, skipping." -ForegroundColor DarkGray
    }
} catch {
    Write-Host "        Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host "  Cleanup complete. All demo artifacts removed." -ForegroundColor Green
Write-Host ""
