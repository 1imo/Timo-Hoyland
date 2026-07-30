class ProjectConfigParse {
    hidden [string]$ConfigPath
    hidden [hashtable]$Tree
    [string]$Name
    [string]$Env
    [string]$Root
    [string]$Image

    static [string] ReadProjectName([string]$RepoRoot) {
        $cfgPath = Join-Path $RepoRoot 'project.cfg'
        if (-not (Test-Path $cfgPath)) { throw "[!] missing $cfgPath" }
        foreach ($line in Get-Content $cfgPath) {
            if ($line -match '^\s*project:\s*(.+)$') {
                return $line.Split(':', 2)[1].Trim().Trim('"').Trim("'")
            }
        }
        throw '[!] project name required in project.cfg'
    }

    ProjectConfigParse([string]$Env) {
        if ($Env -notin @('live', 'test')) { throw '[!] env required: live|test' }
        if (-not $env:REGISTRY_URL) { throw '[!] REGISTRY_URL is required' }
        $repoRoot = if ($env:CI_PROJECT_DIR) { $env:CI_PROJECT_DIR } else { (Get-Location).Path }
        $repoRoot = (Resolve-Path $repoRoot).Path
        Set-Location $repoRoot
        $this.Env = $Env
        $this.ConfigPath = Join-Path $repoRoot 'project.cfg'
        if (-not (Test-Path $this.ConfigPath)) { throw "[!] missing $($this.ConfigPath)" }
        $this.Tree = $this.ReadYaml()
        $this.Name = [string]$this.Get('project')
        if ([string]::IsNullOrWhiteSpace($this.Name)) { throw '[!] project name required in project.cfg' }
        $tag = if ($Env -eq 'live') { 'prod' } else { 'test' }
        $this.Root = $repoRoot
        $this.Image = "$($env:REGISTRY_URL)/$($this.Name):$tag"
    }

    [string] ReleaseImage() {
        if ($env:RELEASE_IMAGE) { return $env:RELEASE_IMAGE }
        return $this.Image
    }

    [string] BuildImage() {
        if ($env:RELEASE_IMAGE) { return $env:RELEASE_IMAGE }
        $sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } elseif ($env:CI_COMMIT_SHA) { $env:CI_COMMIT_SHA } else { '' }
        if ($sha) { return "$($env:REGISTRY_URL)/$($this.Name):ci-$sha" }
        return $this.Image
    }

    [object] Get([string]$Path) {
        if ([string]::IsNullOrWhiteSpace($Path)) { return $this.ToObject($this.Tree) }
        $node = $this.Tree
        foreach ($part in $Path.Split('.')) {
            if ($null -eq $node) { return $null }
            if ($node -is [System.Collections.IDictionary] -and $node.Contains($part)) {
                $node = $node[$part]
            }
            else { return $null }
        }
        return $this.ToObject($node)
    }

    hidden [hashtable] ReadYaml() {
        $doc = [ordered]@{}
        $stack = [System.Collections.Generic.List[object]]::new()
        $stack.Add([ordered]@{ Map = $doc; Indent = -1 })
        $lines = Get-Content $this.ConfigPath

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '^\s*(#|$)') { continue }

            if ($line -match '^(\s*)-\s+(.*)$') {
                $indent = $Matches[1].Length
                $value = $this.Unquote($Matches[2].Trim())
                $this.TrimStack($stack, $indent)
                $map = $stack[$stack.Count - 1].Map
                $listKey = $null
                foreach ($k in $map.Keys) {
                    if ($map[$k] -is [System.Collections.Generic.List[object]]) { $listKey = $k }
                }
                if (-not $listKey) { throw "[!] invalid list in $($this.ConfigPath): $line" }
                [void]$map[$listKey].Add($value)
                continue
            }

            if ($line -notmatch '^(\s*)([^:]+?):\s*(.*)$') { continue }
            $indent = $Matches[1].Length
            $key = $Matches[2].Trim()
            $value = $Matches[3].Trim()
            $this.TrimStack($stack, $indent)
            $frame = $stack[$stack.Count - 1]

            if ($value -eq '') {
                $next = $this.NextContentLine($lines, $i)
                if ($next -match ('^' + (' ' * $indent) + '-\s+')) {
                    $frame.Map[$key] = [System.Collections.Generic.List[object]]::new()
                    continue
                }
                $child = [ordered]@{}
                $frame.Map[$key] = $child
                $stack.Add([ordered]@{ Map = $child; Indent = $indent })
                continue
            }

            $frame.Map[$key] = $this.Unquote($value)
        }

        return $doc
    }

    hidden [string] NextContentLine([string[]]$Lines, [int]$Index) {
        for ($j = $Index + 1; $j -lt $Lines.Count; $j++) {
            if ($Lines[$j] -notmatch '^\s*(#|$)') { return $Lines[$j] }
        }
        return ''
    }

    hidden [void] TrimStack([System.Collections.Generic.List[object]]$Stack, [int]$Indent) {
        while ($Stack.Count -gt 1 -and $Stack[$Stack.Count - 1].Indent -ge $Indent) {
            $Stack.RemoveAt($Stack.Count - 1)
        }
    }

    hidden [string] Unquote([string]$Value) {
        if ($Value.StartsWith('"') -and $Value.EndsWith('"')) { return $Value.Substring(1, $Value.Length - 2) }
        if ($Value.StartsWith("'") -and $Value.EndsWith("'")) { return $Value.Substring(1, $Value.Length - 2) }
        return $Value
    }

    hidden [object] ToObject([object]$Node) {
        if ($Node -is [System.Collections.IDictionary]) {
            $o = [PSCustomObject]@{}
            foreach ($k in $Node.Keys) {
                $o | Add-Member -NotePropertyName $k -NotePropertyValue ($this.ToObject($Node[$k]))
            }
            return $o
        }
        if ($Node -is [System.Collections.Generic.List[object]]) {
            return @($Node | ForEach-Object { $this.ToObject($_) })
        }
        if ($Node -is [array]) {
            return @($Node | ForEach-Object { $this.ToObject($_) })
        }
        return $Node
    }
}
