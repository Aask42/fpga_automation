param (
    [string]$app_root = "c:\hadbadge2019_fpgasoc",
    [string]$toolchain_root = "C:\2019_SuperCon\ecp5-toolchain-windows-v1.6.9\bin"
)

$env:Path += ";$toolchain_root"
$root = "$app_root"

$project_file_prev = (Get-ChildItem "$root\*" -ErrorAction SilentlyContinue | Sort-Object -Property LastWriteTime)[-1]

while($true){

    Push-Location $root
    $project_file_curr = (Get-ChildItem ".\main.c" | Sort-Object -Property LastWriteTime)[-1]

    if($project_file_curr.LastWriteTime -ne $project_file_prev.LastWriteTime){
        # Check the drive
        if(!(Get-PSDrive -Name D -ErrorAction SilentlyContinue)){
            Write-Host "Attempting to mount the disk..."
            Get-Disk -FriendlyName HADBADGE* | Get-Partition | Set-Partition -NewDriveLetter D -ErrorAction SilentlyContinue
            Start-Sleep 2
            if(!(Get-PSDrive -Name D -ErrorAction SilentlyContinue)){
                Write-Host "Errors mounting the D drive!!!"
                Write-Host "Have you tried turning it off and on again? ^_^" -BackgroundColor White -ForegroundColor Red
                Continue
            }
        }
        # Make the file
        Write-Host "Change Places! \nMake the ELF!..."
        Invoke-Expression "powershell.exe make"

        # Push the file
        Write-Host "Uploading code to badge..."
        Copy-Item "$root\$filename.elf" "D:\$filename.elf"
        if(!$error){
            Write-Host "Successfully wrote new ELF to badge ^_^"
        }
        # Lick the .... Dismount the filesystem ^_^
        $vol = get-wmiobject -Class Win32_Volume | where{$_.Name -eq 'D:\'}  
        $vol.DriveLetter = $null  
        $vol.Put()  
        $vol.Dismount($false, $false)

        # Set previous main.c file
        $project_file_prev = (Get-ChildItem "$root\main.c" | Sort-Object -Property CreationTime)[-1]
        Pop-Location
    }else{
        Write-Host "Waiting for next save..."
    }

    Start-Sleep 5
}

function read_config($app_root,$config_filename = "config.ini"){

    Push-Location $app_root

    #$app_list = Get-ChildItem $app_root\app*\*main.c -Recurse
    $config_file = Get-ChildItem .\$config_filename

    if($config_file.Count -lt 1){
        Write-Host 'Unable to find .\app* folder(s)!'
    }else{
        $settings = Get-IniContent .\$config_filename
    }

    return $settings
}

function Get-IniContent ($filePath)
{
    $ini = @{}
    switch -regex -file $FilePath
    {
        “^\[(.+)\]” # Section
        {
            $section = $matches[1]
            $ini[$section] = @{}
            $CommentCount = 0
        }
        “^(;.*)$” # Comment
        {
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = “Comment” + $CommentCount
            $ini[$section][$name] = $value
        }
        “(.+?)\s*=(.*)” # Key
        {
            $name,$value = $matches[1..2]
            $ini[$section][$name] = $value
        }
    }
    return $ini
}