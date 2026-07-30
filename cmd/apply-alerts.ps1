#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/Grafana.ps1"

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg')
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBh50WrgeIWJvv/
# ZWlaWL8oaCMETdjIDyO1dtItiV0vEaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHTVO1+H
# jOyAFJijqkUXqUPykw3U9p6i4W5r0SvFBBNZMAsGCSqGSIb3DQEBAQSCAgB/jWld
# G/90Y18qijzEB7KZzouuVzdZAS3tXQLIsV0Oi+K1Z38ney5sU5l5waVL2WYhDxqV
# qgnCfL98zp2+oPtuXgbDetzEMSiPvU6hGdItJIzCedMIM4pRPhNdqZdyetbj9vIv
# WQeLCLuwDbk+Rgw8ZF59J7MoTw1pis+7ISZvOQfP8WQegHGCBs3vcRCuIEh6XuxT
# otBAbgbjTRiGAFYtKvm2kGuHZQgEZgiCReeocZNsPXelLcZE5Qbrn6Wii+8PU9CH
# nMoYyCjks0/wDHGicVuCNM3VilznLNHpoyeOJIhZztUzQ88VCQIPN5H1BbzONR2a
# PXx3BWkUkv0/UzN4ClWOW1+DKxerEYNAyea4PZHwkCsZW0Ta90W0yOxLNVznNDsk
# JIsG9zcrKwKu0hP6tl6rACHpfkUJ8pML4+QXClRUdwwjCrZ9UmqJBvj49mdmTNpE
# AOOJbvmEExgNDTFJ5+RnUmGDPFyHOg9oozz6jQuMs49rI/F25LoUPWXFrxCaUNbD
# Y7l9SfnxpuAthFz92l83RkOVc281oZ+oW6kKliLb+KEgs0weEogGOkZzCqViTeHj
# 9rwj8ueARZKh0sONWVcsVJnXoGbfrzc3wkfWLbQjPbk8w+Uwr0ZJpO+jbmQtgjkU
# YKE1bXx7klgFheSxI3nx7SMGoBNHd/qGbE/RA6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
