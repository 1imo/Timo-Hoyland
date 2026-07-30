#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Semgrep.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Semgrep]::new()

$elastic.Step('semgrep', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.Scan()
}
catch {
    $err = $_
    $candidate = $scanner.ReportFile
    if (Test-Path $candidate) { $report = $candidate }
}

if ($report -and (Test-Path $report)) {
    $dojo.ImportScan($staging, 'Semgrep JSON Report', $report, 'semgrep')
    $status = if ($err) { 'failed' } else { 'succeeded' }
    $elastic.Finding('semgrep', $status, $scanner.FindingCount, $report)
}
if ($err) {
    $elastic.Step('semgrep', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$elastic.Step('semgrep', 'succeeded', @{ finding_count = $scanner.FindingCount })
