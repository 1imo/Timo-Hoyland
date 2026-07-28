class Gitleaks {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$WorkDir
    hidden [string]$ScanDir

    Gitleaks() {
        $this.ScanDir = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'gitleaks.json'
        $this.WorkDir = (Get-Location).Path
    }

    [string] Scan() {
        if (Test-Path $this.ReportFile) { Remove-Item $this.ReportFile -Force }
        $src = $this.WorkDir
        $report = $this.ReportFile
        Write-Host "[+] gitleaks workdir=$src"
        & docker run --rm `
            -v "${src}:${src}" `
            -v "$($this.ScanDir):$($this.ScanDir)" `
            -w $src `
            zricethezav/gitleaks:v8.21.2 `
            detect --source=$src --report-path=$report --report-format=json --no-banner
        $exit = $LASTEXITCODE
        if (-not (Test-Path $this.ReportFile)) {
            '[]' | Set-Content -Path $this.ReportFile -NoNewline
        }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        if ($exit -ne 0) { throw "[!] gitleaks failed (findings=$($this.FindingCount))" }
        return $this.ReportFile
    }

    hidden [int] CountFindings([string]$Report) {
        $data = Get-Content $Report -Raw | ConvertFrom-Json
        if ($data -is [array]) { return $data.Count }
        return 0
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBiLISWY+4R3DVQ
# fs04Th8cdcLZHg6yUOfHGF4JNs5CgqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIDCtCeFh
# DATlZANLtHN72Vbd5D9f1cIYRLlpo8F8uxzMMAsGCSqGSIb3DQEBAQSCAgBjFJdb
# fv02wy8OD9kDLm8aorceHTkW5Tlg21mGW8gG2YPLJqYgqJTPBBJHZYr89NMjhf1S
# /j5F9NdfgCncxwX2GnX0vWzIZoTjOjwmqIz05X1bEhI9qtmkWqbWx49xlb9HOcoh
# p8tv+sK+DWbH4+7iTMDB04x71EBgKxXg+o0P4uEE5uNiKJbsb/zzCBzVSIi+m2D6
# uYiAfF0f6klCY/9EsNrZoBhvkFSvj68ve3Ej/FVLnk4TU8MkRN/lEpHTCiIMaOEB
# bHdWcVqK6TC4+w2P/QzLgi305x7Vd7LgurM4X6nCJRXh5sqtfg1GRk8p/jrL7cvM
# MRtD3EqY/YPa84MzbAzktD11dZNHtTZZskwiKeyP/LfEaVpuTUW5ZhO/4okDmRQJ
# pOQ25e9vfuLcTXfe9qOv/0KlGjat215CKzBY3wR1yJy4Sd2A1WimXRFyaGJq2/qn
# iquohqWgWKbckgGoMhSS25WTrDok2z989oRSJWtUfd6a4KN41/OsRfmKC4WGCTRf
# XDOV4dYHZgWIPJTsRX77sgK3Rp4rawXGMTaTsPpHcQJ2PaWokNQyHdtcLyda6Egy
# XUieXtF/RWFHs4KSvxpqmK3xNSWydx6lkHubuBBrvrOKrnfTg86UA+gZ1973Ww4E
# 3Grj/UN8dMANj4KqTrCtUwilMtitvje+CVxmyqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
