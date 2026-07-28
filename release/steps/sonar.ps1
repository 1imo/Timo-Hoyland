#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Sonar.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$elastic.Step('sonar', 'started')

$gated = $env:RELEASE_PIPELINE -eq 'gated'
$baseBranch = [string]$project.Get("remotes.$staging.branch")
if ([string]::IsNullOrWhiteSpace($baseBranch)) { $baseBranch = 'develop' }

try {
    [Sonar]::new($project.Name, $project.Root, $gated, $baseBranch).Scan()
    $elastic.Step('sonar', 'succeeded')
}
catch {
    $elastic.Step('sonar', 'failed', @{ error = $_.Exception.Message })
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD8QIx4DOSaYOY1
# gefu7/Tdj7vNpxx4ZB/w9uuwp6JLQaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINYIQCeq
# 3NAmIwatZOqDvBHncmrejh8fj2M0KfKe1DQvMAsGCSqGSIb3DQEBAQSCAgAF107n
# sWibrXXZJIMYCiW0HL6vECOGj13vp+LLNey2DcFmyYJ55LA4NCOla3MnsDm9k60n
# zpBnUUwZMg/L+r+XmHf/N3SB/TTFZzX1hPEE1kzILihbooVTl9/0XsnkAuVLae+b
# PXz0J/bcWnW1VOw1XGUK2+PYdaA+AvEjN8sRAaVqmtGsftQM5D6uw91iGlNcoE5+
# XMsbM+Ah+f/f9JAizsm8Wio1cuhV+YYpLzCJXVDIbNFwfGCuN5y/a+K2svaiHuuz
# xbIoKlA84l6MR8DKagb11emlVP7zLrsE14nXIwSd/hm0mxfgO6X3rG8SFBk3GOz8
# qSlQZl5HN3NwcSoo/DZjEDIAoDutqzQXRsOAAXGCBDv5+kILKhSmxpu1aGv+uc3g
# MbPPNdZD3YQLPZ4F06Mm45otPmvCzgr9v08vsNT+mdZiN5oUX3uZ+1QOhvZz8Zk+
# NF0fFV3lx/QS34Hyf/ZXI1jQGbkY1Gp4CV8jJhgSoUDNqbTiJK2eiiZ6FfhCjHSY
# Ftai/AwqbgW9Kz7qSZpHgkC/K21AfNbxqINwW90GzX1MkkoQSJiqZArYyXkyf4mi
# lx32L2224FH/H2wrQ5xYdL3uRceKLzI9dR5S4RoxMUiorDsW7Fdte3PZUYpWC92z
# XeV8rpnN4G3oELwDsTSUoTcbFgugu0rDJHuBqqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
