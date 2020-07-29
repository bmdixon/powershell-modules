Import-Module SqlServer -ErrorAction Stop # Install-Module -Name SqlServer
Import-Module 7Zip4Powershell # Install-Module -Name 7Zip4Powershell

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    return New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

function Write-Archives() {
    Param (
        [ValidateNotNullOrEmpty()]
        [String] $BackupLocation,
        [ValidateNotNullOrEmpty()]
        [String] $FilesBackupFolder,
        [ValidateNotNullOrEmpty()]
        [String] $DatabaseBackupFolder
    )
    
    $script:config.ArchivePaths | ForEach-Object {
        if ($_.ProcessName -and $null -ne (Get-Process $_.ProcessName -ErrorAction SilentlyContinue)) {
            Write-Host "Waiting on $($_.ProcessName)... Please close any open instances..."  -ForegroundColor Red
            Wait-Process -InputObject (Get-Process $_.ProcessName)
            Write-Host "$($_.ProcessName) closed, continuing..."  -ForegroundColor Yellow
        }

        $source = $ExecutionContext.InvokeCommand.ExpandString($_.Source)
        if ($_.Use7zip) {
            $dest = "$($_.Name).7z"
        
            # Compress-Archive has a file size limit of 2GB so use Compress7zip instead
            # Compress-Archive -Path $_.Source -DestinationPath $dest -Force -CompressionLevel Optimal
            Compress-7Zip -Path $source -ArchiveFileName $dest -CompressionLevel Normal
            if ($null -ne $BackupLocation) {
                Move-Item -Path "$($dest)" -Destination $BackupLocation -Force
            }
        }
        else {
            $dest = "$($_.Name).zip"
        
            Compress-Archive -Path $source -DestinationPath $dest -Force -CompressionLevel Optimal
            if ($null -ne $BackupLocation) {
                Move-Item -Path "$($dest)" -Destination $BackupLocation -Force
            }
        }
    }
}

function Backup-Settings() {
    Param (
        [ValidateNotNullOrEmpty()]
        [String] $FilesBackupFolder
    )

    $script:config.SettingsPaths | ForEach-Object {
        $sourcePath = $ExecutionContext.InvokeCommand.ExpandString($_.Source)
        if (Test-Path $sourcePath) {
            $source = Get-Item $sourcePath
            $dest = [io.path]::combine($FilesBackupFolder, $_.Dest, $source.Name)

            if ($source -is [System.IO.DirectoryInfo] -And (-Not (Test-Path $dest))) {
                mkdir -path $dest | Out-Null
            }

            if ($source -is [System.IO.DirectoryInfo]) {
                # Needed so that it doesn't copy underneath the destination folder from the second run
                $source = [io.path]::combine($source, "*")
            }
            else {
                New-Item -ItemType File -Path $dest -Force | Out-Null
            }

            Copy-Item $source $dest -Recurse -Force
        }
        else {
            Write-Host "$($sourcePath)" not found
        }
    }
}

function Backup-Databases() {
    Param (
        [ValidateNotNullOrEmpty()]
        [String] $BackupLocation,
        [ValidateNotNullOrEmpty()]
        [String] $DatabaseBackupFolder
    )

    $Date = (Get-Date -format "yyyyMMddHHmm")
    $backupPath = [io.path]::combine($BackupLocation, $DatabaseBackupFolder)
    New-Item -Path $backupPath -ItemType "directory" | Out-Null
    $Acl = Get-Acl $backupPath
    $Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("MSSQLServer", "FullControl", "Allow")
    $Acl.SetAccessRule($Ar)
    Set-Acl $backupPath $Acl

    Push-Location "SQLSERVER:\SQL\localhost\DEFAULT\Databases"
    foreach ($database in (Get-ChildItem)) {
        $dbName = $database.Name
        Write-Host "Backing up $dbName..."
        Backup-SqlDatabase -Database $dbName -CompressionOption On -BackupFile "$backupPath\$dbName-$Date.bak"
    }
    Pop-Location

    Push-Location "SQLSERVER:\SQL\(localdb)\mssqllocaldb\Databases"
    foreach ($database in (Get-ChildItem)) {
        $dbName = $database.Name
        Write-Host "Backing up $dbName..."
        Backup-SqlDatabase -Database $dbName -BackupFile "$backupPath\$dbName-$Date.bak"
    }
    Pop-Location

}
function Backup-Data() {
    Param ()

    # Load settings from config file
    $script:config = Get-Content $PSScriptRoot\config.json | ConvertFrom-Json

    $BackupDestination = $ExecutionContext.InvokeCommand.ExpandString($script:config.BackupLocation)

    if (!(Test-Path $BackupDestination)) {
        New-Item -ItemType Directory -Force -Path $BackupDestination | Out-Null
    }

    $FilesBackupFolder = ".\Files"
    $DatabaseBackupFolder = "Databases"
    Push-Location # Store current working directory
    
    $tempPath = $(New-TemporaryDirectory)
    Push-Location $tempPath
    Backup-Settings $FilesBackupFolder
    Backup-Databases $tempPath $DatabaseBackupFolder
    Write-Archives $BackupDestination $FilesBackupFolder $DatabaseBackupFolder
    Pop-Location
    Remove-Item $tempPath -Recurse -Force
    
    Pop-Location # Restore working directory
    Write-Host
    Write-Host Press any key to exit...
    Read-Host
}

Export-ModuleMember -Function Backup-Data