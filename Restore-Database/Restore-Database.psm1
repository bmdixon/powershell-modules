Import-Module SqlServer -ErrorAction Stop # Install-Module -Name SqlServer

function Restore-Database([string] $backupPath, [switch] $noUserRemap, [switch] $noShrink){
    $serverName = "(local)"

    if ($backupPath) {

## – Loading SQL Server SMO assemblied needed:
# $Assem = (
# #"$PSScriptRoot\smo\Microsoft.SqlServer.Smo.dll"
# #"$PSScriptRoot\smo\Microsoft.SqlServer.SmoExtended.dll"
# #"$PSScriptRoot\smo\Microsoft.SqlServer.ConnectionInfo.dll",
# # "$PSScriptRoot\smo\Microsoft.SqlServer.SqlEnum.dll"
# );
# Add-Type -path $Assem;

        try {
            [Microsoft.SqlServer.Management.Smo.Server]$server = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $serverName
            
            #Progress bar handlers
            $percentEventHandler = [Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] { Write-Progress -Activity "Restoring database" -Status $_.Percent -PercentComplete $_.Percent }
         
            $backupDevice = New-Object ("Microsoft.SqlServer.Management.Smo.BackupDeviceItem") ($backupPath, "File")
            $smoRestore = New-Object Microsoft.SqlServer.Management.Smo.Restore
    
            $smoRestore.NoRecovery = $false;
            $smoRestore.ReplaceDatabase = $true;
            $smoRestore.Action = "Database"
            $smoRestore.PercentCompleteNotification = 1;
            $smoRestore.FileNumber = 0
            $smoRestore.Devices.Add($backupDevice)
            $smoRestore.add_PercentComplete($percentEventHandler)
    
            # Get the details from the backup device for the database name and output that
            $smoRestoreDetails = $smoRestore.ReadBackupHeader($server)
            $databaseName = $smoRestoreDetails.Rows[0]["DatabaseName"]
        
            $customDatabaseName = Read-Host 'Database name (Default:'$databaseName')'
    
            if ($customDatabaseName) {
                $databaseName = $customDatabaseName    
            }
        
            $dbLogicalName = ""
            $logLogicalName = ""
    
            $logicalFileNameList = $smoRestore.ReadFileList($server)
            foreach ($row in $logicalFileNameList) { 
                $smoRestore.Database = $databaseName
    
                $fileType = $row["Type"].ToUpper()
                if ($fileType.Equals("D")) {
                    $dbLogicalName = $row["LogicalName"]
                    $smoRestoreFile = New-Object("Microsoft.SqlServer.Management.Smo.RelocateFile") 
                    $smoRestoreFile.LogicalFileName = $dbLogicalName
                    $smoRestoreFile.PhysicalFileName = $server.Information.MasterDBPath + "\" + $dbLogicalName + "_Data.mdf"
                }
                elseif ($fileType.Equals("L")) {
                    $logLogicalName = $row["LogicalName"]
                    $smoRestoreLog = New-Object("Microsoft.SqlServer.Management.Smo.RelocateFile")
                    $smoRestoreLog.LogicalFileName = $logLogicalName
                    $smoRestoreLog.PhysicalFileName = $server.Information.MasterDBPath + "\" + $dbLogicalName + "_Log.ldf"
                }
            }
    
            # Kill any connections to the DB
            $server.KillAllProcesses($databaseName)
    
            Write-Host "[Restore starting]"
            $smoRestore.SqlRestore($server)
            Write-Progress -Activity "Restoring database" -Status "Complete" -Completed
            Write-Host "[Restore complete]" -foregroundcolor green 
        
            if (!$noUserRemap.IsPresent) {
                # Remap orphaned logins
                Write-Host "[Remapping orphaned login's]"
                $instance = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName
                $database = $instance.Databases[$databaseName]
    
                $listObject = invoke-sqlcmd -ServerInstance $instance.Name -database $database.Name -query "EXEC sp_change_users_login 'Report'"
            
                if ($listObject -eq $null) {
                    Write-Host "No users found to remap, these will need to be created manually or through running Migrations." -foregroundcolor red 
                }
                else {
                    foreach ($login in $listObject) {
                        $loginName = $login.UserName
                        if ($instance.Logins.Contains($loginName)) {
                            invoke-sqlcmd -ServerInstance $instance.Name -database $database.Name -query "EXEC sp_change_users_login 'Update_One', '$loginName', '$loginName'"
                            Write-Host " Remapped: '$loginName'." -foregroundcolor green
                        }
                        else {
                            Write-Host " Not remapped: '$loginName'." -foregroundcolor yellow 
                        }
                    }
                }
            }
    
            if (!$noShrink.IsPresent) {
                # Shrink database
                Write-Host "[Shrinking database]"
                $instance = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName
                $database = $instance.Databases[$databaseName]
                $database.Shrink(20, [Microsoft.SqlServer.Management.Smo.ShrinkMethod]'Default')
            }
        }
        catch {
            $err = $_.Exception
            Write-Host $err.Message
            while ( $err.InnerException ) {
                $err = $err.InnerException
                Write-Host $err.Message
            }
        }
        finally {
            Write-Host -NoNewLine 'Press any key to close...';
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        }
    }
    else {
        Write-Host "No path supplied"
    }
}