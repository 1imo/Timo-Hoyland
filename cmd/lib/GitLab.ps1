class GitLab {
    [string]$Remote
    [string]$LocalPath
    [string]$Repo
    [string]$WebUrl
    [Env]$Env

    GitLab([Env]$Env) {
        if (-not $Env) { throw '[!] GitLab requires Env' }
        $this.Env = $Env
        $this.WebUrl = $this.Env.Require('GITLAB_URL').TrimEnd('/')
    }

    GitLab([Env]$Env, [string]$Remote, [string]$LocalPath) {
        if (-not $Env) { throw '[!] GitLab requires Env' }
        $this.Env = $Env
        $this.Remote = $Remote
        $this.LocalPath = $LocalPath
        $this.WebUrl = $this.Env.Require('GITLAB_URL').TrimEnd('/')
    }

    [void] Sync() {
        if (Test-Path (Join-Path $this.LocalPath '.git')) {
            & git -C $this.LocalPath fetch origin 2>&1 | Out-Null
            & git -C $this.LocalPath checkout main 2>$null
            if ($LASTEXITCODE -ne 0) { & git -C $this.LocalPath checkout master 2>$null }
            & git -C $this.LocalPath pull --ff-only 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "[!] git pull failed in $($this.LocalPath)" }
            return
        }
        if (Test-Path $this.LocalPath) { Remove-Item -Recurse -Force $this.LocalPath }
        $parent = Split-Path $this.LocalPath -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        & git clone $this.Remote $this.LocalPath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] git clone failed: $($this.Remote)" }
    }

    [void] WriteFile([string]$RelativePath, [string]$SourcePath) {
        $dest = Join-Path $this.LocalPath $RelativePath
        $parent = Split-Path $dest -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -Path $SourcePath -Destination $dest -Force
    }

    [void] WriteContent([string]$RelativePath, [string]$Content) {
        $dest = Join-Path $this.LocalPath $RelativePath
        $parent = Split-Path $dest -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Set-Content -Path $dest -Value $Content -NoNewline
    }

    [void] CommitAndPush([string]$Message) {
        & git -C $this.LocalPath add -A 2>&1 | Out-Null
        & git -C $this.LocalPath diff --cached --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host '[=] no IaC changes'
            return
        }
        & git -C $this.LocalPath commit -m $Message 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw '[!] git commit failed' }
        & git -C $this.LocalPath push origin HEAD 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw '[!] git push failed' }
        Write-Host "[+] IaC pushed: $Message"
    }

    [bool] LocalBranchExists([string]$Name) {
        & git -C $this.LocalPath show-ref --verify --quiet "refs/heads/$Name"
        return $LASTEXITCODE -eq 0
    }

    [bool] RemoteBranchExists([string]$RemoteName, [string]$BranchName) {
        $out = & git -C $this.LocalPath ls-remote --exit-code --heads $RemoteName $BranchName 2>&1
        if ($LASTEXITCODE -eq 0) { return $true }
        if ($LASTEXITCODE -eq 2) { return $false }
        throw "[!] git ls-remote failed: $RemoteName/$BranchName ($out)"
    }

    [string] CreateBranch([string]$Name, [string]$RemoteName) {
        $branch = $Name
        if ($this.LocalBranchExists($branch) -or $this.RemoteBranchExists($RemoteName, $branch)) {
            $shortSha = (& git -C $this.LocalPath rev-parse --short HEAD).Trim()
            $branch = "$Name-$shortSha"
        }
        $suffix = 2
        while ($this.LocalBranchExists($branch) -or $this.RemoteBranchExists($RemoteName, $branch)) {
            $branch = "$Name-$suffix"
            $suffix++
        }
        & git -C $this.LocalPath branch $branch 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] git branch failed: $branch" }
        return $branch
    }

    [void] PushBranch([string]$RemoteName, [string]$BranchName) {
        $out = & git -C $this.LocalPath push $RemoteName "${BranchName}:${BranchName}" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "[!] git push failed: $BranchName ($out)" }
    }

    [void] SetVariable([string]$Key, [string]$Value) {
        $this.SetVariable($Key, $Value, $false, $false)
    }

    [void] SetVariable([string]$Key, [string]$Value, [bool]$Masked) {
        $this.SetVariable($Key, $Value, $Masked, $false)
    }

    [void] SetVariable([string]$Key, [string]$Value, [bool]$Masked, [bool]$Protected) {
        $token = $this.Env.Require('GITLAB_TOKEN')
        $headers = @{ 'PRIVATE-TOKEN' = $token }
        $payload = @{
            key               = $Key
            value             = $Value
            protected         = $Protected
            masked            = $Masked
            environment_scope = '*'
            variable_type     = 'env_var'
        }
        $body = ($payload | ConvertTo-Json -Compress)
        $base = "$($this.WebUrl)/api/v4/projects/$([uri]::EscapeDataString($this.Repo))/variables"
        try {
            Invoke-RestMethod -Method Put -Uri "$base/$Key" -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
        }
        catch {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -ne 404) { throw "[!] GitLab variable update failed: $Key ($($_.Exception.Message))" }
            Invoke-RestMethod -Method Post -Uri $base -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
        }
        $flags = if ($Protected) { 'protected' } else { 'unprotected' }
        if ($Masked) { $flags += ', masked' }
        Write-Host "[+] GitLab $($this.Repo): variable $Key ($flags)"
    }

    [string] CreatePullRequest([string]$SourceBranch, [string]$TargetBranch, [string]$Title) {
        $query = @(
            "merge_request%5Bsource_branch%5D=$([uri]::EscapeDataString($SourceBranch))"
            "merge_request%5Btarget_branch%5D=$([uri]::EscapeDataString($TargetBranch))"
            "merge_request%5Btitle%5D=$([uri]::EscapeDataString($Title))"
        ) -join '&'
        $url = "$($this.WebUrl)/$($this.Repo)/-/merge_requests/new?$query"
        if (Get-Command open -ErrorAction SilentlyContinue) { & open $url }
        Write-Host "[+] GitLab MR: $url"
        return $url
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBaZIFemBRZRjra
# +jxGpt4dvdzPxVOp4PGtp7C0QOn1BKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHA2VH+r
# OUnkvzqWTTM3QHWAAVIBB6w89c7SrC9NTpkrMAsGCSqGSIb3DQEBAQSCAgCOv38r
# y0ZflDAt/OFgXnxINIOTtyAyprbswqgdT36aXOxHXkpg/62vbt3lq3mqTgJnNTV6
# iPeYc3XH50AJlwZRv09YlxMfMhHg3iidTBRNCGP15wrOtEKlZg4dpoF3IaB4muwB
# hV2MArXTCvTbRaQ5JD9YKZmQNS6vyak2zM6bRJbIXADy2xKK2vf//mNtDAI0o1PB
# dz09X++uojTBgEI1ULIjpUozLejBrYW1/r/I6I+gqSa6+EU54ghsCVq77LpnpD7b
# ERFrqFme4g7e+0S4iNV7S2rbS7OBk7xVo/cJOW7NP5EqB+4+eU8Tpzufueb+pvcU
# nphl0U3BsxgIe+PxKYQGP0mnhr5zCik/OirsJ9hycxl7OH0q+yvXUfDExZAvm3ZA
# Q96LlYtMSH5BLGeG3bVQyPoRd+HNV+QrL9VBY2dYUq9MeFCw5RCfdzKSVmCmtJRc
# KBoIyiyvFXMlNSS4l/mX2P59fX12+qfYXTK0kTEaeP7BUaBYrceyMjb2Ld/JEica
# kjCxODN3sqzLPqYDRLE4w95x5hPkZsbL9HOqkKwB9kU7ROj/FKysfkdMJ+Te3gO7
# rE4PxCCA594TApCu4fwFG9AFgyIsFFZJI/fSCLJURurMjot3C7Wd1M02lIeee86N
# l/r2vlXEEPuKG8n9PRdDXr8huYZiPF1T0dEtDKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
