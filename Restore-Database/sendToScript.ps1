param([string] $backupPath, [switch]$noUserRemap, [switch]$noShrink)

Import-Module "$PSScriptRoot\Restore-Database.psm1"
Restore-Database $backupPath -noUserRemap:$noUserRemap -noShrink:$noShrink