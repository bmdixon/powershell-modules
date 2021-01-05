function Invoke-Git-Status {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        $Action,
        [Parameter(Mandatory = $true)]
        [string]
        $Branch
    )
    
    Push-Location $Path
    Write-Host (Split-Path $Path -Leaf) -ForegroundColor Green

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
            else {
                Write-Error "npm package 'git-removed-branches' not found" -ForegroundColor Red
            }
        }
        "reset" {
            git reset HEAD --hard
        } 
        "fetch" {
            git fetch
        }
        "migratemain" {
            git checkout master
            git branch -m master main
            git fetch
            git branch --unset-upstream
            git branch -u origin/main
            git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
        }
    }

    Pop-Location
    Write-Host
}

function Invoke-Git() {
    param(
    [ValidateSet("pull", "push", "prune", "reset", "fetch", "migratemain")]
    $Action = "pull",

    [string]
    $Branch = "main"
)
    $Repositories = Get-ChildItem -Directory | Select-Object Name

    $Repositories | ForEach-Object {
        $RepositoryName = $_.Name

        Invoke-Git-Status -Path $RepositoryName -Action $Action -Branch $Branch
    }
}

Export-ModuleMember Invoke-Git