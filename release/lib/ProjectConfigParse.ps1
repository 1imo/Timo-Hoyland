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

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCByPCrerOVlUfMP
# VuDdIwyd7fzDcqJRINE8Bvn5KcHSpqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
# R/b0C5YxX/PjyDAKBggqhkjOPQQDAjAgMR4wHAYDVQQDExVOb3R0SW5mcmEgSW50
# ZXJuYWwgQ0EwHhcNMjYwNzI3MjM0NDE1WhcNMjcwNzI3MjM0NDE1WjAlMSMwIQYD
# VQQDExpOT1RUSU5GUkEgTElNSVRFRCBTT0ZUV0FSRTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAKRICuzioM/pLsdWW/uV0Hl7Y5FHNBPTEl3X/oGK+BAi
# kC0es0CLXLykWpsJ/f9ldyyHlMzwUR1zEIhCZXEyo+uqQ8B1yWke7rQ4wkWE6/DU
# htCLSiySkf/KB389/ptcEM+jJ48DQGi0+8K6QQ02vEOAQKLfxA4Rrnl5BYY+nnNs
# Rpa+B6K40i/aFAsc60gbG3SGQePzuHHbPl6CE5AzQNY2WBpY77aonZ830RM5AsS4
# Xe7P8cDJ7Gahw6ZjLEriCaR3xBytPy63RiZdW8upuQ0AIFz4/8GVRYuOJ1wGeU53
# b0OZhj/6Z481Zry0VcBvGfHidIVkQKbWZQ2QWdkSBbSAIR92tKpSqSDy4VQYQ4RO
# l3NY/QHkJsAl6EGzQ514P+qUzkSyxgSNHZFCknqTu6gXtemaCUC7z/eLZDibw+mg
# yAuyLTZoeAlDPaHT4FOPfB8pn6UuGb/LwJwFlBHGAkaYlfAkx3BJYIsQpfPwKxfN
# Ufds8LMYArJlFZJnJ1EmJSE+qIu0cN7SyuFDAdGszrVjltYswzAfhE0NRQQm4HiG
# CWG9ZxDD1TxbhvEecgJCOMy/dZCcjEEzq4wZxSVPicn0QowKDWHy1GpgdR3pT+Ok
# zuIBpfEeXW5uW9e0yoOzwOnh1XCRp8hv+B4l4RvTEl3ccZ+PcmAcsLHODqvW4vmT
# AgMBAAGjQTA/MA4GA1UdDwEB/wQEAwIFoDAMBgNVHRMBAf8EAjAAMB8GA1UdIwQY
# MBaAFKF88Blhy5xs0hQfn4medNFL3FoXMAoGCCqGSM49BAMCA0gAMEUCIQDwlWDa
# ojXZG8h5O2XzW/IG9h+GUKAmx8SCd7NuhB0SUAIgJkQlleqNoGkPuDyi08MuVI36
# ezJPirlP+IxtyaFnz10xggMHMIIDAwIBATA1MCAxHjAcBgNVBAMTFU5vdHRJbmZy
# YSBJbnRlcm5hbCBDQQIRAJ+3kgs9xEf29AuWMV/z48gwCwYJYIZIAWUDBAIBoHww
# EAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJnqVrWz
# ppaPvQaL30yg6J9fWkBEPl9dZBR7nFcNRIl+MAsGCSqGSIb3DQEBAQSCAgB9579Y
# 4NqfSx+K7wzVa2W6skT7Thr6RrDWYVMAJ2v1l5KyUYRp1gOxjEYAhDgWlvcVxvjc
# s5UGYDrxiGgytwuR1IIAyoObyNH9YDqV+NYmI7JPA6OK0CLOUKzCGU/3ZpT2EkrP
# 0Jy385OZBMAbbCY4c1CqR/OWuzWUv1T5CuftL2sena1g+c3gUxE4aq39FqAMU+/j
# wgD+ZG2Gb8TW58b9dfSgP1CGEUcWI1Z1Tz1wVIS29IdS/+IHa7Ss4nlhrbUEpGGT
# lz5wecF8/JELmx+LdQ/YGWi1mY5LLHAaorEIV/U9udPj78BfbHl6hRjToCEopyy5
# E99Cq32hXQKU6p/zfIlESArTjPyOIv4LpPcZ0TYZyJy1rROllLFwg5IheC5MMOIL
# mxVTp8mSz7gSATZ18mRTitQiPGCmCTadRoC8uPhiUs/QGUPi2rRq3M0LleqtKfdd
# HwA4PHt5XJbTogk1Hu5cbXsWE/7m3QZivQ16FkPLBmbY0ZPfX0rVfvd+mf+SmlOk
# /e8WZI6REB5YfTLDmLxTnEYEekd4tgPR8p9W47zMhsvzbTNnUswyNCGWZAyv6F23
# n/xp2L8DpeIqQM5cw77v36fcQzS5jw9L+RmwGaKA2JnHkIT7k+69TCdd+YhtZeVc
# lz8Yunpz/lKvUOwLECu+bco9wyAqsEu+VietYqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
