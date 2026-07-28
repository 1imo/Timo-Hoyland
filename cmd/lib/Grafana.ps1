class Grafana {
    [string]$Url
    [string]$UserPass
    [string]$Env
    [string]$ProjectName

    Grafana([string]$ProjectName) {
        if (-not $env:GRAFANA_URL_PUBLIC) { throw '[!] GRAFANA_URL_PUBLIC is required' }
        if (-not $env:GRAFANA_ADMIN_USER) { throw '[!] GRAFANA_ADMIN_USER is required' }
        if (-not $env:GRAFANA_ADMIN_PASSWORD) { throw '[!] GRAFANA_ADMIN_PASSWORD is required' }
        if (-not $env:ENV) { throw '[!] ENV is required' }
        $this.Url = $env:GRAFANA_URL_PUBLIC
        $this.UserPass = "$($env:GRAFANA_ADMIN_USER):$($env:GRAFANA_ADMIN_PASSWORD)"
        $this.Env = $env:ENV
        $this.ProjectName = $ProjectName
    }

    [void] EnsureFolder([string]$FolderUid, [string]$Title) {
        $uid = "$($this.ProjectName)-$FolderUid"
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
        $body = (@{ uid = $uid; title = "$($this.ProjectName) / $Title" } | ConvertTo-Json -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/folders" -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
        Write-Host "[+] Grafana folder created: $uid"
    }

    [string] PrepareDashboard([string]$File, [string]$Slug) {
        $dash = Get-Content $File -Raw | ConvertFrom-Json
        $dash.title = "$($this.ProjectName) / $Slug ($($this.Env))"
        $dash.uid = "$($this.ProjectName)-$Slug-$($this.Env)"
        if (-not $dash.tags) { $dash.tags = @() }
        if ($dash.tags -notcontains $this.ProjectName) { $dash.tags += $this.ProjectName }
        if ($dash.tags -notcontains $this.Env) { $dash.tags += $this.Env }
        if ($dash.templating -and $dash.templating.list) {
            foreach ($item in $dash.templating.list) {
                if ($item.name -eq 'environment') {
                    $item.current = @{ selected = $true; text = $this.Env; value = $this.Env }
                    $item.options = @(@{ selected = $true; text = $this.Env; value = $this.Env })
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
            $folderUid = "$($this.ProjectName)-$slug"
            $this.EnsureFolder($slug, $slug)
            $dash = $this.PrepareDashboard($f.FullName, $slug)
            $this.ImportDashboard($dash, $folderUid)
        }
    }

    [void] ApplyAlertingRules() {
        if (-not (Test-Path 'alerts/grafana.json')) { throw '[!] Missing alerts/grafana.json' }
        Write-Host "== Grafana alerting rules: $($this.Url) (ENV=$($this.Env)) =="
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
        $headers = @{ Authorization = "Basic $auth" }
        $doc = Get-Content 'alerts/grafana.json' -Raw | ConvertFrom-Json
        $this.EnsureFolder($doc.folder.uid, $doc.folder.title)
        $folderUid = "$($this.ProjectName)-$($doc.folder.uid)"
        foreach ($rule in $doc.rules) {
            $json = ($rule | ConvertTo-Json -Depth 50 -Compress) -replace '__ENV__', $this.Env
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA6w8WOBBmlz3w3
# KEZfxe/OmGBpKVrjuTVgLmrEMKeiK6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPkbqobF
# fIUGpoZ7Xk/gKn4SQ/8+TVvpOigE9k4ywJjIMAsGCSqGSIb3DQEBAQSCAgB2ynzr
# 0PLCCqZ917ZwOAdcqg+/mT5yFs4OPXlAbSplNeyEhNEh0KY3yRVfrmX7b1cxown6
# DVax69PS57gSrTsRgLnJwa3No+EHXPR/cPI7YOUigeHsbwnn0uso/X83ZXcHOFjX
# NnPhRSUjZmFG8lHyS3PPB3dJ79GopAflnD0KYnI7sfHCU8QaREWLO6oiq7bSMtsa
# ce6SWoLLxBDVsCmSZzOp35lZLiYRDwoll9VPS3QkQmyM5ca0i+LRbN3uTDWQeNN2
# B820Xmk9pQQkn5cCyW+0/ZfVzZVzSbbB7AuR8jaJxhYzntxv7Xhf65UekdHFNdpM
# GglvMGE9kiD4Gm0VeTDmG2zHIoOL17OlEKCoyhvY3bPR0WzrbfKttLS9rn1x6yl4
# NLLwKkqpTXjpz0qHyfRStZXatnkf3jggp33A/XlQCOJUgQQATRRAZgLCr3qe64Hx
# HLHf4pK7n9UwvD4eVKP6/6OHbCzQpkmBdXnWcSzG6VwfvR/DjIfyUn23qgTli0sy
# kTCv9SV4wWjuL/kU24zilPw7QoQiJMhd6nQW4vTCDuZjovwUk1w+tC9I2Mq14FEo
# BrWS61NEsHi3mLgdl7y3Zf3pv5CKEuA+hxY3ask6H/SYicKpmTadwvBgKV1p6Hm/
# 96bSFxofANB8AwTZ31kMK5cascF8UVVn3juXxaErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
