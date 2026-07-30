#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Syft.ps1"
. "$PSScriptRoot/../lib/DefectDojo.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$dojo = [DefectDojo]::new($project.Name)
$scanner = [Syft]::new($project.ReleaseImage())

$elastic.Step('syft', 'started')
$report = $null
$err = $null
try {
    $report = $scanner.ScanImage()
    $dojo.ImportScan($staging, 'CycloneDX Scan', $report, 'syft')
    $elastic.Finding('syft', 'succeeded', 0, $report)
    $elastic.Step('syft', 'succeeded')
}
catch {
    $err = $_
    $candidate = $scanner.ReportFile
    if (Test-Path $candidate) {
        $report = $candidate
        $dojo.ImportScan($staging, 'CycloneDX Scan', $report, 'syft')
        $elastic.Finding('syft', 'failed', 0, $report)
    }
    $elastic.Step('syft', 'failed', @{ error = $err.Exception.Message })
    throw $err
}
