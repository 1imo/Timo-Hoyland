#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Tuf.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/PostgreSql.ps1"

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg', [Tuf]::new())
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd")
    $os.Step('apply-db', 'started')
    if (-not (Test-Path 'assets/db.sql')) { throw '[!] Missing assets/db.sql' }
    if (-not (Get-Command psql -ErrorAction SilentlyContinue)) { throw '[!] psql required' }

    $pg = [PostgreSql]::new($Env, $Settings, $Project)
    $pg.EnsureDatabase()
    Write-Host '[+] Applying schema → assets/db.sql'
    $pg.ExecFile('assets/db.sql')
    Write-Host '[+] Done — db schema'
    $os.Step('apply-db', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd") }
        if (-not $os.Url) { $os.Url = $Project.PinnedOpenSearchPublicUrl.TrimEnd('/') }
        $os.Step('apply-db', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-db', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA0aaYhNvzuHxfc
# In6H+SVQvx9F6NYm9c5pIjUa/cUevaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIB2Cs+ib
# Fu6mK3T0bVVI5L3JmV4fqCIT9+pSEvh0+j6UMAsGCSqGSIb3DQEBAQSCAgARj9uU
# F8SvK6SMISBBYWlQbxwCN5pbj4TlOqs3eWnxtulMPPfTgbFCdSd15BwiRckjhlbT
# RElfviwcoY2zK+CfCsMsUJ1t8NMkAtV1xNXM3IwALHrWJZK8tDDtlDExHICCcsFJ
# qIsWh40hobFpxKMz1b8tW5KsV0pL0ZiFzSpJ6Xzw/ocAJAo20F/9tqTfcePzqHDM
# SSCiHPACPqwLcWLaTN+SQvrtXDQGN1Gde3Xlak5/36d0BIIUsGgRDDGndDpPRmJs
# n3CJ+7sjFvNeYOk814gZaJIzNSeEo0ElpMI/Jn2miGUGC0FmdIV4qOwoYr7fKjGn
# xfBblrCVgkQjNGfA0MJ6wKZQnZsemxaepftKOeG6aYEslGeongF+08UU4e97HoIM
# QvPwBiR90bJnzmzJNrq4WdHh98sY7SGX7A6c3TsT01vDOdc1C7nmqGtCSyFZ/QCt
# p3qrVuBmeEFlGoTTpDzMzYyRL4TE3HLCtwWReMFQWO6n64cvMa0V59oO3m0+dhMM
# r5Jogc+DG59aVjFG/3PMqslxAoQ9lMLo8d/uYTXY1T3b0n5tlZAXNCvt/wLvzgj9
# VnHP8SwSsKxep1K7LCcCsDtIY9alVJDiqsuLQON4RmTtc1UMQ1czChNgOYvcqWnq
# GuQQX2990S95HYTdX5BOuCVYu7Fu7hkmDzZeLaErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
