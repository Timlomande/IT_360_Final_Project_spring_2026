#Requires -RunAsAdministrator
param(
    [string]$LMStudioUrl = "http://localhost:1234",
    [string]$OutputPath = $PSScriptRoot,
    [switch]$SkipAI,
    [string]$ApiKey = "lm-studio"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "  USBTrace - Windows USB Forensics Tool" -ForegroundColor Cyan
Write-Host "  Read-Only | v1.0" -ForegroundColor Gray
Write-Host "  -------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

. "$PSScriptRoot\Modules\Get-USBArtifacts.ps1"
. "$PSScriptRoot\Modules\Build-Timeline.ps1"
. "$PSScriptRoot\Modules\Invoke-AIAnalysis.ps1"
. "$PSScriptRoot\Modules\Export-HTMLReport.ps1"

Write-Host "[1/4] Collecting USB forensic artifacts..." -ForegroundColor Yellow
$artifacts = Get-USBArtifacts
Write-Host "      Registry devices found  : $($artifacts.RegistryDevices.Count)" -ForegroundColor Gray
Write-Host "      Event log entries found : $($artifacts.EventLogEntries.Count)" -ForegroundColor Gray
Write-Host "      SetupAPI entries found  : $($artifacts.SetupApiEntries.Count)" -ForegroundColor Gray
Write-Host "      Mounted volumes found   : $($artifacts.MountedVolumes.Count)" -ForegroundColor Gray
Write-Host ""

Write-Host "[2/4] Building device timeline..." -ForegroundColor Yellow
$timeline = Build-Timeline -Artifacts $artifacts
Write-Host "      Unique devices tracked  : $($timeline.Devices.Count)" -ForegroundColor Gray
$totalSessions = ($timeline.Devices | ForEach-Object { $_.Sessions.Count } | Measure-Object -Sum).Sum
Write-Host "      Sessions reconstructed  : $totalSessions" -ForegroundColor Gray
Write-Host ""

$aiAnalysis = $null
if ($SkipAI) {
    Write-Host "[3/4] AI analysis skipped (-SkipAI flag)." -ForegroundColor DarkGray
} else {
    Write-Host "[3/4] Sending artifacts to LM Studio for analysis..." -ForegroundColor Yellow
    $aiAnalysis = Invoke-AIAnalysis -Timeline $timeline -ApiKey $ApiKey -LMStudioUrl $LMStudioUrl
    if ($aiAnalysis) {
        Write-Host "      AI analysis complete." -ForegroundColor Gray
    } else {
        Write-Host "      AI analysis failed. Continuing without it." -ForegroundColor DarkYellow
    }
}
Write-Host ""

Write-Host "[4/4] Generating HTML report..." -ForegroundColor Yellow
$reportPath = Export-HTMLReport -Timeline $timeline -Artifacts $artifacts -AIAnalysis $aiAnalysis -OutputPath $OutputPath
Write-Host ""
Write-Host "  Report saved to: $reportPath" -ForegroundColor Green
Write-Host ""
Write-Host "  Open the .html file in any browser to view the full forensic report." -ForegroundColor Cyan
Write-Host ""
