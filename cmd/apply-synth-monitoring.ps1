#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Tuf.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
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
    $os.Step('apply-synth-monitoring', 'started')

    $domains = @($Project.Get('public.domains')) |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ -and $_ -notmatch '^\{' }
    if (-not $domains -or $domains.Count -eq 0) {
        throw '[!] public.domains required in project.cfg (real domain names, not placeholders)'
    }

    $dnsA = @($Project.Get('public.dns.A')) |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ }
    if (-not $dnsA -or $dnsA.Count -eq 0) {
        $dnsA = @('@', 'www')
    }

    $hostLabel = ([string]$Project.Get('public.ingress.type')).Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($hostLabel)) { $hostLabel = 'external' }

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($domain in $domains) {
        $domain = $domain.Trim().TrimEnd('.')
        if (-not $domain) { continue }
        foreach ($name in $dnsA) {
            $name = $name.Trim()
            if (-not $name) { continue }
            $vhost = switch ($name) {
                '@' { $domain }
                default { "$name.$domain" }
            }
            $rows.Add([ordered]@{
                    targets = @("https://$vhost")
                    labels  = [ordered]@{
                        service = $Project.Name
                        host    = $hostLabel
                        vhost   = $vhost
                    }
                })
        }
    }
    if ($rows.Count -eq 0) { throw '[!] no blackbox HTTPS targets derived from public.domains / public.dns.A' }

    $payload = @($rows.ToArray())
    # Always emit a JSON array (single-target projects must not collapse to an object).
    try {
        $json = ConvertTo-Json -InputObject $payload -Depth 10 -AsArray
    }
    catch {
        $json = ConvertTo-Json -InputObject $payload -Depth 10
        if ($payload.Count -eq 1 -and $json -notmatch '^\s*\[') { $json = "[`n$json`n]" }
    }

    # TrimEnd only accepts chars — do not pass ".git" as a string suffix.
    $root = ([string]$Project.Require('remotes.configs.root')).Trim().TrimEnd('/')
    if ($root.EndsWith('.git', [StringComparison]::OrdinalIgnoreCase)) {
        $root = $root.Substring(0, $root.Length - 4)
    }
    $remoteUrl = "$root/blackbox-targets.git"
    $relPath = "https/$($Project.Name).json"

    Write-Host "[+] blackbox-targets (project=$($Project.Name), domains=$($domains -join ', '), host=$hostLabel)"
    Write-Host "[+] remote=$remoteUrl path=$relPath"

    $git = [SourceControl]::new($Env, $Settings, $remoteUrl, [GitHub]::new(), [GitLab]::new($Env))
    try {
        $git.Sync()
        $git.WriteContent($relPath, ($json.TrimEnd() + "`n"))
        $git.CommitAndPush("chore(blackbox): $($Project.Name)")
    }
    finally {
        $git.Cleanup()
    }

    Write-Host '[+] Done — blackbox-targets'
    $os.Step('apply-synth-monitoring', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd") }
        if (-not $os.Url) { $os.Url = $Project.PinnedOpenSearchPublicUrl.TrimEnd('/') }
        $os.Step('apply-synth-monitoring', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-synth-monitoring', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}
