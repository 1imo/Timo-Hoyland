#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$Env = 'live'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$All = @('gitleaks', 'unit-test', 'semgrep', 'sonar', 'build', 'syft', 'grype', 'trivy', 'deploy')
$env:RELEASE_PIPELINE = 'production'

. (Join-Path $PSScriptRoot 'lib/Vault.ps1')
. (Join-Path $PSScriptRoot 'lib/ProjectConfigParse.ps1')
$name = [ProjectConfigParse]::ReadProjectName($Root)
[Vault]::new().LoadEnv($name)
$project = [ProjectConfigParse]::new($Env)

$step = if ($args[0]) { $args[0] } else { 'all' }
if ($step -eq 'scan') { $step = 'trivy' }

$known = @('all', 'scan') + $All
if ($step -notin $known) {
    Write-Error "[!] unknown step: $step ($($known -join '|'))"
    exit 1
}

$steps = if ($step -eq 'all') { $All } else { @($step) }
foreach ($name in $steps) {
    & pwsh -NoProfile -File (Join-Path $Root "release/steps/$name.ps1") $Env
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
