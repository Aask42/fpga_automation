#requires -version 5.1
<#
.SYNOPSIS
  This script was written by @Aask42 (Amelia Wietting) in order to create a fast-feedback-loop for developing on the 2019 Hackaday SuperCon FPGAmeboy badge
.DESCRIPTION
  This script is a daemon that will run and monitor batches of main.c files for changes, and automatically compile the code via make command, mount the FPGAmeboy, push the file, and unmount safely so end users may more quickly test code changes to new and existing code loaded to the device
.PARAMETER config_root
    This is the location of the configuration file which auto_make.ps1 will look for the config_filename
.PARAMETER config_filename
    This is the name of the config ini file which auto_make.ps1 will read. This will default to config.ini
.PARAMETER toolchain_root
    This is the location of the FPGAmeboy toolchain root. 

    https://github.com/esden/hadbadge2019_fpgasoc/blob/master/doc/toolchain-win.md
.PARAMETER import_only
    If set this flag will cause the functions to be IMPORTED ONLY, and the dameon WILL NOT START automatically  
.PARAMETER as_job
    If set this flag will run the daemon as a background job and output to a log file
.INPUTS
  <Inputs if any, otherwise state None>
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        2
  Author:         Amelia Wietting
  Creation Date:  20191117
  Purpose/Change: Updating for public distribution
  
.EXAMPLE
  powershell.exe .\auto_make.ps1
#>

param (
    [string]$config_root = ".\",
    [string]$config_filename = "config.ini",
    [string]$toolchain_root = "C:\ecp5-toolchain-windows-v1.6.9\bin",
    [switch]$import_only = $false,
    [switch]$as_job = $false
)

if($(Get-ExecutionPolicy) -ne "Bypass"){
    Set-ExecutionPolicy Bypass -Scope CurrentUser -Force
}

function read_config($config_root,$config_filename) 
{
    # Fetch all the info from our config file and return it in a hashtable
    $config_root = $(Get-ChildItem $config_root)[-1].DirectoryName
    Push-Location $config_root
    
    #$app_list = Get-ChildItem $config_root\app*\*main.c -Recurse
    $config_file = Get-ChildItem .\$config_filename
    
    if ($config_file.Count -lt 1) {
        Write-Host 'Unable to find config.ini!!!'
        return 0
    } else {
        $settings = Get-IniContent .\$config_filename
    }
    
    return $settings
}

