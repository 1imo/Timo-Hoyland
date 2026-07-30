#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Trivy.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Trivy]::new($project.ReleaseImage())

$elastic.Step('trivy', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.ScanImage()
}
catch {
    $err = $_
    $candidate = $scanner.ReportFile
    if (Test-Path $candidate) { $report = $candidate }
}

if ($report -and (Test-Path $report)) {
    $dojo.ImportScan($staging, 'Trivy Scan', $report, 'trivy')
    $status = if ($err) { 'failed' } else { 'succeeded' }
    $elastic.Finding('trivy', $status, $scanner.FindingCount, $report)
}
if ($err) {
    $elastic.Step('trivy', 'failed', @{ error = $err.Exception.Message; finding_count = $scanner.FindingCount })
    throw $err
}
$elastic.Step('trivy', 'succeeded', @{ finding_count = $scanner.FindingCount })
