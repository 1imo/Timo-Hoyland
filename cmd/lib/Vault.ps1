class Vault {
    [string]$Addr
    [string]$Token

    Vault() {
        if (-not $env:VAULT_URL_PUBLIC) { throw '[!] VAULT_URL_PUBLIC is required' }
        if (-not $env:VAULT_TOKEN) { throw '[!] VAULT_TOKEN is required' }
        $this.Addr = $env:VAULT_URL_PUBLIC.TrimEnd('/')
        $this.Token = $env:VAULT_TOKEN
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
            if (-not $existing.ContainsKey($key)) {
                $added++
            }
            elseif ([string]$existing[$key] -ne [string]$Data[$key]) {
                $changed++
            }
            else {
                $unchanged++
            }
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB07K8XbtRoqVok
# H/PHGcPxZmE9sv814+7ykaKdWatJwKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEILmuAcGZ
# 9WEk9RnpPEB/2aX9fQt4sbZejdEP8MiCeTX8MAsGCSqGSIb3DQEBAQSCAgAA3tnl
# o4hIkD6cDY1aWHkdPW7ljAj6zk+lu6D2F56FSl7hdT7Ei3ecPyyVSiFXeeyCX5kd
# RiO4Qw/eAHw+MvQGlwr09db+znQlLHav6ASCFYLXeOxp5PVeeE6QNTZJ1hgy1LpZ
# t/kUyJUkBsU66WmfkJ2/NRdB3156p5u/K3IBgRaRPwGl1u0TSLhM4+1qkfGJu9Oi
# dKe7Ny1VIuKcis4qja/gqA8YTWy+kyeK6c2Am2AokaV571ulgSRBTmPF5CW4eOEs
# FDONG74Jsfuuhozn2HGaTrQkj5bZ+LWsD65pg76Irhz3Kumtuqzdk64f1DQ5oYis
# EKWGi2F4PcmsB/QJuor65ghE9NDx5fioHTaMcmK934+ViXB8Dl4Fsz41urekIw2x
# YZBLaohfDPnkF4G6k8ro7Y7Y9GNn8jLQzLWUnD4CbnAiH2p9XP9f05C/xK3F+raH
# HoEZeH/lkI9QcM+jWzJGoC87+5mQQ9MB/pgmHdipO+nPj7mZzxdCO3umcLBfKJLy
# YWy8yNFYNaSh5qNNdQYLDCLNdj7YPozMaSTOozPtKnNHyM7swVG734BNVsOX4Mwm
# WGvJef0fPsVmYpkaP4oFs4L/a67+YXwVoitk6pdHPUWK887jJgweU9IlSBBNat/r
# rJbsTJE3ctlu7ajY05qBRWjRuZRZ7br2c0ZbPaErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
