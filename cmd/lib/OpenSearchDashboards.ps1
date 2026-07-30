class OpenSearchDashboards {
    [string]$Url
    [Env]$Env
    [Config]$Project

    OpenSearchDashboards([Config]$Project, [Env]$Env) {
        if (-not $Project -or -not $Project.Loaded) { throw '[!] OpenSearchDashboards requires project.cfg' }
        if (-not $Env) { throw '[!] OpenSearchDashboards requires Env' }
        $this.Project = $Project
        $this.Env = $Env
        $this.Url = $this.Env.Require('OPENSEARCH_DASHBOARDS_URL').TrimEnd('/')
    }

    hidden [string] PrepareNdjson([string]$File, [string]$Slug) {
        $lines = [System.Collections.Generic.List[string]]::new()
        $title = "$($this.Project.Name) / $Slug"
        foreach ($line in Get-Content $File) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $obj = $line | ConvertFrom-Json
            if ($obj.attributes -and $obj.attributes.PSObject.Properties['title']) {
                $obj.attributes.title = $title
            }
            if ($obj.attributes -and $obj.attributes.PSObject.Properties['description']) {
                $cur = [string]$obj.attributes.description
                if ($cur -notmatch [regex]::Escape($this.Project.Name)) {
                    $obj.attributes.description = "$title — $cur".Trim(' —')
                }
            }
            $lines.Add(($obj | ConvertTo-Json -Depth 50 -Compress))
        }
        return ($lines -join "`n")
    }

    hidden [hashtable] Headers() {
        return @{
            'osd-xsrf' = 'true'
            'kbn-xsrf' = 'true'
        }
    }

    [void] ImportNdjson([string]$File, [string]$Slug) {
        Write-Host "== OpenSearch Dashboards import: $($this.Url) =="
        Write-Host "    $($this.Project.Name) / $Slug ← $File"
        $body = $this.PrepareNdjson($File, $Slug)
        $tmp = [IO.Path]::GetTempFileName()
        try {
            Set-Content -Path $tmp -Value $body -NoNewline
            $form = @{ file = Get-Item $tmp }
            $r = Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/saved_objects/_import?overwrite=true" `
                -Headers $this.Headers() -Form $form
            if (-not $r.success) {
                $r | ConvertTo-Json -Depth 10
                throw '[!] OpenSearch Dashboards import reported errors'
            }
            Write-Host "[+] OpenSearch Dashboards: $($this.Project.Name) / $Slug"
        }
        finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    [void] ImportDir([string]$Dir) {
        if (-not (Test-Path $Dir)) { return }
        $files = Get-ChildItem $Dir -Filter '*.ndjson' -File | Where-Object { $_.Length -gt 0 }
        if (-not $files) { Write-Host "[i] OpenSearch Dashboards: no dashboards in $Dir"; return }
        foreach ($f in $files) {
            $slug = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            $this.ImportNdjson($f.FullName, $slug)
        }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDZP7mRne3r2F5x
# DIdqV3JpD+AKQ71XOIKVcRSNWu99I6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOKKLW4d
# Cd1WmVQhBslSRc6284+nkv6zTJk7AnruZh8QMAsGCSqGSIb3DQEBAQSCAgA2gn71
# 109c2kWXXaA7QjyJJCqBMpxi64CNwyTE6dAgKb35XJIT/rj+rrdLkt9LEROuzAiE
# nX0cVUN4ut4DVwSbpDu7qScD3wmekQhosG3iwgHD+tlUE9so8sjZiVaLfvKSFxwv
# Znle/OcUJ3pBApdM8OElb0jypUIIHN6tX1ES2D4OLVBlml+tPzGTbLNCrjOvciPV
# JSgNTZeqji6ckl79qAbb1QcOL3sKkQFRE1//GBFKbfIpAy6pfh2eRvJrtds6yX0y
# U+9lQFl2DmYVF302ASPkn2+yXUQxfVw3bs27KdbLJZgAitfG9X3r/774xyj/tmlS
# bELE65fOvUXFe4sMXlxoaISIZg8fQi0fMVm/LNUnkag7F91j/2ROcyL0WsfPWbQO
# upvEybHwsyn49USYn59V5rSVClRHSCH3c3bPORNsurvyoiUInHA62XBbZEv/mHIe
# poqamJamZY0PocdI7tprRU8AsQAnjgMEBZJN4DIxcGgnQIbQjZoNFAx42LWNQTlO
# 7IgSfdShy1l8ibvsOwd9yZRiT9rHDzaskohBC1EXBV3Tew/jbklwMdv9xw4WFDKw
# 9Hg5i3lp/B33ak033qq437iF5pw6A5o7bq+63d+dlRsM07wsBBzSPIWUFD23rVnT
# GpNjLr6JavpTjA+c93OPP21RLXvMnSUTxCzxg6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
