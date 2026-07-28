class Kibana {
    [string]$Url
    [string]$Env
    [string]$ProjectName

    Kibana([string]$ProjectName) {
        if (-not $env:KIBANA_URL_PUBLIC) { throw '[!] KIBANA_URL_PUBLIC is required' }
        if (-not $env:ENV) { throw '[!] ENV is required' }
        $this.Url = $env:KIBANA_URL_PUBLIC
        $this.Env = $env:ENV
        $this.ProjectName = $ProjectName
    }

    hidden [string] PrepareNdjson([string]$File, [string]$Slug) {
        $lines = [System.Collections.Generic.List[string]]::new()
        $title = "$($this.ProjectName) / $Slug"
        foreach ($line in Get-Content $File) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $obj = $line | ConvertFrom-Json
            if ($obj.attributes -and $obj.attributes.PSObject.Properties['title']) {
                $obj.attributes.title = $title
            }
            if ($obj.attributes -and $obj.attributes.PSObject.Properties['description']) {
                $cur = [string]$obj.attributes.description
                if ($cur -notmatch [regex]::Escape($this.ProjectName)) {
                    $obj.attributes.description = "$title — $cur".Trim(' —')
                }
            }
            $lines.Add(($obj | ConvertTo-Json -Depth 50 -Compress))
        }
        return ($lines -join "`n")
    }

    hidden [hashtable] Headers() {
        $h = @{ 'kbn-xsrf' = 'true' }
        if ($env:KIBANA_USER) {
            $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($env:KIBANA_USER):$($env:KIBANA_PASSWORD)"))
            $h.Authorization = "Basic $b64"
        }
        return $h
    }

    [void] ImportNdjson([string]$File, [string]$Slug) {
        Write-Host "== Kibana import: $($this.Url) =="
        Write-Host "    $($this.ProjectName) / $Slug ← $File"
        $body = $this.PrepareNdjson($File, $Slug)
        $tmp = [IO.Path]::GetTempFileName()
        try {
            Set-Content -Path $tmp -Value $body -NoNewline
            $form = @{ file = Get-Item $tmp }
            $r = Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/saved_objects/_import?overwrite=true" `
                -Headers $this.Headers() -Form $form
            if (-not $r.success) {
                $r | ConvertTo-Json -Depth 10
                throw '[!] Kibana import reported errors'
            }
            Write-Host "[+] Kibana dashboard: $($this.ProjectName) / $Slug"
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    [void] ImportDir([string]$Dir) {
        if (-not (Test-Path $Dir)) { return }
        $files = Get-ChildItem $Dir -Filter '*.ndjson' -File | Where-Object { $_.Length -gt 0 }
        if (-not $files) { Write-Host "[i] Kibana: no dashboards in $Dir"; return }
        foreach ($f in $files) {
            $slug = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            $this.ImportNdjson($f.FullName, $slug)
        }
    }

    [void] ApplyAlertingRules() {
        if (-not (Test-Path 'alerts/kibana.json')) { throw '[!] Missing alerts/kibana.json' }
        Write-Host "== Kibana alerting rules: $($this.Url) (ENV=$($this.Env)) =="
        $rules = Get-Content 'alerts/kibana.json' -Raw | ConvertFrom-Json
        foreach ($rule in $rules) {
            $id = $rule.id
            Write-Host "   → $id"
            $create = $rule | Select-Object * -ExcludeProperty id
            if ($create.params.esQuery -and $create.params.esQuery -match '__ENV__') {
                $create.params.esQuery = $create.params.esQuery -replace '__ENV__', $this.Env
            }
            $update = $create | Select-Object * -ExcludeProperty rule_type_id, consumer, enabled
            $uri = "$($this.Url)/api/alerting/rule/$id"
            $headers = $this.Headers()
            $headers['Content-Type'] = 'application/json'
            try {
                Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ErrorAction Stop | Out-Null
                $body = $update | ConvertTo-Json -Depth 30 -Compress
                Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -Body $body | Out-Null
            }
            catch {
                $body = $create | ConvertTo-Json -Depth 30 -Compress
                Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body | Out-Null
            }
            Write-Host "[+] Kibana rule OK: $id"
        }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC4GMAPe0xi3njH
# hTMvFMNwKZJRsTVuFJNUq9KjP6FBx6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIMawVWWE
# GE01a0jWIz20P7DOoZHyJR8dW+QC1GKDvarUMAsGCSqGSIb3DQEBAQSCAgBQaVPK
# C15Ayy1lfeWeP31uNyalT0ARqW4l5pO7E26aBdNp25I4sEytGLC5emiaph8sVjWr
# M9VOrubn/xyE1aKfZQNMO4pBKLOZszKa9bdbGzc2WSfGqzAaxokP5qMoJqIG1w15
# E+vBhL4BTr6xsNa8I5JK8NHXnwlnR/ZRmtYqg5c0cI2Q1WL9Jmup9O4olFU13hlR
# Jb7Rqfe7OL4JImogd04wdE4IQP7d3NCJO59QU64tx8Fc+olUE2A2cUdbDi0nN+rR
# mreIuAa3QZNdnxaYFg4i1d8KwD0PCicCMudB6GkA5EpOI+IoB5uz6O0qjdcXFVSG
# FErYqoPyvZ0cWieLy43zH3DkLu1kRsMzdsN8onv4EP6S+UVExahYlW+Q7w576fLW
# djPhid/u4MlHZhp+2MiCNETSrSSUTOAifcM048nlPDoJKlQzuS2QzgdI5nr+hlOz
# azlFoWaEQOmfmW8/UBiV5AZ0bU/Vj5Yrm4D8/flqtjCcxuLi7IVd7UQ8/QT7VJkL
# m/npKsg73tz56XsEicRt+brmr7u7TwNo/r3UwLoaxUv4n5lZK4JKO/WHq859PL51
# hM6E7Ru5ps2u+htnMtkVpPjg7J2aNS7kaR9ja7cF5rItwVuXRRQ0rQekDbj6K3h1
# ZYjQlTgIeQvlN6a6tL4hZbCPtOuRtjqifI2zlqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
