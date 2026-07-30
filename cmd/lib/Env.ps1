$script:CmdLibDir = $PSScriptRoot

class Env {
    [string]$LoadedFile
    [string]$Name

    Env() {
        $top = git rev-parse --show-toplevel 2>$null
        if ($top) { Set-Location (Resolve-Path $top).Path }
        else { Set-Location (Resolve-Path (Join-Path $script:CmdLibDir '../..')).Path }

        # Idempotent: nested [Env]::new() in the same process must not re-parse .env* over process env.
        if ($env:CMD_ENV_LOADED) {
            $this.Name = $this.Current()
            if ($env:ENV_FILE) { $this.LoadedFile = $env:ENV_FILE }
            elseif ($env:ENV) { $this.LoadedFile = $this.FileForName($env:ENV) }
            else { $this.LoadedFile = '.env.shared' }
            return
        }

        $this.LoadShared()

        if ($env:ENV_FILE) {
            $path = if ([IO.Path]::IsPathRooted($env:ENV_FILE)) { $env:ENV_FILE } else { $env:ENV_FILE }
            $this.Load($path)
        }
        elseif ($env:ENV) {
            $this.Load($this.FileForName($env:ENV))
        }
        else {
            $this.Pick()
        }

        $this.Name = $this.Current()
        $env:CMD_ENV_LOADED = '1'
    }

    [string] Current() {
        if ($env:ENV) { return $env:ENV }
        return 'shared'
    }

    [string] Get([string]$Key) {
        if ([string]::IsNullOrWhiteSpace($Key)) { return '' }
        $v = [Environment]::GetEnvironmentVariable($Key)
        if ([string]::IsNullOrWhiteSpace($v)) { return '' }
        return $v
    }

    [string] Require([string]$Key) {
        $v = $this.Get($Key)
        if ([string]::IsNullOrWhiteSpace($v)) { throw "[!] $Key is required" }
        return $v
    }

    [void] BindConfig([object]$Settings, [object]$Project) {
        $this.EnsureNetwork()
        if ($Settings -and $Settings.Loaded) {
            $Settings.ApplyEndpoints($env:NETWORK)
        }
    }

    [void] EnsureNetwork() {
        if ($env:NETWORK) {
            $n = "$($env:NETWORK)".ToLower()
            if ($n -notin @('cluster', 'public')) {
                throw "[!] NETWORK must be cluster or public (got $($env:NETWORK))"
            }
            $env:NETWORK = $n
            return
        }
        $this.PickNetwork()
    }

    [void] PickNetwork() {
        Write-Host ''
        Write-Host 'Network:'
        Write-Host '  1) cluster'
        Write-Host '  2) public'
        $choice = Read-Host 'Choose [1-2]'
        switch ($choice) {
            '1' { $env:NETWORK = 'cluster' }
            '2' { $env:NETWORK = 'public' }
            default { throw "[!] invalid network choice: $choice" }
        }
    }

