#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

[void][Env]::new()

if (-not (Test-Path 'compose.yml')) { throw '[!] Missing compose.yml' }

$project = [Config]::new('project.cfg')
$content = (Get-Content 'compose.yml' -Raw) -replace '@PROJECT@', $project.Name

$git = [SourceControl]::new($project.Require('remotes.iac.url'))
try {
    $git.Sync()
    $iacPath = "docker/$($project.Name)/compose.yml"
    $git.WriteContent($iacPath, $content)
    $git.CommitAndPush("app-config: $($project.Name)")
    Write-Host "[+] Done — app compose → $iacPath ($($env:ENV))"
}
finally {
    $git.Cleanup()
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBzfKm+Llhejmsk
# gyFnrXk0KrYNV2DyVWhG99hSc6jw0qCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEID6u+c72
# dDnxg7Xz856VX3TUZZt1bARImHi+mHHavISnMAsGCSqGSIb3DQEBAQSCAgBtxkrJ
# U/Dy2XUt1CN0qnDQrxckdQkywXNIMo0FAFwMdivPnncz12jNb9DYZjiDMaXw1Kwl
# XYaU55IoD7GtPs9Wk0KnzMhysJEvkSOuurA29gRJxcKYy/YbdhXi00T352sSolEm
# 1zSl2k0kSUbbqixLI/NL7bqVJpvSwFhMUl7h8BYUgltlgnpdVAl7k2K7+KJLgwL4
# FaHFioF+EmiDMU4OP2Y6isr7IyudSamy33b4ptQtoIfEeSrwJM2mrHowkxi0C9KY
# xKi05pGXJvwwA86STdfVCu760iyT+39S6NeFITHNsCVUrPPEi87CSEnhKoN2FTic
# NRGUTnLAinvsoqJZ2QOHTN7T4eULGGhbKEFK8W2ohvvYZEKR4Ko05BEjBXXHseX9
# 1bqFiAk1h9DFSSmueKUPRP8NJUfAO6hraRrhMV+RzhZyxIRDT1cn91Gkd4oICJqv
# /YN2dpcxYEHfsIAG86hobTad/6x1JQfX588hfe8LsEVMyehcYOKp9dugftPK2ueP
# xGaQQEBiyjdIwU+gR7UOzSmrcTaKPxLmUSPa2i0NgkkDi9pqrxDwLWU822zSgDdm
# 9lgsOJmzlPqAdtSGwju/bEJLutY7NbTwfdib3ixOd4JluCZlM8m6YgGngSMpqdiD
# 8+iDC7mVRAaXAxn6S78LjVRyPa1QW7PPDB4QRKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
