function Set-HeadphoneVolume() {
    # https://github.com/frgnca/AudioDeviceCmdlets
    # Install-Module -Name AudioDeviceCmdlets

    Import-Module AudioDeviceCmdlets

    $IDS = @(
        "{0.0.0.00000000}.{349b91a8-939f-4bfe-b02c-f64bc642ccb1}" #AKG Headphones
        "{0.0.0.00000000}.{78be0308-b450-4955-84ca-9f1b01400d20}" # Jabra Elite 65 Earphones
        "{0.0.0.00000000}.{5b8905bc-d1b1-4627-b0da-527aea8c2850}" # Jabra Headset 
    )

    $NAMES = @(
       "Headphones (AKG Y50BT Stereo)" #AKG Headphones
       "Headphones (Jabra Elite 65t Stereo)" # Jabra Elite 65 Earphones
       "Headset Earphone (Jabra Link 370)" # Jabra Headset
    )

    function HeadphonesAreDefault {
        $DefaultPlayback = Get-AudioDevice -Playback

        return $IDS -contains $DefaultPlayback.ID -or $NAMES -contains $DefaultPlayback.Name
    }

    If (-Not (HeadphonesAreDefault)) {
        Get-AudioDevice -List | Where-Object { $_.Type -eq "Playback" } | ForEach-Object {
            if ($IDS -contains $DefaultPlayback.ID -or $NAMES -contains $DefaultPlayback.Name) {            
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