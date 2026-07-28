class Trivy {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$Image
    hidden [string]$ScanDir
    hidden [string]$CacheDir

    Trivy([string]$Image) {
        $this.Image = $Image
        $dirPath = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if ($env:ARTIFACT_DIR) {
            $dirPath = (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
        }
        $this.ScanDir = $dirPath
        $this.CacheDir = Join-Path ([System.IO.Path]::GetTempPath()) 'trivy-cache'
        foreach ($dir in @($this.ScanDir, $this.CacheDir)) {
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        }
        $this.ReportFile = Join-Path $this.ScanDir 'trivy.json'
    }

    [string] ScanImage() {
        & docker run --rm `
            -v '/var/run/docker.sock:/var/run/docker.sock' `
            -v "$($this.CacheDir):/root/.cache/trivy" `
            -v "$($this.ScanDir):$($this.ScanDir)" `
            aquasec/trivy:0.58.1 image `
            --scanners vuln `
            --severity HIGH,CRITICAL `
            --format json `
            --output $this.ReportFile `
            --exit-code 1 `
            $this.Image
        $exit = $LASTEXITCODE
        if (-not (Test-Path $this.ReportFile)) { throw "[!] trivy report missing: $($this.ReportFile)" }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        if ($exit -ne 0) { throw "[!] trivy scan failed (findings=$($this.FindingCount))" }
        return $this.ReportFile
    }

    hidden [int] CountFindings([string]$Report) {
        $data = Get-Content $Report -Raw | ConvertFrom-Json
        $count = 0
        foreach ($r in @($data.Results)) {
            if ($r.Vulnerabilities) { $count += @($r.Vulnerabilities).Count }
        }
        return $count
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCQ8tQ7XWDLnHgZ
# m33G6pvQblM4u4Sh4h+zQ+k1e7HppqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIH6Zwb5S
# YAEeXn7rZToabgpRX4aXQYrndZLDi6j/EhKPMAsGCSqGSIb3DQEBAQSCAgA+ue2l
# VbuGDjhTG93z5XSSTmuayBxhVpvR4T+z+FMcJUC8evFYBt4j+LDl9jmNU2KB1KH6
# AQYqwqbMjl4MW8pT/VXz2FhBUV8z4rZ2k96Bv5qoZCG61Tws9rw/Z0rIKXFgVme5
# rnSN6IEDfFNe1bJbFnWgu96tdWwnPBGeB5Uckd4ZunUViGNYJlcxJR8bKeeb0NDr
# KFY0gdaRrxbke2xRI0KzldXAxHBSzCjnVRAP0rTTuz0QwStUd3JUuCv9Arl2WnLR
# vxxPJ3GiLxddTxWNFjyEXL6OGaYQwFWRcmMU/rVwlm7uXoZceUuJsOtpd4L5W/EL
# AdsSIhdnpm0rba7h/hYMmIDv6l+z9kAdDIlunDNVG2yA90Ctrs7E5TcRRLMNKy/D
# /1lvhaQPS4Of7ezfmbmoIDG+z/zjKjsVWZ3o3dTPRnV1vjZv0S+WJ72/F8xZrWeo
# nvRAZYPyWcNHgrGPqJiuJF/2bko40s26MDrSqCtbmvOxKk5I0YtBevam50/phO3+
# NwkP1inYH7GnSiYCCBXGlUBOEdV7S4gGyvQDAs7eGYb5PX2CelZpyjnx1pPjbHs+
# UjJGGdy5cVkRg93+Z/xWZIMyhzNcnOsaiI4Z9w4jAjGyqQCF9iIeBZxsnVYb82pa
# KFXODIRO12uy/QrpuFpam6+Y0GXm+18B1EWViKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
