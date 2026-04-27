function Export-HTMLReport {
    param(
        [Parameter(Mandatory)][PSCustomObject]$Timeline,
        [Parameter(Mandatory)][PSCustomObject]$Artifacts,
        [PSCustomObject]$AIAnalysis = $null,
        [string]$OutputPath = $PSScriptRoot
    )

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename  = "USBTrace_Report_$($Timeline.Hostname)_$timestamp.html"
    $fullPath  = Join-Path $OutputPath $filename

    function Get-RiskBadge($Level) {
        $Level = [string]$Level
        $colors = @{ CRITICAL="#dc2626"; HIGH="#ea580c"; MEDIUM="#d97706"; LOW="#16a34a"; INFO="#6b7280" }
        $color = if ($colors.ContainsKey($Level.ToUpper())) { $colors[$Level.ToUpper()] } else { "#6b7280" }
        return "<span style='background:$color;color:#fff;padding:2px 8px;border-radius:4px;font-size:0.75rem;font-weight:700'>$Level</span>"
    }

    # Device cards
    $deviceCardsHtml = ""
    foreach ($dev in $Timeline.Devices) {
        if ($dev.DeviceKey -eq "__unmatched__") { continue }
        $sessionRowsHtml = ""
        if ($dev.Sessions.Count -gt 0) {
            foreach ($s in ($dev.Sessions | Sort-Object ConnectTime)) {
                $conn = if ($s.ConnectTime) { $s.ConnectTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "unknown" }
                $disc = if ($s.DisconnectTime) { $s.DisconnectTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "not recorded" }
                $dur  = if ($s.DurationMin) { "$($s.DurationMin) min" } else { "unknown" }
                $note = if ($s.IsOrphaned) { "No disconnect recorded" } else { "" }
                $sessionRowsHtml += "<tr><td>$conn</td><td>$disc</td><td>$dur</td><td>$($s.ConnectEvent)</td><td>$note</td></tr>"
            }
        } else {
            $sessionRowsHtml = "<tr><td colspan='5' style='color:#9ca3af;text-align:center'>No session events in event log</td></tr>"
        }

        $flagsHtml = ""
        if ($dev.Flags.Count -gt 0) {
            $flagsHtml = "<div style='margin-top:12px'>"
            foreach ($flag in $dev.Flags) {
                $flagType = ($flag -split ":")[0].Trim()
                $flagMsg  = ($flag -replace "^[^:]+:\s*", "")
                $color = switch ($flagType) {
                    "HIGH_FREQUENCY"    { "#ea580c" }
                    "SHORT_SESSIONS"    { "#d97706" }
                    "OFF_HOURS"         { "#dc2626" }
                    "ORPHANED_SESSIONS" { "#7c3aed" }
                    default             { "#6b7280" }
                }
                $flagsHtml += "<div style='background:${color}18;border-left:3px solid $color;padding:6px 10px;margin-bottom:4px;font-size:0.8rem'><strong>$flagType</strong>: $flagMsg</div>"
            }
            $flagsHtml += "</div>"
        }

        $deviceCardsHtml += @"
<div style='border:1px solid #e5e7eb;border-radius:8px;padding:16px;margin-bottom:16px'>
  <div style='display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px'>
    <div>
      <h3 style='margin:0 0 4px 0'>$($dev.FriendlyName)</h3>
      <div style='font-size:0.8rem;color:#6b7280'>$($dev.DeviceClass) | VID/PID: $($dev.VidPid)</div>
    </div>
    <div style='font-size:0.8rem;color:#374151;text-align:right'>
      <div><strong>Connections:</strong> $($dev.TotalConnections)</div>
      <div><strong>First seen:</strong> $($dev.FirstSeen)</div>
      <div><strong>Last seen:</strong> $($dev.LastSeen)</div>
    </div>
  </div>
  <div style='margin-top:10px;font-size:0.82rem'>
    <strong>Serial:</strong> $($dev.SerialNumber) &nbsp; <strong>Manufacturer:</strong> $($dev.Manufacturer)
  </div>
  $flagsHtml
  <div style='margin-top:14px;overflow-x:auto'>
    <table style='width:100%;font-size:0.8rem;border-collapse:collapse'>
      <thead><tr style='background:#f3f4f6'><th>Connect</th><th>Disconnect</th><th>Duration</th><th>Event ID</th><th>Notes</th></tr></thead>
      <tbody>$sessionRowsHtml</tbody>
    </table>
  </div>
</div>
"@
    }

    # AI section
    $aiSectionHtml = ""
    if ($AIAnalysis) {
        $riskBadge = Get-RiskBadge $AIAnalysis.riskLevel
        $confBadge = Get-RiskBadge $AIAnalysis.analysisConfidence

        $findingsHtml = ""
        foreach ($f in $AIAnalysis.keyFindings) {
            $sevBadge = Get-RiskBadge $f.severity
            $findingsHtml += "<div style='border:1px solid #e5e7eb;border-radius:6px;padding:12px;margin-bottom:8px'><div style='display:flex;justify-content:space-between;margin-bottom:6px'><strong>$($f.device)</strong>$sevBadge</div><div style='font-size:0.85rem'>$($f.finding)</div><div style='font-size:0.8rem;color:#6b7280;font-style:italic'>$($f.forensicSignificance)</div></div>"
        }

        $behaviorsHtml  = ($AIAnalysis.behaviorPatterns      | ForEach-Object { "<li>$_</li>" }) -join ""
        $indicatorsHtml = if ($AIAnalysis.insiderThreatIndicators.Count -gt 0) { ($AIAnalysis.insiderThreatIndicators | ForEach-Object { "<li>$_</li>" }) -join "" } else { "<li style='color:#6b7280'>None identified</li>" }
        $actionsHtml    = ($AIAnalysis.recommendedActions     | ForEach-Object { "<li>$_</li>" }) -join ""

        $deviceAssessHtml = ""
        foreach ($da in $AIAnalysis.deviceAssessments) {
            $daBadge = Get-RiskBadge $da.riskLevel
            $deviceAssessHtml += "<div style='border:1px solid #e5e7eb;border-radius:6px;padding:10px;margin-bottom:8px'><div style='display:flex;justify-content:space-between;margin-bottom:4px'><strong>$($da.device)</strong>$daBadge</div><div style='font-size:0.82rem'>$($da.assessment)</div><div style='font-size:0.8rem;color:#6b7280'>Notable: $($da.notableActivity)</div></div>"
        }

        $aiSectionHtml = @"
<section>
  <h2>AI Forensic Analysis</h2>
  <div style='background:#f0f9ff;border:1px solid #bae6fd;border-radius:8px;padding:16px;margin-bottom:20px'>
    <div style='display:flex;align-items:center;gap:12px;margin-bottom:8px'>
      <strong>Overall Risk:</strong> $riskBadge
      <span style='font-size:0.8rem;color:#6b7280'>Confidence: $confBadge</span>
    </div>
    <div style='font-size:0.88rem;margin-bottom:4px'><strong>Rationale:</strong> $($AIAnalysis.riskRationale)</div>
    <div style='font-size:0.85rem;margin-top:8px;padding-top:8px;border-top:1px solid #bae6fd'>$($AIAnalysis.executiveSummary)</div>
    <div style='font-size:0.78rem;color:#9ca3af;margin-top:8px;font-style:italic'>$($AIAnalysis.confidenceNote)</div>
  </div>
  <div style='display:grid;grid-template-columns:1fr 1fr;gap:20px;margin-bottom:20px'>
    <div><h3>Key Findings</h3>$findingsHtml</div>
    <div><h3>Device Assessments</h3>$deviceAssessHtml</div>
  </div>
  <div style='display:grid;grid-template-columns:repeat(3,1fr);gap:20px'>
    <div><h3>Behavior Patterns</h3><ul style='font-size:0.85rem;padding-left:16px'>$behaviorsHtml</ul></div>
    <div><h3>Insider Threat Indicators</h3><ul style='font-size:0.85rem;padding-left:16px'>$indicatorsHtml</ul></div>
    <div><h3>Recommended Actions</h3><ul style='font-size:0.85rem;padding-left:16px'>$actionsHtml</ul></div>
  </div>
</section>
"@
    } else {
        $aiSectionHtml = "<section><h2>AI Forensic Analysis</h2><div style='background:#f9fafb;border:1px dashed #d1d5db;border-radius:8px;padding:20px;text-align:center;color:#6b7280'>AI analysis was not performed. Ensure LM Studio is running and re-run USBTrace.ps1.</div></section>"
    }

    # Event log rows
    $eventRowsHtml = ""
    foreach ($evt in ($Artifacts.EventLogEntries | Sort-Object TimeCreated -Descending | Select-Object -First 200)) {
        $msg = if ($evt.Message.Length -gt 120) { $evt.Message.Substring(0,120) + "..." } else { $evt.Message }
        $eventRowsHtml += "<tr><td>$($evt.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))</td><td>$($evt.EventId)</td><td>$($evt.LogName)</td><td>$($evt.Level)</td><td style='font-size:0.75rem'>$msg</td></tr>"
    }

    # Registry rows
    $registryRowsHtml = ""
    foreach ($dev in $Artifacts.RegistryDevices) {
        $registryRowsHtml += "<tr><td>$($dev.FriendlyName)</td><td style='font-size:0.75rem'>$($dev.InstanceId)</td><td>$($dev.Manufacturer)</td><td style='font-size:0.75rem'>$($dev.HardwareID)</td></tr>"
    }

    # Flags summary
    $flagsSummaryHtml = ""
    if ($Timeline.Flags.Count -gt 0) {
        $flagItems = ($Timeline.Flags | ForEach-Object { "<li style='font-size:0.85rem'>$_</li>" }) -join ""
        $flagsSummaryHtml = "<div style='background:#fef3c7;border:1px solid #fbbf24;border-radius:6px;padding:12px;margin-bottom:20px'><strong>System Flags Detected:</strong><ul style='margin:6px 0 0 0;padding-left:20px'>$flagItems</ul></div>"
    }

    $totalSessions = ($Timeline.Devices | ForEach-Object { $_.Sessions.Count } | Measure-Object -Sum).Sum

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>USBTrace Report - $($Timeline.Hostname)</title>
<style>
*,*::before,*::after{box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f3f4f6;color:#111827;margin:0;padding:0}
.container{max-width:1200px;margin:0 auto;padding:24px}
.header{background:linear-gradient(135deg,#1e1b4b,#1d4ed8);color:white;padding:32px;border-radius:12px;margin-bottom:24px}
.header h1{margin:0 0 4px 0;font-size:1.6rem}
section{background:white;border-radius:10px;padding:20px 24px;margin-bottom:20px;box-shadow:0 1px 3px rgba(0,0,0,0.08)}
h2{margin:0 0 16px 0;font-size:1.1rem;color:#1e1b4b;border-bottom:2px solid #e5e7eb;padding-bottom:10px}
h3{font-size:0.95rem;color:#374151;margin:0 0 10px 0}
.stat-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:20px}
.stat-card{background:#f9fafb;border-radius:8px;padding:14px;text-align:center;border:1px solid #e5e7eb}
.stat-card .value{font-size:1.8rem;font-weight:700;color:#1e1b4b}
.stat-card .label{font-size:0.75rem;color:#6b7280;margin-top:2px}
table{width:100%;border-collapse:collapse;font-size:0.82rem}
th{background:#f9fafb;font-weight:600;text-align:left;padding:8px 10px;border-bottom:2px solid #e5e7eb;font-size:0.78rem;color:#6b7280}
td{padding:7px 10px;border-bottom:1px solid #f3f4f6;vertical-align:top}
.tab-bar{display:flex;gap:4px;margin-bottom:16px;flex-wrap:wrap}
.tab{padding:7px 16px;border-radius:6px;border:1px solid #e5e7eb;cursor:pointer;font-size:0.85rem;background:#f9fafb;color:#374151}
.tab.active{background:#1e1b4b;color:white;border-color:#1e1b4b}
.tab-content{display:none}
.tab-content.active{display:block}
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>USBTrace Forensic Report</h1>
    <div style='opacity:0.8;font-size:0.85rem'>Hostname: $($Timeline.Hostname) | Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Read-Only Collection</div>
  </div>

  <section>
    <h2>Summary Statistics</h2>
    $flagsSummaryHtml
    <div class="stat-grid">
      <div class="stat-card"><div class="value">$($Artifacts.RegistryDevices.Count)</div><div class="label">Registry Devices</div></div>
      <div class="stat-card"><div class="value">$($Artifacts.EventLogEntries.Count)</div><div class="label">Event Log Entries</div></div>
      <div class="stat-card"><div class="value">$($Artifacts.SetupApiEntries.Count)</div><div class="label">SetupAPI Entries</div></div>
      <div class="stat-card"><div class="value">$($Artifacts.MountedVolumes.Count)</div><div class="label">Mounted Volumes</div></div>
      <div class="stat-card"><div class="value">$totalSessions</div><div class="label">Sessions Found</div></div>
      <div class="stat-card"><div class="value">$($Timeline.Flags.Count)</div><div class="label">Analyst Flags</div></div>
    </div>
  </section>

  $aiSectionHtml

  <section>
    <h2>Device Timeline</h2>
    $deviceCardsHtml
  </section>

  <section>
    <h2>Raw Artifact Data</h2>
    <div class="tab-bar">
      <div class="tab active" onclick="showTab('events',this)">Event Log ($($Artifacts.EventLogEntries.Count))</div>
      <div class="tab" onclick="showTab('registry',this)">Registry ($($Artifacts.RegistryDevices.Count))</div>
      <div class="tab" onclick="showTab('volumes',this)">Volumes ($($Artifacts.MountedVolumes.Count))</div>
    </div>
    <div id="events" class="tab-content active" style="overflow-x:auto">
      <table><thead><tr><th>Time</th><th>Event ID</th><th>Log</th><th>Level</th><th>Message</th></tr></thead>
      <tbody>$eventRowsHtml</tbody></table>
    </div>
    <div id="registry" class="tab-content" style="overflow-x:auto">
      <table><thead><tr><th>Friendly Name</th><th>Instance ID</th><th>Manufacturer</th><th>Hardware ID</th></tr></thead>
      <tbody>$registryRowsHtml</tbody></table>
    </div>
    <div id="volumes" class="tab-content" style="overflow-x:auto">
      <table><thead><tr><th>Drive Letter</th><th>Raw Data (hex)</th></tr></thead>
      <tbody>$(($Artifacts.MountedVolumes | ForEach-Object { "<tr><td>$($_.DriveLetter)</td><td style='font-family:monospace;font-size:0.72rem'>$($_.RawData.Substring(0,[Math]::Min(80,$_.RawData.Length)))</td></tr>" }) -join "")</tbody>
      </table>
    </div>
  </section>

  <div style="text-align:center;font-size:0.75rem;color:#9ca3af;padding:16px 0">
    USBTrace v1.0 | Read-only | AI by LM Studio | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  </div>
</div>
<script>
function showTab(id,el){
  document.querySelectorAll('.tab-content').forEach(function(t){t.classList.remove('active')});
  document.querySelectorAll('.tab').forEach(function(t){t.classList.remove('active')});
  document.getElementById(id).classList.add('active');
  el.classList.add('active');
}
</script>
</body>
</html>
"@

    $html | Out-File -FilePath $fullPath -Encoding UTF8 -Force
    return $fullPath
}
