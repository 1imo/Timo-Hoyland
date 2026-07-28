#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Gitleaks.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Gitleaks]::new()

$elastic.Step('gitleaks', 'started')
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
    $dojo.ImportScan($staging, 'Gitleaks Scan', $report, 'gitleaks')
    $status = if ($err) { 'failed' } else { 'succeeded' }
    $elastic.Finding('gitleaks', $status, $scanner.FindingCount, $report)
}
if ($err) {
    $elastic.Step('gitleaks', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$elastic.Step('gitleaks', 'succeeded', @{ finding_count = $scanner.FindingCount })

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAvytQJU8ee+bac
# J2rU0sSj+Va540bZ3UUD0i/aKlckxqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOHcdio/
# Fzq/exoZwj3o8jY2xeWVlkRwcJbjx/qL0z8zMAsGCSqGSIb3DQEBAQSCAgA5cw4Q
# sGIZ0D7qN4b1vcWMHiChNhkrUKmZFy9/3/4kJajRAtNWRvFgd0dDw8Mo706fai+F
# mMMRIz7KP4bfmgHsgU0aRMlw8fAclUk1gWQRcHW3LGz11lyulugDHRRbwGeSeEDF
# S6GY59Av46FRKg+X4UlcPhabOLCgwVxPK49PB3bG0wMSMgP/c8xN5+IxbDwMFIk1
# Vw7iboSmVzYa5uYwNcjSA6nEsvLwEpzuAVSVpUoiIGk0SRb/VFEuL/7IB383jDye
# uKGmXQU7usyQr00UwQFzFcEB7C5adOTNpEdsK8Xx/9x6uDmJZ/bQXLlRykRC/uRH
# LL1iKad7+/LKt+5DHB6z33Rrs4fD4ZN2TbKRRY/kBP2/9FBbOf0JziYQeVa2hHRY
# naCqvzgFPJUTLyMv4YEpdojk0nUfy3xfsBxmMPsAOkncKxEbrF1FdkDjEZrR5l98
# 5J2lS79SoztWwpaKgtIewD3B9mITVDG2oAEqIwKI6wtXWmcTDCrs80mCHbDo6ggZ
# 4kwI3DWQJt98iOxiEywi5fCVgSHDJkHdF0PA/3R4qpeKViJpm2i1F6DsTRJ7y8xR
# gYQVGJgVQdFIuJH8SDFUMCnMksvWg1ke0MTuypQwJPVgq/X4WmcaFzaLnET/RLcR
# sYA+nmdPYKvmnBdr42Y0egtMqq7khcW+mYFInKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
