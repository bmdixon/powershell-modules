function Write-ToLog() {
    $date = Get-Date -format "yyyy-MM-dd"
    $year = (Get-Date).Year

    $message = "$($date) | $($args)"

    Add-Content -Value $message -Path "$($env:OneDriveCommercial)\\Build Automation\\$($year).log"

    Write-Host "logged."
}
