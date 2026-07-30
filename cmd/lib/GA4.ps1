class GA4 {
    [Config]$Project
    [string]$AccountId
    [Google]$Google

    GA4([Config]$Project, [Google]$Google) {
        if (-not $Project -or -not $Project.Loaded) { throw '[!] GA4 requires project.cfg' }
        if (-not $Google) { throw '[!] GA4 requires Google' }
        $this.Project = $Project
        $this.Google = $Google
        $this.AccountId = $this.FindOrProvisionAccount()
    }

    hidden [string] FindOrProvisionAccount() {
        $matches = $this.FindAccountIds()
        if ($matches.Count -gt 1) {
            Write-Host "[!] Found $($matches.Count) GA4 accounts named '$($this.Project.Name)' — using $($matches[0]), delete the extras in Admin UI"
        }
        if ($matches.Count -ge 1) {
            Write-Host "[+] GA4 account: $($this.Project.Name) (accounts/$($matches[0]))"
            return [string]$matches[0]
        }

        Write-Host "[+] GA4 account '$($this.Project.Name)' not found — requesting provision ticket"
        $headers = $this.Google.AuthHeaders()
        $body = (@{
                account     = @{
                    displayName = $this.Project.Name
                    regionCode  = 'GB'
                }
                redirectUri = 'https://analytics.google.com/'
            } | ConvertTo-Json -Compress -Depth 5)
        try {
            $ticket = Invoke-RestMethod -Method Post -Uri 'https://analyticsadmin.googleapis.com/v1beta/accounts:provisionAccountTicket' -Headers $headers -Body $body
        }
        catch {
            throw "[!] GA4 cannot create account '$($this.Project.Name)': $($_.Exception.Message)"
        }

        $url = "https://analytics.google.com/analytics/web/?provisioningSignup=false#/termsofservice/$($ticket.accountTicketId)"
        Write-Host "[!] Accept GA4 ToS: $url"
        if (Get-Command open -ErrorAction SilentlyContinue) { & open $url }

        Write-Host "[+] Waiting for GA4 account '$($this.Project.Name)' (poll every 5s, up to 15m)..."
        $deadline = (Get-Date).AddMinutes(15)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 5
            $matches = $this.FindAccountIds()
            if ($matches.Count -ge 1) {
                Write-Host "[+] GA4 account: $($this.Project.Name) (accounts/$($matches[0]))"
                return [string]$matches[0]
            }
            Write-Host "[=] waiting for account '$($this.Project.Name)'..."
        }
        throw "[!] Timed out waiting for GA4 account '$($this.Project.Name)' after ToS"
    }

    hidden [string[]] FindAccountIds() {
        $headers = $this.Google.AuthHeaders()
        $found = [System.Collections.Generic.List[string]]::new()
        $pageToken = $null
        do {
            $uri = 'https://analyticsadmin.googleapis.com/v1beta/accountSummaries'
            if ($pageToken) { $uri += "?pageToken=$([uri]::EscapeDataString($pageToken))" }
            $r = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            $summaries = @()
            if ($null -ne $r.accountSummaries) { $summaries = @($r.accountSummaries) }
            foreach ($summary in $summaries) {
                if ($summary.displayName -eq $this.Project.Name -and $summary.account) {
                    $id = ($summary.account -replace '^accounts/', '')
                    if ($id) { $found.Add($id) }
                }
            }
            $pageToken = $r.nextPageToken
        } while ($pageToken)
        return @($found | Sort-Object { [long]$_ })
    }

    [string] EnsureProperty([string]$Domain) {
        if ([string]::IsNullOrWhiteSpace($Domain)) { throw '[!] domain required' }
        $headers = $this.Google.AuthHeaders()
        $parent = "accounts/$($this.AccountId)"
        $filter = [uri]::EscapeDataString("parent:$parent")
        $pageToken = $null
        do {
            $uri = "https://analyticsadmin.googleapis.com/v1beta/properties?filter=$filter"
            if ($pageToken) { $uri += "&pageToken=$([uri]::EscapeDataString($pageToken))" }
            $r = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            foreach ($prop in @($r.properties)) {
                if ($prop.displayName -eq $Domain) {
                    Write-Host "[+] GA4 property: $Domain ($($prop.name))"
                    return $this.EnsureWebStream($prop.name, $Domain)
                }
            }
            $pageToken = $r.nextPageToken
        } while ($pageToken)

        $body = (@{
                parent           = $parent
                displayName      = $Domain
                timeZone         = 'Europe/London'
                currencyCode     = 'GBP'
                industryCategory = 'OTHER'
            } | ConvertTo-Json -Compress)
        $created = Invoke-RestMethod -Method Post -Uri 'https://analyticsadmin.googleapis.com/v1beta/properties' -Headers $headers -Body $body
        Write-Host "[+] GA4 property created: $Domain ($($created.name))"
        return $this.EnsureWebStream($created.name, $Domain)
    }

    hidden [string] EnsureWebStream([string]$PropertyName, [string]$Domain) {
        $headers = $this.Google.AuthHeaders()
        $pageToken = $null
        do {
            $uri = "https://analyticsadmin.googleapis.com/v1beta/$PropertyName/dataStreams"
            if ($pageToken) { $uri += "?pageToken=$([uri]::EscapeDataString($pageToken))" }
            $r = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            foreach ($stream in @($r.dataStreams)) {
                if ($stream.type -eq 'WEB_DATA_STREAM') {
                    $mid = [string]$stream.webStreamData.measurementId
                    if ($mid) {
                        Write-Host "[+] GA4 measurement ID: $Domain → $mid"
                        return $mid
                    }
                }
            }
            $pageToken = $r.nextPageToken
        } while ($pageToken)

        $body = (@{
                type          = 'WEB_DATA_STREAM'
                displayName   = $Domain
                webStreamData = @{
                    defaultUri = "https://$Domain"
                }
            } | ConvertTo-Json -Compress -Depth 5)
        $created = Invoke-RestMethod -Method Post -Uri "https://analyticsadmin.googleapis.com/v1beta/$PropertyName/dataStreams" -Headers $headers -Body $body
        $mid = [string]$created.webStreamData.measurementId
        if (-not $mid) { throw "[!] GA4 web stream created for $Domain but measurementId missing" }
        Write-Host "[+] GA4 measurement ID created: $Domain → $mid"
        return $mid
    }

    [hashtable] EnsureDomains([string[]]$Domains) {
        $out = [ordered]@{}
        foreach ($domain in $Domains) {
            $out[$domain] = $this.EnsureProperty([string]$domain)
        }
        return $out
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD+tteNIJqNgZIl
# pPJ/hyrurn1UFOVnu8a3n0nN6EV/QKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEILUon883
# gVGah0Uamwr/2hHRuNOiosbbmdR8SswlmeEvMAsGCSqGSIb3DQEBAQSCAgBEiyAX
# ezjc2bOo4HIbLLiIArOcm48Zwou0AxqV/iCAd3WbRJ6DIz7DXioIXLwyPqRQ2dZx
# fzsnkMX93VBKRmh1y9mnFAUBYZtYdBNgzv2g38V+i1xY9scARLJFdWoGEd1/3P/r
# 6R7CLiASKCAwvzRyWHDOEa7nAJolEzx0pnTiW2smnjN4pXlxCVkewvpOGTE4gFdF
# ak08ZyIoQvUplRobvPnztCfjVo4OHXA1s83kPk8T2weG/pQT4x4K9hM9zzr01oXm
# 8LhaLwFnFOuAReNSsFV2uElkEFzZwXd9XzhjcyTfzzvQDuhseWcH9n3PDHkqMK2B
# K0fleaizsbyELsOnuhKup+pOf/mHQ7fPTDdPrxtwl6ZMK9W+x9+KoSaTbiojnAwH
# XuUB7mEGFHBt7EvmIAxh5dVgXYOoMcv4vvGjsGFttqzNDK/qLaMQ/drqqFWir0Zl
# VJkmyjrcPAA21vtp46KLqmewr+mq21o7ZEHI28zHu0QhyO5GGDeJp3AZsl7Bbocg
# xeQq/+CmRY4mU/PRcUnA/KXMUXmu4482GtLjpFGGajLUquCzugoIuE0j/TS+Cgsu
# upFx9EPV0hzJbkmOWqD9YYBb6HqWP0F+Oseg7TvtHP1aFEyfNeW6jGbm5C9hSEIh
# jK5R8d7GrGBbGejGY5ThTXhkATxOjv2nXPAWW6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
