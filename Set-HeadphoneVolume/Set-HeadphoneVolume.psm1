function Set-HeadphoneVolume() {
    # https://github.com/frgnca/AudioDeviceCmdlets

    Push-Location "$($profile | Split-Path)\Modules\AudioDeviceCmdlets"
    Import-Module AudioDeviceCmdlets
    $HeadphonesID = "{0.0.0.00000000}.{349b91a8-939f-4bfe-b02c-f64bc642ccb1}"
    $HeadphonesName = "Headphones (AKG Y50BT Stereo)"
    $JabraHeadphonesID = "{0.0.0.00000000}.{78be0308-b450-4955-84ca-9f1b01400d20}"
    $JabraHeadphonesName = "Headphones (Jabra Elite 65t Stereo)"

    function HeadphonesAreDefault {
        $DefaultPlayback = Get-AudioDevice -Playback

        return ($DefaultPlayback.ID -eq $HeadphonesID `
                -or $DefaultPlayback.Name -eq $HeadphonesName `
                -or $DefaultPlayback.ID -eq $JabraHeadphonesID `
                -or $DefaultPlayback.Name -eq $JabraHeadphonesName)
    }

    If (-Not (HeadphonesAreDefault)) {
        Get-AudioDevice -List | Where-Object { $_.Type -eq "Playback" } | ForEach-Object {
            if ($_.ID -eq $HeadphonesID -or $_.Name -eq $HeadphonesName -or$_.ID -eq $JabraHeadphonesID -or $_.Name -eq $JabraHeadphonesName ) {            
                Set-AudioDevice -ID $_.ID | Out-Null        
            }
        }
    }

    # Check again in case we changed the default in the block above
    If (HeadphonesAreDefault) {
        Set-AudioDevice -PlaybackMute 0
        Set-AudioDevice -PlaybackVolume 20
    }
    else {
        Set-AudioDevice -PlaybackMute 1
    }

    Pop-Location
}