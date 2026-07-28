#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$elastic.Step('deploy', 'started')

try {
    $sourceImage = $project.ReleaseImage()
    if ($sourceImage -ne $project.Image) {
        $source = [Registry]::new($project.Root, $sourceImage)
        $source.Pull()
        $source.Tag($project.Image)
    }

    [Registry]::new($project.Root, $project.Image).Push()
    $elastic.Step('deploy', 'succeeded')
}
catch {
    $elastic.Step('deploy', 'failed', @{ error = $_.Exception.Message })
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCbSmFgxTVIDcCj
# 0QUBW+/2adcjZZ2/S9lyJIIojVdzcqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIBeHs1KY
# oNOqO8BwCuw+45TwPfhFoqehOYyb9IVLISWyMAsGCSqGSIb3DQEBAQSCAgBegX8l
# Y6pDznO5ZENykChNLLz5pjMCUYNY02BbM0iztah7Oi9SBCHBAevwT09EmPJqMRBN
# T5DoBloGQMh88c6DDfB8V3EcasIJ2khFm1gKk7tCgc8+T37oWUbFpQdqW7Kp2UFK
# xioSnIBe+JcUPJ2w750LsxCZqQ/kF43tqg1bgwy0MjXrpcBzu2Zc9qAYbtv+ElRO
# yEQ5LgcqcVPu4zmmE4zFeDli6X0hu+SfACmbqmnfVmsPbi8ebO15pdoI1EqG1WfA
# BcIGpiQK5AGPGjme74gYXPmHJirDeO6cBt01S6ELndOPF8TQr40og+sSOtp53Yri
# aOaEt6Off781mQ7/OESSnvRQpdmd0drM34Hxg+9uNhZ/Lp1S5OnDJ+NMSV5iDMn/
# +GevwbCCecBlgOku3496z5FFYdkQ2p0+mxXNpSv3z4ErdVH6kz4MO/PWfaQmFsZj
# A9Ylilcw14BsjYPynQMau5k56AIN3tWn8PUnzFIgHer02H05iBwSS3OnFr9kvHRn
# IKfwvDwvTenSw6wUHLHMHD1eT349nwGrM5ebo2oI48f8DD72lcpHdBvJR7Ka5+xx
# rlwGR2kLMDKjjfbt6RmWLcEeXg+Uu7x70Mey6owTztcibpG09lXpJWto/efPxShh
# CTr2w+XjxRJRhmV9uuQzXNi7NvKkP0VN9rQzxqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
