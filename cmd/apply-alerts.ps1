#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Tuf.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/Grafana.ps1"

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg', [Tuf]::new())
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd")
    $os.Step('apply-alerts', 'started')
    Write-Host "[+] Applying alerts (ENV=$($Env.Name))"
    $os.ApplyAlertingMonitors()
    if (Test-Path 'alerts/grafana.json') {
        [Grafana]::new($Project, $Env).ApplyAlertingRules()
    }
    else {
        Write-Host '[i] alerts/grafana.json missing — skipping Grafana rules'
    }
    Write-Host '[+] Done — alerts'
    $os.Step('apply-alerts', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd") }
        if (-not $os.Url) { $os.Url = $Project.PinnedOpenSearchPublicUrl.TrimEnd('/') }
        $os.Step('apply-alerts', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-alerts', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAg1QM1C7rKG33d
# +1JxRnlreAVLSNk8/pPg3mGCuZaQ36CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIGP6JrNG
# 9SM8Qq1aWq0Ycp7JbJ7tWhxAAmkP12YSYZPMMAsGCSqGSIb3DQEBAQSCAgAzPZiE
# vvWk3x4chWr1Js3Mv6OY+87yQiwZTbXQl2iLL+UPjXOrbRH4AfzEoUi6D+t8ZxIT
# AI6IS3VtyO1QcXoXB8qlWvVtirq3LZllvxOPE+4C+ElBYwba9OWu7SjNjgsjZGjQ
# HoGkJanEl3GZdq8ArZ9UCKAnt/28hTyLWycwyH1A5mWmh72DZbafHF8NzuCGf4HQ
# efF4IKfXXgxONAcFh8jzSWo6sOIgP7LFPgwpL2xdQQFVFcWsWHyMyKd00GujVCzh
# XOHsu9fn8r83giltmswgB4KfBaK2XEygP5/UimJgMjR+077DBWzEPrEru7Ddyptc
# BthO+9Lb0FxUzxvlhDvXbjfx5YixwKgPCXiDfM+T3HhAE5R/rGq09H0kuuoX9PKi
# UlgRD5LqKo4Rf6mF3Yed/fSW00lV9NCj3lNwE3Qv+jrrc7kPIx2zcdjcAb53E3/b
# cYxQtHbqv/N7pdzPYJkbd6J/Y9nOnilC6iTL68aul5gsHccwfMVxM6DJNx+GiChU
# YOV2PI94U/K6AjZpPzeikVeHOKnYXg0E+cY5sd9TVBSrv7xJV6ptFGMawpGRS9IG
# viZa94oigDJONWwH8HRl05xOUB+yuss2WcahBlIsdYv9d6QNJNhlTBnH0FO87P8a
# mycWFtc/9y3Arp3E9/70Aqpn5DMPtQFF/mQdwqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCGGu8/u8OdqO9v
# J+PVM9wfMy53oWXksq4M3/SlFNNgVaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINaAkr6g
# od5xbQNNYMul03jqQXuX4Lv1BMzvXj1iXxWTMAsGCSqGSIb3DQEBAQSCAgBnaoMz
# bSSY0SnuWaS31BGl4tu2LDZNjBn4+GSIPqoHdxbH23uV39kf/nl2X2TmjNTv9F4s
# QqjuUWmV3GFUy8aZ4FRVthhr90CVqFOTRP/JiZNiqEr45f1nbWxr5ocsL1lDe75P
# zSuSwL1ZDnXtnnAlrYFqKZKmmkTZ2FXRIctts9cv0CPRqr0XMJV3X0za7hIVK8KA
# 7yeHeC2/QJbsHG1gzxC1kjJJcwbHG7/L2n+uwCuGZ7H577VSiQNgm2uUetufDq1Y
# t7ohw+Yg8+HSivuKoxnLnSCzUBVtDC3LippUYrvbV6qaNKzzpHWEOYLSulKRDnjY
# kDDpmTxWu9pw4Ma3azkmVhzM6tqPa/F6fDPMusq1gWEMycmcaluyaeFlg+8uLOIx
# U7dfJ9+HBWJHCT8DZdzRYo8M+C8XZ3hXm28LEJ65s79jVeo7wMmnAV/rWr4tams/
# S8Pw0iXwQPvymwdQZWdTjwcYyt993ifU+eAq36xoTl6eonP00hlNuiSXTLhdwMaV
# GY0oLlPc4X6RdIXPY7N3VTPTEWje1IWBfvq0JRfKLcgtGZ7lJKoWWxF5bzbEXaSF
# KAJKqriV9ryG1EPBt/vyshFHYaKLAejkuaoR6gRRQs0k9COZ6bjT7s1UDV0IrEXf
# fizIRgn6G796qr59Rek4ZWziQPGp2dNAXPVuk6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
