class Grype {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$ScanDir

    Grype() {
        $dirPath = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if ($env:ARTIFACT_DIR) {
            $dirPath = (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
        }
        $this.ScanDir = $dirPath
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'grype.json'
    }

    [string] Scan() {
        $sbom = Join-Path $this.ScanDir 'sbom.cyclonedx.json'
        if (-not (Test-Path $sbom)) { throw "[!] grype sbom missing: $sbom (run syft first)" }
        Write-Host "[+] grype sbom=$sbom"
        docker run --rm -v "$($this.ScanDir):$($this.ScanDir)" anchore/grype:0.84.0 "sbom:$sbom" -o "json=$($this.ReportFile)"
        if ($LASTEXITCODE -ne 0) { throw '[!] grype scan failed' }
        if (-not (Test-Path $this.ReportFile)) { throw "[!] grype report missing: $($this.ReportFile)" }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        $report = $this.ReportFile
        return $report
    }

    hidden [int] CountFindings([string]$Report) {
        $matches = @(Get-Content $Report -Raw | ConvertFrom-Json | Select-Object -ExpandProperty matches -ErrorAction SilentlyContinue)
        if ($matches) { return $matches.Count }
        return 0
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDwqV7XnasH2tx9
# Ekh4v7eLN6xLZFbJi3FB+UPrUsTFl6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHR4hTny
# WOVfkea3sUul+aP2Cq15hf4iNz/NCbA7EKAVMAsGCSqGSIb3DQEBAQSCAgBgH3v8
# 2pBROK04X7R641FjJ/3kGRUpAvmVkQ9qu+mYqHMPl0NT9nkCplB8qpclrdsVfH3J
# xI/EVC0Enx8/oG0AZAUdy3096oZS8/aDL9rmirEhyr+ot76n27de1ukNT5lpQ0zp
# 145+AGAaj87Cze+5xr9bhgZPsLeFfp3OSGuNunGbxWH1OC4Q3ydCel1ouLnDjFK1
# K8VvcKpgV8u3HLdI7jgQ5goWEhQxBjzdxZJp3xqyKMFcxjUdn2r9oknBPoYrZO6I
# LDvkxE6q6vSPToYBWH0OH864sOaIIS59QB/AeayuMAwNv9O0EjdtLHcPQMNWlube
# 8ou1GjMTcMc4bCO7eQ0ryw8HXfybepMp89zCFkZqKgsBSKwjBxvU/Tk9tfhLbIyM
# asw7rUD0uMKQNnn4cixk+STYKcaTClQ5Qx0h+335RcTconv/n+A3Eu+mX+6h0NhK
# mC8UHXhSEeFobv1hzgZHSiPB1IXM+23uoDKJar9WrboiRbrgHX8mSRaQ4dMR7vsq
# Ya6Xi4RuSQsvpG1Y1hiXf9IKEPmX2EnnPVro9VPzvRiLXM9PdtEN4/B8RtFdoN1h
# 0FzFoppdW/pbUWm+VRZE/z6SoLlmNAbqCtNrulDuFJEomiulc4ixJ/POnuZ2Ecok
# zeR0HtGLDpNxUxSEUrdLbULkphuA4K2Zspdd46ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
