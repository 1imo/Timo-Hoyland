#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/Gitleaks.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

[void][Env]::new()
$project = [Config]::new('project.cfg')
$settings = [Config]::new('settings.cfg')
if (-not $settings.Loaded) { throw '[!] settings.cfg required (cp settings.cfg.example settings.cfg)' }

if (-not (Get-Command gitsign -ErrorAction SilentlyContinue)) {
    throw '[!] gitsign required (https://github.com/sigstore/gitsign)'
}

git config gpg.x509.program gitsign
git config gpg.format x509
git config commit.gpgsign true
git config gitsign.fulcio $settings.Require('SIGSTORE.FULCIO_URL')
git config gitsign.rekor $settings.Require('SIGSTORE.REKOR_URL')
git config gitsign.issuer $settings.Require('SIGSTORE.OIDC_ISSUER')
git config gitsign.clientID $settings.Require('SIGSTORE.OIDC_CLIENT_ID')
git config gitsign.redirectURL $settings.Require('SIGSTORE.OIDC_REDIRECT_URL')
git config gitsign.autoclose false
$env:GITSIGN_LOG = Join-Path ([IO.Path]::GetTempPath()) 'gitsign.log'
Write-Host "[+] gitsign configured from settings.cfg (log=$env:GITSIGN_LOG)"

$channel = switch ($env:ENV.ToLower()) {
    'live' { 'live' }
    { $_ -in @('test', 'development', 'dev') } { 'test' }
    default { throw "[!] apply-commit requires development, test, or live (got $env:ENV)" }
}

foreach ($name in @('live', 'test')) {
    $remote = $project.Require("remotes.$name.remote")
    $url = $project.Require("remotes.$name.url")
    git remote get-url $remote 2>$null
    if ($LASTEXITCODE -eq 0) { git remote set-url $remote $url }
    else { git remote add $remote $url }
}

$targetRemote = $project.Require("remotes.$channel.remote")
$targetUrl = $project.Require("remotes.$channel.url")
$targetBranch = $project.Require("remotes.$channel.branch")

Write-Host ''
Write-Host "[+] Push target: $channel → $targetRemote / $targetBranch (ENV=$env:ENV)"

$msg = Read-Host 'Commit message'
if ([string]::IsNullOrWhiteSpace($msg)) { throw '[!] Commit message required' }

[Gitleaks]::new().Scan()

if (git status --porcelain) { git add -A; git commit -S -m $msg }
else { Write-Host '[i] Working tree clean — pushing existing commits only' }

if ((Read-Host 'Create pull request? [y/N]') -match '^[yY]$') {
    $slug = $msg.Trim() -replace '\s+', '-' -replace '[~^:?*\[\\]', '' -replace '\.+', '.'
    if ([string]::IsNullOrWhiteSpace($slug)) { throw '[!] Commit message cannot produce a valid branch name' }
    $git = [SourceControl]::new($targetUrl)
    $branch = $git.CreateBranch("pull-request/$slug", $targetRemote)
    $git.PreparePullRequestBranch($branch, $targetRemote, $targetBranch)
    $git.PushBranch($targetRemote, $branch)
    $prUrl = $git.CreatePullRequest($branch, $targetBranch, $msg)
    Write-Host "[+] PR $branch → $targetBranch ($prUrl)"
}
else {
    git push $targetRemote "HEAD:$targetBranch"
    Write-Host "[+] Pushing $channel → $targetRemote $targetBranch ($($project.Name))"
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD/GDFNRuMDYaWv
# E31Ne4p0SSj5Nwl6hiJlCCqjsofTHKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIFDtOB8x
# iKDKnRkl9vaht1PHM/LyxpFEObSsFC7fqtDjMAsGCSqGSIb3DQEBAQSCAgADqdCU
# HYxi3MDehEYY1lK/PKBxMimnakmCZzZyYpJZ/XVLnun9epihp6k/TyHl6eZcs/6q
# B6kGSgSGuTHgPKGuKONe8WqmqRnkZWmQlOuwk1oxyV1IfHVWZlGE7ur02/auEyaS
# J6v7mvhCw4O2g659/H9NP/ojQhez2mv73TfqIUyGo8vHnq7mOByEJHyf9NjlcSNB
# x58o2s6E3o6N0RX2DupYf9lLNo4qWXD+0zymKYbKcJxul9B6WjV/eQRVTuVAsNa/
# 4+I46q5kpXttXJeImb2QeXyPhRSQh3ZgRbAdbmr7PFwVvjU905NowPqj/D1yZSx2
# DSIrlqW57/T1L2g+yKz4O1bD0S96+v1TWN9ykasL047ZmeOCXybxdE/6+9/CLggo
# aJ9HPvQ/l3JN/Mgz+By14w38/MV67MI3GD+SE6x/p4ZKenUYbFAH6C2Okw/cTUrD
# 9M8it9NBZarhsVriXLE+nhgbITDaxN/v3Lsi2JQJQE121Z8/AYNyqy9ZpQQAa50u
# ufcNySokZx9T+EgMFxXTBXRJ9VkQaBAOZSPjXrsLLuZ39lWMTYJsv/uz4mMC24o2
# IqockdZgRB6t8uzspeOimd0SwQkte5UqJRsFtVjAvTY1R76YfO9+Ev8VRKrHYG8b
# ziR2oESYnZp2u9w7na3pID57ExxEP6FHYAJvxqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
