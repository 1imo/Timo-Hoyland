#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Tuf.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/OpenSearchDashboards.ps1"
. "$PSScriptRoot/lib/Grafana.ps1"
. "$PSScriptRoot/lib/DefectDojo.ps1"

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg', [Tuf]::new())
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd")
    $os.Step('apply-dashboards', 'started')

    $dirs = @('dashboards/grafana', 'dashboards/opensearch')
    $hasAny = $false
    foreach ($d in $dirs) {
        if (Test-Path $d) {
            $hasAny = [bool](Get-ChildItem $d -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })
            if ($hasAny) { break }
        }
    }
    if (-not $hasAny) { throw '[!] No dashboards found under dashboards/{grafana,opensearch}/' }

    Write-Host "[+] Applying dashboards (ENV=$($Env.Name), project=$($Project.Name))"

    [OpenSearch]::new($Env, $Project, "$($Project.Name)-logging").Ensure()
    [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd").Ensure()

    if ((Get-ChildItem 'dashboards/opensearch' -Filter '*.ndjson' -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })) {
        [OpenSearchDashboards]::new($Project, $Env).ImportDir('dashboards/opensearch')
    }

    if ((Get-ChildItem 'dashboards/grafana' -Filter '*.json' -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })) {
        [Grafana]::new($Project, $Env).ImportDir('dashboards/grafana')
    }

    if (-not $Env.Get('DEFECT_DOJO_ENGAGEMENT_ID')) {
        try {
            $dojo = [DefectDojo]::new($Project, $Env)
            $engId = $dojo.EnsureEngagement()
            Write-Host ''
            Write-Host "[i] Add this to $($Env.LoadedFile):"
            Write-Host "    DEFECT_DOJO_ENGAGEMENT_ID=$engId"
        }
        catch {
            Write-Host "[i] Defect Dojo skipped: $($_.Exception.Message)"
        }
    }

    Write-Host '[+] Done — dashboards'
    $os.Step('apply-dashboards', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd") }
        if (-not $os.Url) { $os.Url = $Project.PinnedOpenSearchPublicUrl.TrimEnd('/') }
        $os.Step('apply-dashboards', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-dashboards', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCO5RZOAJatKLyY
# XmBa1wogzIVqVfjCoJosvIMOaltjZqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIERYo5Tu
# RU3tNBkf/q5c59X90df59Thc3+DLFpzCzpbhMAsGCSqGSIb3DQEBAQSCAgBXxH0C
# EkbNZSJz0OLKM5i6tOeOa393tvcHq/n0AN81ChPXLzdEV8aBW6BPQXn4nvEjo/TE
# 2r3nCv6TQiQDDslJmm0d/T8ys7NXQ8634n68u9Nb2vW1BHpWwrD99n9jpNN6/yj7
# nj3IibwT85a6SQatSVB9JXQ03cIPZgnsIMiwwKwm/AC/+Oujljw0PLkbNz7NSE+d
# 73iWwJTia/XhtboU3FZlD2ZUt9oDKv3Z1QWZyquROd7Gpn7yT3c4S2tA1Pn3xNpE
# hcgn8vYpBgV9KPfLiruYIgqNF86DHfWewu6Cv1OnVONy4FAquM8kOseB6kRzdkxk
# 1JH430AbC8rBB36C4q15RCfoUxlpt5Mh63Y7VgUy335tESDKF10s9yvW0vTric5N
# UtBfwoO4/u7rbdyg5OX8n8Yf/uXpsq/3iqT1CvJbqH9t+L0hUrt7YL8+vYnoIr/U
# 82YI9p2V0AfaHwIrR6PpVOn1w7OeF5azqza5ELguCqOfSpZwKffpMSOI/42mJ6Qa
# 2dc71FURQ9nST1n8UihFDeIU1YoZvB/vGWp0ASJoGS0oT2dQtlUiS7AwlnflEz4Z
# szhzKFj1NcWjKCWyUugB6xBZVB98A+rLNtLokS2kYv7W0FepKlW6a/oqo8KKC3W0
# A0et1LiSXJjieR2xDWAVFCocaakQ2pE1oJXfMqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
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
