function Get-USBArtifacts {

    $result = [PSCustomObject]@{
        CollectionTime  = (Get-Date).ToString("o")
        Hostname        = $env:COMPUTERNAME
        RegistryDevices = @()
        EventLogEntries = @()
        SetupApiEntries = @()
        MountedVolumes  = @()
    }

    Write-Host "      [Registry] Reading USBSTOR..." -ForegroundColor DarkGray
    try {
        $usbstorPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"
        if (Test-Path $usbstorPath) {
            $deviceClasses = Get-ChildItem $usbstorPath -ErrorAction SilentlyContinue
            foreach ($class in $deviceClasses) {
                $instances = Get-ChildItem $class.PSPath -ErrorAction SilentlyContinue
                foreach ($instance in $instances) {
                    $props = Get-ItemProperty $instance.PSPath -ErrorAction SilentlyContinue
                    $friendly = ""
                    $mfg = ""
                    $svc = ""
                    $cid = ""
                    $hwid = ""
                    if ($props) {
                        if ($props.PSObject.Properties["FriendlyName"]) { $friendly = $props.FriendlyName }
                        if ($props.PSObject.Properties["Mfg"])          { $mfg = $props.Mfg }
                        if ($props.PSObject.Properties["Service"])      { $svc = $props.Service }
                        if ($props.PSObject.Properties["ContainerID"])  { $cid = $props.ContainerID }
                        if ($props.PSObject.Properties["HardwareID"])   { $hwid = $props.HardwareID -join "; " }
                    }
                    $result.RegistryDevices += [PSCustomObject]@{
                        DeviceClass  = $class.PSChildName
                        InstanceId   = $instance.PSChildName
                        FriendlyName = $friendly
                        Manufacturer = $mfg
                        Service      = $svc
                        ContainerID  = $cid
                        HardwareID   = $hwid
                        SerialNumber = ($instance.PSChildName -split "&")[0]
                        VidPid       = ""
                    }
                }
            }
        }
    } catch {
        Write-Host "      [Registry] USBSTOR error: $_" -ForegroundColor DarkRed
    }

    Write-Host "      [Registry] Reading USB Enum (VID/PID)..." -ForegroundColor DarkGray
    try {
        $usbEnumPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USB"
        if (Test-Path $usbEnumPath) {
            $vidPids = Get-ChildItem $usbEnumPath -ErrorAction SilentlyContinue
            foreach ($vidPid in $vidPids) {
                $instances = Get-ChildItem $vidPid.PSPath -ErrorAction SilentlyContinue
                foreach ($inst in $instances) {
                    $props = Get-ItemProperty $inst.PSPath -ErrorAction SilentlyContinue
                    if ($props) {
                        foreach ($dev in $result.RegistryDevices) {
                            if ($dev.SerialNumber -eq $inst.PSChildName) {
                                $dev.VidPid = $vidPid.PSChildName
                            }
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host "      [Registry] USB Enum error: $_" -ForegroundColor DarkRed
    }

    Write-Host "      [Registry] Reading MountedDevices..." -ForegroundColor DarkGray
    try {
        $mountedPath = "HKLM:\SYSTEM\MountedDevices"
        if (Test-Path $mountedPath) {
            $mounted = Get-ItemProperty $mountedPath -ErrorAction SilentlyContinue
            if ($mounted) {
                $mounted.PSObject.Properties | Where-Object { $_.Name -like "\DosDevices\*" } | ForEach-Object {
                    $result.MountedVolumes += [PSCustomObject]@{
                        DriveLetter = ($_.Name -replace "\\DosDevices\\", "")
                        RawData     = ($_.Value | ForEach-Object { "{0:X2}" -f $_ }) -join " "
                    }
                }
            }
        }
    } catch {
        Write-Host "      [Registry] MountedDevices error: $_" -ForegroundColor DarkRed
    }

    Write-Host "      [EventLog] Querying USB-related events..." -ForegroundColor DarkGray

    # NOTE: Queries System log for IDs 2003/2101 in addition to the
    # DriverFrameworks log so demo events written by Setup-Demo.ps1 are captured.
    $eventQueries = @(
        @{ LogName = "Microsoft-Windows-DriverFrameworks-UserMode/Operational"; EventIDs = @(2003,2004,2100,2101,2105,2106) },
        @{ LogName = "System";   EventIDs = @(7045,20001,20003,2003,2101) },
        @{ LogName = "Security"; EventIDs = @(6416) }
    )
    foreach ($query in $eventQueries) {
        try {
            $events = Get-WinEvent -FilterHashtable @{ LogName = $query.LogName; Id = $query.EventIDs } -ErrorAction SilentlyContinue -MaxEvents 500
            if ($events) {
                foreach ($evt in $events) {
                    $result.EventLogEntries += [PSCustomObject]@{
                        TimeCreated = $evt.TimeCreated
                        EventId     = $evt.Id
                        LogName     = $evt.LogName
                        Level       = $evt.LevelDisplayName
                        Message     = ($evt.Message -replace "\s+", " ")
                    }
                }
            }
        } catch {}
    }
    $result.EventLogEntries = @($result.EventLogEntries | Sort-Object TimeCreated)

    Write-Host "      [SetupAPI] Parsing device installation log..." -ForegroundColor DarkGray
    $result.SetupApiEntries = @()
    foreach ($logPath in @("$env:WINDIR\INF\setupapi.dev.log", "$env:WINDIR\setupapi.dev.log")) {
        if (Test-Path $logPath) {
            try {
                $lines = Get-Content $logPath -ErrorAction SilentlyContinue
                $cur = $null
                foreach ($line in $lines) {
                    if ($line -match "^\[Device Install") {
                        if ($cur) { $result.SetupApiEntries += $cur }
                        $cur = [PSCustomObject]@{ Header = $line.Trim(); Timestamp = $null; Device = ""; Lines = @() }
                    } elseif ($cur) {
                        $cur.Lines += $line
                        if ($line -match "Section start (\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})") {
                            try { $cur.Timestamp = [datetime]::ParseExact($matches[1], "yyyy/MM/dd HH:mm:ss", $null) } catch {}
                        }
                        if ($line -match "USBSTOR" -and $cur.Device -eq "") { $cur.Device = $line.Trim() }
                    }
                }
                if ($cur) { $result.SetupApiEntries += $cur }
                $result.SetupApiEntries = @($result.SetupApiEntries | Where-Object {
                    $_.Header -match "USB" -or $_.Device -match "USB"
                })
            } catch {}
            break
        }
    }

    return $result
}
