class Elastic {
    [string]$Url
    [string]$UserPass
    [string]$Env
    [string]$ProjectName

    Elastic([string]$ProjectName) {
        if ([string]::IsNullOrWhiteSpace($ProjectName)) { throw '[!] project name required' }
        $this.ProjectName = $ProjectName
        
        if (-not $env:ELASTIC_URL) { throw '[!] ELASTIC_URL is required' }
        if (-not $env:ENV) { throw '[!] ENV is required' }
        if (-not $env:ELASTIC_USER) { throw '[!] ELASTIC_USER is required' }
        if (-not $env:ELASTIC_PASSWORD) { throw '[!] ELASTIC_PASSWORD is required' }
        $this.Url = $env:ELASTIC_URL
        $this.Env = $env:ENV
        $this.UserPass = "$($env:ELASTIC_USER):$($env:ELASTIC_PASSWORD)"
    }

    [void] CreateStream() {
        $dataStream = "$($this.ProjectName)-logging"
        $template = @{
            index_patterns = @("${dataStream}*")
            data_stream    = @{}
            priority       = 10000
            template       = @{ mappings = @{ dynamic = $true } }
        } | ConvertTo-Json -Depth 10 -Compress

        $headers = @{}
        if ($this.UserPass) {
            $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
            $headers['Authorization'] = "Basic $b64"
        }

        Write-Host "== Elasticsearch: $($this.Url) =="
        Write-Host "== index template ($dataStream) =="
        Invoke-RestMethod -Method Put -Uri "$($this.Url)/_index_template/$dataStream" -Headers $headers -ContentType 'application/json' -Body $template | Out-Null

        Write-Host "== bootstrap document → $dataStream =="
        $doc = (@{
                '@timestamp'             = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                event                    = 'import_bootstrap'
                'deployment.environment' = $this.Env
            } | ConvertTo-Json -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/$dataStream/_doc?refresh=wait_for" -Headers $headers -ContentType 'application/json' -Body $doc | Out-Null

        Write-Host '== data stream =='
        Invoke-RestMethod -Method Get -Uri "$($this.Url)/_data_stream/$dataStream" -Headers $headers | Out-Null
        Write-Host '== field caps =='
        Invoke-RestMethod -Method Get -Uri "$($this.Url)/$dataStream/_field_caps?fields=event,@timestamp" -Headers $headers | Out-Null
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBokKpz4ARiNuqz
# D8UAWiT0Bo3VCDNzhpRRVqBXCVCO16CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKFBOA67
# 79M6ftyug2EGGMn6TQ8LlhAW7wngEsicsQycMAsGCSqGSIb3DQEBAQSCAgCg+kRI
# minPyCKgvCJr+r3iv7a6+G9Mi+tOGi+JvWxU2u/9yreWj7AgT0G9bCvZATdm6tGo
# 6nYFfIzHECgMwGuarwvPM29fpdvho+eEwjMiQRudBZhlXoD5jSpF2NyXcn4bCOvu
# xYos63UytPb6Tz9S+FX7x3bY4z/xTxVbQI65JwRWRzt5+9tV2v0xofiGKsaYATS5
# 5OlARNGvNb3I/jUysok6vZan4lIeFiyEsIMo7r/LgExpHMdu0UW8sXpfqE8dHTKx
# sE3TIaUGDWUykviJuAoWcj8IQiTzPXy31r1cO1p2EdOwijq83no7vv2QGn5qfPIX
# WR1xLzC8HkKMLrTon8aUi2PzSAGDbLqo5/utAgk4rbg7vEhMalqjVr+Q6T4IhH+E
# f4znHJAkIJSiheMDpRufA7poroWZHg3RAm62boxPRMq19F9k8oU0oK1YkURxfsbL
# gDFR6KRLLxbhoEuAP8cRZgV5cp3jdwhKXDFtjOz05St+9g4I4F2p7Fxm632R8pzc
# L+8MGy9Hl+eXyXntI3ZP9nXTvTXotBv5A0zsS7W0MFaqCrSubYMM+dLN+Om4oGR7
# FGSzM/gdpcL1M3eBecT+5pA/FKmsZfoA6+VA+ICeRM2mA2TK5ixrpnDPi7tJOKwW
# 0DQzUV0g5Cp2gtQH9Vxb34R5LYMfpdMKjY/kEaErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
