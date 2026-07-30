#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/Google.ps1"
. "$PSScriptRoot/lib/GA4.ps1"
. "$PSScriptRoot/lib/SearchConsole.ps1"
. "$PSScriptRoot/lib/Spaceship.ps1"

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg')
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd")
    $os.Step('apply-google-observability', 'started')

    $domains = @($Project.Get('public.domains')) | ForEach-Object { [string]$_ } | Where-Object { $_ -and $_ -notmatch '^\{' }
    if (-not $domains -or $domains.Count -eq 0) {
        throw '[!] public.domains required in project.cfg (real domain names, not placeholders)'
    }

    Write-Host "[+] Google observability (project=$($Project.Name), domains=$($domains -join ', '), envfile=$($Env.LoadedFile))"

    $google = [Google]::new($Env, $Settings)
    $ga4 = [GA4]::new($Project, $google)
    $measurementIds = $ga4.EnsureDomains($domains)

    Write-Host ''
    $keys = @($measurementIds.Keys)
    if ($keys.Count -eq 1) {
        $mid = [string]$measurementIds[$keys[0]]
        Write-Host "[i] Add this to $($Env.LoadedFile):"
        Write-Host "    GA4_MEASUREMENT_ID=$mid"
    }
    else {
        Write-Host "[i] Add these to $($Env.LoadedFile):"
        foreach ($domain in $keys) {
            $slug = ($domain -replace '[^a-zA-Z0-9]', '_').ToUpper()
            Write-Host "    GA4_MEASUREMENT_ID_$slug=$($measurementIds[$domain])"
        }
    }

    $sc = [SearchConsole]::new($Project, $google)
    $dnsTxt = $sc.GetDnsTxtTokens($domains)
    Write-Host ''
    Write-Host '[i] Add these TXT records to project.cfg under public.dns.sites:'
    foreach ($domain in @($dnsTxt.Keys)) {
        Write-Host "    $domain`:"
        Write-Host '      TXT:'
        Write-Host "        '@': $($dnsTxt[$domain])"
    }

    [Spaceship]::new($Env, $Project).Apply($dnsTxt)
    $sc.EnsureDomains($domains)

    Write-Host '[+] Done — google observability'
    $os.Step('apply-google-observability', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd") }
        if (-not $os.Url) { $os.Url = $Project.PinnedOpenSearchPublicUrl.TrimEnd('/') }
        $os.Step('apply-google-observability', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-google-observability', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAr78h5GAZidS9h
# RyEDMHT1d0dux49Am/wjkxE08OqW4qCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINE9sObg
# QV/v3rmHXLO0x43murvp5gc+95OGe7HnElRzMAsGCSqGSIb3DQEBAQSCAgCI4q5p
# c2XIvZOq8iHrzSN72ciCfW1rUpiu44C7vMHYD9iC71vsjZNuTvbXQZLnuzzAfwVr
# tHB6LN4W25QCadbl9sAtEl0pZsVFh9Zld9mac69qSoQ0JTqwMouVHJ23OhnvaSNJ
# MGWVVEEGcX4qaJqjX54pSO1zldV/eRcwrlXoLxwJLrUktBx1NR2jdyPA7WXGEbcz
# A24xDGAVl48mgzvJqXDrrbwhFuUXdVL2cd4qa3RoQl/afc1HYm9oBW1hjZRKQhtn
# YRcZaOuARXgZ2nW2PtgVmSb9JeRtHJoe8WGouz0YsDppZKNOrbbQJgFMm24Ep2qF
# wQKDkdZ0NsSjLkg7aBzUkRgxPKwLOHYbB2hIM6S8AlXiGkm8KvM6iOj0Mj/bHrAb
# QATYTKtcoXeOk0J0DgHmhCTcKPNdrvpkIrY+OE9V4MSFCa9VRMOI8JuJ/TSESESC
# UFCf92Hmq7fXpuYu3E87qZmqgs7owWBgF+4+3I4uaZ6u3XY3ngZ/AAWzBtKzrlR9
# 1uR+X8bOoELEF9bPO7PAV3Yp0mQWOUz7TnK7iWqxWkMmZsciu8Drb1IPhy1ts8Xx
# r0RspTQmFlSRVZtoLJeiiTuLZClGIMSQpUEnOXxgMVKf02TIaRWrrtmFN1J8QM7O
# LUIwjE3YzIrdMplbOYg7zkbdpmsY9xAelyW1zaErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
