#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Trivy.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Trivy]::new($project.ReleaseImage())

$elastic.Step('trivy', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.ScanImage()
}
catch {
    $err = $_
    $candidate = $scanner.ReportFile
    if (Test-Path $candidate) { $report = $candidate }
}

if ($report -and (Test-Path $report)) {
    $dojo.ImportScan($staging, 'Trivy Scan', $report, 'trivy')
    $status = if ($err) { 'failed' } else { 'succeeded' }
    $elastic.Finding('trivy', $status, $scanner.FindingCount, $report)
}
if ($err) {
    $elastic.Step('trivy', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$elastic.Step('trivy', 'succeeded', @{ finding_count = $scanner.FindingCount })

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA46BnsqEqdT/Zt
# CgIyEt5wSstQgASI2AaEIhgN4V97c6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJEY2RFh
# sfwQ6MImt/Sg+KoK1Xp5Sf6qvMw+uAnvDvZrMAsGCSqGSIb3DQEBAQSCAgBGGfbL
# Hn5gg5OFkL0Fdf7rmSDUfde4pUr4a3ddvSErz3K6PTZY+Cs696E6Una9kzpG2miL
# GnQ+EFqoJd+uzvjg4Sj9cW0V96fFUfptt01kHkDJdnKojfmBXzgYZ1OWwRHzY7gQ
# cxQyqs6PKvBsd6dVVYmgn/Q/5QLPNAMIwwEBVY34Mha6Ro6TW0gsSd0wg+I3bL/M
# LYu/RK7C6QjWzoAq818Lqrn1GIh/mU22rUJUlpST8Xphh7B/lh4YsuaUvwFBjt+2
# HLWAjsSI9qUREbIap7CMu9xaYnBRhXLkah8Gf8z4usyCFhZqw8zBmIRNQV9TFJIq
# Olo0QRC6WLkG+g/9jFieeueWT71eKgxcFGintFwGp7fz0yea2JFDw10Tg3oJhJvF
# kaCcAxbxnZfsQL1MYXDzSRC7W6iPtWUrwEbXCDlcNQ03XtYutkz/+IBj7ZztvoIr
# 35OgxSkYFABJknjTtqZERZO4eEo1W0R7Y5J1DW9aKP2tXPNeKci9pq/C6JqDPrHX
# INYN/MbmAPFZuyWQiD+/ipZ18aC76ywj2UhzdsnLAN2c0TXYcZN+5qoB6X1lueax
# Nbyj6dqBkvOIHgVzfBAmK+kuaFnzROxvvIOX2A7JyqVJfcs+Vn8cPt8d4xXwQ2wF
# 78z5uMQO14RlW+nATrU6+jkgfD6ELecwAVAQkaErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
