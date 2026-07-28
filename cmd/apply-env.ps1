#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/Vault.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

$envLoader = [Env]::new()
$project = [Config]::new('project.cfg')
$vault = [Vault]::new()
$vault.Health()

$staging = $envLoader.VaultStaging()
$secret = "$staging-$($project.Name)"
$configSecret = "$staging-$($project.Name)-config"
$data = $envLoader.ParseFile($envLoader.LoadedFile)
$diffSecret = $vault.Compare($secret, $data)

$config = [Config]::new('settings.cfg')
$diffConfig = $vault.Compare($configSecret, $config.Data)

$ciVars = @{
    VAULT_URL           = $data['VAULT_URL']
    VAULT_TOKEN         = $data['VAULT_TOKEN']
    VAULT_SECRET_PREFIX = $staging
}
if (-not $ciVars.VAULT_URL) { throw '[!] VAULT_URL missing in env file' }
if (-not $ciVars.VAULT_TOKEN) { throw '[!] VAULT_TOKEN missing in env file' }

$remoteUrl = $project.Require("remotes.$staging.url")
$ciLabel = if ($env:ENV -eq 'live') { "GitHub $remoteUrl" } else { "GitLab $remoteUrl" }

Write-Host ''
Write-Host "Vault @ $($vault.Addr)"
Write-Host "Project: $($project.Name)"
Write-Host "[i] $staging : secret/$secret"
Write-Host "    source: $($envLoader.LoadedFile)"
Write-Host "    added=$($diffSecret.Added) changed=$($diffSecret.Changed) unchanged=$($diffSecret.Unchanged) removed=$($diffSecret.Removed)"
if ($config.Loaded) {
    Write-Host "[i] config : secret/$configSecret"
    Write-Host '    source: settings.cfg'
    Write-Host "    keys=$($config.Data.Count) added=$($diffConfig.Added) changed=$($diffConfig.Changed) unchanged=$($diffConfig.Unchanged) removed=$($diffConfig.Removed)"
}
else {
    Write-Host "[i] config : skipped (no settings.cfg)"
}
Write-Host "[i] CI → $ciLabel"
foreach ($key in $ciVars.Keys) {
    Write-Host "    $key=$($ciVars[$key])"
}

if ((Read-Host 'Apply? [y/N]') -notmatch '^[yY]$') {
    Write-Host '[=] skipped'
    exit 0
}

$vault.WriteSecret($secret, $data)
Write-Host "[+] secret/$secret updated"

if ($config.Loaded) {
    $vault.WriteSecret($configSecret, $config.Data)
    Write-Host "[+] secret/$configSecret updated ($($config.Data.Count) keys)"
}

$ci = [SourceControl]::new($remoteUrl)
$ci.SetCiVars($ciVars)

Write-Host '[+] Done'

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCQSJ1+dcZ0vUE0
# hrw3xaPBL4r1uke2qRQ7X0TDBQBD26CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKg0DC4A
# Nzmon/PWsFVBuhMaBlf6T/7AJlPIFZI7x4SBMAsGCSqGSIb3DQEBAQSCAgAWgdIj
# F+78IrdaEDDewObwqzpPMuFocQ2ecHqnV9BDRF7cCtIBEmP4p/1ELGrY/c3cAkaH
# Ncou1veTID8EjeUQghq5nhFgWZr2bRkHuHvZ0WhfQIPWsE7vPtzikyDPjIrYdrCY
# HHarkQ6+wt7akCI/DmUD1/2mVCF2iTNruY6cVW34/QRIYPZqW1yQBSVZFI51wdbW
# gTd1JhoS+jrh0PbxWdLS/v+bSrv55I769PtlQTlQPZOKTpJs/YDtoaCj0LEGYlj1
# 3WfPJ65hXtjPCbGxChSlSHEJurTMEjs68T6NpeQq6kEq6OWeTJl3gLokbwePl0Ze
# pdnTZ0SN6Tpkf57P3ogOydto07tm67yiTKLKjsKc8k5xNj3NTzVqlKpDrqS0N0Bo
# sco7Zm458nMiMFVS+f1yLzkP7AASO4WQ905AWyC3KZ/CqaeBBJuu35fD3VdGX9wg
# MCK1Jn/ikCVMSp6B9+8/hIK63AKAMbNOUBp3FmwoN/kbpUtDTB/R3AcOUL01dCjY
# Js2bwQrnK9B18DcnVry+S2nc9WdLoHCTb58PNf/alHnAzAXj7HFU8fNwAht36Qjd
# bD285FnpK/Y2Qo0AM2Cng2nRsEkaAQsSljiJ3996phu/yjUKom2KN22rEvv41sqx
# IKjYOUG4NhrzhJWPYc4h94RATX1XxVLWmP1xbqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
