#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../lib/ProjectConfigParse.ps1"
. "$PSScriptRoot/../lib/Registry.ps1"
. "$PSScriptRoot/../lib/Elastic.ps1"

$staging = $args[0]
if (-not $staging) { throw '[!] staging required: live|test' }

$project = [ProjectConfigParse]::new($staging)
$elastic = [Elastic]::new($project.Name, $staging)
$elastic.Step('deploy', 'started')

try {
    $sourceImage = $project.ReleaseImage()
    if ($sourceImage -ne $project.Image) {
        $source = [Registry]::new($project.Root, $sourceImage)
        $source.Pull()
        $source.Tag($project.Image)
    }

    [Registry]::new($project.Root, $project.Image).Push()
    $elastic.Step('deploy', 'succeeded')
}
catch {
    $elastic.Step('deploy', 'failed', @{ error = $_.Exception.Message })
    throw
}
