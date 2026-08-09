#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Tuf.ps1"
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
    $Settings = [Config]::new('settings.cfg', [Tuf]::new())
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBxPM/ymZJiFiI5
# kCATrO0PJ/M+Ur3WayhUG40eTmuqoaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEILpJbCs/
# G8VZZWBUIsMtQHmHQhfI2mIwQqtLfVnIpH7IMAsGCSqGSIb3DQEBAQSCAgAsh7NG
# 2NMEjVUF9IqJU4Go0ktVjMcKWpdvDi+R8Y20/uw/sOJmbOm8qWOFJGm+2RKr1yAW
# 5SJU5bR+fHRcNmE/20RLKUa3+MvjL+ZS4ywOnf6bxINm1/bRYDGp3xwKfqpgouwv
# fr56CXSDz6CtqyjhP6NrkR9dMr5pU25D/z54yh7AUL1zZ6SiFXD4RGwd0y0208l3
# WOn+/JNERZJ/PnZO1XOPAJjoz17ZI1+tmICGp9fuCA2fSiPQ3Y7H0E98g6I3Cufl
# ASgV6Qdom3KSAyqvYL3JhwmSZ5w97Oh+uxbZhg+DFNjE7IDbRz3IT+muqQ50s0jb
# +LbUHL+Sf54a5KJ2X6g0bPHgneg2cS4k9CeRAs21CYjQqa/1x6Oxq0jwP0qGaWKy
# 5EN/s3l4VE2XtnQj3dpHT6aMybxKUcTAto2nO42fSkQ3HK3QOh9Xh74463Xqfk3S
# QQmnhpNTcW1xYSLgR6dG+ITXzlW+z2TQi+ZAtHoHpvbBtEr1vKOQQqy29CSE8vYY
# 0NPOQah3CYqzrzfaRHmcTdnNL9vLt+FL1yHTT5mE4ZPYOGZ0s23nWJoyWvSbqIW3
# HjTdvA40wJfwn9bO09Nqchbo/jbf3bH+Ig6HYqjhXgsRPwZvBnMTmO1d154cyNL9
# cdbKcZX1cdZk/YAszj8m+BFPfhULrHzUJHio+6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
