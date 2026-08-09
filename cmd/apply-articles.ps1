#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Tuf.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/PostgreSql.ps1"

function Split-Keywords([string]$Raw) {
    if ([string]::IsNullOrWhiteSpace($Raw)) { return @() }
    return @(
        $Raw -split ',' |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )
}

function Merge-Keywords([string[]]$Parts) {
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($part in $Parts) {
        foreach ($k in (Split-Keywords $part)) {
            if ($seen.Add($k)) { $out.Add($k) }
        }
    }
    return @($out)
}

function Get-DefaultKeywords([string]$AssetsDir) {
    $path = Join-Path $AssetsDir 'prompts/default-keywords.txt'
    if (-not (Test-Path $path)) { return @() }
    return (Split-Keywords (Get-Content -Raw $path))
}

function Invoke-AIChat([string]$System, [string]$User) {
    $aiUrl = "$env:AI_URL".Trim().TrimEnd('/')
    $apiKey = "$env:API_KEY".Trim()
    $model = "$env:MODEL_NAME".Trim()
    if (-not $aiUrl -or -not $apiKey -or -not $model) {
        return $null
    }

    $endpoint = if ($aiUrl -match '/chat/completions$') { $aiUrl } else { "$aiUrl/v1/chat/completions" }
    $payload = @{
        model       = $model
        temperature = 0.2
        messages    = @(
            @{ role = 'system'; content = $System }
            @{ role = 'user'; content = $User }
        )
    } | ConvertTo-Json -Depth 6

    $headers = @{
        Authorization  = "Bearer $apiKey"
        'Content-Type' = 'application/json'
    }
    $resp = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -Body $payload -TimeoutSec 120
    return [string]$resp.choices[0].message.content
}

function Invoke-ArticleKeywords([string]$Title, [string]$Body, [string]$AssetsDir) {
    $promptPath = Join-Path $AssetsDir 'prompts/article-keywords.md'
    if (-not (Test-Path $promptPath)) { throw "[!] missing $promptPath" }
    $system = (Get-Content -Raw $promptPath).Trim()
    $user = @"
Title: $Title

$Body
"@
    try {
        $text = Invoke-AIChat -System $system -User $user
        if (-not $text) {
            Write-Host '[=] AI_URL/API_KEY/MODEL_NAME unset — skipping AI keywords'
            return @()
        }
        return (Split-Keywords $text)
    }
    catch {
        Write-Warning "AI keywords failed: $($_.Exception.Message)"
        return @()
    }
}

function Invoke-ArticleHtml([string]$Title, [string]$Body, [string]$AssetsDir) {
    $promptPath = Join-Path $AssetsDir 'prompts/article-html.md'
    if (-not (Test-Path $promptPath)) { throw "[!] missing $promptPath" }
    $system = (Get-Content -Raw $promptPath).Trim()
    $user = @"
Title: $Title

$Body
"@
    try {
        $html = Invoke-AIChat -System $system -User $user
        if (-not $html) {
            Write-Host '[=] AI_URL/API_KEY/MODEL_NAME unset — html left empty (app falls back to markdown)'
            return ''
        }
        $html = $html.Trim()
        $html = $html -replace '^```html\s*', '' -replace '^```HTML\s*', '' -replace '^```\s*', '' -replace '\s*```$', ''
        return $html.Trim()
    }
    catch {
        Write-Warning "AI html failed: $($_.Exception.Message)"
        return ''
    }
}

function Parse-ArticleFile([string]$Path) {
    $raw = Get-Content -Raw -Path $Path
    $parts = $raw -split "`n---`n", 2
    if ($parts.Count -ne 2) { throw "[!] missing frontmatter: $Path" }

    $meta = @{}
    foreach ($line in ($parts[0] -split "`n")) {
        $line = $line.Trim()
        if (-not $line -or $line -eq '---') { continue }
        $idx = $line.IndexOf(':')
        if ($idx -le 0) { continue }
        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim().Trim('"')
        $meta[$key] = $val
    }

    $body = $parts[1].Trim()
    $title = [string]$meta['title']
    if ([string]::IsNullOrWhiteSpace($title)) {
        $first, $rest = ($body -split "`n", 2)
        $title = $first.Trim()
        if ($rest) { $body = $rest.Trim() }
    }
    if ([string]::IsNullOrWhiteSpace($title)) {
        throw "[!] title required in frontmatter or first body line: $Path"
    }

    $created = [string]$meta['created']
    $updated = [string]$meta['updated']
    if (-not $created) { $created = (Get-Item $Path).LastWriteTimeUtc.ToString('yyyy-MM-dd') }
    if (-not $updated) { $updated = $created }

    return [pscustomobject]@{
        Title    = $title
        Keywords = [string]$meta['keywords']
        Content  = $body
        Created  = $created
        Updated  = $updated
    }
}

function Encode-SqlText([string]$Text) {
    if ($null -eq $Text) { $Text = '' }
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Text))
}

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg', [Tuf]::new())
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd")
    $os.Step('apply-articles', 'started')

    if (-not (Get-Command psql -ErrorAction SilentlyContinue)) { throw '[!] psql required' }
    if (-not (Test-Path 'assets/articles')) { throw '[!] Missing assets/articles' }

    $pg = [PostgreSql]::new($Env, $Settings, $Project)
    $pg.EnsureDatabase()

    $defaults = Get-DefaultKeywords 'assets'
    $files = Get-ChildItem -Path 'assets/articles' -Filter '*.md' -File
    if (-not $files) { throw '[!] no markdown articles in assets/articles' }

    $count = 0
    foreach ($file in $files) {
        $a = Parse-ArticleFile $file.FullName
        $aiKeywords = Invoke-ArticleKeywords -Title $a.Title -Body $a.Content -AssetsDir 'assets'
        $keywords = Merge-Keywords @(($defaults -join ', '), $a.Keywords, ($aiKeywords -join ', '))
        $keywordsJson = ($keywords | ConvertTo-Json -Compress)
        if (-not $keywordsJson.StartsWith('[')) { $keywordsJson = "[$keywordsJson]" }

        $html = Invoke-ArticleHtml -Title $a.Title -Body $a.Content -AssetsDir 'assets'

        $sql = @"
INSERT INTO article (title, keywords, content, html, created_at, updated_at)
VALUES (
  convert_from(decode('$(Encode-SqlText $a.Title)', 'base64'), 'UTF8'),
  convert_from(decode('$(Encode-SqlText $keywordsJson)', 'base64'), 'UTF8')::jsonb,
  convert_from(decode('$(Encode-SqlText $a.Content)', 'base64'), 'UTF8'),
  convert_from(decode('$(Encode-SqlText $html)', 'base64'), 'UTF8'),
  '$(($a.Created))'::timestamptz,
  '$(($a.Updated))'::timestamptz
)
ON CONFLICT (title) DO UPDATE SET
  keywords = EXCLUDED.keywords,
  content = EXCLUDED.content,
  html = EXCLUDED.html,
  updated_at = EXCLUDED.updated_at;
"@
        & psql $pg.DbUrl -v ON_ERROR_STOP=1 -c $sql
        if ($LASTEXITCODE -ne 0) { throw "[!] upsert failed for $($a.Title)" }
        Write-Host "[+] upserted $($a.Title) ($($keywords.Count) keywords, html=$($html.Length) chars)"
        $count++
    }

    Write-Host "[+] Done — $count articles"
    $os.Step('apply-articles', 'succeeded', @{ count = $count })
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd") }
        if (-not $os.Url) { $os.Url = $Project.PinnedOpenSearchPublicUrl.TrimEnd('/') }
        $os.Step('apply-articles', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-articles', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}
