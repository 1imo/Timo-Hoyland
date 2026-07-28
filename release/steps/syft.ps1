#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Syft.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Syft]::new($project.ReleaseImage())

$elastic.Step('syft', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.ScanImage()
    $dojo.ImportScan($staging, 'CycloneDX Scan', $report, 'syft')
    $elastic.Finding('syft', 'succeeded', 0, $report)
    $elastic.Step('syft', 'succeeded')
}
catch {
    $err = $_
    $candidate = $scanner.ReportFile
    if (Test-Path $candidate) {
        $report = $candidate
        $dojo.ImportScan($staging, 'CycloneDX Scan', $report, 'syft')
        $elastic.Finding('syft', 'failed', 0, $report)
    }
    $elastic.Step('syft', 'failed', @{ error = $err.Exception.Message })
    throw $err
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC84x3Y0ddO/coW
# mlNirzPoFAHLwsrRn8tqfnxnUj/heqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKPMtcwR
# 6mgZNP9SimrwLa97OoyLVBac0nREbXd5DYmhMAsGCSqGSIb3DQEBAQSCAgAeztSF
# M+aZq88eVhI2sMHK4ou+mi0GqGzNMDGVoVbQ3jEEQeBw6waPVBWXBafi4T7Q7sKU
# 88POY+07W3h91RM/qZE9nMHc6XV4KWJnNsuc2b3gQWPG8hk4Newt+Zks8TVCeFpI
# jDfSVAW4duobgxqIR065reYSwe3WasuHhUWXZnfv0Gobs0Ng7CxffmXP9UbNSgfk
# /1xi7KcaoKYtcQrdG5i40EeKB+uacWMe9nMjYEQGVnCebE72BH8mya+9tVtheR4f
# C7jyFbUQV0OGip2iQ2dKeaZ3zuPBCok+riNrXLaZ10yYhFzzI9/LNUWhxp2V70IY
# WhfTBN+6z1mwPOeeqz4tC1MdM/fhBmuE3p06pxy3TzZrgFUnDhKlxaVNyVEFSF3d
# KzQVM9cjATSpOIkWVfEMW/lznY0AiitMniuRjJahJ3VhtZ6kuAbX9AUtHaEOHKQ2
# RKTXBONehJQOi5Ocblo0TlEqEdsUMGPaup3IHPZ4olxsCHGYcIXk2scPjokd40d6
# ReagCvezJUpSbvuqeVyxA1HdEHpvsQcus515NvFjKZJbB+Guk9szZ/S3+kvi17XJ
# k49ubewk15wHp1KLxedva2cUAC+DyyagHAzE4fsos0xq3w5ftnGTMgj0oH4Xup2A
# dsG/j5hOwTrBhgq6BX0YX1i6tPJZ43ZZoiy5h6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