    [hashtable] ParseFile([string]$File) {
        if (-not (Test-Path $File)) { throw "[!] missing env file: $File" }
        $data = @{}
        foreach ($line in Get-Content $File) {
            if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $Matches[1].Trim()
                $val = $Matches[2].Trim()
                if ($val -match '^"(.*)"$') { $val = $Matches[1] }
                elseif ($val -match "^'(.*)'$") { $val = $Matches[1] }
                $data[$key] = $val
            }
        }
        return $data
    }

    [hashtable] MergedData([object]$Settings, [object]$Project) {
        $data = @{}
        if (Test-Path '.env.shared') {
            foreach ($e in $this.ParseFile('.env.shared').GetEnumerator()) { $data[$e.Key] = $e.Value }
        }
        if ($this.LoadedFile -and (Test-Path $this.LoadedFile) -and $this.LoadedFile -ne '.env.shared') {
            foreach ($e in $this.ParseFile($this.LoadedFile).GetEnumerator()) { $data[$e.Key] = $e.Value }
        }
        if ($Settings -and $Settings.Loaded) {
            $network = if ($env:NETWORK) { $env:NETWORK } else { 'public' }
            foreach ($e in $Settings.EndpointEnvVars($network).GetEnumerator()) {
                $data[$e.Key] = $e.Value
            }
        }
        if ($env:NETWORK) { $data['NETWORK'] = $env:NETWORK }
        if ($env:DB_URL) { $data['DB_URL'] = $env:DB_URL }
        return $data
    }

    [void] Load([string]$File) {
        $data = $this.ParseFile($File)
        foreach ($key in $data.Keys) {
            Set-Item -Path "env:$key" -Value $data[$key]
        }
        $this.LoadedFile = $File
        $env:ENV_FILE = $File
    }

    [void] Pick() {
        $candidates = @(
            @{ Label = 'development'; Path = '.env.development' }
            @{ Label = 'test'; Path = '.env.test' }
            @{ Label = 'live'; Path = '.env.live' }
        ) | Where-Object { Test-Path $_.Path }

        if (-not $candidates) { throw '[!] no env files found (.env.development, .env.test, .env.live)' }

        Write-Host ''
        Write-Host 'Env file:'
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host "  $($i + 1)) $($candidates[$i].Label)  ← $($candidates[$i].Path)"
        }
        $choice = Read-Host "Choose [1-$($candidates.Count)]"
        if (-not $choice) { throw '[!] choice required' }
        $idx = 0
        if (-not [int]::TryParse($choice, [ref]$idx)) { throw "[!] invalid choice: $choice" }
        $idx = $idx - 1
        if ($idx -lt 0 -or $idx -ge $candidates.Count) { throw "[!] invalid choice: $choice" }
        $this.Load($candidates[$idx].Path)
        if (-not $env:ENV) { throw '[!] ENV is required in env file' }
        $this.Name = $env:ENV
        $this.EnsureNetwork()
    }

    hidden [void] LoadShared() {
        if (-not (Test-Path '.env.shared')) { return }
        $data = $this.ParseFile('.env.shared')
        foreach ($key in $data.Keys) {
            Set-Item -Path "env:$key" -Value $data[$key]
        }
    }

    hidden [string] FileForName([string]$Name) {
        switch ($Name.ToLower()) {
            'development' { return '.env.development' }
            'test' { return '.env.test' }
            'live' { return '.env.live' }
        }
        throw "[!] unknown ENV: $Name (expected development, test, live)"
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDsvnvt1Iz/oNJa
# sKpWv9q0MsAFLR6TwCZtdTZ0ShkV5qCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOjCpnR1
# I8r4xFK5NmreSWbYJVMtUqmnS/pxFjNWoIhqMAsGCSqGSIb3DQEBAQSCAgBUkZNI
# 2KBdIlcYMy2efSQdq+bzAgvfIZE+4hOjMoD0zeHGo6pXSyPj9gpLvdQZ2D4Eajjs
# gfPh9dOLtZCq2HGO7ALa/kTFG1kguJy056bhpkReQukLOSHYCMJx5BvdA9DM+fQu
# iBhK2xm2jBz9mkaGywrRVDaHTo9S1Fn1yeVwyd67m8ZmSftfglFm0c4WexANs9Qv
# V79M2j8QOfSUZze9tMEXeL4xFRMRtqz5KiOkHRUEeF5U0n3NN6H/dPbFEGHyYXrW
# CUtxWVZh7dCoBP+Mcechivy/jpIxuW79+XS8rUL//jmHQKzGfQEMEoS+EsuedRvu
# uVp7VXPx8pzI9SPX31XbwhC3x9aJ0Xy3emsJlngKpLBlROR8JeayKVDNX1t+4Bx+
# 4cd4hcqnDCu503xNwgTJVe5oQTdUbQIwiV5VJY2AaPb8W5gm7hUycLq049pKMCwM
# Cm2BNTmBdN/6rjJ7RR6D7M3SaIlwIMLdEHSW7Xgw87ud69d2EXHBUB6OOXHg3f6j
# 5LGJDMiUqR+7Lr1hQUZ8LiafnVrjUSrITAcLgnPKA7iRT10KH75U/5Qo92BJgpMG
# AuqREZyBbkneUnX77FbcxbBZDKqnJubuVkQVtUchFc3XQu0jaQlyQFURDUFJ13IM
# R+Vnd9Z2+isfSrhaxPDZXJZkUuCcM4Cw9i+lh6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
