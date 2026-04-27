function Build-Timeline {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Artifacts
    )

    $timeline = [PSCustomObject]@{
        GeneratedAt   = (Get-Date).ToString("o")
        Hostname      = $Artifacts.Hostname
        Devices       = @()
        RawEventCount = $Artifacts.EventLogEntries.Count
        Flags         = @()
    }

    $deviceGroups = @{}

    foreach ($dev in $Artifacts.RegistryDevices) {
        $serial = ($dev.InstanceId -split "&")[0]
        if (-not $deviceGroups.ContainsKey($serial)) {
            $friendlyName = "Unknown USB Device"
            if ($dev.FriendlyName -and $dev.FriendlyName -ne "") { $friendlyName = $dev.FriendlyName }
            $deviceGroups[$serial] = [PSCustomObject]@{
                DeviceKey        = $serial
                FriendlyName     = $friendlyName
                Manufacturer     = $dev.Manufacturer
                DeviceClass      = $dev.DeviceClass
                HardwareID       = $dev.HardwareID
                VidPid           = $dev.VidPid
                ContainerID      = $dev.ContainerID
                SerialNumber     = $serial
                Sessions         = @()
                FirstSeen        = $null
                LastSeen         = $null
                TotalConnections = 0
                Flags            = @()
            }
        }
    }

    $connectEvents    = @($Artifacts.EventLogEntries | Where-Object { $_.EventId -in @(2003,2004) })
    $disconnectEvents = @($Artifacts.EventLogEntries | Where-Object { $_.EventId -in @(2100,2101) })
    $usedDisconnects  = @{}
    $sessions         = @()

    foreach ($conn in ($connectEvents | Sort-Object TimeCreated)) {
        $matchDisc = $disconnectEvents |
            Where-Object { $_.TimeCreated -gt $conn.TimeCreated -and -not $usedDisconnects.ContainsKey($_.GetHashCode()) } |
            Sort-Object TimeCreated |
            Select-Object -First 1

        $duration = $null
        $discTime = $null
        if ($matchDisc) {
            $usedDisconnects[$matchDisc.GetHashCode()] = $true
            $discTime = $matchDisc.TimeCreated
            $duration = [math]::Round(($matchDisc.TimeCreated - $conn.TimeCreated).TotalMinutes, 2)
        }

        $sessions += [PSCustomObject]@{
            ConnectTime     = $conn.TimeCreated
            DisconnectTime  = $discTime
            DurationMin     = $duration
            ConnectEvent    = $conn.EventId
            DisconnectEvent = if ($matchDisc) { $matchDisc.EventId } else { $null }
            IsOrphaned      = ($null -eq $matchDisc)
        }
    }

    foreach ($session in $sessions) {
        $assigned = $false
        foreach ($key in $deviceGroups.Keys) {
            if (-not $assigned) {
                $deviceGroups[$key].Sessions += $session
                $assigned = $true
            }
        }
        if (-not $assigned) {
            if (-not $deviceGroups.ContainsKey("__unmatched__")) {
                $deviceGroups["__unmatched__"] = [PSCustomObject]@{
                    DeviceKey = "__unmatched__"; FriendlyName = "Unmatched Session Events"
                    Manufacturer = "N/A"; DeviceClass = "N/A"; HardwareID = "N/A"
                    VidPid = "N/A"; ContainerID = "N/A"; SerialNumber = "N/A"
                    Sessions = @(); FirstSeen = $null; LastSeen = $null
                    TotalConnections = 0; Flags = @()
                }
            }
            $deviceGroups["__unmatched__"].Sessions += $session
        }
    }

    foreach ($key in $deviceGroups.Keys) {
        $dev = $deviceGroups[$key]
        $dev.TotalConnections = $dev.Sessions.Count

        $allTimes = @()
        foreach ($s in $dev.Sessions) {
            if ($s.ConnectTime)    { $allTimes += $s.ConnectTime }
            if ($s.DisconnectTime) { $allTimes += $s.DisconnectTime }
        }
        if ($dev.FirstSeen) { $allTimes += $dev.FirstSeen }

        if ($allTimes.Count -gt 0) {
            $sorted = $allTimes | Sort-Object
            if ($null -eq $dev.FirstSeen) { $dev.FirstSeen = $sorted[0] }
            $dev.LastSeen = $sorted[-1]
        }

        if ($dev.TotalConnections -gt 5) {
            $dev.Flags += "HIGH_FREQUENCY: Device connected $($dev.TotalConnections) times"
            $timeline.Flags += "HIGH_FREQUENCY on $($dev.FriendlyName)"
        }

        $shortSessions = @($dev.Sessions | Where-Object { $_.DurationMin -ne $null -and $_.DurationMin -lt 2 -and -not $_.IsOrphaned })
        if ($shortSessions.Count -gt 0) {
            $dev.Flags += "SHORT_SESSIONS: $($shortSessions.Count) session(s) under 2 minutes"
        }

        $offHours = @($dev.Sessions | Where-Object { $_.ConnectTime -and ($_.ConnectTime.Hour -lt 6 -or $_.ConnectTime.Hour -ge 20) })
        if ($offHours.Count -gt 0) {
            $dev.Flags += "OFF_HOURS: $($offHours.Count) connection(s) outside 06:00-20:00"
            $timeline.Flags += "OFF_HOURS on $($dev.FriendlyName)"
        }

        $orphaned = @($dev.Sessions | Where-Object { $_.IsOrphaned })
        if ($orphaned.Count -gt 0) {
            $dev.Flags += "ORPHANED_SESSIONS: $($orphaned.Count) connect event(s) with no disconnect"
        }

        $timeline.Devices += $dev
    }

    $timeline.Devices = @($timeline.Devices | Sort-Object { $_.LastSeen } -Descending)
    return $timeline
}
