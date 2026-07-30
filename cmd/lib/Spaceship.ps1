class Spaceship {
    [string]$BaseUrl
    [string]$ApiKey
    [string]$ApiSecret
    [Env]$Env
    [Config]$Project

    Spaceship([Env]$Env, [Config]$Project) {
        if (-not $Env) { throw '[!] Spaceship requires Env' }
        if (-not $Project -or -not $Project.Loaded) { throw '[!] Spaceship requires project.cfg' }
        $this.Env = $Env
        $this.Project = $Project
        $this.ApiKey = $this.Env.Require('SPACESHIP_API_KEY')
        $this.ApiSecret = $this.Env.Require('SPACESHIP_API_SECRET')
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

    [void] Apply() {
        $this.Apply(@{})
    }

    # $SiteTxt: domain → TXT value for @ (e.g. Search Console tokens); merged with project.cfg sites.
    [void] Apply([System.Collections.IDictionary]$SiteTxt) {
        $registry = $this.Project.Require('public.dns.registry')
        $domains = @($this.Project.Get('public.domains'))
        $pubHost = $this.Project.Require('public.ingress.ip')
        $dnsCfg = $this.Project.Get('public.dns')
        if (-not $domains -or $domains.Count -eq 0) { throw '[!] public.domains required in project.cfg' }
        if (-not $dnsCfg) { throw '[!] public.dns required in project.cfg' }
        if ($registry.ToUpper() -ne 'SPACESHIP') {
            throw "[!] public.dns.registry must be SPACESHIP (got $registry)"
        }
        if (-not $SiteTxt) { $SiteTxt = @{} }

        foreach ($domain in $domains) {
            $domain = [string]$domain
            $items = [System.Collections.Generic.List[object]]::new()
            $specs = [System.Collections.Generic.List[object]]::new()

            foreach ($prop in $dnsCfg.PSObject.Properties) {
                if ($prop.Name -in @('registry', 'sites')) { continue }
                $specs.Add([ordered]@{ Type = [string]$prop.Name; Spec = $prop.Value })
            }
            if ($dnsCfg.sites -and $dnsCfg.sites.$domain) {
                foreach ($prop in $dnsCfg.sites.$domain.PSObject.Properties) {
                    $specs.Add([ordered]@{ Type = [string]$prop.Name; Spec = $prop.Value })
                }
            }

            foreach ($entry in $specs) {
                $type = [string]$entry.Type
                $spec = $entry.Spec
                if ($null -eq $spec) { continue }
                if ($spec -is [array] -or $spec -is [System.Collections.Generic.List[object]]) {
                    foreach ($name in @($spec)) {
                        $items.Add([ordered]@{
                                type    = $type
                                name    = [string]$name
                                address = $pubHost
                                ttl     = 3600
                            })
                    }
                    continue
                }
                foreach ($rec in $spec.PSObject.Properties) {
                    $row = [ordered]@{
                        type = $type
                        name = [string]$rec.Name
                        ttl  = 3600
                    }
                    if ($type -in @('A', 'AAAA')) { $row.address = [string]$rec.Value }
                    else { $row.value = [string]$rec.Value }
                    $items.Add($row)
                }
            }

            $extraTxt = [string]$SiteTxt[$domain]
            if (-not [string]::IsNullOrWhiteSpace($extraTxt)) {
                $dup = $false
                foreach ($existing in $items) {
                    if ([string]$existing.type -eq 'TXT' -and [string]$existing.name -eq '@' -and [string]$existing.value -eq $extraTxt) {
                        $dup = $true
                        break
                    }
                }
                if (-not $dup) {
                    $items.Add([ordered]@{
                            type  = 'TXT'
                            name  = '@'
                            value = $extraTxt
                            ttl   = 3600
                        })
                }
            }

            if ($items.Count -eq 0) { throw "[!] no DNS records to apply for $domain" }
            Write-Host "[+] Applying DNS ($domain, registry=$registry, ip=$pubHost, records=$($items.Count))"
            $this.SaveRecords($domain, @($items))
        }
        Write-Host '[+] Done — DNS'
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD3D3FObidkBtTb
# BFWeBcoqiYqD1mkEjvaoME/K3t1A36CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPJnmgv6
# SbFH/U47POKvfNLTj+9YenA8Y9z10mtCaeTVMAsGCSqGSIb3DQEBAQSCAgB48ub5
# /Bhcf5nOFzNhyTK3cZKa9O3k7SuM0flvdc4FyXsKII3MmNXJSutE4Km9nnKpQeC7
# qd0u4mBVKuf8+7NXSk3qoiFe/G0fmlWi4OwDbz9eJkpPoMtLWohBCjEzIsgK1CjZ
# nfStE+IH30TAr4yZZ5WxGiTxkeGnHeHttEt8P7L5CHSlFQ803+nyp2I2YNSMNh3M
# 7Gm+upoZXE+bhd9UmqXYbj0fbjKxsqVve8JIUbNWat1DgYWRdwM2/VuamPl1xjFt
# yFZAjT4IP4xdHcG1qrUDS0QT76D1dMpzgIjurJs1NstAwBuPgMbm9tIEvTW1UCoH
# 0FUKhLnd0wpYFKf1XIP9cY71PTGSErEKuz4zhC7k6gXNdmY4jYmZ+RvHSRzA1j43
# 26F2BEj9MOaRYS80lfO3RtQB3LkDvAKmHyBnyMG/JfxvTSxLShouq5XyGBOdSOlh
# Rbt0XZoLiwfZcOiGDh343B2D1zA5hyOUa/3cNN+OBTnIGntidTGNU7/DeEEnaUTW
# /8xe9y6YFsn3NYFFR6FJMpWQOEfRrwqXzUrR4gI0O4YAcaA2TtwGidbxPv6G04bI
# 3u0G9CWhxvYMefnI7f5aCfrNf7aFwpquLuZRi1jhyN2ZoB3Yelu4kXP3060u3y/I
# tUnFVWQ82wyCIG23MA1fvn/+eCDxfe6Pr+4fQqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
