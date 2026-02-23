# IT_360_Final_Project_spring_2026

## Team Members
- Tim Lomande
- James Yahr

  ## Project idea
  
  
This project involves creating a Windows-based digital forensics tool using PowerShell that focuses on tracking and reconstructing the activity of removable media devices such as USB drives. When a USB device is connected to a system, the tool will collect relevant forensic artifacts from the Windows registry and event logs to identify when the device was connected, how long it remained in use, and what system interactions occurred during that time. These artifacts will be correlated into a timeline, allowing investigators to clearly see USB-related activity on the machine. The tool is designed to operate in a read-only manner to preserve forensic integrity and minimize system impact. Its goal is to simplify USB usage analysis for investigations involving data exfiltration, policy violations, or unauthorized device use.




## Use of AI


The project utilizes AI to provide interpretive analysis of USB forensic information collected from the Windows registry and event logs. The AI will identify and highlight key indicators such as device connection times, duration of use, repeated insertions, and unusual activity patterns that may suggest data exfiltration or policy violations. By correlating and analyzing this information, the AI helps reconstruct device usage timelines and models real-world insider threat or unauthorized access scenarios. To ensure reliability, the system emphasizes accuracy in artifact interpretation and implements safeguards to minimize false correlations or misleading conclusions, maintaining objective and forensically sound analysis.
