class Vault {
    [string]$Addr
    [string]$Token
    [Env]$Env

    Vault([Env]$Env) {
        if (-not $Env) { throw '[!] Vault requires Env' }
        $this.Env = $Env
        $this.Addr = $this.Env.Require('VAULT_URL').TrimEnd('/')
        $this.Token = $this.Env.Require('VAULT_TOKEN')
    }

    [string] Staging() {
        switch ($this.Env.Name.ToLower()) {
            'live' { return 'live' }
            'test' { return 'test' }
        }
        throw "[!] apply-env only pushes test/live env files (selected ENV=$($this.Env.Name))"
    }

    [hashtable] ReadSecret([string]$Path) {
        $uri = "$($this.Addr)/v1/secret/data/$Path"
        try {
            $r = Invoke-RestMethod -Uri $uri -Headers @{ 'X-Vault-Token' = $this.Token }
            $data = $r.data.data
            if ($null -eq $data) { return @{} }
            if ($data -is [hashtable]) { return $data }
            $h = @{}
            foreach ($p in $data.PSObject.Properties) {
                $h[$p.Name] = $p.Value
            }
            return $h
        }
        catch {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -eq 404) { return @{} }
            throw "[!] Vault read failed: $uri ($($_.Exception.Message))"
        }
    }

    [void] Load([string]$Path) {
        $secret = $this.ReadSecret($Path)
        foreach ($k in $secret.Keys) {
            Set-Item -Path "env:$k" -Value $secret[$k]
        }
        $env:VAULT_SECRET_PATH = $Path
    }

    [void] Health() {
        $uri = "$($this.Addr)/v1/sys/health?standbyok=true&sealedcode=503&uninitcode=503"
        try {
            Invoke-RestMethod -Uri $uri -ErrorAction Stop | Out-Null
        }
        catch {
            throw "[!] Vault health check failed: $uri ($($_.Exception.Message))"
        }
    }

    [hashtable] Compare([string]$Path, [hashtable]$Data) {
        $existing = $this.ReadSecret($Path)
        $added = 0
        $changed = 0
        $unchanged = 0
        foreach ($key in $Data.Keys) {
            if (-not $existing.ContainsKey($key)) { $added++ }
            elseif ([string]$existing[$key] -ne [string]$Data[$key]) { $changed++ }
            else { $unchanged++ }
        }
        $removed = 0
        foreach ($key in $existing.Keys) {
            if (-not $Data.ContainsKey($key)) { $removed++ }
        }
        return @{ Added = $added; Changed = $changed; Unchanged = $unchanged; Removed = $removed }
    }

    [void] WriteSecret([string]$Path, [hashtable]$Data) {
        $uri = "$($this.Addr)/v1/secret/data/$Path"
        $body = (@{ data = $Data } | ConvertTo-Json -Depth 20 -Compress)
        Invoke-RestMethod -Method Post -Uri $uri -Headers @{ 'X-Vault-Token' = $this.Token } -ContentType 'application/json' -Body $body | Out-Null
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC9r2RNyGSuCi5O
# pue1Ns/aGiRuD1URk5xT6Mv4lWJUWqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIBWKG8Sy
# qq+nYXX5pn9Xy9Hj5Utii6yWwdP54+IsPv+NMAsGCSqGSIb3DQEBAQSCAgBUIx4/
# sdAUOEQy5fAP6vPNvmcJpWJhNvl08Ovhp4vS6s7ppqFzZZwj4x3GQ9Lw/n5a74kw
# WOr/gAnO77Ic6u+RtlV3YkihhbWmFTj5zlSzI5h/39ZiEpD3kne1F1I49AyUIGOA
# pg2+FsQq5oyAp7sj4bwXbkBvcpOvv52TLu/m2n532i41keMak1jHyqJes0XWhl12
# NO1T67Co5ftMMcaYmKdpINX6cNkTRw6+IZWVZG0kXQG3nI1g8ONdYT6ienMyDxNk
# kCMWTKo8ZfV+VM3Km4hBwNdE4fxozyVU3p2dymik8n+hgdQs5gxHFcKyxgGNVunN
# bWBszsIBeL7Ct617ApGkWeI/03bcVGgY5juMOi5w1YBOe0YWyCdVhXllgQNTe/A+
# J3kSdz0fZTpLFTlSFVq6Wit0k05O2s9zYgZmC6cdwzAEbPb+msBSJcIj3HQfo9+U
# YTLmNX9UlEXVaT0xiPr6XWU3oiTwzqw30Vcl+uIJMOPCZ2IDTFp+is9c2onnbSh9
# gxMQo8PvvaiJEQOyKCmRiR40uh8Huh8vA1Uo+7lG2c9ohvC52JkmKphqDln25T7f
# iziqwksLuUWgCz9AeyGL1HY6YAxdrDhVBSId9EJFoT+O1Tguevok7WSj4GcvkOJ2
# CcfYzvh6crh1BtRD51HOGpnGW5ihzUz/3HSMPKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
