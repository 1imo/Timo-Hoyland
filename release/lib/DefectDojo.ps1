class DefectDojo {
    hidden [string]$Url
    hidden [string]$Token
    hidden [int]$EngagementId
    hidden [string]$ProjectName

    DefectDojo([string]$ProjectName) {
        if (-not $env:DEFECT_DOJO_URL) { throw '[!] DEFECT_DOJO_URL is required' }
        if (-not $env:DEFECT_DOJO_API_TOKEN) { throw '[!] DEFECT_DOJO_API_TOKEN is required' }
        if (-not $env:DEFECT_DOJO_ENGAGEMENT_ID) { throw '[!] DEFECT_DOJO_ENGAGEMENT_ID is required' }
        $this.Url = $env:DEFECT_DOJO_URL.TrimEnd('/')
        $this.Token = $env:DEFECT_DOJO_API_TOKEN
        $this.EngagementId = [int]$env:DEFECT_DOJO_ENGAGEMENT_ID
        $this.ProjectName = $ProjectName
    }

    [void] ImportScan([string]$Staging, [string]$ScanType, [string]$ReportFile, [string]$StepName) {
        if (-not (Test-Path $ReportFile)) { throw "[!] report missing: $ReportFile" }
        $title = "$($this.ProjectName)-$Staging-$StepName"
        $headers = @{
            Authorization = "Token $($this.Token)"
            Accept        = 'application/json'
        }
        $form = @{
            scan_type        = $ScanType
            test_title       = $title
            engagement       = $this.EngagementId
            file             = Get-Item -LiteralPath $ReportFile
            active           = 'true'
            verified         = 'true'
            minimum_severity = 'Info'
        }
        $uri = "$($this.Url)/api/v2/reimport-scan/"
        Write-Host "[+] Defect Dojo import: $ScanType → $title"
        $r = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Form $form
        if ($r.statistics) {
            Write-Host "[+] Defect Dojo: created=$($r.statistics.created) reactivated=$($r.statistics.reactivated)"
        }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCXqCYfkS3Ahrt9
# KBXPiNx8/ox83v9BZ/Id4wUQHF21k6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJx5r6Bg
# 5tnXui5a1SZhaKlcyV7MFp6Y045tuhdDc2hYMAsGCSqGSIb3DQEBAQSCAgAV5NPO
# C9Od6g42eyS8ddVPK0DIiHW92oSFWKO2YOhWWnGBylvuDvjHrx7VHETL8DGOAuKb
# clfANXz52a5V3PrUdxHnC+aJP3cb845ijfftXej5QHN6KLcrrZ5bogC7nPPfImcA
# 8jpd+hrEGQYSOa/EFYC/zA1Blglzbg6taQ1MB6geao2mIZx67i0oxvGN7HhW+8LG
# z75u8UmcXmfO57jRwLgmLZ0G3s2/GggGI7nLLjNtu7iZhUyCM0uJZrRs3ALhIMXg
# li5OiZ34XiRqKAJSATpyjcUmTZmGKtn8ejpkfSlz6fZh+amYBR8BVJrOtbxjlfv1
# BAk4DX6KrN7EOfdO6H3uSHU9EqteVJxogH3Y2bWEdE/3PySu+iXr7KxMGoo9qv4U
# R/ySdPV9kz/H4okftaDgZ+Tkx/eO6faFAF+ZhFVjiksCPOVQ1RcJ8mNSAuEhyKTW
# pPupvFWRf16lYl2vq+b45Cr/06+J5G8xFneYlMPJOBANiMP7xDZUH96HY0lGFZFz
# 8H+KKRKaT0EKWhfs/kJBDep/a7QKzVUvhtkvQWrSx63PjqgE50taser0gpjSzLlj
# f0urjY/gv+4yXaPenYoLPHUiqZu7TAQOzI810cZ/jZsxRhSkISb+mQsqqSRPgpt+
# TtBuNuZhTYnnXY6YzkHGXSoIGZl2qQSlVB+c+qErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
