#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

[void][Env]::new()

if (-not (Test-Path 'Caddyfile')) { throw '[!] Missing Caddyfile' }

$project = [Config]::new('project.cfg')

$git = [SourceControl]::new($project.Require('remotes.iac.url'))
try {
    $git.Sync()
    $iacPath = "host/caddy/configs/$($project.Name).caddy"
    $git.WriteFile($iacPath, 'Caddyfile')
    $git.CommitAndPush("caddy: $($project.Name)")
    Write-Host "[+] Done — Caddy → $iacPath ($($env:ENV))"
}
finally {
    $git.Cleanup()
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCVymh0siPRh6yR
# X0dD7OzbcZWp02R9c+CQ2bnI4V3lDaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINkH/Q/O
# UGm1F1/0DpfdxFPjhTwtYHOItM9RF8U+RMMSMAsGCSqGSIb3DQEBAQSCAgAxvOie
# PDVDTQDvs5NMzPw39IqyA0DRdGNYSsNP0mH/W2cJ7IQ0mg7rvRmwyDvM6545zRge
# cGCCaoAYdb9iK4POXQIRBWqUJFKLHEizplgy9kh0m2TM9eLpRuuiBzr0YZeR1mFP
# VNfhe/srjHSMOPp/DFTy7pMOb/8C/nNsfpO1pMMFTQH/95+qndhyVgnz6i6SqYkw
# ZXUR86dkpHxgtbJ0aEO5K4y1zj/NE4BuLfdo7x7ea6B2F22q1VUutoqMVAqP/O43
# HbZQYUHBnou5dtIQVmaQkAYm9i467WluBtqeMaMVCi+HLaBSmEwU4I7/Eznoy7Mn
# Ifndj6//n82BzLnWlqP2xJA0Fj+5Xe//9z6mruLeH5n/5cFBmJU3L7pH6EkGtV7R
# erlQukDwNRHqaogzhJQGxvgfhIXY5RSkJtXKVlp30eofsatDoGii2pegEBYGfHxK
# GpfzxABIyJNNab5BAFWSirs732M/+azMSx9KBVEpiQV8u2zz7PIIMToazaQx9dwI
# IaiF0gr/KdNRt1uudAokCodYRZpxMGJK+WLAJrYgPI9+D+4IoIsHr9PeTkJ+4Tai
# ftgS0dXfJJIdUdEbsHqvXgG57HUhhyU8AewzUhwm2sEIIj38QQv8s+Qe79uBJ5UC
# mpVASE6FzbB6ptC5JKU+tDVsockKijyyDP1cDqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
