class Tuf {
    # Hardcoded — Tuf must not read settings.cfg / Config (chicken/egg).
    [string]$Url = 'https://tuf.nottinfra.co.uk'

    # Set by caller (e.g. Config) before GetTarget / CheckSigned.
    [string]$TargetsPublicKeyHex
    [string]$TargetsKeyId

    hidden [object]$Targets
    hidden [string]$OpenSslPath

    Tuf() {}

    [void] CheckSigned([string]$File, [string]$SigFile, [string]$CaTarget) {
        if ([string]::IsNullOrWhiteSpace($File)) { throw 'file path required' }
        if ([string]::IsNullOrWhiteSpace($SigFile)) { throw 'sig file path required' }
        if ([string]::IsNullOrWhiteSpace($CaTarget)) { throw 'CA target name required' }
        if (-not (Test-Path -LiteralPath $File)) { throw "missing $File" }
        if (-not (Test-Path -LiteralPath $SigFile)) { throw "missing $SigFile" }

        $sig = $null
        try {
            $sig = Get-Content -LiteralPath $SigFile -Raw -Encoding utf8 | ConvertFrom-Json
        }
        catch {
            throw ("cannot parse $SigFile ($($_.Exception.Message))")
        }

        if ([string]$sig.format -ne 'cms-detached') {
            throw "$SigFile format must be cms-detached"
        }
        if ([string]::IsNullOrWhiteSpace([string]$sig.cms_pem)) {
            throw "$SigFile missing cms_pem"
        }
        if ([string]::IsNullOrWhiteSpace([string]$sig.digest)) {
            throw "$SigFile missing digest"
        }

        $sha = [System.Security.Cryptography.SHA256]::Create()
        $digest = ''
        try {
            $fileBytes = [System.IO.File]::ReadAllBytes($File)
            $hex = ([BitConverter]::ToString($sha.ComputeHash($fileBytes)) -replace '-', '').ToLowerInvariant()
            $digest = 'sha256:' + $hex
        }
        finally {
            $sha.Dispose()
        }
        if ($digest -ne [string]$sig.digest) {
            throw "digest $digest does not match $SigFile digest $($sig.digest)"
        }

        $caPem = ''
        try {
            $caPem = $this.GetTargetText($CaTarget)
        }
        catch {
            throw ("TUF CA $CaTarget unavailable ($($_.Exception.Message))")
        }

        $dir = Join-Path ([IO.Path]::GetTempPath()) ('tuf-cms-' + [guid]::NewGuid().ToString('n'))
        New-Item -ItemType Directory -Path $dir | Out-Null
        try {
            $caPath = Join-Path $dir 'ca.crt'
            $cmsPath = Join-Path $dir 'signed.cms'
            $outPath = Join-Path $dir 'out.bin'
            [IO.File]::WriteAllText($caPath, $caPem)
            [IO.File]::WriteAllText($cmsPath, [string]$sig.cms_pem)
            $openssl = $this.ResolveOpenSsl()
            $cmsOut = & $openssl cms -verify -inform PEM -in $cmsPath -content $File -CAfile $caPath -binary -out $outPath -purpose any 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "CMS verification failed ($cmsOut)"
            }
        }
        finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    [string] ResolveOpenSsl() {
        if (-not [string]::IsNullOrWhiteSpace($this.OpenSslPath)) { return $this.OpenSslPath }
        $candidates = [System.Collections.Generic.List[string]]::new()
        foreach ($c in @(
                '/opt/homebrew/bin/openssl',
                '/usr/local/bin/openssl',
                (Get-Command openssl -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
                '/usr/bin/openssl'
            )) {
            if ([string]::IsNullOrWhiteSpace($c)) { continue }
            if (-not (Test-Path -LiteralPath $c)) { continue }
            if ($candidates -contains $c) { continue }
            $candidates.Add($c)
        }
        foreach ($candidate in $candidates) {
            # Prefer OpenSSL 3+ (ed25519 pkeyutl); LibreSSL can still verify CMS.
            $algs = & $candidate list -public-key-algorithms 2>$null
            if ($LASTEXITCODE -eq 0 -and ("$algs" -match 'ED25519')) {
                $this.OpenSslPath = $candidate
                return $this.OpenSslPath
            }
        }
        if ($candidates.Count -gt 0) {
            $this.OpenSslPath = $candidates[0]
            return $this.OpenSslPath
        }
        throw '[!] openssl not found (required for TUF / settings verification)'
    }

    [byte[]] GetTarget([string]$Name) {
        if ([string]::IsNullOrWhiteSpace($Name)) { throw '[!] TUF target name required' }
        $meta = $this.TargetMeta($Name)
        $hash = [string]$meta.hashes.sha512
        if ([string]::IsNullOrWhiteSpace($hash)) { throw "[!] TUF target $Name missing sha512" }
        $expectedLen = [int]$meta.length
        $uri = "$($this.Url.TrimEnd('/'))/targets/$hash.$Name"
        $bytes = $null
        try {
            $client = [System.Net.Http.HttpClient]::new()
            $client.Timeout = [TimeSpan]::FromSeconds(60)
            try {
                $bytes = $client.GetByteArrayAsync($uri).GetAwaiter().GetResult()
            }
            finally {
                $client.Dispose()
            }
        }
        catch {
            throw "[!] TUF download failed for $Name ($uri): $($_.Exception.Message)"
        }
        if ($bytes.Length -ne $expectedLen) {
            throw "[!] TUF target $Name length $($bytes.Length) != $expectedLen"
        }
        $sha = [System.Security.Cryptography.SHA512]::Create()
        $digestHex = ''
        try {
            $digestHex = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
        }
        finally {
            $sha.Dispose()
        }
        if ($digestHex -ne $hash.ToLowerInvariant()) {
            throw "[!] TUF target $Name sha512 mismatch"
        }
        return [byte[]]$bytes
    }

    [string] GetTargetText([string]$Name) {
        return [Text.Encoding]::UTF8.GetString($this.GetTarget($Name))
    }

    hidden [object] TargetMeta([string]$Name) {
        $doc = $this.EnsureTargets()
        $map = $doc.signed.targets
        $prop = $map.PSObject.Properties[$Name]
        if (-not $prop) { throw "[!] TUF target not found: $Name" }
        return $prop.Value
    }

    hidden [object] EnsureTargets() {
        if ($null -ne $this.Targets) { return $this.Targets }
        $uri = "$($this.Url.TrimEnd('/'))/targets.json"
        $raw = $null
        try {
            $raw = (Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 60).Content
        }
        catch {
            throw "[!] TUF targets.json fetch failed ($uri): $($_.Exception.Message)"
        }
        if ($raw -is [byte[]]) { $raw = [Text.Encoding]::UTF8.GetString($raw) }

        $this.VerifyTargetsSignatureRaw([string]$raw)

        $doc = $null
        try {
            $doc = $raw | ConvertFrom-Json
        }
        catch {
            throw "[!] TUF targets.json parse failed: $($_.Exception.Message)"
        }
        if ([string]$doc.signed._type -ne 'targets') {
            throw '[!] TUF metadata is not targets'
        }
        $expiresRaw = $doc.signed.expires
        if ($expiresRaw -is [datetime]) {
            $expires = ([datetime]$expiresRaw).ToUniversalTime()
        }
        else {
            $expires = [datetime]::Parse(
                [string]$expiresRaw,
                [Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
            )
        }
        if ($expires -le [datetime]::UtcNow) {
            throw "[!] TUF targets metadata expired at $expires"
        }
        $this.Targets = $doc
        return $this.Targets
    }

    # Verify using System.Text.Json so ISO8601 date strings are not coerced to DateTime.
    hidden [void] VerifyTargetsSignatureRaw([string]$Raw) {
        $jdoc = [System.Text.Json.JsonDocument]::Parse($Raw)
        try {
            $root = $jdoc.RootElement
            $sigEntry = $null
            foreach ($s in $root.GetProperty('signatures').EnumerateArray()) {
                if ($s.GetProperty('keyid').GetString() -eq $this.TargetsKeyId) {
                    $sigEntry = $s
                    break
                }
            }
            if ($null -eq $sigEntry) {
                throw "[!] TUF targets.json missing signature for key $($this.TargetsKeyId)"
            }

            $msg = [Text.Encoding]::UTF8.GetBytes($this.CanonicalJsonElement($root.GetProperty('signed')))
            $sig = $this.HexToBytes($sigEntry.GetProperty('sig').GetString())
            $pub = $this.HexToBytes($this.TargetsPublicKeyHex)

            $dir = Join-Path ([IO.Path]::GetTempPath()) ('tuf-' + [guid]::NewGuid().ToString('n'))
            New-Item -ItemType Directory -Path $dir | Out-Null
            try {
                $msgPath = Join-Path $dir 'signed.bin'
                $sigPath = Join-Path $dir 'sig.bin'
                $pubPath = Join-Path $dir 'targets.pub.pem'
                [IO.File]::WriteAllBytes($msgPath, $msg)
                [IO.File]::WriteAllBytes($sigPath, $sig)
                [IO.File]::WriteAllText($pubPath, $this.Ed25519PublicKeyPem($pub))

                $openssl = $this.ResolveOpenSsl()
                $out = & $openssl pkeyutl -verify -pubin -inkey $pubPath -rawin -in $msgPath -sigfile $sigPath 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "[!] TUF targets.json signature invalid ($openssl): $out"
                }
            }
            finally {
                Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        finally {
            $jdoc.Dispose()
        }
    }

    hidden [string] Ed25519PublicKeyPem([byte[]]$RawPublicKey) {
        if ($RawPublicKey.Length -ne 32) { throw '[!] ed25519 public key must be 32 bytes' }
        # SubjectPublicKeyInfo for id-Ed25519
        $prefix = [byte[]](0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00)
        $spki = New-Object byte[] ($prefix.Length + $RawPublicKey.Length)
        [Array]::Copy($prefix, 0, $spki, 0, $prefix.Length)
        [Array]::Copy($RawPublicKey, 0, $spki, $prefix.Length, $RawPublicKey.Length)
        $b64 = [Convert]::ToBase64String($spki)
        $lines = for ($i = 0; $i -lt $b64.Length; $i += 64) {
            $b64.Substring($i, [Math]::Min(64, $b64.Length - $i))
        }
        return "-----BEGIN PUBLIC KEY-----`n$($lines -join "`n")`n-----END PUBLIC KEY-----`n"
    }

    hidden [byte[]] HexToBytes([string]$Hex) {
        $h = ($Hex -replace '\s', '').ToLowerInvariant()
        if ($h.Length % 2 -ne 0) { throw '[!] invalid hex length' }
        $bytes = New-Object byte[] ($h.Length / 2)
        for ($i = 0; $i -lt $bytes.Length; $i++) {
            $bytes[$i] = [Convert]::ToByte($h.Substring($i * 2, 2), 16)
        }
        return $bytes
    }

    # OLPC / TUF canonical JSON encoding.
    hidden [string] CanonicalJsonElement([System.Text.Json.JsonElement]$Node) {
        switch ($Node.ValueKind) {
            'Null' { return 'null' }
            'True' { return 'true' }
            'False' { return 'false' }
            'String' { return ($Node.GetString() | ConvertTo-Json -Compress) }
            'Number' { return $Node.GetRawText() }
            'Array' {
                $parts = [System.Collections.Generic.List[string]]::new()
                foreach ($item in $Node.EnumerateArray()) {
                    $parts.Add($this.CanonicalJsonElement($item))
                }
                return '[' + ($parts -join ',') + ']'
            }
            'Object' {
                $props = [System.Collections.Generic.List[System.Text.Json.JsonProperty]]::new()
                foreach ($p in $Node.EnumerateObject()) { $props.Add($p) }
                $sorted = @($props | Sort-Object { $_.Name })
                $parts = [System.Collections.Generic.List[string]]::new()
                foreach ($p in $sorted) {
                    $k = ($p.Name | ConvertTo-Json -Compress)
                    $parts.Add($k + ':' + $this.CanonicalJsonElement($p.Value))
                }
                return '{' + ($parts -join ',') + '}'
            }
            default { throw "[!] unsupported JSON value kind: $($Node.ValueKind)" }
        }
        throw '[!] unreachable'
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD6azci8G6W+hIy
# r0pbRm/1zUyk+sktUtYKJN/8JPtphKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIMF/7FNn
# vddSWTvqN0fwAFB8BzG6kRsRb5nXh1Ntc5h3MAsGCSqGSIb3DQEBAQSCAgCPLzQ0
# c20VKIPRYwIsZo+QdsheOv+VWEc3q3W1Z4r8dpYP6fx17AKjWMsJfi2UzbdujZFf
# drR6e5HdWiSK6Qk5HruKi8uSozFg7gAXjddYNz5z0Z8LO87Wsqdz5g6X8UKg1aUM
# 3BXDtCBaXoRxesRm+ZBE1bEN8V3VKNERRGQiE35Hiar+NRKZkGEuplgzfmEqU3aS
# UOnCNY1EfqSjkCzRYnZxHOzYyVWMx2sz5iI2luIYFC2Wc4c+Fp79VWTtwiTJttKH
# xDUJ9pAeb6/X8ysU1hxrmr+VCJRYQFnK/66sIPPcq949f8rQKlFuaz9KczE/2BRs
# l3h96mDxybeG5y/wfWaDu1Cfv8dkHQurKqxPht7L6baEUT3pRThdndTbnd5KNcK4
# O7+L7svmpED5wsNh4oXMatXYi8T0cUfkbPyQwXCpUoMHToJP4yyMh36afQmfAOeF
# 74BycNI/YDI1ClS0zFMuXQL2CV3ycG1KIB2nEZP9Dekm9qeUqc3WIj86I7TIvLzZ
# OWA9q6v13XvzY/JJEjZUZcMcy3qgajeFHR37y9L9evvAwXIs3kKdicBFoMwlNqyP
# 21waY9BtH8Iuwazj7VSFj/f+r7LF4hA7SezmNrIXuB7EmWPcOp2p/KouuHGRmrmP
# 7qq48U+5R/UtIkka1Rwy2hDU2Scj4U4JE8zJK6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
