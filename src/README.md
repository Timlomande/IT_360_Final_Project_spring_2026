# USBTrace - Windows USB Forensics Tool

A PowerShell-based digital forensics tool that collects, correlates, and AI-analyzes
USB device artifacts from a Windows system. Designed for forensic integrity - read-only,
no system modifications.

---

## Quick Setup (5 minutes)

### Step 1 - Download & Extract
Copy the USBTrace folder to your Windows machine. Suggested path:
```
C:\Tools\USBTrace\
```

### Step 2 - Allow Script Execution
Open PowerShell **as Administrator** and run:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 3 - Get an Anthropic API Key (for AI analysis)
1. Go to https://console.anthropic.com
2. Sign in or create an account
3. Go to **API Keys** → **Create Key**
4. Copy the key (starts with `sk-ant-`)

> **Skip this step** if you only want artifact collection without AI analysis.

### Step 4 - Run USBTrace

**With AI analysis:**
```powershell
cd C:\Tools\USBTrace
.\USBTrace.ps1 -ApiKey "sk-ant-YOUR_KEY_HERE"
```

**Without AI analysis (offline/air-gapped):**
```powershell
cd C:\Tools\USBTrace
.\USBTrace.ps1 -SkipAI
```

**Custom output directory:**
```powershell
.\USBTrace.ps1 -ApiKey "sk-ant-..." -OutputPath "C:\Investigations\Case001"
```

### Step 5 - Open Report
The tool prints the report path when done. Open the `.html` file in any browser.

---

## What It Collects (Read-Only)

| Source | What | Why |
|---|---|---|
| `HKLM\SYSTEM\...\USBSTOR` | Device class, instance ID, serial, friendly name | Identifies every USB storage device ever connected |
| `HKLM\SYSTEM\...\Enum\USB` | VID/PID, manufacturer, bus descriptor | Maps vendor identity to device |
| `HKLM\SYSTEM\MountedDevices` | Drive letter assignments | Links device to drive letter |
| Event Log: DriverFrameworks | IDs 2003, 2004, 2100, 2101, 2105, 2106 | Connect/disconnect timestamps |
| Event Log: System | IDs 7045, 20001, 20003 | Driver installation events |
| Event Log: Security | ID 6416 | Plug and play audit (if enabled) |
| `%WINDIR%\INF\setupapi.dev.log` | First-install timestamps | Establishes first-ever connection date |

---

## Analyst Flags

USBTrace automatically raises flags for:

| Flag | Meaning |
|---|---|
| `HIGH_FREQUENCY` | Device connected more than 5 times |
| `SHORT_SESSIONS` | Sessions under 2 minutes (possible quick copy/exfil pattern) |
| `OFF_HOURS` | Connections before 06:00 or after 20:00 |
| `ORPHANED_SESSIONS` | Connect event with no corresponding disconnect |
| `GENERIC_DEVICE` | No vendor-specific name - unverified device identity |

---

## Troubleshooting

**"Access Denied" on event logs**
Run PowerShell as Administrator.

**AI analysis returns nothing**
- Verify API key is correct and has credits
- Check internet connectivity
- Try running with `-SkipAI` first to confirm artifact collection works

**No sessions reconstructed**
Windows DriverFrameworks-UserMode logging may be disabled by default. Enable it:
```powershell
wevtutil sl Microsoft-Windows-DriverFrameworks-UserMode/Operational /e:true
```
Note: This only captures *future* events, not past ones.

**Empty event log results**
Normal if the machine has had logs cleared or has never had USB auditing enabled.
Registry artifacts (device list, first seen) are always available regardless of log state.

---

## File Structure

```
USBTrace/
├── USBTrace.ps1              # Main entry point
├── README.md                 # This file
└── Modules/
    ├── Get-USBArtifacts.ps1  # Registry + event log + setupapi collection
    ├── Build-Timeline.ps1    # Correlation engine, session reconstruction, flags
    ├── Invoke-AIAnalysis.ps1 # Claude API integration
    └── Export-HTMLReport.ps1 # Standalone HTML report generator
```

---

## Forensic Notes

- **Read-only**: No registry writes, no file creation outside the output directory.
- **Admin required**: Some event logs and registry hives require elevated access.
- **No data exfiltration**: The only outbound network call is to `api.anthropic.com` with your timeline data for AI analysis. Use `-SkipAI` on air-gapped systems.
- **Artifact preservation**: Raw artifacts are embedded in the report for chain-of-custody documentation.
