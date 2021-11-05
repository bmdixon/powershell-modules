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
        "stale" {
            $TTL = 90 #days
            $outPath = "$([Environment]::GetFolderPath("Desktop"))\StaleBranches.txt"
            $borderTime = (Get-Date).AddDays(-$TTL)
            git fetch origin
            $remoteBranches = git branch -a | Where-Object { $_ -like '*remotes/origin/*' } | ForEach-Object { $_.trim() }
            $remoteBranches = $remoteBranches | Where-Object { ($_ -notlike 'remotes/origin/HEAD*') -and ($_ -ne 'remotes/origin/master') -and ($_ -ne 'remotes/origin/main') -and ($_ -notlike 'remotes/origin/release*') -and ($_ -notlike 'remotes/origin/escrow*') }
            "`r`n#### $(Split-Path -Path $pwd -Leaf) ####" | Add-Content $outPath
            "$(git config --get remote.origin.url)/branches?_a=stale" | Add-Content $outPath
            foreach ($branch in $remoteBranches) {
                $branchName = ($branch.Split('/', 3))[2]
                $branchSHA = git rev-parse origin/$branchName
                $branchLastUpdate = [DateTime]::Parse($(git show -s --format=%ci $branchSHA))
                if ($branchLastUpdate -lt $borderTime) {
                    $branchName | Add-Content $outPath
                }
            }
        }
    }

    Pop-Location
    Write-Host
}

function Invoke-Git() {
    param(
        [ValidateSet("pull", "push", "prune", "reset", "fetch", "migratemain", "stale")]
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