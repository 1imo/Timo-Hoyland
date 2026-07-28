#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$elastic.Step('unit-test', 'started')

try {
    if (-not (Get-Command go -ErrorAction SilentlyContinue) -or -not (Get-Command make -ErrorAction SilentlyContinue)) {
        throw '[!] go and make are required for unit tests'
    }
    & make test
    if ($LASTEXITCODE -ne 0) { throw '[!] make test failed' }
    $elastic.Step('unit-test', 'succeeded')
}
catch {
    $elastic.Step('unit-test', 'failed', @{ error = $_.Exception.Message })
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCsXnToFBJ1ov6z
# GRKtQTHcltmlh6qJDCbM5oxiGgNAnKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEICXUFNZd
# RHQSUtnv/it+gt2f+qVjKBtN7Co1E+2yPdJjMAsGCSqGSIb3DQEBAQSCAgB8UsIr
# KarYHqO5N2pLp9fQLFW2cNh8ptoVqVUFMwY9shKBzL70KUgs7NsRvbxn3vGOEMSh
# tnNrc6WZns5ZkSBpQsi194rQdPNbg1UPPjs+s/wdbXZHAMLkPc4a/uCBqZTmE55S
# /GsCv/dtjaPsEq9bcsFQK9UGe7cn27MbMedO2k3SbxJWMpXnz0pYcJ94JplzpsRO
# Z94H1ishtQPOJSyBmDqpCDdRnt10AZu0d6fKE/YbXjg0opACqL6atmtY5pHmvf+A
# J4dhHEULEqtPBKO6YY9t7YB+X9yDv2QaSMoRoOUkiGckic5WQCuNYi23U19v8kUZ
# RcWCvYErtQixsHwtRUnUNU26QPokeOGx+BEBfKROXHhJkC9mTAiHtAftyze0Duj4
# 3hiCbCrPvl+QJkljuLcbuuC3xQludxdCl9ydp09YZlSDIGXpWd0kud+F6JfjOhWD
# 2iM71ltegtDSg02Zuc2evhvO+2T3wxOr2vPP9iImaD9p9YUKCttF2gjh/K/Y4j/U
# eFdBZmXFQx4O7PL4o/QLNgPQN7HbggFui5vdMbnyegy0NA6vDxcmaRhZvY86Ojx7
# Ia+72TUW5ITHOUZma/FWrcotJiYbU37jlbCzwL4894d3J1kTe8kACZy/LPIUqT61
# J9ZPbSnYTRq8oMJuC/CUYDrwyrwZnMUcsBEcSKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
