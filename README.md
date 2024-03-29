# CI for The Hackaday SuperCon 2019 FPGAmeboy

## Preface 

Welcome to the repository for a basic Continuous Integration/Continuous Development tool which was built for the FPGAmeboy badge distributed at the 2019 Hackaday SuperCon in Pasadena California. SupplyFrame hosted the event over several days with many different workshops and a massive area full of soldering irons, complete with a misc components table provided by DigiKey. 

This tool unexpectedly tied for runner up in the "App Hacks" contest...which I didn't even know was a thing and actually had to run down the street to my car to get my laptop to show on stage. 

Ceremony on YouTube: https://youtu.be/3se_L0tRZeg?t=2242  

## Introduction

This project came about when I was about 10% of the way through the [Intro workshop for the FPGAmeboy badge](https://github.com/esden/hadbadge2019_workshops). After getting my first few ELF files complied and pushed to my badge I got annoyed at the excessive process of plugging in, unplugging, dismounting disks, mounting disks, etc.... so I did the only thing that I could think of - automated the process chain!

Currently PowerShell on Windows 10 is the only supported version of this tool. Once I get more free time I will be making a version for other platforms as well. 

## How to use this CI (Continuous Integration) tool

Or better titled, **Automated Process Stack**

### Initial Setup

NOTE: Currently this is only working on Windows 10 with PowerShell 5.1+, though there are plans to make a *nix compatable version

1. Open a PowerShell console and set your desired application repository as root
2. Clone this repository in the desired location and set the new directory as root
```powershell
git clone https://github.com/Aask42/fpga_automation
cd fpga_automation
```
3. Plug in FPGAmeboy Badge to determine which letter will be auto-assigned on initial mounting of the drive 
4. Open "config.ini" in your text editor of choice and add your application details  
**Example Config:**
    ```ini
    [SPACEFORCE]
    app_root_folder=C:\hadbadge2019_workshops\basic\app-spaceforce
    toolchain_root=C:\ecp5-toolchain-windows-v1.6.9\bin
    device_drive=D
    ```  

### Operating the agent

1. Open a console with "fpga_automation" as root directory
2. Run the auto_make daemon from the console
    ```powershell
    powershell .\auto_make.ps1
    ```
   - This will monitor **ONLY main.c** for changes saved to the file
   - Once changes are **saved** to **main.c**, the daemon will execute all the steps listed in the [Manual Process Stack](#Manual-Process-Stack) using PowerShell/CLI tools
   - **Any errors in compilation will print out on this PowerShell console, and will serve as your "fast-feedback-loop" for continuously integrating and developing whatever code on which you are working**
     - If you would like to run this daemon in the background and write the output to a log, run the following command instead
        ```powershell
        .\auto_make.ps1 -as_job
        ```
   - Feel free to edit the loop time, 5 seconds was an arbitrary choice
3. Press **"CTRL + C"** to exit when you're done

## Manual Process Stack

This is the process chain that really made me want to automate this stack:

Process Step | How to execute | Other Notes
-|-|-
Plug in badge | Determine which COM the badge is using, open PuTTy or other tool and connect to the console | 115200 BAUD
Mount badge as filesystem | **Windows will auto-mount as a drive letter on the first run**</br>*If you previously unmounted using console tools, drive **WILL NOT AUTO-MOUNT**; you will need to manually assign a drive letter via console or GUI* | Drive letter is automatically assigned on first run
Open PowerShell console with the directory for main.c as your root | Shift-Right-Click in the explorer window to open a new CMD, then just type "powershell" and hit enter | You can also just hit WinKey+r, run "powershell", and **Set-Location** to the desired directory
Add the Make command to path variable | Adding locally ensures Windows picks it up | This should be a **temporary** path add as to not leave a mess behind as dev toolchains continue to update
Run the **make** command | On the PowerShell console, if the path was set correctly for **make** it should ust require an **Invoke-Expression** | You can also just type in "make" and hit enter. This is your first chance at debugging your code
Debugging | Watch the PowerShell console for errors from the make command | There are plans to make a VSCode Plugin to do this all automatically based off of a config.json file  
Copy ELF file to the mounted Windows drive | You could Drag and drop </br>Or use the CLI and take advantage of **Copy-Item** | There are a lot of other tools that can be used for file replication too
"Eject" the filesystem to prevent data corruption | Unmount using GUI</br>or you could unmount using CLI | If using the CLI to unmount, drive will NOT continue to auto-mount when plugged in
On first load of a specific app | Reboot the badge to add to the main menu | No reboot necessary if previous version of the app was already loaded