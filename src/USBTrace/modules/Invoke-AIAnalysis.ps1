function Invoke-AIAnalysis {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Timeline,
        [string]$ApiKey = "lm-studio",
        [string]$LMStudioUrl = "http://localhost:1234",
        [string]$ModelName = "local-model"
    )

    $deviceSummaries = @()
    foreach ($dev in ($Timeline.Devices | Where-Object { $_.DeviceKey -ne "__unmatched__" })) {
        $sessionText = "  - No session events correlated"
        if ($dev.Sessions.Count -gt 0) {
            $lines = @()
            foreach ($s in $dev.Sessions) {
                $conn = if ($s.ConnectTime)    { $s.ConnectTime.ToString("yyyy-MM-dd HH:mm:ss") }    else { "unknown" }
                $disc = if ($s.DisconnectTime) { $s.DisconnectTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "not recorded" }
                $dur  = if ($s.DurationMin)    { "$($s.DurationMin) min" }                           else { "unknown" }
                $lines += "  - Connected: $conn | Disconnected: $disc | Duration: $dur | Orphaned: $($s.IsOrphaned)"
            }
            $sessionText = $lines -join "`n"
        }
        $flagText = if ($dev.Flags.Count -gt 0) { $dev.Flags -join "; " } else { "None" }
        $deviceSummaries += "Device: $($dev.FriendlyName)`n  Serial: $($dev.SerialNumber)`n  VID/PID: $($dev.VidPid)`n  Manufacturer: $($dev.Manufacturer)`n  First Seen: $($dev.FirstSeen)`n  Last Seen: $($dev.LastSeen)`n  Connections: $($dev.TotalConnections)`n  Flags: $flagText`n  Sessions:`n$sessionText"
    }

    $systemPrompt = "You are a digital forensics analyst specializing in USB device forensics. Analyze the provided artifacts and respond with ONLY a valid JSON object. No markdown, no code fences, no extra text. Use this exact structure with these exact string values: riskLevel must be one of: LOW, MEDIUM, HIGH, or CRITICAL. analysisConfidence must be one of: LOW, MEDIUM, or HIGH. All other fields as described: {riskLevel, riskRationale, executiveSummary, keyFindings (array of {severity, device, finding, forensicSignificance}), behaviorPatterns (array of strings), insiderThreatIndicators (array of strings), recommendedActions (array of strings), analysisConfidence, confidenceNote, deviceAssessments (array of {device, riskLevel, assessment, notableActivity})}"

    $userPrompt = "Analyze these USB forensic artifacts from Windows system $($Timeline.Hostname). Total devices: $($Timeline.Devices.Count). Total log entries: $($Timeline.RawEventCount). System flags: $(if ($Timeline.Flags.Count -gt 0) { $Timeline.Flags -join '; ' } else { 'None' }). Devices: $($deviceSummaries -join ' --- '). Respond with ONLY the JSON object. riskLevel and analysisConfidence must be strings like HIGH or LOW, never numbers."

    $bodyObj = @{
        model       = $ModelName
        max_tokens  = 2000
        temperature = 0.2
        messages    = @(
            @{ role = "system"; content = $systemPrompt },
            @{ role = "user";   content = $userPrompt }
        )
    }
    $body = $bodyObj | ConvertTo-Json -Depth 10

    Write-Host "      [AI] Connecting to LM Studio at $LMStudioUrl..." -ForegroundColor DarkGray
    try {
        $null = Invoke-RestMethod -Uri "$LMStudioUrl/v1/models" -Method GET -ErrorAction Stop -TimeoutSec 5
        Write-Host "      [AI] Server reachable. Sending data for analysis..." -ForegroundColor DarkGray
    } catch {
        Write-Host "      [AI] Cannot reach LM Studio at $LMStudioUrl" -ForegroundColor Red
        Write-Host "      [AI] Make sure LM Studio is open with a model loaded and server started." -ForegroundColor Yellow
        return $null
    }

    $rawText = ""
    try {
        $response = Invoke-RestMethod -Uri "$LMStudioUrl/v1/chat/completions" -Method POST -Headers @{"Content-Type" = "application/json"} -Body $body -ErrorAction Stop -TimeoutSec 180
        $rawText = $response.choices[0].message.content

        $cleanJson = $rawText -replace "(?s)^[^{]*", "" -replace "(?s)}[^}]*$", "}"
        $cleanJson = $cleanJson.Trim()

        if (-not $cleanJson.StartsWith("{")) {
            Write-Host "      [AI] Model did not return valid JSON. Try a larger model." -ForegroundColor Yellow
            return $null
        }

        $parsed = $cleanJson | ConvertFrom-Json -ErrorAction Stop

        # Sanitize fields that small models sometimes return as numbers instead of strings
        $stringFields = @("riskLevel", "analysisConfidence")
        foreach ($field in $stringFields) {
            if ($parsed.PSObject.Properties[$field]) {
                $val = $parsed.$field
                if ($val -isnot [string]) {
                    # Map numeric confidence (0-100) to LOW/MEDIUM/HIGH
                    if ($val -ge 75) { $parsed.$field = "HIGH" }
                    elseif ($val -ge 40) { $parsed.$field = "MEDIUM" }
                    else { $parsed.$field = "LOW" }
                }
                # Normalize to uppercase
                $parsed.$field = ([string]$parsed.$field).ToUpper()
                # Validate it is a known value, default to MEDIUM if not
                $allowed = @("LOW","MEDIUM","HIGH","CRITICAL")
                if ($parsed.$field -notin $allowed) { $parsed.$field = "MEDIUM" }
            }
        }

        # Sanitize deviceAssessments riskLevel fields too
        if ($parsed.PSObject.Properties["deviceAssessments"] -and $parsed.deviceAssessments) {
            foreach ($da in $parsed.deviceAssessments) {
                if ($da.PSObject.Properties["riskLevel"]) {
                    $val = $da.riskLevel
                    if ($val -isnot [string]) {
                        if ($val -ge 75) { $da.riskLevel = "HIGH" }
                        elseif ($val -ge 40) { $da.riskLevel = "MEDIUM" }
                        else { $da.riskLevel = "LOW" }
                    }
                    $da.riskLevel = ([string]$da.riskLevel).ToUpper()
                    if ($da.riskLevel -notin @("LOW","MEDIUM","HIGH","CRITICAL")) { $da.riskLevel = "LOW" }
                }
            }
        }

        # Sanitize keyFindings severity fields
        if ($parsed.PSObject.Properties["keyFindings"] -and $parsed.keyFindings) {
            foreach ($kf in $parsed.keyFindings) {
                if ($kf.PSObject.Properties["severity"]) {
                    $val = $kf.severity
                    if ($val -isnot [string]) {
                        if ($val -ge 75) { $kf.severity = "HIGH" }
                        elseif ($val -ge 40) { $kf.severity = "MEDIUM" }
                        else { $kf.severity = "LOW" }
                    }
                    $kf.severity = ([string]$kf.severity).ToUpper()
                    if ($kf.severity -notin @("INFO","LOW","MEDIUM","HIGH","CRITICAL")) { $kf.severity = "INFO" }
                }
            }
        }

        Write-Host "      [AI] Analysis complete. Risk level: $($parsed.riskLevel)" -ForegroundColor DarkGray
        return $parsed

    } catch {
        Write-Host "      [AI] Analysis failed: $_" -ForegroundColor Red
        if ($rawText.Length -gt 0) {
            Write-Host "      [AI] Raw output preview: $($rawText.Substring(0, [Math]::Min(200, $rawText.Length)))" -ForegroundColor DarkGray
        }
        return $null
    }
}
