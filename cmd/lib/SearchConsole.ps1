class SearchConsole {
    [Config]$Project
    [Google]$Google

    SearchConsole([Config]$Project, [Google]$Google) {
        if (-not $Project -or -not $Project.Loaded) { throw '[!] SearchConsole requires loaded project.cfg' }
        if (-not $Google) { throw '[!] SearchConsole requires Google' }
        $this.Project = $Project
        $this.Google = $Google
    }

    [string] GetDnsTxtToken([string]$Domain) {
        $headers = $this.Google.AuthHeaders()
        $body = (@{
                verificationMethod = 'DNS_TXT'
                site               = @{
                    type       = 'INET_DOMAIN'
                    identifier = $Domain
                }
            } | ConvertTo-Json -Compress -Depth 5)
        $r = Invoke-RestMethod -Method Post -Uri 'https://www.googleapis.com/siteVerification/v1/token' -Headers $headers -Body $body
        if (-not $r.token) { throw "[!] Search Console DNS token missing for $Domain" }
        return [string]$r.token
    }

    [hashtable] GetDnsTxtTokens([string[]]$Domains) {
        $out = @{}
        foreach ($domain in $Domains) {
            $out[[string]$domain] = $this.GetDnsTxtToken([string]$domain)
        }
        return $out
    }

    [bool] IsVerified([string]$Domain) {
        $headers = $this.Google.AuthHeaders()
        try {
            $r = Invoke-RestMethod -Method Get -Uri 'https://www.googleapis.com/siteVerification/v1/webResource' -Headers $headers
            foreach ($item in @($r.items)) {
                if ($item.site.type -eq 'INET_DOMAIN' -and $item.site.identifier -eq $Domain) {
                    return $true
                }
            }
        }
        catch {
            return $false
        }
        return $false
    }

    [void] VerifyDomain([string]$Domain) {
        if ($this.IsVerified($Domain)) {
            Write-Host "[=] Search Console already verified: $Domain"
            return
        }
        $headers = $this.Google.AuthHeaders()
        $body = (@{
                site = @{
                    type       = 'INET_DOMAIN'
                    identifier = $Domain
                }
            } | ConvertTo-Json -Compress -Depth 5)
        Invoke-RestMethod -Method Post -Uri 'https://www.googleapis.com/siteVerification/v1/webResource?verificationMethod=DNS_TXT' -Headers $headers -Body $body | Out-Null
        Write-Host "[+] Search Console verified: $Domain"
    }

    [void] EnsureSite([string]$Domain) {
        $headers = $this.Google.AuthHeaders()
        $siteUrl = "sc-domain:$Domain"
        $encoded = [uri]::EscapeDataString($siteUrl)
        try {
            Invoke-RestMethod -Method Get -Uri "https://www.googleapis.com/webmasters/v3/sites/$encoded" -Headers $headers | Out-Null
            Write-Host "[=] Search Console site exists: $siteUrl"
            return
        }
        catch {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -ne 404) { throw "[!] Search Console site lookup failed for ${siteUrl}: $($_.Exception.Message)" }
        }
        Invoke-RestMethod -Method Put -Uri "https://www.googleapis.com/webmasters/v3/sites/$encoded" -Headers $headers | Out-Null
        Write-Host "[+] Search Console site added: $siteUrl"
    }

    [void] EnsureDomains([string[]]$Domains) {
        foreach ($domain in $Domains) {
            $this.VerifyDomain([string]$domain)
            $this.EnsureSite([string]$domain)
        }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDjfML9bLxciaTa
# QwTfuEyc6xOTYsyPUs4AfWNSwJ8KpqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIETopzqd
# Mu6kwhj3WqAtGHdYO0xC+A8lzMHpRtmJbwQXMAsGCSqGSIb3DQEBAQSCAgBsr1Io
# GRnaSgEA8D1jccxrntHw3Ducm/diSFyiPKH3042wgLAMA73qmw1fg+oITOFSRaRe
# Gd/KR1khkPtFJLdmazW5TKCWEId6chI/pfPj8/hAk74QOf08+ugqGQZs9wNihZD6
# 2WAl7ligHZ1umF65imr60dvERfP33s8TUX/+62ouVxXrcmmJPhjSEGm10BZ8erte
# ujXKFnaKYaF+ZwTr/Fr+wAu7RplQnsrriEBqpP5fAG7bBaqelbTHa4GLfPnCR2/N
# ZTJ6YUhge6VHbQTn9cTz5azywcQdOtkz07tKfveGrS+BRkNQlbHMffZiYxEI6V8Q
# CFm6rkvF6VYH9c8l5ryJ64uxk5mYJN1CXiqq+ve4dYc4jZj0EllNQjnhwRK9d8rC
# mQyVc8uOatDytWj9be1+UyaX8Ngp4NAMnIB4+1detYIikODECDrRa7yPRZK8OclH
# EzZNq2i1RMZxibxizmVitliDKCuQ/k51qM49n7Y+uJEOxvcJbg+XPx+1Pz9afsf3
# 3D/JVyUHE8SFnmSc0MrYH8Rth+lyN3zaDy9l2ipZx9DuLgtddU0/1aPhI6TGa08O
# pkxzmmtjs7ZQuoYSUUPNanG+XA1r3hdRIC6c8ODPK5fOESncepPooA9ETPrfcRV7
# Rbwc2ZHR6xWztDuLf6dpkBzVPwrMz4l7osDmSqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
