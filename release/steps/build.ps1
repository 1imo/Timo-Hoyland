#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$elastic.Step('build', 'started')

try {
    $artifactDir = if ($env:ARTIFACT_DIR) {
        (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
    }
    else {
        $project.Root
    }

    $sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } elseif ($env:CI_COMMIT_SHA) { $env:CI_COMMIT_SHA } else { '' }
    $releaseImage = $project.BuildImage()

    $registry = [Registry]::new($project.Root, $releaseImage)
    $registry.Build()
    $registry.Push()

    $artifact = [ordered]@{
        image = $releaseImage
        targetImage = $project.Image
        commit = $sha
        staging = $staging
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    $artifact | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $artifactDir 'build-artifact.json') -Encoding utf8

    $elastic.Step('build', 'succeeded')
}
catch {
    $elastic.Step('build', 'failed', @{ error = $_.Exception.Message })
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBlCYQ2TI+3v1FP
# JuyNF69KjlWrVfgmg8fCEoAj5EuxrKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPXmhO09
# yIeVidbNomiYkRHXjzVtb7EmKn3HC7IMsRUvMAsGCSqGSIb3DQEBAQSCAgCB1b0H
# 4k2KDBx56vTopUff60vW5mdMfFQPhzdLpOjvc1noPb0yGVXu/+TqIef/ZJ6bszIk
# eqp3UmSnw88qLrgZeGQV5RnW0MSiAzRyoH7lT+4FOBR5nSK2H/YjfLtqDxwnKvQA
# bpZ3n9r8nigIA8ijafTlocW1N48318s+89fHrYXn6ajPGGao9EpjbH8h5E0YGYLg
# 9ecyekje5AeWy4ctSP3bUOBVV3J7BSneYVs4a4Pd2wQx/5LnxP70j/2Vgr0rg0gC
# 7tsdtN6jkXbJkYx8yYa/onkolnJBYq7OjbvNGuRtsyS5ds0YjyNeOqSzxB1VAO+A
# vPtsmjOnSDe3YpSQUJwJJOhijX3xoarGje3ESO4WsOoUrd9nkXypkjqfDwWRKTt8
# 2V4OlgYIfPvXXbQ5ZHqC6zp2BnoiHRfcDzFzQAWk7ERJv40wGnKKrM076dxYqJTc
# 3Bkyt1k8Fcbod3V+PngADOW32omFY3gT5wf4zHSFggRUNIbSYowtmvP5dEB5cqIC
# cI3M4aqtfSnYC9SUnlSJskWR8g/HGiEvzfSVC/52K4vccs4mtJIvSfkBoH5JdAWi
# 6eeqS/f9+9g52PX4kXOc/QByKpnF24hnuLyabezEc33uOzphSfmbYsIfl2sasekh
# TfoUJoQPyjgWJvjZbo9T9ZXepbnMH8khMZki96ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
