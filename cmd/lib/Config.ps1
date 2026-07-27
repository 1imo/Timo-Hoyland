class Config {
    hidden [string]$File
    [hashtable]$Tree
    [hashtable]$Data
    [string]$Name
    [bool]$Loaded

    Config([string]$FileName) {
        if ([string]::IsNullOrWhiteSpace($FileName)) { throw '[!] config file name required' }
        $this.File = $FileName
        $this.Data = @{}
        $this.Tree = @{}
        if (-not (Test-Path $FileName)) { return }
        $this.File = (Resolve-Path $FileName).Path
        $this.Tree = $this.ReadYaml()
        $this.Loaded = $true
        if ((Split-Path $FileName -Leaf) -eq 'settings.cfg') {
            $this.Data = $this.FlattenNode($this.Tree, '')
        }
        $projectName = [string]$this.Get('project')
        if (-not [string]::IsNullOrWhiteSpace($projectName)) { $this.Name = $projectName }
    }

    [object] Get([string]$Path) {
        if ([string]::IsNullOrWhiteSpace($Path)) { return $this.ToObject($this.Tree) }
        $node = $this.Tree
        $found = $true
        foreach ($part in $Path.Split('.')) {
            if ($null -eq $node) { $found = $false; break }
            if ($node -is [System.Collections.IDictionary] -and $node.Contains($part)) {
                $node = $node[$part]
            }
            else { $found = $false; break }
        }
        if ($found) { return $this.ToObject($node) }
        # settings.cfg list entries (KEY=value) live in flattened Data
        if ($this.Data.ContainsKey($Path)) { return $this.Data[$Path] }
        return $null
    }

    [string] Require([string]$Path) {
        $val = $this.Get($Path)
        if ($null -eq $val -or ($val -is [string] -and [string]::IsNullOrWhiteSpace($val))) {
            throw "[!] $Path not set in $($this.File)"
        }
        return [string]$val
    }

    hidden [hashtable] FlattenNode([object]$Node, [string]$Prefix) {
        $out = @{}
        if (-not ($Node -is [System.Collections.IDictionary])) { return $out }

        foreach ($key in $Node.Keys) {
            $segment = [string]$key
            $path = if ($Prefix) { "$Prefix.$segment" } else { $segment }
            $child = $Node[$key]

            if ($child -is [System.Collections.IDictionary]) {
                foreach ($entry in $this.FlattenNode($child, $path).GetEnumerator()) {
                    $out[$entry.Key] = $entry.Value
                }
                continue
            }

            if ($child -is [System.Collections.Generic.List[object]]) {
                foreach ($item in $child) {
                    $line = [string]$item
                    if ($line -notmatch '^([^=]+)=(.*)$') {
                        throw "[!] invalid settings entry at ${path}: $line"
                    }
                    $out["$path.$($Matches[1])"] = $this.Unquote($Matches[2].Trim())
                }
                continue
            }

            $out[$path] = [string]$child
        }

        return $out
    }

    hidden [hashtable] ReadYaml() {
        $doc = [ordered]@{}
        $stack = [System.Collections.Generic.List[object]]::new()
        $stack.Add([ordered]@{ Map = $doc; Indent = -1 })
        $lines = Get-Content $this.File

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
                if (-not $listKey) { throw "[!] invalid list in $($this.File): $line" }
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
                $isList = $false
                if ($next -match '^(\s*)-\s+') {
                    $listIndent = $Matches[1].Length
                    if ($listIndent -eq $indent -or $listIndent -gt $indent) { $isList = $true }
                }
                if ($isList) {
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
