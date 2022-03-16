function Invoke-CustomCommandInternal {
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
            git fetch
            if ($null -ne (npm list -g --depth=0 | Select-String git-removed-branches)) {
                git removed-branches --prune --force
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
        "ports" {   
            git checkout -b 'feature/update-ports'

            $Ports = $script:config.Ports

            Get-ChildItem -r -Exclude *.exe `
            | Where-Object { $_ -notmatch 'node_modules' }`
            | Where-Object { $_ -notmatch 'packages' }`
            | Where-Object { $_ -notmatch 'bin' }`
            | Where-Object { $_ -notmatch 'obj' }`
            | Where-Object { $_ -notmatch '.angular' }`
            | Where-Object { $_ -notmatch '.git' }`
            | Where-Object { !$_.PSIsContainer }`
            | foreach-object {
                $filename = $_.FullName
                $Ports | ForEach-Object {
                    $file = Get-Content $filename
                    $oldPort = $_.old
                    $newPort = $_.new
                    $containsWord = $file | ForEach-Object { $_ -match $oldPort }
                    If ($containsWord -contains $true) {
                        ($file) | foreach-object {
                            $_ -replace $oldPort, $newPort
                        } | set-content $filename
                    }
                }
            }

            git add *
            git commit -m "Update ports"
            git push --set-upstream origin feature/update-ports
        }
        "sqlscript" {
            If (Test-Path "scripts\configure-identity-server.sql") {
                Write-Host "Running configure-identity-server.sql for $(Split-Path -Path $pwd -Leaf)"
                Invoke-Sqlcmd -ServerInstance $script:config.DBInstance -Database $script:config.AuthDbName -InputFile "scripts\configure-identity-server.sql"
            }
            If (Test-Path "scripts\configure-user-management.sql") {
                Write-Host "Running configure-user-management.sql for $(Split-Path -Path $pwd -Leaf)"
                Invoke-Sqlcmd -ServerInstance $script:config.DBInstance -Database $script:config.UserManagementDbName  -InputFile "scripts\configure-user-management.sql"
            }
        }
    }

    Pop-Location
    Write-Host
}

function Invoke-CustomCommand() {
    param(
        [ValidateSet("pull", "push", "prune", "reset", "fetch", "migratemain", "stale", "ports", "sqlscript")]
        $Action = "pull",

        [string]
        $Branch = "main"
    )
    # Load settings from config file
    $script:config = Get-Content $PSScriptRoot\config.json | ConvertFrom-Json
    
    $Repositories = Get-ChildItem -Directory | Select-Object Name

    $Repositories | ForEach-Object {
        $RepositoryName = $_.Name

        $Skip = @(
        )
        if ($Skip.Contains($RepositoryName)) {
        }
        else {
            Invoke-CustomCommandInternal -Path $RepositoryName -Action $Action -Branch $Branch
        }
    }
}

Export-ModuleMember Invoke-CustomCommand