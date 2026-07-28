#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Grype.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Grype]::new()

$elastic.Step('grype', 'started')
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
    $dojo.ImportScan($staging, 'Grype Scan', $report, 'grype')
    $status = if ($err) { 'failed' } else { 'succeeded' }
    $elastic.Finding('grype', $status, $scanner.FindingCount, $report)
}
if ($err) {
    $elastic.Step('grype', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$elastic.Step('grype', 'succeeded', @{ finding_count = $scanner.FindingCount })

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCArKDKrmhNyrIB9
# E//nGPkIf2Qq/EZpAlnzaGdZhGX/66CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEID9dtI0e
# eVl72aFBhWKzHTOuhHcRTdMmv7BscMPtR9XaMAsGCSqGSIb3DQEBAQSCAgBIgysn
# Fuht2lrcNbVz12wlVusGI9qRa2d86TlVxiKdnNfWqKQjsFdbPUeZb8yYATH7Vqm0
# i8uegLVLWLn7soi0ePpX64xwIovkrtH4AvFxjZzty8JU+sxjBSaC30dxaVJbLQKm
# dhxQWVjkwGT8wzoSYgqPVDPqyUSJRCZtbR/Me+4ps0SokdGwpDfek0NvwqdbkEGk
# uMsGrbxixDBklmV5QtTRitOPOcKF5BKuxSCmBupxhKr7hFwPowU7v0Ns2r2gQPxb
# 38rIN8zjv3vkUVUehNlQYe09eO3eMFzUAf3+qUHRvJKtxVdJESGQ8BLtSnLjiKsh
# 8DxLqqzvJ6vJNrUXEV/oLAgFAuIJMexCfEyqXOI+ur2Afn3OzQJS7bs1PlrKy4Nb
# zYUDAgUER7ycaP5SjVz8GTtjc45fz/xmg1pCghu7ZeoQlEHkFYxVmT7iVZbaDeRl
# 4eXBQQJ3lALJEOyj/iEveZ5Ey7WVFq2Uh5gEcGGKAKxG9O9pn5GAwPbNmRvg1r7A
# eRU/pttzYTHl1OAzMS5Ta9lJB47H02p4nPE1iZGWlHtYSbQdwfSIrjeKRZdq7m1W
# sXOpnHMwRKKpY0vABZoV6nWtrrnSjCCjfT36l5V+Rc6qKuzwe1lGzeFY7aYMP/OQ
# 1NmyfHKo8bKJSipRIzwWeGxfErJse2LZuqFZ/qErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
