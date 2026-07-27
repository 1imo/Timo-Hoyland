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
