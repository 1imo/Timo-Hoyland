class Sonar {
    hidden [string]$Name
    hidden [string]$Root
    hidden [string]$Token
    hidden [string]$Url
    hidden [string]$WorkDir
    hidden [bool]$Gated
    hidden [string]$BaseBranch
    hidden [string]$Image = 'sonarsource/sonar-scanner-cli:11.1.1.1669_6.2.1'

    Sonar([string]$Name, [string]$Root, [bool]$Gated, [string]$BaseBranch) {
        if (-not $env:SONAR_TOKEN) { throw '[!] SONAR_TOKEN is required' }
        if (-not $env:SONAR_URL) { throw '[!] SONAR_URL is required' }
        $this.Name = $Name
        $this.Root = $Root
        $this.Token = $env:SONAR_TOKEN
        $this.Url = $env:SONAR_URL
        $this.WorkDir = (Resolve-Path $Root).Path
        $this.Gated = $Gated
        $this.BaseBranch = $BaseBranch
    }

    hidden [string[]] ScannerArgs() {
        $args = @("-Dsonar.projectKey=$($this.Name)")
        if (-not $this.Gated) { return $args }

        $branch = if ($env:CI_COMMIT_REF_NAME) { $env:CI_COMMIT_REF_NAME } else {
            & git -C $this.Root rev-parse --abbrev-ref HEAD 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { throw '[!] cannot resolve current branch for sonar pull request analysis' }
            (& git -C $this.Root rev-parse --abbrev-ref HEAD).Trim()
        }
        $key = if ($env:CI_MERGE_REQUEST_IID) { $env:CI_MERGE_REQUEST_IID } else { $branch }
        $base = if ($env:CI_MERGE_REQUEST_TARGET_BRANCH_NAME) { $env:CI_MERGE_REQUEST_TARGET_BRANCH_NAME } else { $this.BaseBranch }

        $args += "-Dsonar.pullrequest.key=$key"
        $args += "-Dsonar.pullrequest.branch=$branch"
        $args += "-Dsonar.pullrequest.base=$base"
        return $args
    }

    [void] Scan() {
        $props = Join-Path $this.Root 'sonar-project.properties'
        if (-not (Test-Path $props)) { throw "[!] sonar-project.properties missing in $($this.Root)" }

        $mode = if ($this.Gated) { 'pull-request' } else { 'branch' }
        Write-Host "[+] sonar-scanner workdir=$($this.WorkDir) mode=$mode"

        & docker run --rm `
            -e "SONAR_HOST_URL=$($this.Url)" `
            -e "SONAR_TOKEN=$($this.Token)" `
            -v "$($this.WorkDir):/usr/src" `
            -w /usr/src `
            $this.Image `
            @($this.ScannerArgs())

        if ($LASTEXITCODE -ne 0) { throw '[!] sonar-scanner failed' }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD0YlgpOeo95YqA
# kRWgHbjUi0ryWPi7uKxID4XChltvzqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIASY73aP
# v0PQ7KQdbuWaqM3Jphu3edzL6Skcmtt/c0JEMAsGCSqGSIb3DQEBAQSCAgBA6kvy
# 2qakppcKf08FsYJATP4KWpLoStl6UYqvuHGPzZYPdM4EB0mtjjlHmdWBcxEtdVHd
# MKpwZjiLtzhilEJ/8+l6iaOv5cklNWJs5jNZONK64KLGxCNYvuQxiBuaI8K06OVo
# +MmyCtdpcl8VhhfqO2WTPWV3qD8UMH3NqrXGR8gVwWlTZBtoT75TV4mAfIffAzHp
# krzOZeW1UYGSgvldGvoo1BspxDF3BTVhHW1Athz00EeM31WZ3AVGlGi8Gj+GobVZ
# 9ydfeXSpgeVM6zBu4rtv+hQ0lvC57HT+C1FiPaayCU34SNroLfik75GKeVymQFN0
# xwJ53n9R7/YE5/b3rLwjEOBhmnVQB/POzu5fCTtj7jJKNVWvIZhRVfm4Vu8fvd2U
# c1PO0SglcJa4iacVtrJB58C6nRnOalzxcAP6GyztI/bGqMkdPzL+887L4xtBBynj
# jJeegcoByVYf48iGQWd7QpURXD87hyBMP5Dbc9Sqbmcxh/myBM/ynZVwCqSZdcne
# 4BXNZwPkJrM89bj6dr/kgvgxd5n6LG7tKwrPREv2d4+/qFLiDX7GZjl+D0ZmweVc
# xkKMbICndlsZssly1/ygGbOjAzFp6rpjjz8WADkhDDoWUBDw1LkIa/A/FNXlvtLw
# qck5JVvpmWmCz4lz2X39OF+uFh9MEScPc+cvGaErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
