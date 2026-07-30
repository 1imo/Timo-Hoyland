class Config {
    hidden [string]$File
    [hashtable]$Tree
    [hashtable]$Data
    [string]$Name
    [bool]$Loaded
    [Tuf]$Tuf

    # Fallback when OPENSEARCH_URL is unbound (e.g. unsigned-settings alert path).
    [string]$PinnedOpenSearchPublicUrl = 'https://opensearch.nottinfra.co.uk'

    # TUF targets-role ed25519 public key from root (keyid 4b7b9ec5…).
    hidden [string]$TufTargetsPublicKeyHex = '5fb64cdf03bbce4a54d27cf1981614075066732297f1539a5d39160f6de7dc13'
    hidden [string]$TufTargetsKeyId = '4b7b9ec52e91431e7310abf27edf4d3b0abb39308801b038aad8dac35f0f8907'
    # TUF target used as CMS trust anchor for settings.cfg.sig.
    hidden [string]$SettingsCaTarget = 'nottinfra.crt'

    Config([string]$FileName) {
        $this.Init($FileName, $null)
    }

    Config([string]$FileName, [Tuf]$Tuf) {
        $this.Init($FileName, $Tuf)
    }

    hidden [void] Init([string]$FileName, [Tuf]$Tuf) {
        if ([string]::IsNullOrWhiteSpace($FileName)) { throw '[!] config file name required' }
        $this.File = $FileName
        $this.Tuf = $Tuf
        $this.Data = @{}
        $this.Tree = @{}
        if (-not (Test-Path $FileName)) { return }
        $this.File = (Resolve-Path $FileName).Path
        if ([IO.Path]::GetFileName($this.File) -eq 'settings.cfg') {
            if (-not $this.Tuf) { throw '[!] settings.cfg requires Tuf' }
            $this.Tuf.TargetsKeyId = $this.TufTargetsKeyId
            $this.Tuf.TargetsPublicKeyHex = $this.TufTargetsPublicKeyHex
            try {
                $this.Tuf.CheckSigned($this.File, ($this.File + '.sig'), $this.SettingsCaTarget)
            }
            catch {
                throw ('[!] UNSIGNED_SETTINGS_CFG: ' + $_.Exception.Message)
            }
        }
        $this.Tree = $this.ReadYaml()
        $this.Loaded = $true
        $this.Data = $this.FlattenNode($this.Tree, '')
        $projectName = [string]$this.Get('project')
        if (-not [string]::IsNullOrWhiteSpace($projectName)) { $this.Name = $projectName }
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

    [string] Require([string]$Path) {
        $val = $this.Get($Path)
        if ($null -eq $val -or ($val -is [string] -and [string]::IsNullOrWhiteSpace($val))) {
            throw "[!] $Path not set in $($this.File)"
        }
        return [string]$val
    }

    hidden [string] EndpointNetwork([string]$Network) {
        $n = "$Network".ToLower()
        if ($n -eq 'cluster') { return 'CLUSTER' }
        if ($n -eq 'public') { return 'PUBLIC' }
        throw "[!] NETWORK must be cluster or public (got $Network)"
    }

    [string] Endpoint([string]$Service) {
        $network = if ($env:NETWORK) { $env:NETWORK } else { 'public' }
        return $this.Endpoint($Service, $network)
    }

    [string] Endpoint([string]$Service, [string]$Network) {
        if ([string]::IsNullOrWhiteSpace($Network)) { $Network = 'public' }
        $kind = $this.EndpointNetwork($Network)
        return $this.Require("ENDPOINTS.$($Service.ToUpper()).$kind")
    }

    [hashtable] EndpointEnvVars([string]$Network) {
        $kind = $this.EndpointNetwork($Network)
        $out = @{}
        $eps = $this.Tree['ENDPOINTS']
        if (-not ($eps -is [System.Collections.IDictionary])) { return $out }
        foreach ($svc in @($eps.Keys)) {
            $val = $this.Get("ENDPOINTS.$svc.$kind")
            if ($null -eq $val -or ($val -is [string] -and [string]::IsNullOrWhiteSpace([string]$val))) { continue }
            $out["$([string]$svc)_URL"] = [string]$val
        }
        return $out
    }

    [void] ApplyEndpoints([string]$Network) {
        foreach ($entry in $this.EndpointEnvVars($Network).GetEnumerator()) {
            Set-Item -Path "env:$($entry.Key)" -Value $entry.Value
        }
    }

    [void] Save() {
        if (-not $this.Loaded -or [string]::IsNullOrWhiteSpace($this.File)) {
            throw '[!] cannot save unloaded config'
        }
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('# Project manifest')
        $lines.Add('')
        $this.WriteYamlNode($lines, $this.Tree, 0)
        while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
            $lines.RemoveAt($lines.Count - 1)
        }
        Set-Content -Path $this.File -Value ($lines -join "`n") -Encoding utf8
        if (-not ((Get-Content -Path $this.File -Raw) -match '\n\z')) {
            Add-Content -Path $this.File -Value '' -Encoding utf8
        }
    }

    hidden [void] WriteYamlNode([System.Collections.Generic.List[string]]$Lines, [object]$Node, [int]$Indent) {
        $pad = ' ' * $Indent
        if (-not ($Node -is [System.Collections.IDictionary])) { return }
        foreach ($key in $Node.Keys) {
            $child = $Node[$key]
            if ($child -is [System.Collections.Generic.List[object]] -or $child -is [array]) {
                $Lines.Add("${pad}$($this.QuoteYamlKey([string]$key)):")
                foreach ($item in @($child)) {
                    $Lines.Add("$pad  - $($this.QuoteYaml([string]$item))")
                }
                continue
            }
            if ($child -is [System.Collections.IDictionary]) {
                $Lines.Add("${pad}$($this.QuoteYamlKey([string]$key)):")
                $this.WriteYamlNode($Lines, $child, $Indent + 2)
                continue
            }
            $Lines.Add("${pad}$($this.QuoteYamlKey([string]$key)): $($this.QuoteYaml([string]$child))")
        }
    }

    hidden [string] QuoteYamlKey([string]$Key) {
        if ($Key -match '[:#\[\]\{\},&*!|>''"%@`]|^\s|\s$|^\?|^-') {
            return "'" + ($Key -replace "'", "''") + "'"
        }
        return $Key
    }

    hidden [string] QuoteYaml([string]$Value) {
        if ($null -eq $Value) { return '""' }
        if ($Value -match '[:#\[\]\{\},&*!|>''"%`]|^\s|\s$|^[-?]') {
            return "'" + ($Value -replace "'", "''") + "'"
        }
        return $Value
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
            $key = $this.Unquote($Matches[2].Trim())
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

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCDQUNxHccBxVJZ
# oionDQemdvdyRiNUAFXqxDoIuGOAkaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIGRuRxNg
# jQ2n08SWg8va/pYG4ZiRp/eXveJ1wIYHlvG8MAsGCSqGSIb3DQEBAQSCAgB90Wd5
# KyD/5iOh27eigvLgMVZuEnnDDBeYAoIXMtKvhb/V1RrCEdnaqPuGxbyE82MKHIg5
# a5hTJzTXD1ZSi+cgIR5cYZq/Lb+JCWanRuB6nqx1vEjoKpHg1CjpQoKkGXPiCyFe
# KhEcfaUzRWFQUT89f313g08yZrq2OBw1+RrhMJjujuFIfXJtrB8hkp2OpgjAw9Qw
# 3bQIG8mEObiVWDu9cRi/BHRvCpUHUMkwh0krDgFiXKLf0APi7m3pbQcRAhVXVDOW
# QbntqAYM2dvAjlj9+tBS0Tywy4hBSsCqriEHKbCyD8PWXY0A6sdWp1sFm2Uda7WP
# Q/6kUydxkCDWRN9dzhhOfTq1up1M5NUJETFX8uCFLHzUSoJ1CXv0n4Qim3VG0xdg
# /yhmn0Ecqbns4lxQshheRVGFtI+HHVFeSpHcPRV7EkVhIkWYux2f0WehQc+Fbhnk
# xsZFeE25kAiRrleKzJ/WfHi5PFgnA/24mX+z/O7fxWps+S62qgXFr/NaVg0EcN29
# dc0euORPMAg6iSDxRPu4tPvXYwdk+UYbfbOxhuS41LCCwn/gR+7c+m0AhnKDsTBK
# XVr0H5Y6hf8qMP7QBwjqOBVxo1F3I0x4EQ2I6E63hFgEwzrbtdkcujBq2Z8AbmuD
# gXUsOeb668jFifrUVPp16OeKsCQoBg5Phl+YtaErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
