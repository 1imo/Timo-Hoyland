class GitLab {
    [string]$Remote
    [string]$LocalPath
    [string]$Repo
    [string]$WebUrl

    GitLab([string]$Remote, [string]$LocalPath) {
        $this.Remote = $Remote
        $this.LocalPath = $LocalPath
        if (-not $env:GITLAB_URL_PUBLIC) { throw '[!] GITLAB_URL_PUBLIC is required' }
        $this.WebUrl = $env:GITLAB_URL_PUBLIC.TrimEnd('/')
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
        if (-not $env:GITLAB_TOKEN) { throw '[!] GITLAB_TOKEN is required' }
        $headers = @{ 'PRIVATE-TOKEN' = $env:GITLAB_TOKEN }
        $payload = @{
            key                 = $Key
            value               = $Value
            protected           = $Protected
            masked              = $Masked
            environment_scope   = '*'
            variable_type       = 'env_var'
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDSkJm3X49Z3k4B
# EGN3DaIS+4fs5LtSflTIRBfVzpZ9NKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOnBx3Ew
# W61agLJe/CMLFV19q+trm+4j75q+sLm5Va5UMAsGCSqGSIb3DQEBAQSCAgBrBOM0
# AVv73ke6aHiqT9r+ntn2Wf1HDumTqvlMmilJF8gPlraPx6AOu4ZJ6rHgKf+g8SPf
# WLQuMBFCoI5tSt27GHbv24tTFzjOAtdPITOmYlTqa25DIFGTeTJBgkgING6tK6Uk
# yY79K291yQcC9c6ahjlLZ7gCk8Phqlon8oDq9oOFgcBbsL2UnKAhaEfVwnrWoTo0
# 3Li7Pqs9zq3mszr7idWBNsW/rZVh1FS9OqL00+ZfpBTCAm7ikgBr0CZ5yfFbnYLL
# ZnI4hNWWEAdKYdiv+Ek+8nMVUat0ii29F07GWBg2AkiUY0bJ5376lR5coRDDb7kX
# 9+SrKowKenhDa6uN9++pbI2DMiiMXhtLSDnEZWFEvyZo/XHXpqY6lWuS8eRxVPNv
# PZ2zv9E/bT/gnpt5iPmzq8j0/HGvga2/xiEUvzbpsEJUuihBPFVeEkO8Wl1yNGEp
# ALdubj9WLu4I78qpF0Pl9psg9a56PLWRYNgYgbC39jKEMfrKMUAX8tUaSo2XCEZt
# ghWcO6UAyfULaA0Zwwn78H9FnLBOuYF64JGsbKB8jKNDPKAVGLuGm8CgEjtcb4zH
# 7dbZFMazy7WyiblQKCTx2CS+YVQhGYxCDE1cB6CeV67HHyhJ2IZ5M+IiXwa8A3DQ
# IXn2NOmkgCNfkQ6oupSdMCHcn77gEGzrwdyk0aErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
