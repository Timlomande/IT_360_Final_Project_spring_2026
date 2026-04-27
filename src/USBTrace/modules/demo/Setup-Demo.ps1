#Requires -RunAsAdministrator
<#
.SYNOPSIS
    USBTrace Demo Setup
    Creates fake USB device artifacts so USBTrace flags them as suspicious.
    Run this BEFORE running USBTrace.ps1
#>

Write-Host ""
Write-Host "  USBTrace - Demo Setup" -ForegroundColor Cyan
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# Step 1: Register event source
Write-Host "  [1/3] Registering event log source..." -ForegroundColor Yellow
try {
    if ([System.Diagnostics.EventLog]::SourceExists("USBTrace-Demo")) {
        Write-Host "        Already registered." -ForegroundColor DarkGray
    } else {
        New-EventLog -LogName "System" -Source "USBTrace-Demo" -ErrorAction Stop
        Write-Host "        Source registered." -ForegroundColor Green
    }
} catch {
    Write-Host "        Error: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Write 8 connect/disconnect pairs using event IDs 2003 and 2101
# USBTrace queries System log for these IDs so they will be picked up
Write-Host "  [2/3] Writing 8 fake USB session events..." -ForegroundColor Yellow
$msg = "USB device activity: USBSTOR\Disk&Ven_SanDisk&Prod_Ultra\AA01234567890&0"
$written = 0
for ($i = 0; $i -lt 8; $i++) {
    try {
        Write-EventLog -LogName "System" -Source "USBTrace-Demo" -EventId 2003 -EntryType Information -Message $msg -ErrorAction Stop
        Start-Sleep -Milliseconds 300
        Write-EventLog -LogName "System" -Source "USBTrace-Demo" -EventId 2101 -EntryType Information -Message $msg -ErrorAction Stop
        $written++
    } catch {
        Write-Host "        Pair $($i+1) failed: $_" -ForegroundColor DarkYellow
    }
}
Write-Host "        Wrote $written session pairs (Event IDs 2003 and 2101)." -ForegroundColor Green

# Step 3: Create fake USBSTOR registry device
Write-Host "  [3/3] Creating fake registry device entry..." -ForegroundColor Yellow
try {
    $instPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\Disk&Ven_SanDisk&Prod_Ultra&Rev_1.00\AA01234567890&0"
    New-Item -Path $instPath -Force -ErrorAction Stop | Out-Null
    New-ItemProperty -Path $instPath -Name "FriendlyName" -PropertyType String       -Value "SanDisk Ultra USB Device"  -Force | Out-Null
    New-ItemProperty -Path $instPath -Name "Mfg"          -PropertyType String       -Value "SanDisk"                   -Force | Out-Null
    New-ItemProperty -Path $instPath -Name "Service"      -PropertyType String       -Value "USBSTOR"                   -Force | Out-Null
    New-ItemProperty -Path $instPath -Name "HardwareID"   -PropertyType MultiString  -Value @("USBSTOR\DiskSanDisk_Ultra___1.00","USBSTOR\DiskSanDisk_Ultra__") -Force | Out-Null
    New-ItemProperty -Path $instPath -Name "ContainerID"  -PropertyType String       -Value "{a1b2c3d4-e5f6-7890-abcd-ef1234567890}" -Force | Out-Null
    Write-Host "        SanDisk Ultra USB Device entry created in USBSTOR." -ForegroundColor Green
} catch {
    Write-Host "        Registry error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host "  Setup complete. Expected flags:" -ForegroundColor Green
Write-Host "    HIGH_FREQUENCY  - 8 connections logged" -ForegroundColor White
Write-Host "    SHORT_SESSIONS  - all sessions under 2 minutes" -ForegroundColor White
Write-Host ""
Write-Host "  Run USBTrace now:" -ForegroundColor Cyan
Write-Host "    powershell -ExecutionPolicy Bypass -File .\USBTrace.ps1" -ForegroundColor White
Write-Host ""
