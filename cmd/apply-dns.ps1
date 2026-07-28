#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/Spaceship.ps1"

[void][Env]::new()

$project = [Config]::new('project.cfg')
$registry = $project.Require('public.dns.registry')
$domain = $project.Require('public.domain')
$pubHost = $project.Require('public.host')
$names = @($project.Get('public.dns.A'))
if (-not $names -or $names.Count -eq 0) { throw '[!] public.dns.A required in project.cfg' }

if ($registry.ToUpper() -ne 'SPACESHIP') {
    throw "[!] public.dns.registry must be SPACESHIP (got $registry)"
}

$items = foreach ($name in $names) {
    [ordered]@{
        type    = 'A'
        name    = $name
        address = $pubHost
        ttl     = 3600
    }
}

Write-Host "[+] Applying DNS ($domain, registry=$registry)"
[Spaceship]::new().SaveRecords($domain, $items)
Write-Host '[+] Done — DNS'

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCvrlMWOLZMuf/9
# QSE00jZAJD/gYWlnb3x6gWHEHiqq5KCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKkTVrnE
# IWV+NZN42/1UEOHytkjRqe15G8YPJFJQHktYMAsGCSqGSIb3DQEBAQSCAgAS+Y2X
# cvQWpuYuspXvlB+/jCIc6tpzbz+a4NZStXcxjz+HlKQaRfQ+z0hq5CNuR5vmleZP
# wK/FSMJcS6wR2N9vqeQXOifW3ld9AVs+LzoSoMZ85qXv/28WrIgKiCCTTZWIMYT4
# 3eaPPe8qlCSz0m6xP6uy31UszR+NLys6Ef8DoI6vpnKbLmIV40g/B4koZrF0MM/Q
# yexQAhjCl6wTn+HyS3hw2PQKjLqIEDxwZoK24c2s9EutRARaJKsbcWOtV5ykH3d1
# bPYeoKVlkFLte+rr0Xuh55B9lbOOihDg7UWcAA31NwJk9Lj4B1Q2mLsFquCynxs5
# fi0b3o91yAN/52z47/8LRS67NRQ1DAX/NQEI5ZNheciHeq71Pi4K0qyOpfUwo8+e
# ASNww6CJ/P8JmGoJqoVv2K/gor94oeamb1Uk0qPTkVxst0pREhjtqAkbIXKOdfDG
# +RQugc78cFcP3dFaO9mLeNdRuFpobfO19WX+OaLKpiSN7KlNV3UM1evdp3oz2MAC
# ou6MtL//SnCIRPHpXOI2nupPFdVW+dW7ea1Bj+P3T0wfxpKVYvTVyQGyrfaJLCae
# a1MADfIiXYqxxW3jUzx9al5Rq5mHExGVPqlumD6xtfuagShEzY1gV2kEThKA6UWj
# 3gLh1iSv3hfBq/OoL3TV+nnosuNrhAgNqPj01qErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
