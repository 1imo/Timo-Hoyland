#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/OpenSearchDashboards.ps1"
. "$PSScriptRoot/lib/Grafana.ps1"
. "$PSScriptRoot/lib/DefectDojo.ps1"

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg')
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC/2451zASj20ZP
# fU17LkJ+sve17st9+4achygd4xf+L6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEID7pAiEF
# d9A4HHiZupriGOekc1sag+d/FyIgm/iOzqSPMAsGCSqGSIb3DQEBAQSCAgARtjFQ
# fGNb7vY+6dXWVM7djyZxKcjHpjNb1RDr0U1kVq6LyMejHAEiMTT/wNiMpc1HavH5
# Z2wjc6ou5KryH7x1HKUeJ+wl4M4yyRNNIcGMZufUPK72nXilZouSLbKmC0DS1fYM
# t+945fRRwjxo5+5xLCUn7yIGbwkWG2wL9C2Tu29iGrzqMnSqw0oo2TnIsX2Uo7S6
# MXSLVnB8iqMGQs4QE1aghN4UycWxbgyu6LQPvnVk0amNjOLDKIbgLP47UYLc1OIx
# UtRsx6hDgg+W/itGb0yme9REZ/U9AuPwH1P1YZ5/pbyD9a6Mwmq9JhBKg+VSfoGX
# TgcLNLXd2lZrvVnzAvmbYMhQa+uxrNkrNp0aQ8AWBD1qyR4ICA29wKg0SBxUAdXi
# DJfbO+WRIUo5PLRvXJ/2VdlsP/FskKgErFm/xOXkiVt3g92yX+qrfAMxSoumvJsr
# G/L6kDcOy7iyHxUR+qgd1mtufNWTPTHfKhnR0dGY72QeSvCF2ZNKTaIRBqubqmDI
# XJUtmfSnQ20Syf8O4cI5C2eVzsRnn9wzCYG4yczG0lelECn/ujHv2RDi4TFKFsjq
# ruxI8uhtvRk5gb/EA+LIAt9jvY0n4Av00r83xXxVSA3AVyjU814poPhzF6zNjx/z
# +gXdwmsbSe2WDvp8/ctA/B0eSajD7yyC/uisxqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
