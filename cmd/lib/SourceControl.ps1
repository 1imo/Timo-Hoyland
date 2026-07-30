class SourceControl {
    hidden [object]$Backend
    hidden [string]$WorkDir
    [string]$Channel
    [string]$Root
    [Env]$Env
    [Config]$Settings

    SourceControl([Env]$Env, [Config]$Settings, [string]$RemoteUrl, [GitHub]$GitHub, [GitLab]$GitLab) {
        if (-not $Env) { throw '[!] SourceControl requires Env' }
        if (-not $Settings -or -not $Settings.Loaded) { throw '[!] SourceControl requires settings.cfg' }
        if (-not $GitHub) { throw '[!] SourceControl requires GitHub' }
        if (-not $GitLab) { throw '[!] SourceControl requires GitLab' }
        $this.Env = $Env
        $this.Settings = $Settings
        $this.Channel = switch ($Env.Name.ToLower()) {
            { $_ -in @('dev', 'development') } { 'test' }
            'live' { 'live' }
            'test' { 'test' }
            default { throw "[!] env must be live or test (got $($Env.Name))" }
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
        if ($this.Channel -eq 'live') {
            $GitHub.Remote = $RemoteUrl
            $GitHub.LocalPath = $localPath
            $GitHub.Repo = $repo
            $this.Backend = $GitHub
        }
        else {
            $GitLab.Remote = $RemoteUrl
            $GitLab.LocalPath = $localPath
            $GitLab.Repo = $repo
            $this.Backend = $GitLab
        }
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

    hidden [void] ConfigureGitsign([string]$RepoPath) {
        if (-not (Get-Command gitsign -ErrorAction SilentlyContinue)) {
            throw '[!] gitsign required (https://github.com/sigstore/gitsign)'
        }
        & git -C $RepoPath config gpg.x509.program gitsign
        & git -C $RepoPath config gpg.format x509
        & git -C $RepoPath config commit.gpgsign true
        & git -C $RepoPath config gitsign.fulcio $this.Settings.Endpoint('FULCIO')
        & git -C $RepoPath config gitsign.rekor $this.Settings.Endpoint('REKOR')
        & git -C $RepoPath config gitsign.issuer $this.Settings.Endpoint('KEYCLOAK')
        & git -C $RepoPath config gitsign.clientID $this.Env.Require('OIDC_CLIENT_ID')
        & git -C $RepoPath config gitsign.redirectURL $this.Settings.Require('SIGSTORE.OIDC_REDIRECT_URL')
        & git -C $RepoPath config gitsign.autoclose false
        $env:GITSIGN_LOG = Join-Path ([IO.Path]::GetTempPath()) 'gitsign.log'
        Write-Host "[+] gitsign configured (log=$env:GITSIGN_LOG)"
    }

    [string] PromptCommitMessage() {
        $types = @(
            @{ Name = 'feat';     Hint = 'new feature' }
            @{ Name = 'fix';      Hint = 'bug fix' }
            @{ Name = 'docs';     Hint = 'documentation only' }
            @{ Name = 'style';    Hint = 'formatting / whitespace (no logic change)' }
            @{ Name = 'refactor'; Hint = 'code change that is not feat or fix' }
            @{ Name = 'perf';     Hint = 'performance improvement' }
            @{ Name = 'test';     Hint = 'add or fix tests' }
            @{ Name = 'build';    Hint = 'build system or dependencies' }
            @{ Name = 'ci';       Hint = 'CI configuration' }
            @{ Name = 'chore';    Hint = 'maintenance / misc' }
            @{ Name = 'revert';   Hint = 'revert a previous commit' }
        )

        Write-Host ''
        Write-Host 'Conventional commit type:'
        for ($i = 0; $i -lt $types.Count; $i++) {
            Write-Host ("  {0}) {1,-9} {2}" -f ($i + 1), $types[$i].Name, $types[$i].Hint)
        }
        $choice = Read-Host "Choose [1-$($types.Count)]"
        if (-not $choice) { throw '[!] commit type required' }
        $idx = 0
        if (-not [int]::TryParse($choice, [ref]$idx)) { throw "[!] invalid choice: $choice" }
        $idx = $idx - 1
        if ($idx -lt 0 -or $idx -ge $types.Count) { throw "[!] choice out of range: $choice" }
        $type = [string]$types[$idx].Name

        $scope = (Read-Host 'Scope (optional)').Trim()
        $desc = (Read-Host 'Short description').Trim()
        if ([string]::IsNullOrWhiteSpace($desc)) { throw '[!] commit description required' }
        $desc = $desc.TrimEnd('.')

        $breaking = $false
        if ((Read-Host 'Breaking change? [y/N]') -match '^[yY]$') { $breaking = $true }

        $body = (Read-Host 'Body (optional)').Trim()
        $footer = ''
        if ($breaking) {
            $footer = (Read-Host 'BREAKING CHANGE description').Trim()
            if ([string]::IsNullOrWhiteSpace($footer)) { throw '[!] BREAKING CHANGE description required' }
        }

        $bang = if ($breaking) { '!' } else { '' }
        $scopePart = if ($scope) { "($scope)" } else { '' }
        $header = "${type}${scopePart}${bang}: $desc"

        $parts = [System.Collections.Generic.List[string]]::new()
        $parts.Add($header)
        if ($body) {
            $parts.Add('')
            $parts.Add($body)
        }
        if ($footer) {
            $parts.Add('')
            $parts.Add("BREAKING CHANGE: $footer")
        }
        $msg = ($parts -join "`n").Trim()
        Write-Host ''
        Write-Host "[+] commit message:"
        Write-Host $msg
        return $msg
    }

    [void] Commit([string]$Message) {
        $this.ConfigureGitsign($this.Root)
        if (git -C $this.Root status --porcelain) {
            & git -C $this.Root add -A
            & git -C $this.Root commit -S -m $Message
            if ($LASTEXITCODE -ne 0) { throw '[!] git commit failed' }
        }
        else {
            Write-Host '[i] Working tree clean — pushing existing commits only'
        }
    }

    [void] CommitAndPush([string]$Message) {
        $this.ConfigureGitsign($this.Backend.LocalPath)
        $this.Backend.CommitAndPush($Message)
    }

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
        if ($this.Channel -eq 'live') {
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAHeBH0LrMlGw8m
# UjmolGaj86hmSyLiEODGmfZdYlMljqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIIXOrvaA
# IX0gsJXSAznrlG1O3yH0JjSfV9eHb8slrxNUMAsGCSqGSIb3DQEBAQSCAgAwTUt8
# Uzjksq/0Ajw6S4ScR4fVn22iBEtsqL1YgmbGOEZmUCT2P8gIgztskQGkyNTIPsoV
# GGZncJA4tpNO5YYEIK1MQjZsGtr1mqU4Pdon3lyjRf3/X1wnRrJ0eTi1UVL3ONGp
# i+q4En1ElJmU8up0mdvAYWZICUQr9qyIkNM/NIRQmSWoac4lTgBYTyBLeo4DaKYf
# hwBUF3cCUIu1xUAf2Bdv5A8FcS9kkAkEqlakqVsKvZyqi1vhf8As430+6vKn1JDg
# hx2kFYAlaxF3G/8W6F6fSux1WS+qbs9Nu9fXViFKI02+iIH5ecOLdmAjWF7DvD4V
# oIJETuJ0pk5CnbgVfJXpdspgERgtTZybpq5zOY0Ce8nrwPEArevmO+gqi6zbFfml
# jb1FEI1Zea0NDjYYa5Y+J+BoJgx2N6O4Plp00T2gTn1YlBncYfy/4QoVWbN0LvYc
# WGpfLiLY4+CcVtjeMD5B6ethQfPzsvIzuK5ew4EvFDFsgdRSJLFUjRSsXPgpeUUK
# g6s1GLuEMjkG4rntvAT1uwmvs1CT5+HfSjSywelNWXuOkRZGvWgAP43YulXEg/Ww
# H1lw0pDPaQLLFyoevHK7uNQ2KuANyYv7KtULcTMkxBwGCT1E+Nf+53IuA3VAYlfm
# YaU8vib6Fc9MKwtim5ETKWnbd0WmtP7dnP17zaErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
