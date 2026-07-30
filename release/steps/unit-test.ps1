#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$elastic.Step('unit-test', 'started')

try {
    if (-not (Get-Command go -ErrorAction SilentlyContinue) -or -not (Get-Command make -ErrorAction SilentlyContinue)) {
        throw '[!] go and make are required for unit tests'
    }
    & make test
    if ($LASTEXITCODE -ne 0) { throw '[!] make test failed' }
    $elastic.Step('unit-test', 'succeeded')
}
catch {
    $elastic.Step('unit-test', 'failed', @{ error = $_.Exception.Message })
    throw
}
