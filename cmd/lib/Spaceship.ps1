class Spaceship {
    [string]$BaseUrl
    [string]$ApiKey
    [string]$ApiSecret

    Spaceship() {
        if (-not $env:SPACESHIP_API_KEY) { throw '[!] SPACESHIP_API_KEY is required' }
        if (-not $env:SPACESHIP_API_SECRET) { throw '[!] SPACESHIP_API_SECRET is required' }
        $this.ApiKey = $env:SPACESHIP_API_KEY
        $this.ApiSecret = $env:SPACESHIP_API_SECRET
        $this.BaseUrl = 'https://spaceship.dev/api/v1'
    }

    [object[]] GetRecords([string]$Domain) {
        Write-Host "== Spaceship DNS list: $Domain =="
        $r = Invoke-RestMethod -Method Get -Uri "$($this.BaseUrl)/dns/records/$Domain" -Headers @{
            'X-Api-Key'    = $this.ApiKey
            'X-Api-Secret' = $this.ApiSecret
            Accept         = 'application/json'
        }
        return @($r.items)
    }

    [void] SaveRecords([string]$Domain, [object[]]$Items) {
        Write-Host "== Spaceship DNS save: $Domain ($($Items.Count) record(s)) =="
        foreach ($item in $Items) {
            $n = if ($item.name) { $item.name } else { '@' }
            $addr = if ($item.address) { $item.address } elseif ($item.value) { $item.value } else { '' }
            Write-Host "   → $($item.type) $n → $addr (ttl=$($item.ttl))"
        }
        $body = (@{ force = $true; items = $Items } | ConvertTo-Json -Depth 10 -Compress)
        Invoke-RestMethod -Method Put -Uri "$($this.BaseUrl)/dns/records/$Domain" -Headers @{
            'X-Api-Key'    = $this.ApiKey
            'X-Api-Secret' = $this.ApiSecret
            Accept         = 'application/json'
            'Content-Type' = 'application/json'
        } -Body $body | Out-Null
        Write-Host '[+] Spaceship DNS records saved'
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAi/VdAm/TNLIE6
# uPv0PN3Q8dtPK9h85GVIfLn7s9CfC6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEICn9lBCP
# 5hIaOmYBj2vo8kt17rxowVJwXkBy22onUZMVMAsGCSqGSIb3DQEBAQSCAgAr7rgz
# 2nPC0jIuUnhmTn1D1cG9ifbpNjOVpivdT1iXtTTYKdKqNkgl8WlQSI9jjS3n1/if
# kM4ybFtyoUKwp4ygZhZ11tCVIAZ8qCPLeBIwZVd81/oMu04shdaze99hTwKW/UUx
# Y7LujHyIl05f2XZjxm3nXOgUoO3WqGu9WFGCGghTITYKufEecBy2iEFje2LUX6mY
# gIyVa15+w1HsnMK0JQ07c8Gj2bJrqtD2h5Q6sKohGc+HByO3GqjAzbU/ywWWCNJk
# 0OKE58a6VMV8masl/BjpDs6F18THmaxaMoAP/GVpnI3pz+yNFP769U+afXkdNR9W
# JqorOXkgVt4Dwif7pWc2Kcf7j3tAXkg3EN4BhBGsolw2+qmqQ+O3jnYbMujJPA18
# v9sUKSBBc3DQe8xjug3MK6UXc5SJaYfKbQMVFh5pl2faQErtVO+ddUqueQxxU/XV
# p44R7w0nwVYUK+VBfCdFGL5wMAMoOB9gtUkioPebRqFunM4vO0vRr7EVtvqZ6YD4
# AZarM+4fghHrR3kJkXitFt4lEl0GraVJufsa903viEpHl7GzQy0McvbBPAGvrg74
# cV8FqVc4l580CajmAnFRQHhjCXBDtGsef7uf/Xq/GjTh70K3qesXyn18+8kbRyrC
# 0f1TrYb0cFaFJVf4Dxtd1cBo0lF9Bn6UCQCnFKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
