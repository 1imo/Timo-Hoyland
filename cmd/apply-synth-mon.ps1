#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

[void][Env]::new()

$project = [Config]::new('project.cfg')

$pubDomain = [string]$project.Get('public.domain')
$rows = [System.Collections.Generic.List[object]]::new()
foreach ($stage in @('live', 'test')) {
    $url = [string]$project.Get("public.app.$stage.endpoint")
    if ([string]::IsNullOrWhiteSpace($url)) { continue }
    $srv = [string]$project.Get("public.app.$stage.server")
    if ([string]::IsNullOrWhiteSpace($srv)) { throw "[!] public.app.$stage.server required in project.cfg" }
    $vhost = ($url -replace '^https?://', '').Split('/')[0]
    $rows.Add([ordered]@{
        targets = @($url)
        labels  = @{ service = $project.Name; host = $srv; vhost = $vhost }
    })
    if ($stage -eq 'live' -and $pubDomain) {
        $rows.Add([ordered]@{
            targets = @("https://www.$pubDomain")
            labels  = @{ service = $project.Name; host = $srv; vhost = "www.$pubDomain" }
        })
    }
}
$json = ($rows | ConvertTo-Json -Depth 10 -Compress)

$git = [SourceControl]::new($project.Require('remotes.iac.url'))
try {
    $git.Sync()
    $iacPath = "docker/blackbox/configs/https/$($project.Name).json"
    $git.WriteContent($iacPath, $json)
    $git.CommitAndPush("blackbox: $($project.Name)")
    Write-Host "[+] Done — synth-mon → $iacPath ($($env:ENV))"
}
finally {
    $git.Cleanup()
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAIjlIZh8ceYAQg
# nyo+7mzv0ORekRZq9+lI/4jlUNiCSKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIMbvFt5f
# xv1x/j+oCqe7zMT2B3ctW4dHKIQnu6dyBdsoMAsGCSqGSIb3DQEBAQSCAgAS5HXS
# KL8mWEDZnFPbt90TA9HBi9w4DyNVb2kFEErET+Jfi8dDXQyhwFPnkcO+jEAEMGQh
# KyZirVhFfZXqKee99L15ueuRS9QYVGFDA8EzAi3afwkBvz5eAeE2wFrExlFL1kG9
# BW4P4/vqc/aCU/39Ftih9CsExg6QFz0fVSxqL1X1LQp5Y/LMojHaEPOsat3HT4EF
# XydBQwNIL/1okckZFA5ZGPT5iD5+FHY0jIM1w4WCPhShdz1D+79h4MHpAfIyZxVb
# Swc6SR1UGtRPsMp9+wDaRdxSXSy8Hbdx89rJwLOVs8uPhoISJ3BViYdH7BLa91c/
# 99sl7kF5pTmjQLf2hXxUyJWKC9sVk6meYuNEBVe5MZiWAOy4zHyK3fpXuS4xlMIs
# EBmGwWdzUPGSac+oYSnRNYquQjd53Z4bBmoYV5zkNuEB/ZES57V9nzUUclhILtYR
# HdZxwjrxKhWdxJBWhGv5O/Wd/GRzKAzqPOiB9OFw4AXivu2QRRbrkn2YBxgBlx/8
# h8IKNnKhcAKGOP5zVZbcv92biTVTdNYTmcyYhWXnUSOuNXugKIruwaFq1+mz2CGy
# Kb3GNL2Rp1grAgAR0RF4WI63vy43XnAPZZ5Rx0jeuw3c0xMXnBjINEcW/VrfyAD/
# CCkrIx9Z0xFH7Ep7hFJcRSj8OkQ1rEbfuB9DxqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
