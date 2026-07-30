#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Config.ps1"

$preserve = @('.git', 'src', '.env.development', '.env.test', '.env.live', 'project.cfg', 'settings.cfg', 'Caddyfile', 'compose.yml', 'assets/db.sql')

$added = [System.Collections.Generic.List[string]]::new()
$updated = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()
$overwritten = [System.Collections.Generic.List[string]]::new()
$unchanged = 0
$preserved = 0

function Merge {
    param([string]$Source, [string]$Dest, [string]$Root)

    if (-not (Test-Path -LiteralPath $Source)) { return }

    if (Test-Path -LiteralPath $Source -PathType Container) {
        if (-not (Test-Path -LiteralPath $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
        Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
            Merge $_.FullName (Join-Path $Dest $_.Name) $Root
        }
        return
    }

    $rel = ([IO.Path]::GetRelativePath($Root, $Dest)) -replace '\\', '/'
    if ($preserve -contains $rel) { $script:preserved++; return }

    if ((Test-Path -LiteralPath $Dest) -and (Get-FileHash -LiteralPath $Source).Hash -eq (Get-FileHash -LiteralPath $Dest).Hash) {
        $script:unchanged++
        return
    }

    if (-not (Test-Path -LiteralPath $Dest)) {
        $parent = Split-Path $Dest -Parent
        if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -LiteralPath $Source -Destination $Dest -Force
        $script:added.Add($rel)
        return
    }

    & git -C $Root rev-parse --verify "HEAD:$rel" 2>$null | Out-Null
    $matchesHead = $false
    if ($LASTEXITCODE -eq 0) {
        $headHash = (& git -C $Root rev-parse "HEAD:$rel").Trim()
        $localHash = (& git -C $Root hash-object $Dest).Trim()
        $matchesHead = $headHash -eq $localHash
    }

    if ($matchesHead) {
        Copy-Item -LiteralPath $Source -Destination $Dest -Force
        $script:updated.Add($rel)
        return
    }

    Write-Host "[!] drift: $rel — edited since last commit; source of truth unknown" -ForegroundColor Yellow
    if ((Read-Host '    Overwrite with boilerplate? [y/N]') -match '^[yY]$') {
        Copy-Item -LiteralPath $Source -Destination $Dest -Force
        $script:overwritten.Add($rel)
        return
    }

    Write-Host "    skipped $rel"
    $script:skipped.Add($rel)
}

$Root = (git rev-parse --show-toplevel 2>$null)
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location $Root

$git = [Config]::new('project.cfg').Require('remotes.boilerplate.url')
$stage = Join-Path ([IO.Path]::GetTempPath()) "boilerplate.$([guid]::NewGuid().ToString('N').Substring(0, 8))"
New-Item -ItemType Directory -Path $stage -Force | Out-Null
try {
    Write-Host "[+] Cloning $git"
    & git clone --depth 1 $git (Join-Path $stage 'repo')
    if ($LASTEXITCODE -ne 0) { throw '[!] git clone failed' }

    Write-Host '[+] Merging boilerplate'
    Get-ChildItem -LiteralPath (Join-Path $stage 'repo') -Force | ForEach-Object {
        if ($preserve -contains $_.Name) { return }
        Merge $_.FullName (Join-Path $Root $_.Name) $Root
    }

    Write-Host "[+] Done — added $($added.Count), updated $($updated.Count), unchanged $unchanged, overwritten $($overwritten.Count), skipped $($skipped.Count), preserved $preserved"
    if ($skipped.Count -gt 0) {
        Write-Host '[!] refresh incomplete — drifted files were skipped (re-run and choose Y to overwrite)' -ForegroundColor Yellow
        $skipped | ForEach-Object { Write-Host "    skipped $_" }
    }
    if ($added.Count -gt 0) {
        Write-Host '[+] added:'
        $added | ForEach-Object { Write-Host "    $_" }
    }
}
finally {
    Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAVKlr767uretdq
# qDLlW2z9KK1/nCwXr8874YS2QmUfsaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCGKvsh7+fkenES
# MU0kKyRtyvde0Nw79FcA1KLDZ3YPc6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIDXEviM6
# tZ5igXXahWUN27lH7djqwd1gVB9fWldNKud0MAsGCSqGSIb3DQEBAQSCAgA32kvl
# JDdHl0DSJxXl5IBu5VparBsap/0Y2gtDVcNMI1oQ5mOzSuUU0Y8zOUYKpmBDhFGS
# R5bmrb3/m/I8aja1YK721i0XATJ8CIlSvVHQmeEJRusNJ2QP28xG8ubRP9nKgGc7
# SM+BNj4HybK+kZ69vnoC3hrh5k+nTzJBhW/uvkbSCjz7FX3CEes8jVi06mMkUj/j
# vpAR5TrjE4R8nw/Mm/BS9rNntAzs+9f7k65icUChodzDgBTzZoyCCdfv1VodjmXz
# oTwdKjkpfiAWskUDa1TwfqOMoCWzsvCVq2B8PFa9ksHd8JOchg+YlX+rSn+865aB
# FpQ6LAOisCOVPXlW1IoBNKt1xzbc3JN/olHWI92dGK1mq1kuD3GYAAZSvZFTB+3t
# mitqOk+IFK8CP0sWtyuhQ4xpSQKJpqn4AJAvYAk1WRpxxLJKLzKswEzum1ebR9Vr
# TnO/IaKUC7/ST0O8tTMgxnElH7esotXXhgje9wCbRp+QvHiHEnTvwEG+0HMolBoX
# TV7NIp8psO5+gaurP8Z3xOsRX5fbmX0xTGsx8ONvO7PW/rk1j+WK0v15FdTVE6X0
# d18e6jx+MRmQjxY5VLGsu+cT9/lAM1KT8rrYAUFC/myY5q7b3drKuYGE+QK2pX7U
# zWI1T2Byq5oqkv16auGXklzotrYB0wAWXEesM6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINe5o8Mm
# hHSTr748IZfgxRzmHaD07tLxF5MzPTbJ1PLtMAsGCSqGSIb3DQEBAQSCAgAR69ai
# 4YMU+Jk/We9irj+1zA2RP9oWl2jBZuRHrxs4NdjPwRt4ph7WgS34azYj/Fe7iWzq
# C9FACfW4+hmyhh1xuElt47F5XpTVQbSHNW92Uk4aM9u47NMZY0fHlTwiZTJCyrGf
# KQVfn1yqYXhM4/d7aocJr7rtsg4R4y8Ste4Xfs6w3WXgtbnw87VahsLIsBHKa2fa
# 3Qjfu721y+nhJd7khcOYP+KM807CY9D2KGRJCIxdQXgIVVYeGA6BpJAK/nydvWbr
# FEex2xj+DuhHDJr08KhoRutoRhD+6lZB+eoiKEYk9wdrLsaFO8yOEWZ2qhLLXj6d
# yhA4fjXtrNjgUQsiFjsTdTNmAZN77jW0AtUYwzCxss3s3KtADVqtvfpnKr86gF6T
# /KHpjKZ8nvGv49wM80JDahDwUzVqbzoCO6P3jtjYy6AP5yRn+Ko8tYH32pbVwtGk
# bpnUJjBcxDtT3suxMfTTFSv+0GDjW5itDx9veIkeYE1hswDYZlIINR+VvXnqglfF
# lLQv+NA/sOnI/Jm0f4mo6S/Y/VYEWGGMb51fvzQbuHZsfQGTGYawgunZTd+yY51v
# UzMjXohYsAKuLRiII4C1yg+QMA0XvmJh4KyMzAkOERlydW5kG4g5LlK5DDw35Fcr
# +JP71/kBA9dTQnLjtnGnzKT3FumJm+6JGZQYIKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
