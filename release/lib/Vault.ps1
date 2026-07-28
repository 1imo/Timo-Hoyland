class Vault {
    [string]$Addr
    [string]$Token
    [string]$Prefix

    Vault() {
        if (-not $env:VAULT_URL) { throw '[!] VAULT_URL is required' }
        if (-not $env:VAULT_TOKEN) { throw '[!] VAULT_TOKEN is required' }
        if (-not $env:VAULT_SECRET_PREFIX) { throw '[!] VAULT_SECRET_PREFIX is required' }
        $this.Addr = $env:VAULT_URL.TrimEnd('/')
        $this.Token = $env:VAULT_TOKEN
        $this.Prefix = $env:VAULT_SECRET_PREFIX
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
            if ($status -eq 404) { throw "[!] Vault secret missing: $Path" }
            throw "[!] Vault read failed: $uri ($($_.Exception.Message))"
        }
    }

    [void] LoadEnv([string]$ProjectName) {
        $path = "$($this.Prefix)-$ProjectName"
        $secret = $this.ReadSecret($path)
        foreach ($key in $secret.Keys) {
            Set-Item -Path "env:$key" -Value $secret[$key]
        }
        $env:VAULT_SECRET_PATH = $path
        Write-Host "[+] Vault secret/$path loaded ($($secret.Count) keys)"
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAo4fQBlVpJcZab
# cnGL09t3QubNWF0mJk/72hcu2hxqkaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIP34CKty
# FLkYp9sTq7DFcnx5zwIuTNFQNHMu9gOoSBJ4MAsGCSqGSIb3DQEBAQSCAgBcAWMx
# KYa+bup5PG7VRKJK8Ik7csH28PNdTE30A7aZme/msCNem7AtURBQfNL8sGPWrMxZ
# SMxoCA8ULBudtuUpdp0UDHQKfGdQOYrM+z1M8gtdrXLOkQ0UZ26wo6ctB/68/FmG
# AnW2Iq6gVZzPvI+mrnQ4bsgrj3nGJ3riXlU8IFbTvzSza2GPdrCzfaEFWedWzEqN
# W8/hXqWNQJUnMF/xWeYqaks93Lcj3Cv1s7DDqfx6VuFGM/rAbIAU9Dk2uz4qj1/w
# JXDpfp3CTgjyWUnfXUet58GaBVT4avPG1PcWKaq2cxW6XMvHDHSjNDZEWs3RxDXd
# jTQx7MY12iYJQTlln7wg9OvZ+k1vRYSDEAxGQiiFvUVa7dPr4S8fhV/7ZXWT0beU
# x5TYJVY7qvPc30s7qXVm6QElt8tRQeAwBGaTldurxFVh8JhFHYg47MfegSKXtmj0
# S9D7bJAONiYtgOEbCxNC1MoYNYz4y9t4hV6/nJJGpgKlks3UER0E1UXJD6ux7ylF
# DVD7DVPaPQjrxDXCcGmAQBfMG/WBSIux2/i04OYHI4qHT1WgSZu4Dbb3VyLeIWbQ
# 9a6/BbFZN53nX5YxP8QLICm65KplvjoLinB5y9XvarU+ZMmLqK+29prD61SB3hGs
# 0+i2OjsiTfJTALNDUg4wq/RfpxeM9VC9358lWKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
