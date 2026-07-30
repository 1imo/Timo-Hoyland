#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Sonar.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$elastic.Step('sonar', 'started')

$gated = $env:RELEASE_PIPELINE -eq 'gated'
$baseBranch = [string]$project.Get("remotes.$staging.branch")
if ([string]::IsNullOrWhiteSpace($baseBranch)) { $baseBranch = 'develop' }

try {
    [Sonar]::new($project.Name, $project.Root, $gated, $baseBranch).Scan()
    $elastic.Step('sonar', 'succeeded')
}
catch {
    $elastic.Step('sonar', 'failed', @{ error = $_.Exception.Message })
    throw
}
