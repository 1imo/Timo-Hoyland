class Syft {
    [string]$ReportFile
    hidden [string]$Image
    hidden [string]$ScanDir

    Syft([string]$Image) {
        $this.Image = $Image
        $dirPath = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if ($env:ARTIFACT_DIR) {
            $dirPath = (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
        }
        $this.ScanDir = $dirPath
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'sbom.cyclonedx.json'
    }

    [string] ScanImage() {
        Write-Host "[+] syft image=$($this.Image)"
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$($this.ScanDir):$($this.ScanDir)" anchore/syft:1.18.0 $this.Image -o "cyclonedx-json=$($this.ReportFile)"
        if ($LASTEXITCODE -ne 0) { throw '[!] syft scan failed' }
        if (-not (Test-Path $this.ReportFile)) { throw "[!] syft report missing: $($this.ReportFile)" }
        $report = $this.ReportFile
        return $report
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA4G+mIaTTClUtN
# GN5+MDc1og0fxOik1z333dxDBl4oKaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIH6jnAr0
# qEFpZYo+CnbGANeiaJudk9R3W0gjdNJQmVQFMAsGCSqGSIb3DQEBAQSCAgA+53gI
# 4zOmh55UQOL66hhDazcwqAblbNFQET7XlOQWp0uf54fGB7Ad2d0fsXImN9Jp1rgC
# qglDMoi8qP0C/qCihakqdll55pQzrMNOWIO+a1hTLdcxZSkRMFw707MfO3UrzsQt
# /wTWXR5I2FciWDMeMvQV+QMkmkDCuzwWZcO21/z+js3wwnfdKBk2K+6qfdFYntGg
# +kw3Mq1AlL3vZXWnZ/VGuktozVEtlsEgWmEho/u0zUMcv1/9lhl9yq9UvyLvYp/x
# TkkAL9bADV7AOkiSNXh6FaAxxGC3s03wQ9SHtyzYZzMNQys2HuTVbgQa7fRVGS8H
# 2fWzRqo8xGgO9b6rGScL9Mt+UY4R5pgdu4ubFka1RytoauGInFiopN1A6R1XdBt2
# vlA939TCDRwT8TINQuQOl4q24UeG7zOMvcaVrUeT1eQejKlht4iPBwXb31r0mMqC
# nIXikp3cUab5Bgre5cWZfP5/DteBf9SX72IkBphF1GG+ZRMyWcgvK+w56Q7cRSac
# sZgqZJtqwhnFfsLWIy5t8N7Xk9Weowbaz3Do80mg2/Gej3vV8MqPJ/CHuSLlOru7
# LY44AXNxmAsXZtHzHG0pZRLKEyme5Qm10UnLA3/BYGYUebMnDP8Qju/A29q8kVu1
# Eoj+LzeYlfLD/vU880NFXAq78gYe7KQumbJFU6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
