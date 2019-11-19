param (
    [string]$app_root = "c:\hadbadge2019_fpgasoc",
    [string]$toolchain_root = "C:\2019_SuperCon\ecp5-toolchain-windows-v1.6.9\bin"
)

function read_config($app_root,$config_filename = "config.ini") 
{
    
    Push-Location $app_root
    
    #$app_list = Get-ChildItem $app_root\app*\*main.c -Recurse
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
    param (
            [string]$app_root,
            [string]$toolchain_root
        )
        
        # Add toolchain root to path variable
        if($env:Path -notlike $toolchain_root){
            $env:Path += ";$toolchain_root"
        }
        
        $config = read_config($app_root)
        $main_file_list = @{}
        $config.Keys | % {
            $root= $config.$_.app_root_folder
            $drive = $config.$_.device_drive

            Push-Location $root
            
            if (!(Test-Path $root\main.c)) {
                Write-Host "Unable to find main.c for $root...Skipping..."
            }else{
                $main_file_list += @{
                    "$($_)" = @{
                        "app_root_folder" = $root;
                        "file_info" = $(Get-ChildItem .\main.c);
                        "prev_file_info" = $(Get-ChildItem .\*)[-1];
                        "device_drive" = $drive
                        "name" = $_
                    }
                }
            }
        }    
        
        while($true) {
            $main_file_list.Keys | % { 
                $item = $main_file_list.$_

                Push-Location $item.app_root_folder
                
                $main_file_list.$_.file_info = $(Get-ChildItem .\main.c)
                $drive = $item.device_drive
                # Write-Host $item.Keys
                # read-host "Drive: $drive"
                
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
                    Write-Host "Change Places! \nMake the ELF!..."
                    Invoke-Expression "powershell.exe make"
                    
                    # Push the file
                    Write-Host "Uploading code to badge..."
                    $filename = $item.name
                    # Read-Host $filename
                    $command = ""
                    $command = "Copy-Item '$($item.app_root_folder)\$filename.elf' '$drive`:\$filename.elf'"
                    Write-Host "$command"
                    Invoke-Expression "$command"
                    if(!$error){
                        Write-Host "Successfully wrote new ELF to badge ^_^"
                    }
                    
                    # Lick the .... Dismount the filesystem ^_^
                    $vol = get-wmiobject -Class Win32_Volume | where{$_.Name -eq "$drive"+':\'}  
                    $vol.DriveLetter = $null  
                    $vol.Put()  
                    $vol.Dismount($false, $false)
                    
                    # Set previous main.c file
                    $main_file_list.$_.prev_file_info = $main_file_list.$_.file_info
                } else {
                    Write-Host "Waiting for changes to $_ main.c file..."
                }
            }
            Start-Sleep 5
        }
    }

function Get-IniContent ($filePath)
{
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
    
# Run the daemon
Write-Host "Daemon starting up..."
run_daemon -app_root $app_root -toolchain_root $toolchain_root