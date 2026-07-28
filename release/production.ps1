#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$Env = 'live'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$All = @('gitleaks', 'unit-test', 'semgrep', 'sonar', 'build', 'syft', 'grype', 'trivy', 'deploy')
$env:RELEASE_PIPELINE = 'production'

. (Join-Path $PSScriptRoot 'lib/Vault.ps1')
. (Join-Path $PSScriptRoot 'lib/ProjectConfigParse.ps1')
$name = [ProjectConfigParse]::ReadProjectName($Root)
[Vault]::new().LoadEnv($name)
$project = [ProjectConfigParse]::new($Env)

$step = if ($args[0]) { $args[0] } else { 'all' }
if ($step -eq 'scan') { $step = 'trivy' }

$known = @('all', 'scan') + $All
if ($step -notin $known) {
    Write-Error "[!] unknown step: $step ($($known -join '|'))"
    exit 1
}

$steps = if ($step -eq 'all') { $All } else { @($step) }
foreach ($name in $steps) {
    & pwsh -NoProfile -File (Join-Path $Root "release/steps/$name.ps1") $Env
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBPZf+Vps9Zg0ay
# NmCbxjxky2zsqDr4F58oRv3I8VUDWaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIDozGlr1
# 0hdcvc1iIPWVI6FVj8KoW/7SGaiw3PWd25/CMAsGCSqGSIb3DQEBAQSCAgAJ2GkQ
# x/G8Zq3JmUFwmQQZk18t+Y1nLdQC2cB4xmc6Y5DSzB/RW2bnTQLEpSgsI/a4KzOJ
# ubJ0gEbPEgxbnBAmGIOk5ccB7QVl5LTk4uZVF4PZUuyB4ioBSrQ1B7is+Ri8hUdj
# Aovdanjuo+n+w57ltbL8nsWHQ/Swck/vnk3LOSd8VwxRkUEcNgAX6qEC1WQoE3WQ
# DvlltduMOj3NfDvlVNm4drAdXmcD8JXDuSzmWYDLr/ylZXCT4UXFltdk+4W3Q1T0
# sAzO0zgewypXaVwAK4hUOKzAwyFalNeJTq4k0geiApwrQ6dd/cTIBxVO60njepVb
# pnO7y+SFv/ZFtslF+z7KTbv8jHWLpuXf4/q/53O3PUkMvhU2l1519l9xk260f+aV
# 9Tr7vmTBH+c36Dgkp6w7lA26aKiTO4oeV1hHxnaDxBmdqkpttFXDzU3Ex1F0eQnN
# xvQzZSkUedxo+zlsjfrt9zRO2ZayjIQlSiEfTbiWhmSqj51+Vhdth6IP+CbNDe0o
# lk2iudJsO0B9nRUnZfSPQ1NZgu3UhTB9UEs5RSFIVudqAY+dYtXwTHgRDazfEfCa
# VIgFSTNzjVpwSRwaQOZL84GgysF14J9yJpzhYK2wg497NIc8SzA32+SzJlc/vw15
# SMyFTwk4+EdICFH/ju/B9rPhxiZMu8uNSKt2ZqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
