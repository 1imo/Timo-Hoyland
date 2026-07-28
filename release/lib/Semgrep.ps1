class Semgrep {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$WorkDir
    hidden [string]$ScanDir

    Semgrep() {
        $this.ScanDir = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'semgrep.json'
        $this.WorkDir = (Get-Location).Path
    }

    [string] Scan() {
        Write-Host "[+] semgrep workdir=$($this.WorkDir)"
        & docker run --rm `
            -v "$($this.WorkDir):$($this.WorkDir)" `
            -v "$($this.ScanDir):$($this.ScanDir)" `
            -w $this.WorkDir `
            semgrep/semgrep:1.96.0 `
            semgrep scan --config auto --json --output $this.ReportFile $this.WorkDir
        if ($LASTEXITCODE -ne 0) { throw '[!] semgrep scan failed' }
        if (-not (Test-Path $this.ReportFile)) { throw "[!] semgrep report missing: $($this.ReportFile)" }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        return $this.ReportFile
    }

    hidden [int] CountFindings([string]$Report) {
        $data = Get-Content $Report -Raw | ConvertFrom-Json
        if ($data.results) { return @($data.results).Count }
        return 0
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDAPUH5/aAN0SoV
# 2B5RqGKvP3W+omezCylnJI/mgb3HTaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIN6MP4X4
# jjPEWlasLYPByALfUl9B/FFjyfi8aBkyrTeGMAsGCSqGSIb3DQEBAQSCAgCMYiej
# jNn0TEr1eD9BrqAzugA734oivqH4EHRxulZtcIGSoiSbyVb1F5S53PhVJX3/iwp2
# JHJ0xOkz6nTOso/1ZELwsI+Ysumv946yOeo+Ez5A5MGBUaPbjA53kA6Qvpgbbuy0
# TctnVYZtzeIyb7Vp7TdwLuw4RH6gnlwOwp1bhqnAaupzFLcpNvfe285vlvJEl0rQ
# Su43z70G2bykfFXFbaY5qDCZOn9IG6vKWO4LVSJohrCdTlCZIce81IPuMV326ftk
# YH60SMD7A4Xo6e/KtQvR+sklylUP/HdFSRJpaHy1gcm/Qh74WHNV5zSX3BojQXAB
# cKALw5ivqkk6t87JWBSPqExF8xeC74EQw3hsm1HXeVdF8CsU4hFdylcRvPJ650eA
# hWXzBZRRReW9CUYand+4UVx0f1vqF614CCEkkVOKpbX0xLIoqs54yj1mroQJaE/e
# lnnJoybLbUBb9kc+2yUvLpcDBYCePivEyJNOQfFCPFNVR6AQaHEgyGRbBPaiKGbn
# yy6buVHuDeSgt0KSZaCFSr9OMC9mcBnpB6iQVotKi39Ocbp3OEnl9JDREVCJGOh9
# DA6NZCrNgGtCy91tGa2bbin3kf6Tvu1kevNmVR6Y2OxA/H+pmmtX85Iz4WcQA3/3
# 5k9djJeO1uR5bh4P225814ijni/y4WH2yUSDOKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
