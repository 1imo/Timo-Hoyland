$script:CmdLibDir = $PSScriptRoot

class Env {
    [string]$LoadedFile
    [string]$Name

    Env() {
        $top = git rev-parse --show-toplevel 2>$null
        if ($top) { Set-Location (Resolve-Path $top).Path }
        else { Set-Location (Resolve-Path (Join-Path $script:CmdLibDir '../..')).Path }

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
        if (-not $env:ENV) { throw '[!] ENV is required in env file' }
        $this.Name = $env:ENV
    }

    hidden [string] FileForName([string]$Name) {
        switch ($Name.ToLower()) {
            'development' { return '.env.development' }
            'test' { return '.env.test' }
            'live' { return '.env.live' }
        }
        throw "[!] unknown ENV: $Name (expected development, test, live)"
    }

    [string] VaultStaging() {
        switch ($this.Name.ToLower()) {
            'live' { return 'live' }
            'test' { return 'test' }
        }
        throw "[!] apply-env only pushes test/live env files (selected ENV=$($this.Name))"
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
        $idx = [int]$choice - 1
        if ($idx -lt 0 -or $idx -ge $candidates.Count) { throw "[!] invalid choice: $choice" }
        $this.Load($candidates[$idx].Path)
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBQeJurAvV5p008
# 4S3cwmLY7p5EIjOqvSLhqLFgqkP1yqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJK+Yyj9
# gf75/I3E8cbcACQV7KotOsEqBAUwGLprDa+mMAsGCSqGSIb3DQEBAQSCAgArRC53
# iGuENjmQq8saDhUrhGg5GT9SAdLVKKnREsHdJWzZFtbi6TuFuRp9WrwHtwFX5n5v
# 3Pa7qFstiBHSOkjF+wdw5anx5Uh2GHfzLPDJQWmjqBOo3ZyTOLgLnyJrIOYJUBWi
# Fq9Zi7qKnrUGrQ68sn5E9VWCzVF2xkVGx918xADWZBnnT9e/HXbriYI6sOM1icEQ
# X9faVP72EP85os49yRbbMds6fT+IbYHSe/ZefuWKWFs/w4y2tdddala7K8MO8FGS
# 5lvkRszlBrPjTvWZl2Yk1aiWY9soGtY9s14ycolHNCkfjId/LZFTt7mFp8fQibhd
# rPqZldNm/U//Wj1cXShv7+oBkN1OFPWgnZS/0pyLJruYzBekCfdYatqU9OHkE+vs
# e1z6gbjzjp2qkhhM0PpurCe3I6Lb8EDOhAt2NkdpEzqhh0Lsm9LDKTZYeb4C39a3
# Kby6reHbnyBUBGY0P5B9IwVgTFeEJXL4cGUOi1wxOLI3at/rOJZrMC2Ib56bxqxR
# fcs7JxMsIbr8iY/GyfsYBcZCgx14+pa290K0/XgDWOl5vBCBKFvs1YW2jHbIiqiL
# C2AiVYxET/OIvWz+cTLnGYvNSW+8fAwMDe+OgfpsxeYoTtHqf6jvWtt429pV8f2K
# D5R/lEmF1xu1wBSZSEMvgXaUCGlY/KMEbQ3cW6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
