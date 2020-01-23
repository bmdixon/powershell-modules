function Write-Log() {
    $date = Get-Date -format "yyyy-MM-dd"

    $message = "$($date) | $($args)"

    Add-Content -Value $message -Path "$($env:OneDriveCommercial)\\Build Automation\\2020.log"

    Write-Host "logged."
}
