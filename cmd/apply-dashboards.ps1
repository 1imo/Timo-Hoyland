#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/Elastic.ps1"
. "$PSScriptRoot/lib/Kibana.ps1"
. "$PSScriptRoot/lib/Grafana.ps1"
. "$PSScriptRoot/lib/PostHog.ps1"
. "$PSScriptRoot/lib/DefectDojo.ps1"

[void][Env]::new()

$dirs = @('dashboards/grafana', 'dashboards/kibana', 'dashboards/posthog')
$hasAny = $false
foreach ($d in $dirs) {
    if (Test-Path $d) {
        $hasAny = [bool](Get-ChildItem $d -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })
        if ($hasAny) { break }
    }
}
if (-not $hasAny) { throw '[!] No dashboards found under dashboards/{grafana,kibana,posthog}/' }

$project = [Config]::new('project.cfg')

Write-Host "[+] Applying dashboards (ENV=$($env:ENV), project=$($project.Name))"

[Elastic]::new($project.Name).CreateStream()

if ((Get-ChildItem 'dashboards/kibana' -Filter '*.ndjson' -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })) {
    [Kibana]::new($project.Name).ImportDir('dashboards/kibana')
}

if ((Get-ChildItem 'dashboards/grafana' -Filter '*.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })) {
    [Grafana]::new($project.Name).ImportDir('dashboards/grafana')
}

$envHints = [System.Collections.Generic.List[string]]::new()
$posthog = $null

if ((Get-ChildItem 'dashboards/posthog' -Filter '*.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })) {
    if ($env:POSTHOG_URL -and $env:POSTHOG_API_KEY) {
        $posthog = [PostHog]::new($project.Name)
        $posthog.ImportDir('dashboards/posthog')
        if ($posthog.ResolvedProjectId) {
            $envHints.Add("POSTHOG_PROJECT_ID=$($posthog.ProjectId)")
        }
    }
    else {
        Write-Host '[i] PostHog dashboards present but POSTHOG_URL / POSTHOG_API_KEY not set — skipping'
    }
}

if ($env:DEFECT_DOJO_URL_PUBLIC -and $env:DEFECT_DOJO_API_TOKEN) {
    $dojo = [DefectDojo]::new($project.Name)
    $engId = $dojo.EnsureEngagement()
    if (-not $env:DEFECT_DOJO_ENGAGEMENT_ID) {
        $envHints.Add("DEFECT_DOJO_ENGAGEMENT_ID=$engId")
    }
}
elseif (-not $env:DEFECT_DOJO_ENGAGEMENT_ID) {
    Write-Host '[i] Defect Dojo not configured — set DEFECT_DOJO_URL_PUBLIC and DEFECT_DOJO_API_TOKEN, then re-run'
}

if ($envHints.Count -gt 0) {
    Write-Host ''
    Write-Host '[i] Add to .env:'
    foreach ($line in $envHints) {
        Write-Host "    $line"
    }
}

Write-Host '[+] Done — dashboards'

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBDu3E3ge53k+hV
# U/NU7cHt5g1jLo2RxIKtM36n3W1DRqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIP2+WkNK
# DzKlQxDOkpawzMdLTKQFdTgRsZuddcTCEY7yMAsGCSqGSIb3DQEBAQSCAgAzyOs7
# Jge2iy4ZFG6CUuGua9CREnfTCzbqFY+y4T2VKBcHL/mu0Csch5hVKL1fLSYABSt7
# PUD0lGF9yN9UjqU6c31o05YWLSme4eCNhkmQt2KphCbStosGrQlimgfzeEWQ0Z/h
# WjOfVLKbYBlbTXH+/Sh0PlmDrH7+34tPfOReK/n8KQW2shMJ5Fjx5fqnSvVDDDjp
# CzTBds79apkwIUudA1hoiJ57w1Eq/QYEICtb/PK1nRstuaEGcZF3rFkQZo3LFT38
# 1wBf+LQme/X/lliCXX9mNsaErY7yCwec1FNcUdoxEuFH36tI9Ro8E3IyQQL/4crG
# z4PGivwdChcojeZb/PkXxL9KzSbQij+vE8hQoBeknnIXSuGK5W1WvRMqccp0UAiu
# Y1miCZuCECcotw2CItP2T6znakqhswf5aS6NlR1xlVXNAK4RPnsAEKsqrLMMqVmC
# lxDlPEySr0CCuS5sTQqVf+OZkIV3g+lZY5wOR35wumdFxrF5dkV5TGw9yU6cRFTM
# DZ9hlFP2z3fxQjxLVLed/bamtAtAR/B7TSQbl72/AenPwJwn6zxwFWLS+7ol/G4O
# Fn6LjIa3cdTM/xFWPgK0qqzDKc5nqAiMP6swcgKq0499sfZIzUqUAJ/qRDOz/Qoj
# 1lKm00jcXG+hI+yP39YWwzVM47bZ60/cfKFLX6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