function run_daemon()
{
    # Create our main app list from our config
    param (
        [string]$config_root,
        [string]$config_filename
        )
    # Read our configuration file
    $config = read_config -config_root $config_root -config_filename $config_filename

    # Create empty hashtable to use as a psuedo-object
    $main_file_list = @{}

    # Loop through the different apps in the configuration file 
    $config.Keys | % {

        # Set local variables
        $toolchain_root = $config.$_.toolchain_root
        $root= $config.$_.config_root_folder
        $drive = $config.$_.device_drive

        # Add item to our hashtable if needed
        if (!(Test-Path $root\main.c)) {
            Write-Host "Unable to find main.c for $root...Skipping..."
        }else{
            $main_file_list += @{
                "$($_)" = @{
                    "config_root_folder" = $root;
                    "file_info" = $(Get-ChildItem $root\main.c);
                    "prev_file_info" = $(Get-ChildItem $root\main.c);
                    "device_drive" = $drive
                    "name" = $_
                    "toolchain_root" = $toolchain_root
                }
            }
        }
    }    
    # Start the daemon. Using the $true allows us to just "Ctrl+C" to exit the script
    while($true) {
        $main_file_list.Keys | % { 

            # Get the main.c root folder
            $main_c_root = $main_file_list.$_

            # Set the main.c root folder as our root folder
            Push-Location $main_c_root.config_root_folder
            
            # Previously validated file exists when generating the config
            $main_file_list.$_.file_info = $(Get-ChildItem .\main.c)

            # This is the drive that is set in the config, usually the drive letter which is assigned on initial plugging in of the FPGAmeboy
            $drive = $main_c_root.device_drive

            # Write-Host $main_c_root.Keys
            # read-host "Drive: $drive"
            
            # Check to see if the file has changed
            # TODO: Change over to use the New-Object System.IO.FileSystemWatcher class to watch stuff
            if($main_file_list.$_.file_info.LastWriteTime -gt $main_file_list.$_.prev_file_info.LastWriteTime) {
                
                # Check the drive
                if(!(Get-PSDrive -Name $drive -ErrorAction SilentlyContinue)){
                    Write-Host "Attempting to mount the disk..."
                    Get-Disk -FriendlyName HADBADGE* | Get-Partition | Set-Partition -NewDriveLetter $drive -ErrorAction SilentlyContinue
                    Start-Sleep 2
                    if(!(Get-PSDrive -Name $drive -ErrorAction SilentlyContinue)){
                        Write-Host "Errors mounting the $drive drive!!!"
                        Write-Host "Have you tried turning it off and on again? ^_^" -BackgroundColor White -ForegroundColor Red
                        Continue
                    }
                }
                
                # Make the file
                Write-Host "Change Places! 
                Making ELF for $_..."

                # Add toolchain root to path variable
                $toolchain_root = $main_file_list.$_.toolchain_root
                
                if($env:Path -notlike ";$toolchain_root"){
                    $env:Path += ";$toolchain_root"
                }

                # Run the make command
                Invoke-Expression "powershell.exe make"

                # Remove the toolchain root from the path variable
                $env:PATH = $env:Path.Replace(";$toolchain_root","")
                
                # Push the file
                Write-Host "Uploading code to badge..."
                $filename = $main_c_root.name

                # Clear any previous versions of the command variable so we don't accidentally use previous data
                $command = ""
                $command = "Copy-Item '$($main_c_root.config_root_folder)\$filename.elf' '$drive`:\$filename.elf'"
                Write-Host "$command"
                Invoke-Expression "$command"
                if(!$error){
                    Write-Host "Successfully wrote new ELF to badge ^_^"
                }
                
                # Lick the .... Dismount the filesystem ^_^
                $vol = get-wmiobject -Class Win32_Volume | Where-Object{$_.Name -eq "$drive"+':\'}  
                $vol.DriveLetter = $null  
                $vol.Put()  
                $vol.Dismount($false, $false)
                
                # Set previous main.c file
                $main_file_list.$_.prev_file_info = $main_file_list.$_.file_info

            } else {
                Write-Host "Waiting for changes to $_ main.c file..."
            }
            Pop-Location
        }
        Start-Sleep 5
    }
}

function Get-IniContent ($filePath)
{
    # Good ol TechGallery
    # https://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91
    
    $ini = @{}
    switch -regex -file $FilePath
    {
        "^\[(.+)\]" # Section
        {
            $section = $matches[1]
            $ini[$section] = @{}
            $CommentCount = 0
        }
        "^(;.*)$" # Comment
        {
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = “Comment” + $CommentCount
            $ini[$section][$name] = $value
        }
        "(.+?)\s*=(.*)" # Key
        {
            $name,$value = $matches[1..2]
            $ini[$section][$name] = $value
        }
    }
    return $ini
}

if ($import_only) {
    Write-Host "Successfully imported functions from auto_make.ps1!!!"
} elseif ($as_job) {
    # Get the auto_make file location
    $filepath = $(Get-ChildItem .\auto_make.ps1).DirectoryName

    Write-Host "Starting the FPGAmeboy CI Daemon..."
    
    # Start the job
    $job = Start-Job -ArgumentList $filepath -ScriptBlock {
        Set-Location $args[0]
        powershell .\auto_make.ps1 | Out-File .\auto_make.log -Append
    } 
    # Instruct users on how to end this daemon
    Write-Host "To end this daemon, please run: `n
    Stop-Job -Id $($job.Id)`n"
} else {
    # Run the daemon
    Write-Host "Daemon starting up..."
    run_daemon -config_root $config_root -config_filename $config_filename
}