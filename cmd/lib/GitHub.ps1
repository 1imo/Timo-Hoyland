class GitHub {
    [string]$Remote
    [string]$LocalPath
    [string]$Repo
    hidden [string]$Gh

    GitHub([string]$Remote, [string]$LocalPath) {
        $this.Remote = $Remote
        $this.LocalPath = $LocalPath
        $this.Gh = [GitHub]::ResolveGh()
    }

    static [string] ResolveGh() {
        $cmd = Get-Command gh -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
        $paths = [System.Collections.Generic.List[string]]::new()
        if ($env:HOMEBREW_PREFIX) { $paths.Add((Join-Path $env:HOMEBREW_PREFIX 'bin/gh')) }
        $paths.Add('/opt/homebrew/bin/gh')
        $paths.Add('/usr/local/bin/gh')
        foreach ($p in $paths) {
            if (Test-Path $p) { return $p }
        }
        throw '[!] gh CLI required (install: brew install gh)'
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

    [void] CreateRepo([string]$Owner, [string]$Name, [bool]$Private = $true) {
        $vis = if ($Private) { '--private' } else { '--public' }
        & $this.Gh repo create "$Owner/$Name" $vis --confirm 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] gh repo create failed: $Owner/$Name" }
        Write-Host "[+] GitHub repo created: $Owner/$Name"
    }

    [void] SetSecret([string]$Repo, [string]$Name, [string]$Value) {
        $Value | & $this.Gh secret set $Name --body - -R $Repo 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] gh secret set failed: $Name" }
        Write-Host "[+] GitHub ${Repo}: secret $Name"
    }

    [void] SetVariable([string]$Repo, [string]$Name, [string]$Value) {
        $Value | & $this.Gh variable set $Name --body - -R $Repo 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "[!] gh variable set failed: $Name" }
        Write-Host "[+] GitHub ${Repo}: variable $Name"
    }

    [string] CreatePullRequest([string]$SourceBranch, [string]$TargetBranch, [string]$Title) {
        $out = & $this.Gh pr create --repo $this.Repo --base $TargetBranch --head $SourceBranch --title $Title --body $Title 2>&1
        if ($LASTEXITCODE -ne 0) { throw "[!] gh pr create failed: $out" }
        $url = ($out | Select-Object -Last 1).ToString().Trim()
        Write-Host "[+] GitHub PR created: $url"
        return $url
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBUVfq6TLNaWJV+
# gDgOK0tjx2bUcSahsbUhwQMcxCwiQKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAnvsZVG
# 2Rx1HFe6F1RuXiUq5Y7RwLQVT6lfVDd3NtORMAsGCSqGSIb3DQEBAQSCAgAcmQJ2
# ydKR4RTMPG36GGEEr2pHUQWoMp/in2VWBH8bLpYzFk+8J4kdkvL4HfbzIs+5nSMO
# eqQGL5rGIVBhZrqfhbf8gYkoCUH6exmksxO3A2nGrX5lJ9sIdtxL/LwPkpZL0lT1
# VNkpXHMQts0s/y3YULdvJhWjkMwClTAPjsiXcs3Ur3S5w8lSCzKxWYl4YQFlw9RM
# 8wrt/beQ3TXS2fFnJD6vHbDVi7Nc8SXgphnRYJwXyyFh//1VklTMDsclXFfqH171
# mEUr3sRNzFyGL9vmqfFJS290vggnlQk9uyGafifLl/4pg7y+hyANoCge6UKirrwF
# d+15CeJIMDpDO7p57/JEZgJIDbKhxDYnTyaw4YHPVNKZouwBacoK7zOKDSPpqo7E
# 77ZaLpibqypzTSGZVEKoiBxEMm6mLWp7CROnx4YaajsWvgO5YDszAf4uNLuYlG7C
# fRQYxEC16DHa1CYwDzK5gYSE+eQC3xhvMklVJzT0XiEyibrwh5hxNqHLR6UiMa+s
# SIlUSXidIljObcb5OsfeKvZujWeiNGTZ85iQzNny3DXmE6R1Xw/Jw1kRptVtIdJ0
# f1XG3jm3yu4x5Fvagj0xdzz8YkQx7zlwJsDgdyRLonC0x3BU3wreG5KIEK9U8Exo
# Z195eCOjtWa8PtvVOPlLXhsLErofBbq6MWdASqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
