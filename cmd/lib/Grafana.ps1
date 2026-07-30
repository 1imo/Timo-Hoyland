class Grafana {
    [string]$Url
    [string]$UserPass
    [Env]$Env
    [Config]$Project

    Grafana([Config]$Project, [Env]$Env) {
        if (-not $Project -or -not $Project.Loaded) { throw '[!] Grafana requires project.cfg' }
        if (-not $Env) { throw '[!] Grafana requires Env' }
        $this.Project = $Project
        $this.Env = $Env
        $this.Url = $this.Env.Require('GRAFANA_URL')
        $this.UserPass = "$($this.Env.Require('GRAFANA_ADMIN_USER')):$($this.Env.Require('GRAFANA_ADMIN_PASSWORD'))"
    }

    [void] EnsureFolder([string]$FolderUid, [string]$Title) {
        $uid = "$($this.Project.Name)-$FolderUid"
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
        $headers = @{ Authorization = "Basic $auth" }
        $code = 200
        try {
            Invoke-RestMethod -Method Get -Uri "$($this.Url)/api/folders/$uid" -Headers $headers -ErrorAction Stop | Out-Null
        }
        catch {
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode.value__ }
            else { throw }
        }
        if ($code -eq 200) { Write-Host "[+] Grafana folder exists: $uid"; return }
        if ($code -ne 404) { throw "[!] Grafana folder GET HTTP $code" }
        $body = (@{ uid = $uid; title = "$($this.Project.Name) / $Title" } | ConvertTo-Json -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/folders" -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
        Write-Host "[+] Grafana folder created: $uid"
    }

    [string] PrepareDashboard([string]$File, [string]$Slug) {
        $dash = Get-Content $File -Raw | ConvertFrom-Json
        $dash.title = "$($this.Project.Name) / $Slug ($($this.Env.Name))"
        $dash.uid = "$($this.Project.Name)-$Slug-$($this.Env.Name)"
        if (-not $dash.tags) { $dash.tags = @() }
        if ($dash.tags -notcontains $this.Project.Name) { $dash.tags += $this.Project.Name }
        if ($dash.tags -notcontains $this.Env.Name) { $dash.tags += $this.Env.Name }
        if ($dash.templating -and $dash.templating.list) {
            foreach ($item in $dash.templating.list) {
                if ($item.name -eq 'environment') {
                    $item.current = @{ selected = $true; text = $this.Env.Name; value = $this.Env.Name }
                    $item.options = @(@{ selected = $true; text = $this.Env.Name; value = $this.Env.Name })
                }
            }
        }
        return ($dash | ConvertTo-Json -Depth 50 -Compress)
    }

    [void] ImportDashboard([string]$DashboardJson, [string]$FolderUid) {
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
        $headers = @{ Authorization = "Basic $auth" }
        $dash = $DashboardJson | ConvertFrom-Json
        $payload = (@{
            dashboard = $dash
            folderUid = $FolderUid
            overwrite = $true
            message   = 'apply-dashboards'
        } | ConvertTo-Json -Depth 50 -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/dashboards/db" -Headers $headers -ContentType 'application/json' -Body $payload | Out-Null
        Write-Host "[+] Grafana dashboard: $($dash.title) → folder/$FolderUid"
    }

    [void] ImportDir([string]$Dir) {
        if (-not (Test-Path $Dir)) { return }
        $files = Get-ChildItem $Dir -Filter '*.json' -File | Where-Object { $_.Length -gt 0 }
        if (-not $files) { Write-Host "[i] Grafana: no dashboards in $Dir"; return }
        foreach ($f in $files) {
            $slug = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            $folderUid = "$($this.Project.Name)-$slug"
            $this.EnsureFolder($slug, $slug)
            $dash = $this.PrepareDashboard($f.FullName, $slug)
            $this.ImportDashboard($dash, $folderUid)
        }
    }

    [void] ApplyAlertingRules() {
        if (-not (Test-Path 'alerts/grafana.json')) { throw '[!] Missing alerts/grafana.json' }
        Write-Host "== Grafana alerting rules: $($this.Url) (ENV=$($this.Env.Name)) =="
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
        $headers = @{ Authorization = "Basic $auth" }
        $doc = Get-Content 'alerts/grafana.json' -Raw | ConvertFrom-Json
        $this.EnsureFolder($doc.folder.uid, $doc.folder.title)
        $folderUid = "$($this.Project.Name)-$($doc.folder.uid)"
        foreach ($rule in $doc.rules) {
            $json = ($rule | ConvertTo-Json -Depth 50 -Compress) -replace '__ENV__', $this.Env.Name
            $parsed = $json | ConvertFrom-Json
            $parsed.folderUid = $folderUid
            $json = $parsed | ConvertTo-Json -Depth 50 -Compress
            $uid = $parsed.uid
            Write-Host "   → $uid"
            $uri = "$($this.Url)/api/v1/provisioning/alert-rules/$uid"
            $ruleHeaders = $headers.Clone()
            $ruleHeaders['X-Disable-Provenance'] = 'true'
            $code = 200
            try {
                Invoke-RestMethod -Method Put -Uri $uri -Headers $ruleHeaders -ContentType 'application/json' -Body $json -ErrorAction Stop | Out-Null
            }
            catch {
                if ($_.Exception.Response) {
                    $code = [int]$_.Exception.Response.StatusCode.value__
                    if ($code -eq 404) {
                        Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v1/provisioning/alert-rules" -Headers $ruleHeaders -ContentType 'application/json' -Body $json | Out-Null
                        $code = 200
                    }
                    else { throw }
                }
                else { throw }
            }
            if ($code -lt 200 -or $code -ge 300) { throw "[!] Grafana rule $uid HTTP $code" }
            Write-Host "[+] Grafana rule OK: $uid"
        }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCjzIZ+sWB91qSD
# LIh9/+IA6I30KJWrccF2rtbrrRgAv6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIL/fasig
# FxrKZDW87W4pd+m94DDKh9BCmdLP6GhqCvJfMAsGCSqGSIb3DQEBAQSCAgA++8yw
# D5fUHS4Sde7gpNigVrgsD8wmuoliXRhQTA+MULhdrm4hB5bGdgoRLWOqOfP5JHux
# C+fES4z35x6t4w4RmJ1DYZxAoNXQ/pFqjGgOXxTLGgZBMR3nSopx9UMk+IPbxP1c
# VsbPPjebzdPL8s2pb5hdRKkEZlV3NHTv2jDTqfLH3lSh6JWSbKmqhatEUU/PjKyI
# 5ogJNGLEeEWDECBCuytbpEweZYCCvZDKunU9cu4GUNN6Fdg2AMQ3VYGlbnj2R9TW
# Og2q/IB2Wp3HwZZJ2frxhROwJnhqfn9b3qM9Q3kiCwMrUlgVirqXJDhZYy8p+V/I
# B0IaJwSlFDyMs7NfY/k+cD+TQyF7mzVA3kuqphiXYV7NUCpvZHszJUcmX4g0Xbpq
# 5PEpjynLjcRz02qcc0uPuKmAYYX7Mi+/OrKbpwvWBD7iIucD/2eINoyWNViStBN4
# seekeOa4w4ZF7f2CX0Z07QxzWXWBxP8Exxv74ZS25m/wrkQsUWKmZN+SDCWMtv2r
# Hlb7372IpIvlxwHedBfq2n6k4lUOBHUDWq5rSC+WPI4ayq1++ufR/XU2sc1oL64S
# VKjBC235BHORM5hjoWGDy7jjMv06Ilj7/VBYN1olMJwUQTONlBauelvex8ufezeJ
# N5QPqmZzzpiCrykaksVTh7avirs1RqwzXWqu/6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
