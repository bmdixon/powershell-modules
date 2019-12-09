Import-Module SqlServer -ErrorAction Stop
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
    
    $script:ArchivePaths = @(
        @{
            Source      = "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\Backup"
            Name        = "SQL_Backup"
            ProcessName = ""
        },
        @{
            Source      = "$($env:LOCALAPPDATA)\Google\Chrome\User Data\Default"
            Name        = "Chrome"
            ProcessName = "chrome"
        },
        @{
            Source      = "$env:USERPROFILE\.vscode"
            Name        = "VSCode"
            ProcessName = "code"
        },
        @{
            Source      = $FilesBackupFolder
            Name        = "Files"
            ProcessName = ""
        },
        @{
            Source      = $DatabaseBackupFolder
            Name        = "Databases"
            ProcessName = ""
        }
    )

    $script:ArchivePaths | ForEach-Object {
        if ($_.ProcessName -and $null -ne (Get-Process $_.ProcessName -ErrorAction SilentlyContinue)) {
            Write-Host "Waiting on $($_.ProcessName)... Please close any open instances..."
            Wait-Process -InputObject (Get-Process $_.ProcessName)
            Write-Host "$($_.ProcessName) closed, continuing..."
        }

        $dest = "$($_.Name).7z"

        # Compress-Archive has a file size limit of 2GB so use Compress7zip instead
        # Compress-Archive -Path $_.Source -DestinationPath $dest -Force -CompressionLevel Optimal
        Compress-7Zip -Path $_.Source -ArchiveFileName $dest -CompressionLevel Normal
        if ($null -ne $BackupLocation) {
            Move-Item -Path "$($dest)" -Destination $BackupLocation -Force
        }
    }
}

function Backup-Settings() {
    Param (
        [ValidateNotNullOrEmpty()]
        [String] $FilesBackupFolder
    )

    $script:Settings = @(
        @{
            Source = "$env:USERPROFILE\AppData\Roaming\Code\User"
            Dest   = "vscode"
        },
        @{
            Source = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.Powershell_profile.ps1"
            Dest   = "WindowsPowerShell"
        },
        @{
            Source = "$env:USERPROFILE\Documents\PowerShell\Microsoft.Powershell_profile.ps1"
            Dest   = "PowerShell"
        },
        @{
            Source = "$env:USERPROFILE\appdata\local\microsoft\visualstudio\15.0_95eb5983\Settings\CurrentSettings.vssettings"
            Dest   = "VisualStudio2017"
        },
        @{
            Source = "$env:USERPROFILE\appdata\local\microsoft\visualstudio\16.0_379a93ea\settings\CurrentSettings.vssettings"
            Dest   = "VisualStudio2019"
        },
        @{
            Source = "$env:USERPROFILE\Documents\SQL Server Management Studio\Templates\XEventTemplates\Debug.xml"
            Dest   = "SQLExtendedEvents"
        },
        @{
            Source = "$env:USERPROFILE\Documents\SQL Server Management Studio\ViewSetting.viewsetting"
            Dest   = "SQLExtendedEvents"
        },
        @{
            Source = "$env:USERPROFILE\.gitconfig"
            Dest   = "Git"
        },
        @{
            Source = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\profiles.json"
            Dest   = "Terminal"
        }
    )

    $script:Settings | ForEach-Object {
        if (Test-Path $_.Source) {
            $source = Get-Item $_.Source
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
            Write-Host "$($_.Source)" not found
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
    Param (
        [ValidateNotNullOrEmpty()]
        [String] $BackupLocation = "$($env:OneDriveCommercial)\Backups",
        [ValidateNotNullOrEmpty()]
        [String] $FilesBackupFolder = ".\Files",
        [ValidateNotNullOrEmpty()]
        [String] $DatabaseBackupFolder = "Databases"
    )

    Push-Location # Store current working directory
    
    $tempPath = $(New-TemporaryDirectory)
    Push-Location $tempPath
    Backup-Settings $FilesBackupFolder
    Backup-Databases $tempPath $DatabaseBackupFolder
    Write-Archives $BackupLocation $FilesBackupFolder $DatabaseBackupFolder
    Pop-Location
    Remove-Item $tempPath -Recurse -Force
    
    Pop-Location # Restore working directory
    Write-Host
    Write-Host Press any key to exit...
    Read-Host
}

Export-ModuleMember -Function Backup-Data