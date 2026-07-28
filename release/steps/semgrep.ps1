#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Semgrep.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Semgrep]::new()

$elastic.Step('semgrep', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.Scan()
}
catch {
    $err = $_
    $candidate = $scanner.ReportFile
    if (Test-Path $candidate) { $report = $candidate }
}

if ($report -and (Test-Path $report)) {
    $dojo.ImportScan($staging, 'Semgrep JSON Report', $report, 'semgrep')
    $status = if ($err) { 'failed' } else { 'succeeded' }
    $elastic.Finding('semgrep', $status, $scanner.FindingCount, $report)
}
if ($err) {
    $elastic.Step('semgrep', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$elastic.Step('semgrep', 'succeeded', @{ finding_count = $scanner.FindingCount })

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBs3y7UQHsio02Y
# v6fQEJ2vMORLKAiIDAt057tuk55faaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINPvxRxK
# gVH9HQf0oiVK7FNyI0qOXdELS+ZrJIKV58mOMAsGCSqGSIb3DQEBAQSCAgADsIC2
# Z1VAN24QojShiPMsroQbMXc+TF4i5BSIRWMJhT9bX+U6CFlCYgDH+VhA6CmULOoO
# +R3qTnDpJMo8ogSUGFJHdxR802/b7fIYXdoxSn4ej9zqnudhXncirhAkiU3M1oW/
# 0TFDTTqbX+drujYCMr2eiZ3Okt1aCBbbWtmFK2A+Ox9MODSdbqnApllniLrgFhWm
# 3R04rAg1QVBn993SXg0EHJJ3S8AQq/xCdNCUa4IUpk1gMsoJtlT15PNKq4+/L94A
# VqQ3Bybmmq4bwJ5yHCH+Rx3vd9q6NdJCqAxr92eOMilMOmyWH4c8z+10fqjP2itO
# VROp7JX7jWbWq2U1tqm7y7YXdrv4K6Xpv37MYPl2IiRMOjnQmXqB6//YzFJr8pm9
# VF3C85nSa0HxRlz9JZjj/ZdTjaHDZR4JC+IBniK2ysxUo/35P22XxYB0WKXRZTG6
# qGbXeiY1A6CCB3RpLcFzdUSt7eGU8K6AuP+4ylz2bPU09J3LnKhJ8eU5S4zc9qbR
# h+hxhbP0wNhVpIUGRZQ/yfUB4/9YeKF0koL7cP+dKhWv49JrC1LWLtv9FpEHjklh
# Rxq0JPJqIQCpcRTcy4H4uqN/OCw9XS9fuYcy45TOVhYzmcv0n0pIxWeKCmrHgaUO
# 3af+1wJkvQBjCMyuuHaLycYR/QYJaicdhkWld6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
