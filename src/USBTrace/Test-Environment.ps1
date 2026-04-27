<#
.SYNOPSIS
    Quick pre-flight check. Run this before USBTrace.ps1 to verify your environment.
    No admin rights required for this script.
#>

param([string]$ApiKey = "")

Write-Host ""
Write-Host "  USBTrace - Pre-Flight Check" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$allGood = $true

# Check 1: Admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "  [PASS] Running as Administrator" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Not running as Administrator - some event logs may be inaccessible" -ForegroundColor Yellow
    $allGood = $false
}

# Check 2: PowerShell version
$psVer = $PSVersionTable.PSVersion.Major
if ($psVer -ge 5) {
    Write-Host "  [PASS] PowerShell version $($PSVersionTable.PSVersion)" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] PowerShell 5+ required (found $($PSVersionTable.PSVersion))" -ForegroundColor Red
    $allGood = $false
}

# Check 3: USBSTOR registry access
try {
    $null = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR" -ErrorAction Stop
    Write-Host "  [PASS] USBSTOR registry readable" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] USBSTOR registry not accessible: $_" -ForegroundColor Red
    $allGood = $false
}

# Check 4: DriverFrameworks event log
try {
    $evt = Get-WinEvent -LogName "Microsoft-Windows-DriverFrameworks-UserMode/Operational" -MaxEvents 1 -ErrorAction Stop
    Write-Host "  [PASS] DriverFrameworks event log accessible" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -match "not found|does not exist") {
        Write-Host "  [INFO] DriverFrameworks log not enabled (expected on many systems)" -ForegroundColor DarkYellow
        Write-Host "         Enable with: wevtutil sl Microsoft-Windows-DriverFrameworks-UserMode/Operational /e:true" -ForegroundColor DarkGray
    } else {
        Write-Host "  [WARN] DriverFrameworks log access issue: $_" -ForegroundColor Yellow
    }
}

# Check 5: SetupAPI log
$setupFound = $false
foreach ($p in @("$env:WINDIR\INF\setupapi.dev.log", "$env:WINDIR\setupapi.dev.log")) {
    if (Test-Path $p) {
        Write-Host "  [PASS] SetupAPI log found: $p" -ForegroundColor Green
        $setupFound = $true
        break
    }
}
if (-not $setupFound) {
    Write-Host "  [INFO] SetupAPI log not found (tool will run without it)" -ForegroundColor DarkYellow
}

# Check 6: Modules present
$modules = @("Get-USBArtifacts.ps1","Build-Timeline.ps1","Invoke-AIAnalysis.ps1","Export-HTMLReport.ps1")
$allModules = $true
foreach ($m in $modules) {
    $mPath = Join-Path $PSScriptRoot "Modules\$m"
    if (Test-Path $mPath) {
        Write-Host "  [PASS] Module: $m" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Missing module: $m" -ForegroundColor Red
        $allModules = $false
        $allGood = $false
    }
}

# Check 7: API key (if provided)
if ($ApiKey) {
    try {
        $body = @{
            model      = "claude-haiku-4-5-20251001"
            max_tokens = 10
            messages   = @(@{ role = "user"; content = "ping" })
        } | ConvertTo-Json -Depth 5

        $resp = Invoke-RestMethod `
            -Uri "https://api.anthropic.com/v1/messages" `
            -Method POST `
            -Headers @{
                "x-api-key" = $ApiKey
                "anthropic-version" = "2023-06-01"
                "content-type" = "application/json"
            } `
            -Body $body -ErrorAction Stop

        Write-Host "  [PASS] Anthropic API key is valid and reachable" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] API key test failed: $_" -ForegroundColor Red
        $allGood = $false
    }
} else {
    Write-Host "  [INFO] No API key provided - re-run as: .\Test-Environment.ps1 -ApiKey 'sk-ant-...'" -ForegroundColor DarkGray
}

Write-Host ""
if ($allGood) {
    Write-Host "  ✔  All checks passed. Ready to run USBTrace.ps1" -ForegroundColor Green
} else {
    Write-Host "  ⚠  Some checks failed or warned. Review above before running." -ForegroundColor Yellow
}
Write-Host ""
