#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/Gitleaks.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg')
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd")
    $os.Step('apply-commit', 'started')

    $channel = switch ($Env.Name.ToLower()) {
        'live' { 'live' }
        { $_ -in @('test', 'development', 'dev') } { 'test' }
        default { throw "[!] apply-commit requires development, test, or live (got $($Env.Name))" }
    }

    foreach ($name in @('live', 'test')) {
        $remote = $Project.Require("remotes.$name.remote")
        $url = $Project.Require("remotes.$name.url")
        git remote get-url $remote 2>$null
        if ($LASTEXITCODE -eq 0) { git remote set-url $remote $url }
        else { git remote add $remote $url }
    }

    $targetRemote = $Project.Require("remotes.$channel.remote")
    $targetUrl = $Project.Require("remotes.$channel.url")
    $targetBranch = $Project.Require("remotes.$channel.branch")

    Write-Host ''
    Write-Host "[+] Push target: $channel → $targetRemote / $targetBranch (ENV=$($Env.Name))"

    [Gitleaks]::new().Scan()

    $git = [SourceControl]::new($Env, $Settings, $targetUrl, [GitHub]::new(), [GitLab]::new($Env))
    $msg = $git.PromptCommitMessage()
    $git.Commit($msg)

    if ((Read-Host 'Create pull request? [y/N]') -match '^[yY]$') {
        $slug = $msg.Trim() -replace '\s+', '-' -replace '[~^:?*\[\\]', '' -replace '\.+', '.'
        if ([string]::IsNullOrWhiteSpace($slug)) { throw '[!] Commit message cannot produce a valid branch name' }
        $branch = $git.CreateBranch("pull-request/$slug", $targetRemote)
        $git.PreparePullRequestBranch($branch, $targetRemote, $targetBranch)
        $git.PushBranch($targetRemote, $branch)
        $prUrl = $git.CreatePullRequest($branch, $targetBranch, $msg)
        Write-Host "[+] PR $branch → $targetBranch ($prUrl)"
    }
    else {
        git push $targetRemote "HEAD:$targetBranch"
        Write-Host "[+] Pushing $channel → $targetRemote $targetBranch ($($Project.Name))"
    }
    $os.Step('apply-commit', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd") }
        if (-not $os.Url) { $os.Url = $Project.PinnedOpenSearchPublicUrl.TrimEnd('/') }
        $os.Step('apply-commit', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-commit', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDyDpOwXkwnv3m8
# /eNrJo0OCUDWWjnoc2TEB2/pTktOZKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJlDgoFP
# VCpAlxbT/t+1IAmlGMdX+cmQ01OSjmhNHAuFMAsGCSqGSIb3DQEBAQSCAgA9vyPb
# R4S9/ATyTmeASenCaa5xA3fOncEw+rjFToR50THGnudcQQgJZuCI7oOQVb68Z2OD
# y0z9npOCmfXi3R2NbSpaIYIa4Q6036kJG9xFy7jTBscB60c+entlE9alcs5bBM04
# uyjYKGXBJf0WYnEQT65zlLUdeR5zDr8KOsfD4iz1tlsCwqnRmW1j6+fIYB7JSwqt
# ztNAKIonBE0J9HvfytPEB3IrZtMcrCrpejqlLdKDAtvmcIohwo+saY5/nAKH6vcF
# rEcGxsMptN6qTfR3Li5wC8YYSFuXhnBTZAGnJvOIXtADpK5yo6i7L+rZdxltEJLs
# NgMIEfdloW4wf9OyUFbHU1LsWxvTaO0V5eInIG050M96ijOADiHSG///23zaUqC9
# WXyEZ5gE9Nx+gMjqOo9zQ7tAc2FkhgpRNlfS1u/AjpHqha16RxXe2wJraBuy7ic5
# Qx10PMsie41tGEnupg47z8y/fReA8zQgaWH74bwAt2y0zHq9QD51E6tn87U3mkab
# j+XWegKNkRJh3DnAInDZAQKQ9kJbwCEr0KnYm3EoXAg3yGdB8WykjyEtirtSXwN7
# wrqX5g/xmXrSW6eP0C3bhdxdrRwH0OHvtu8tKbBssUrNs4QctAieGnYOm3fiYtHb
# nxDWOkO61DayroOx66CaXXt0Zn/0WXcZihTRT6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
