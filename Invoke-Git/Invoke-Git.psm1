function Invoke-Git-Status {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        [ValidateSet("pull", "push", "prune", "reset", "")]
        $Action,
        [Parameter(Mandatory = $true)]
        [string]
        $Branch
    )
    
    Push-Location $Path
    Write-Host (Split-Path $Path -Leaf)

    git checkout $Branch

    switch ($Action) {
        "pull" {
            git pull
        }
        "push" {
            git push
        }
        "prune" {
            if ($null -ne (npm list -g --depth=0 | Select-String git-removed-branches)) {
                git removed-branches --prune
            }
        }
        "reset" {
            git reset HEAD --hard
        } 
        "fetch" {
            git fetch
        }
    }

    Pop-Location
    Write-Host
}

function Invoke-Git() {
    param(
    [ValidateSet("pull", "push", "prune", "reset", "")]
    $Action,

    [string]
    $Branch = "master"
)
    $Repositories = Get-ChildItem -Directory | Select-Object Name

    $Repositories | ForEach-Object {
        $RepositoryName = $_.Name

        Invoke-Git-Status -Path $RepositoryName -Action $Action -Branch $Branch
    }
}