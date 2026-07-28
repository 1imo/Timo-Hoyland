class SourceControl {
    hidden [object]$Backend
    hidden [string]$WorkDir
    [string]$Env
    [string]$Root

    SourceControl([string]$RemoteUrl) {
        if (-not $env:ENV) { throw '[!] ENV required' }
        $this.Env = switch ($env:ENV.ToLower()) {
            { $_ -in @('dev', 'development') } { 'test' }
            'live' { 'live' }
            'test' { 'test' }
            default { throw "[!] env must be live or test (got $env:ENV)" }
        }

        if ([string]::IsNullOrWhiteSpace($RemoteUrl)) { throw '[!] remote url required' }

        $repoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $repoRoot) { throw '[!] not in a git repo' }
        $this.Root = (Resolve-Path $repoRoot).Path

        $localPath = $this.Root
        if ($this.UsesTempClone($RemoteUrl)) {
            $this.WorkDir = Join-Path ([IO.Path]::GetTempPath()) "iac-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
            $localPath = $this.WorkDir
        }

        $repo = $this.RepoPath($RemoteUrl)
        if ($this.Env -eq 'live') {
            $this.Backend = New-Object GitHub $RemoteUrl, $localPath
        }
        else {
            $this.Backend = New-Object GitLab $RemoteUrl, $localPath
        }
        $this.Backend.Repo = $repo
    }

    hidden [string] RepoPath([string]$Url) {
        if ($Url -match '^ssh://git@([^:/]+):[0-9]+/(.+)$') { return $Matches[2] -replace '\.git$', '' }
        if ($Url -match '^git@([^:]+):(.+)$') { return $Matches[2] -replace '\.git$', '' }
        if ($Url -match '^https?://([^/]+)/(.+)$') { return $Matches[2] -replace '\.git$', '' }
        throw "[!] cannot parse git URL: $Url"
    }

    hidden [bool] UsesTempClone([string]$RemoteUrl) {
        $names = git -C $this.Root remote 2>$null
        if (-not $names) { return $true }
        foreach ($name in $names) {
            $url = (git -C $this.Root remote get-url $name 2>$null).Trim()
            if ($url -eq $RemoteUrl) { return $false }
        }
        return $true
    }

    [void] Cleanup() {
        if ($this.WorkDir -and (Test-Path $this.WorkDir)) {
            Remove-Item -Recurse -Force $this.WorkDir -ErrorAction SilentlyContinue
            $this.WorkDir = $null
        }
    }

    [void] Sync() { $this.Backend.Sync() }

    [void] WriteFile([string]$RelativePath, [string]$SourcePath) {
        $this.Backend.WriteFile($RelativePath, $SourcePath)
    }

    [void] WriteContent([string]$RelativePath, [string]$Content) {
        $this.Backend.WriteContent($RelativePath, $Content)
    }

    [void] CommitAndPush([string]$Message) { $this.Backend.CommitAndPush($Message) }

    [string] CreateBranch([string]$Name, [string]$RemoteName) {
        return $this.Backend.CreateBranch($Name, $RemoteName)
    }

    [void] PreparePullRequestBranch([string]$BranchName, [string]$RemoteName, [string]$TargetBranch) {
        $repo = $this.Backend.LocalPath
        & git -C $repo fetch $RemoteName $TargetBranch 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] git fetch failed: $RemoteName $TargetBranch" }

        $previous = (& git -C $repo branch --show-current 2>$null).Trim()
        & git -C $repo checkout $BranchName 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] git checkout failed: $BranchName" }

        $target = "$RemoteName/$TargetBranch"
        & git -C $repo merge-base HEAD $target 2>$null | Out-Null
        if ($LASTEXITCODE -eq 1) {
            Write-Host "[i] unrelated histories — merging $target into $BranchName"
            & git -C $repo merge $target --allow-unrelated-histories -m "Merge $TargetBranch into $BranchName" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                & git -C $repo merge --abort 2>$null | Out-Null
                if ($previous) {
                    & git -C $repo checkout $previous 2>&1 | Out-Null
                }
                throw "[!] git merge failed: $target into $BranchName"
            }
        }
        elseif ($LASTEXITCODE -ne 0) {
            throw "[!] git merge-base failed: HEAD $target"
        }

        if ($previous) {
            & git -C $repo checkout $previous 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "[!] git checkout failed: $previous" }
        }
    }

    [void] PushBranch([string]$RemoteName, [string]$BranchName) {
        $this.Backend.PushBranch($RemoteName, $BranchName)
    }

    [string] CreatePullRequest([string]$SourceBranch, [string]$TargetBranch, [string]$Title) {
        return $this.Backend.CreatePullRequest($SourceBranch, $TargetBranch, $Title)
    }

    [void] SetCiVars([hashtable]$Vars) {
        if ($this.Env -eq 'live') {
            foreach ($key in $Vars.Keys) {
                $val = [string]$Vars[$key]
                if ($key -match 'TOKEN|SECRET') {
                    $this.Backend.SetSecret($this.Backend.Repo, $key, $val)
                }
                else {
                    $this.Backend.SetVariable($this.Backend.Repo, $key, $val)
                }
            }
            return
        }
        foreach ($key in $Vars.Keys) {
            $masked = $key -match 'TOKEN|SECRET'
            $this.Backend.SetVariable($key, [string]$Vars[$key], $masked, $false)
        }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAEk/17EOaOwwBg
# 1lBhJs8KAN7aKXrfBgtrWgACUQF5VaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
# R/b0C5YxX/PjyDAKBggqhkjOPQQDAjAgMR4wHAYDVQQDExVOb3R0SW5mcmEgSW50
# ZXJuYWwgQ0EwHhcNMjYwNzI3MjM0NDE1WhcNMjcwNzI3MjM0NDE1WjAlMSMwIQYD
# VQQDExpOT1RUSU5GUkEgTElNSVRFRCBTT0ZUV0FSRTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAKRICuzioM/pLsdWW/uV0Hl7Y5FHNBPTEl3X/oGK+BAi
# kC0es0CLXLykWpsJ/f9ldyyHlMzwUR1zEIhCZXEyo+uqQ8B1yWke7rQ4wkWE6/DU
# htCLSiySkf/KB389/ptcEM+jJ48DQGi0+8K6QQ02vEOAQKLfxA4Rrnl5BYY+nnNs
# Rpa+B6K40i/aFAsc60gbG3SGQePzuHHbPl6CE5AzQNY2WBpY77aonZ830RM5AsS4
# Xe7P8cDJ7Gahw6ZjLEriCaR3xBytPy63RiZdW8upuQ0AIFz4/8GVRYuOJ1wGeU53
# b0OZhj/6Z481Zry0VcBvGfHidIVkQKbWZQ2QWdkSBbSAIR92tKpSqSDy4VQYQ4RO
# l3NY/QHkJsAl6EGzQ514P+qUzkSyxgSNHZFCknqTu6gXtemaCUC7z/eLZDibw+mg
# yAuyLTZoeAlDPaHT4FOPfB8pn6UuGb/LwJwFlBHGAkaYlfAkx3BJYIsQpfPwKxfN
# Ufds8LMYArJlFZJnJ1EmJSE+qIu0cN7SyuFDAdGszrVjltYswzAfhE0NRQQm4HiG
# CWG9ZxDD1TxbhvEecgJCOMy/dZCcjEEzq4wZxSVPicn0QowKDWHy1GpgdR3pT+Ok
# zuIBpfEeXW5uW9e0yoOzwOnh1XCRp8hv+B4l4RvTEl3ccZ+PcmAcsLHODqvW4vmT
# AgMBAAGjQTA/MA4GA1UdDwEB/wQEAwIFoDAMBgNVHRMBAf8EAjAAMB8GA1UdIwQY
# MBaAFKF88Blhy5xs0hQfn4medNFL3FoXMAoGCCqGSM49BAMCA0gAMEUCIQDwlWDa
# ojXZG8h5O2XzW/IG9h+GUKAmx8SCd7NuhB0SUAIgJkQlleqNoGkPuDyi08MuVI36
# ezJPirlP+IxtyaFnz10xggMHMIIDAwIBATA1MCAxHjAcBgNVBAMTFU5vdHRJbmZy
# YSBJbnRlcm5hbCBDQQIRAJ+3kgs9xEf29AuWMV/z48gwCwYJYIZIAWUDBAIBoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIGHcl7RG
# Jw6sihzGOaiZRFgLIX3yeKcwgFmselNKs3M8MAsGCSqGSIb3DQEBAQSCAgABTnLo
# wBGybVhJJfKPTPjRvKE0OCWJudK3g9lG1SnE34DI45KvBiVX2hFjZBtckK9O3Yrp
# sc5WjzS5U4HQxa1dBg6GqkHwBNI3rChFf7dLiwAp38F2uGQz4saJnqdzBa0l7Yai
# HiRHGQvX1OD/v8xiEYnwrk0tIMSG900xCdaM0CE/PLxV5W7iE8s5cjSRX7DfN+8T
# EZoq8nLuHriV5FYtscRBYap+3hCa0ug6XFSVBaC9sLcCz8rfZeAUtUwDVqU/8cRK
# z6HkgyYbd8ot6n1ZJUya+laO9f3dvp3CyAZYsAIwNmhGQXL+8o55SblujhLk9w7r
# miBtgM1s+fy7BAiIHzlU8h99letwcjTGFOeLBuC7EYTNN5N7FyWRv13Abg3xgNUE
# KLqCNp9Hn+z6HAINCloNG8UWffRgsKT4jtuApntPm14G/ljBY3UHaVVJAOlpHqr0
# vbipWp+gG7dlAl3kjUAdTiPSLbmZKGT3pGLf1hrBtfXxOMOfJEkPvPzgCL/TFTk+
# 38AvDTVwo7itE0EVjr8D3GsT3wxAT9A7ME7xMc/a8+nUagT++2m+4HVfF7xEZJjO
# K2Uj6Mh+DduQo2SMrXtinjl324Gmp+tLdXWjtBu+Ba6lvP/80rrhXFhamXxE627e
# 4yB1z+9GcI8CKHyeZvTXN7ubuIe+RLBD92mng6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
