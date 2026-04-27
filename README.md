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
- PowerShell 5.1 or later (built into Windows)
- Administrator privileges
- [LM Studio](https://lmstudio.ai) for local AI analysis

### Step 1 — Clone the Repository

```bash
git clone https://github.com/Timlomande/IT_360_Final_Project_spring_2026.git
cd IT_360_Final_Project_spring_2026
```

### Step 2 — Allow PowerShell Scripts to Run

Open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 3 — Set Up LM Studio

1. Download and install [LM Studio](https://lmstudio.ai)
2. Search for and download a model, we used `llama-3.2-3b-instruct`. The `llama-3.1-8b-instruct` model gives better results if your machine can handle it
3. Go to the **Developer** tab on the left sidebar
4. Load your model and hit **Start Server**
5. The server should be running at `http://localhost:1234`

### Step 4 — Test Your Setup

```powershell
cd src/USBTrace
powershell -ExecutionPolicy Bypass -File ".\Test-LMStudio.ps1"
```

This runs a quick check to make sure LM Studio is talking to USBTrace correctly. All four checks should be green before moving on.

### Step 5 — Run the Tool

```powershell
powershell -ExecutionPolicy Bypass -File ".\USBTrace.ps1"
```

USBTrace will collect artifacts from the registry and event logs, build a device timeline, run AI analysis through LM Studio, and drop an HTML report in the same folder. Open it in any browser.

---

### Demo Mode

If you want to see the behavioral flags and AI risk escalation without plugging in a physical drive, use the demo scripts. They write fake USB connect/disconnect events and a fake registry device entry that USBTrace will pick up and flag as suspicious.

```powershell
# 1. Create the fake artifacts
powershell -ExecutionPolicy Bypass -File ".\Demo\Setup-Demo.ps1"

# 2. Run the tool
powershell -ExecutionPolicy Bypass -File ".\USBTrace.ps1"

# 3. Clean up when done
powershell -ExecutionPolicy Bypass -File ".\Demo\Cleanup-Demo.ps1"
```

The report should show a SanDisk Ultra device with `HIGH_FREQUENCY` and `SHORT_SESSIONS` flags and a MEDIUM or HIGH risk rating from the AI.

---

### File Structure
