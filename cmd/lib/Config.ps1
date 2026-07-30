class Config {
    hidden [string]$File
    [hashtable]$Tree
    [hashtable]$Data
    [string]$Name
    [bool]$Loaded

    # Pinned settings.cfg.sig — update when re-signing settings.cfg.
    hidden [string]$ExpectedSettingsSigFormat = 'cms-detached'
    hidden [string]$ExpectedSettingsSigKeyName = 'nottinfra-config'
    hidden [string]$ExpectedSettingsSigDigest = 'sha256:b288364d4a942ae1b95bcc7c51de675ea679d44cad73635571caa5ca8c9136f6'
    hidden [string]$ExpectedSettingsSigUrl = 'https://nottinfra.co.uk'
    [string]$PinnedOpenSearchPublicUrl = 'https://opensearch.nottinfra.co.uk'

    hidden [string] ExpectedSettingsSigCmsPem() {
        return @'
-----BEGIN CMS-----
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
xd/L5kXuWvM2/wdC98tKOYpC2AA2C51tFBcC5A==
-----END CMS-----

'@
    }

    hidden [string] ExpectedSettingsSigCertPem() {
        return @'
-----BEGIN CERTIFICATE-----
MIIDVTCCAvugAwIBAgIRAKDf2sb4UMzR8nVYLvQZP0IwCgYIKoZIzj0EAwIwIDEe
MBwGA1UEAxMVTm90dEluZnJhIEludGVybmFsIENBMB4XDTI2MDczMDEwNDM0NloX
DTI3MDczMDEwNDM0NlowKjEoMCYGA1UEAxMfTk9UVElORlJBIExJTUlURUQgQ09O
RklHVVJBVElPTjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL3YgBVF
K2PeAf80KLpf/mWyj/RFSB6u4koA8tvCVr16IUrufXqf7fhW9Qh0K2aYdEdcTO1A
f3XvkMk8mNrnMMhgbtrz3mMMXX81xzYcYUHXeVZE3m4X1M04Lcoq9o8AlYMXCU0a
1MGJL6bHcuk85GYm/P+2pqsveruR8kSn0VYxhvrbxWJx4VzIObvvfi0LDWCN2YYC
7njpG73JzW3IGcmTAim0zE3E7VW9gvSyu1GDejDNPR9hMJrw/OTwX9b35JPV+jan
KF59XW0oL18sIqPl0/QtUpOal9TYUeihypiBlfuy03e8lZ80mKqmIB3JTLsXv0Le
WxjTHnkdH7y927oGOtoFFUY0mDzEQTifsVuEQDmTCqTrItgWkhUEGP0lp0JU6pTs
cyIedgKF253mMtdwoE7Ncp3Tb2L/A109B6QoFyNBDiGcjjDsRzeryHwAfcFmSkNb
ouBPrNjBI8ALjSa/v+5JVAnPOMjohlkci7yDS+gVwKONUyxUYjrkKy3/K0UZcuJJ
Gd50Xz0hJ6TxSeXsc1T3vn0eE3WSgB9aP3sdNpuNkz+U2SiP8yoOlrWsrwOTCBYG
wRxkMC1wJXgcbtI7NpD/1zNy53uzm0Ei7LV5HUlZZ0EMG+QNS/jPpkVhTNhjxzcE
000+ytLBuFla0UeHluMX6/ZhKGQeoIhXu8rVAgMBAAGjQTA/MA4GA1UdDwEB/wQE
AwIFoDAMBgNVHRMBAf8EAjAAMB8GA1UdIwQYMBaAFKF88Blhy5xs0hQfn4medNFL
3FoXMAoGCCqGSM49BAMCA0gAMEUCIQDzbVV7ImHLZH//KhhpQnAlF59TJPVSYHoF
pNJAwHtWCgIgT5dcCskZLN7DvjSaNesTmclhoLqjylNlyqHlkjxeOKo=
-----END CERTIFICATE-----

'@
    }

    hidden [string] UnsignedSettingsErrorPrefix() {
        return '[!] UNSIGNED_SETTINGS_CFG'
    }

    hidden [string] NormalizePem([string]$Text) {
        if ($null -eq $Text) { return '' }
        return (($Text -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd() + "`n"
    }

    hidden [void] AssertSettingsSigned([string]$SettingsPath) {
        $sigPath = $SettingsPath + '.sig'
        $prefix = $this.UnsignedSettingsErrorPrefix()
        if (-not (Test-Path -LiteralPath $sigPath)) {
            throw ($prefix + ': missing ' + $sigPath)
        }
        try {
            $sig = Get-Content -LiteralPath $sigPath -Raw -Encoding utf8 | ConvertFrom-Json
        }
        catch {
            throw ($prefix + ': cannot parse ' + $sigPath + ' (' + $_.Exception.Message + ')')
        }

        $checks = [ordered]@{
            format          = $this.ExpectedSettingsSigFormat
            key_name        = $this.ExpectedSettingsSigKeyName
            digest          = $this.ExpectedSettingsSigDigest
            url             = $this.ExpectedSettingsSigUrl
            cms_pem         = $this.ExpectedSettingsSigCmsPem()
            certificate_pem = $this.ExpectedSettingsSigCertPem()
        }
        foreach ($key in $checks.Keys) {
            $expected = [string]$checks[$key]
            $actual = [string]$sig.$key
            if ($key -in @('cms_pem', 'certificate_pem')) {
                $expected = $this.NormalizePem($expected)
                $actual = $this.NormalizePem($actual)
            }
            if ($actual -ne $expected) {
                throw ($prefix + ': ' + $sigPath + ' ' + $key + ' does not match pinned signature')
            }
        }

        $sha = [System.Security.Cryptography.SHA256]::Create()
        $got = ''
        try {
            $bytes = [System.IO.File]::ReadAllBytes($SettingsPath)
            $hex = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
            $got = 'sha256:' + $hex
        }
        finally {
            $sha.Dispose()
        }
        if ($got -ne $this.ExpectedSettingsSigDigest) {
            throw ($prefix + ': settings.cfg digest ' + $got + ' does not match pinned ' + $this.ExpectedSettingsSigDigest)
        }
    }

    Config([string]$FileName) {
        if ([string]::IsNullOrWhiteSpace($FileName)) { throw '[!] config file name required' }
        $this.File = $FileName
        $this.Data = @{}
        $this.Tree = @{}
        if (-not (Test-Path $FileName)) { return }
        $this.File = (Resolve-Path $FileName).Path
        if ([IO.Path]::GetFileName($this.File) -eq 'settings.cfg') {
            $this.AssertSettingsSigned($this.File)
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDQfSLh4CQptLHU
# Z94DzSSdh9zoq7ZYIBjh9ePpqaCxHqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINzFSS17
# CNDHIm5dkhpwOJUiR9bHg1fqH+nUoDUYIsvyMAsGCSqGSIb3DQEBAQSCAgCSpyoI
# bVF/KSS1Kw1DhAFPrqj9UC1SHHMYjF6Sjy0mMxZhmoI/TN0qfyhYFgSUcGpa6+IR
# d2jDwm5soQDCaS6nZgYHERXiWFnhHcgeP+IcjDCwtsbUume9u+PI+f+pdfQXTM+B
# K7XPVra0kMdXX57Z0h7wWF2zLSyP4jldx1OJsbrBNqw2WjEPczHsD8k7sOPaoRq+
# 5S/h92WfiWlzjrcmVjm+idGhAEyGNftgyTSnD7h9rE72EqL/qEfIM0T/QTaLISSd
# bvYlMT7JxMRYqVE3Gz39gqjsUgVd69IxaHyaIct2koWlvqIK2cz8TEQJFe8AizoJ
# ZlK87OTNJvV9c4amC/7v1Mflwoaebzn4n5nQC/u83iUZc7p9BJsicDSiqAEJEjJv
# I1XREGX7l2xfhiS+5601KS+p1BOChHUjFKYkuVVNh5po52hLG15d8LQrM4fKoRpp
# 05OPDD4k6XXvg73j1UjLMCyYe0YTzY6NBMymQxJGATEBrg+3410EGlQ35Mg5ZMsL
# 9Z8xYZHM9xV4iaxd3Cyr8xyyZSS1TxM8M/LpVH46YT9uT5nhO50RabWDHmrkioYG
# 1S1gzgsJMkdOHNZfgjIt05HhSS0Qw3A52P38vZhdPhoW9q9KZlOrlbcp9Lnnaidv
# KVQZZkK0zp+N8wfSVLYxQAm4Dgt09jpKAsD6BqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
