# IT_360_Final_Project_spring_2026

## Team Members
- Tim Lomande
- James Yahr

  ## Project idea
  
  
This project involves creating a Windows-based digital forensics tool using PowerShell that focuses on tracking and reconstructing the activity of removable media devices such as USB drives. When a USB device is connected to a system, the tool will collect relevant forensic artifacts from the Windows registry and event logs to identify when the device was connected, how long it remained in use, and what system interactions occurred during that time. These artifacts will be correlated into a timeline, allowing investigators to clearly see USB-related activity on the machine. The tool is designed to operate in a read-only manner to preserve forensic integrity and minimize system impact. Its goal is to simplify USB usage analysis for investigations involving data exfiltration, policy violations, or unauthorized device use.




## Use of AI


The project utilizes AI to provide interpretive analysis of USB forensic information collected from the Windows registry and event logs. The AI will identify and highlight key indicators such as device connection times, duration of use, repeated insertions, and unusual activity patterns that may suggest data exfiltration or policy violations. By correlating and analyzing this information, the AI helps reconstruct device usage timelines and models real-world insider threat or unauthorized access scenarios. To ensure reliability, the system emphasizes accuracy in artifact interpretation and implements safeguards to minimize false correlations or misleading conclusions, maintaining objective and forensically sound analysis.




## Setup & Installation

### Prerequisites

- Windows 10 or Windows 11
- PowerShell 5.1 or later (included with Windows by default)
- Administrator privileges
- [LM Studio](https://lmstudio.ai) with a loaded model for AI analysis

### Step 1 — Clone the Repository

```bash
git clone https://github.com/Timlomande/IT_360_Final_Project_spring_2026.git
cd IT_360_Final_Project_spring_2026
```

### Step 2 — Allow PowerShell Script Execution

Open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 3 — Configure LM Studio

1. Download and install [LM Studio](https://lmstudio.ai)
2. Open LM Studio and go to the **Discover** tab to download a model
   - Recommended: `llama-3.2-3b-instruct` (lightweight) or `llama-3.1-8b-instruct` (better accuracy)
3. Go to the **Developer** tab (the `< >` icon in the left sidebar)
4. Select your downloaded model and click **Start Server**
5. Confirm the server is running on `http://localhost:1234`

### Step 4 — Run the Pre-Flight Check (Optional)

Before running the tool, verify your environment is configured correctly:

```powershell
cd src/USBTrace
powershell -ExecutionPolicy Bypass -File ".\Test-LMStudio.ps1"
```

All four checks should pass before proceeding.

### Step 5 — Run USBTrace

```powershell
cd src/USBTrace
powershell -ExecutionPolicy Bypass -File ".\USBTrace.ps1"
```

The tool will collect artifacts, build a timeline, send data to LM Studio for analysis, and save a self-contained HTML report to the `src/USBTrace` directory. Open the generated `.html` file in any browser to view the full forensic report.

### Demo Mode (Simulated Suspicious Activity)

To demonstrate the tool's behavioral flag detection without a physical USB device:

**1. Run the demo setup script** (creates fake USB artifacts in the registry and event log):

```powershell
powershell -ExecutionPolicy Bypass -File ".\Demo\Setup-Demo.ps1"
```

**2. Run USBTrace** to analyze the simulated artifacts:

```powershell
powershell -ExecutionPolicy Bypass -File ".\USBTrace.ps1"
```

The report will show a simulated SanDisk Ultra USB device with `HIGH_FREQUENCY` and `SHORT_SESSIONS` flags raised and a MEDIUM or HIGH AI risk assessment.

**3. Clean up** after the demo to remove all fake artifacts:

```powershell
powershell -ExecutionPolicy Bypass -File ".\Demo\Cleanup-Demo.ps1"
```

### File Structure
src/USBTrace/
├── USBTrace.ps1              # Main entry point
├── Test-LMStudio.ps1         # LM Studio connectivity test
├── Test-Environment.ps1      # Pre-flight environment check
├── requirements.txt          # Dependency notes
├── Modules/
│   ├── Get-USBArtifacts.ps1  # Registry, event log, and SetupAPI collection
│   ├── Build-Timeline.ps1    # Timeline correlation and behavioral flag engine
│   ├── Invoke-AIAnalysis.ps1 # LM Studio AI integration
│   └── Export-HTMLReport.ps1 # HTML report generator
└── Demo/
├── Setup-Demo.ps1        # Creates simulated USB artifacts for demo
└── Cleanup-Demo.ps1      # Removes all demo artifacts
