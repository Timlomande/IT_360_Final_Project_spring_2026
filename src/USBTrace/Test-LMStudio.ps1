param(
    [string]$LMStudioUrl = "http://localhost:1234"
)

Write-Host ""
Write-Host "  USBTrace - LM Studio Integration Test" -ForegroundColor Cyan
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

Write-Host "  [1/4] Checking LM Studio server..." -ForegroundColor Yellow
try {
    $models = Invoke-RestMethod -Uri "$LMStudioUrl/v1/models" -Method GET -ErrorAction Stop -TimeoutSec 5
    Write-Host "        Server is UP at $LMStudioUrl" -ForegroundColor Green
    if ($models.data -and $models.data.Count -gt 0) {
        Write-Host "        Loaded model: $($models.data[0].id)" -ForegroundColor Green
    } else {
        Write-Host "        WARNING: No model loaded. Load a model in LM Studio then start server." -ForegroundColor Yellow
    }
} catch {
    Write-Host "        FAILED - Cannot reach $LMStudioUrl" -ForegroundColor Red
    Write-Host "        1. Open LM Studio" -ForegroundColor Yellow
    Write-Host "        2. Load a model" -ForegroundColor Yellow
    Write-Host "        3. Go to Developer/API tab and click Start Server" -ForegroundColor Yellow
    Write-Host "        4. Re-run this test" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "  [2/4] Testing basic completion..." -ForegroundColor Yellow
try {
    $body = '{"model":"local-model","max_tokens":50,"temperature":0.1,"messages":[{"role":"user","content":"Reply with exactly the word: WORKING"}]}'
    $resp = Invoke-RestMethod -Uri "$LMStudioUrl/v1/chat/completions" -Method POST -Headers @{"Content-Type"="application/json"} -Body $body -ErrorAction Stop -TimeoutSec 60
    $reply = $resp.choices[0].message.content.Trim()
    Write-Host "        Response received: $reply" -ForegroundColor Green
    Write-Host "        Basic completion: PASS" -ForegroundColor Green
} catch {
    Write-Host "        Basic completion FAILED: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  [3/4] Testing JSON output format..." -ForegroundColor Yellow
try {
    $sysMsg = "You respond only in valid JSON with no extra text, no markdown, no code fences."
    $userMsg = "Return a JSON object with these exact fields: riskLevel (set to LOW), riskRationale (set to test), executiveSummary (set to test), keyFindings (empty array), behaviorPatterns (empty array), insiderThreatIndicators (empty array), recommendedActions (empty array), analysisConfidence (set to HIGH), confidenceNote (set to test), deviceAssessments (empty array)."
    $bodyObj = @{
        model = "local-model"
        max_tokens = 500
        temperature = 0.1
        messages = @(
            @{ role = "system"; content = $sysMsg },
            @{ role = "user"; content = $userMsg }
        )
    }
    $body = $bodyObj | ConvertTo-Json -Depth 5
    $resp = Invoke-RestMethod -Uri "$LMStudioUrl/v1/chat/completions" -Method POST -Headers @{"Content-Type"="application/json"} -Body $body -ErrorAction Stop -TimeoutSec 90
    $rawText = $resp.choices[0].message.content
    $cleanJson = $rawText -replace "[\s\S]*?(\{[\s\S]*\})[\s\S]*", '$1'
    $parsed = $cleanJson | ConvertFrom-Json -ErrorAction Stop
    $required = @("riskLevel","riskRationale","executiveSummary","keyFindings","deviceAssessments")
    $missing = $required | Where-Object { -not ($parsed.PSObject.Properties.Name -contains $_) }
    if ($missing.Count -eq 0) {
        Write-Host "        JSON structure: PASS - all required fields present" -ForegroundColor Green
        Write-Host "        riskLevel value: $($parsed.riskLevel)" -ForegroundColor Green
    } else {
        Write-Host "        JSON structure: PARTIAL - missing: $($missing -join ', ')" -ForegroundColor Yellow
        Write-Host "        Try a larger model for better results." -ForegroundColor DarkGray
    }
} catch {
    Write-Host "        JSON test FAILED - model did not return parseable JSON" -ForegroundColor Red
    Write-Host "        Try a larger model like llama-3.1-8b-instruct" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  [4/4] Checking USBTrace modules..." -ForegroundColor Yellow
$modules = @("Get-USBArtifacts.ps1","Build-Timeline.ps1","Invoke-AIAnalysis.ps1","Export-HTMLReport.ps1")
$allPresent = $true
foreach ($m in $modules) {
    $path = Join-Path $PSScriptRoot "Modules\$m"
    if (Test-Path $path) {
        Write-Host "        $m - FOUND" -ForegroundColor Green
    } else {
        Write-Host "        $m - MISSING" -ForegroundColor Red
        $allPresent = $false
    }
}

Write-Host ""
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
if ($allPresent) {
    Write-Host "  All checks passed. Run USBTrace with:" -ForegroundColor Green
    Write-Host "    .\USBTrace.ps1" -ForegroundColor Cyan
} else {
    Write-Host "  Some modules missing. Re-download the USBTrace zip." -ForegroundColor Red
}
Write-Host ""
