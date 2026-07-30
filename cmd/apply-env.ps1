#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/PostgreSql.ps1"
. "$PSScriptRoot/lib/Vault.ps1"
. "$PSScriptRoot/lib/GitHub.ps1"
. "$PSScriptRoot/lib/GitLab.ps1"
. "$PSScriptRoot/lib/SourceControl.ps1"

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg')
    $Env.BindConfig($Settings, $Project)
    [PostgreSql]::new($Env, $Settings, $Project) | Out-Null
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd")
    $os.Step('apply-env', 'started')

    $vault = [Vault]::new($Env)
    $vault.Health()

    $staging = $vault.Staging()
    $secret = "$staging-$($Project.Name)"
    $configSecret = "$staging-$($Project.Name)-config"
    $data = $Env.MergedData($Settings, $Project)
    $diffSecret = $vault.Compare($secret, $data)

    $diffConfig = $vault.Compare($configSecret, $Settings.Data)

    $ciVars = @{
        VAULT_URL           = $data['VAULT_URL']
        VAULT_TOKEN         = $data['VAULT_TOKEN']
        VAULT_SECRET_PREFIX = $staging
    }
    if (-not $ciVars.VAULT_URL) { throw '[!] VAULT_URL missing in env file' }
    if (-not $ciVars.VAULT_TOKEN) { throw '[!] VAULT_TOKEN missing in env file' }

    $remoteUrl = $Project.Require("remotes.$staging.url")
    $ciLabel = if ($Env.Name -eq 'live') { "GitHub $remoteUrl" } else { "GitLab $remoteUrl" }

    Write-Host ''
    Write-Host "Vault @ $($vault.Addr)"
    Write-Host "Project: $($Project.Name)"
    Write-Host "[i] $staging : secret/$secret"
    Write-Host "    source: .env.shared + $($Env.LoadedFile)"
    Write-Host "    added=$($diffSecret.Added) changed=$($diffSecret.Changed) unchanged=$($diffSecret.Unchanged) removed=$($diffSecret.Removed)"
    if ($Settings.Loaded) {
        Write-Host "[i] config : secret/$configSecret"
        Write-Host '    source: settings.cfg'
        Write-Host "    keys=$($Settings.Data.Count) added=$($diffConfig.Added) changed=$($diffConfig.Changed) unchanged=$($diffConfig.Unchanged) removed=$($diffConfig.Removed)"
    }
    else {
        Write-Host "[i] config : skipped (no settings.cfg)"
    }
    Write-Host "[i] CI → $ciLabel"
    foreach ($key in $ciVars.Keys) {
        Write-Host "    $key=$($ciVars[$key])"
    }

    if ((Read-Host 'Apply? [y/N]') -notmatch '^[yY]$') {
        Write-Host '[=] skipped'
        $os.Step('apply-env', 'skipped')
        return
    }

    $vault.WriteSecret($secret, $data)
    Write-Host "[+] secret/$secret updated"

    if ($Settings.Loaded) {
        $vault.WriteSecret($configSecret, $Settings.Data)
        Write-Host "[+] secret/$configSecret updated ($($Settings.Data.Count) keys)"
    }

    $ci = [SourceControl]::new($Env, $Settings, $remoteUrl, [GitHub]::new(), [GitLab]::new($Env))
    $ci.SetCiVars($ciVars)

    Write-Host '[+] Done'
    $os.Step('apply-env', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd") }
        if (-not $os.Url) { $os.Url = $Project.PinnedOpenSearchPublicUrl.TrimEnd('/') }
        $os.Step('apply-env', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-env', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAZD3Xl2Z7AAuDD
# y+39bRDkj/ZL9Q/Zdtfe3EWwscyHBKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIFKPDM2P
# LQf3t4oIMq52wOhk3HMPKjTRS93Rd3p3u/HKMAsGCSqGSIb3DQEBAQSCAgBmahag
# AzS5LXFOUcGrrGTzpjF7TlHq8K0wjaROeR6nUbDDgxiOIgMDHI5/Nobgnew4Qrxf
# xp1PLPzkAjNmvNsmglxDkGH9KgRGPfcF+weXuy2VEBejpUZa60CYeTSJlKWbWe8S
# hFlQm6ROtJvYi/3WFhW5EmEQ3ABv6dK3BneI5uqK1yNBD19QwiEyT+tBKkqvynRc
# Aw5IvbcWzGGKseFjBaHbB6v+O5on9GeQ3udgfSxzMpjqsk/TxzuD69zckCpkGPf0
# o0AVwrLdPcYFUTwJdJEYdUEx/XIgbXIKmfMlvV+Bn3vUKls8rx1DMxvcf7jPM4Mw
# SwjDIlwzqsUno+v1r2cGgt0jFlaINgxFwmO0a89ha/5oiuy+JxGVxN1oP44CynD4
# 9OeJM8+SN45xfU9fEmhRumd3FyGpeQTeL5lHqCwz+0Z2cOINwxwxMHR1pOojXWHY
# p1EZtjSjypNE49XA/4FKVuQn+Prxmf+gVl+ohGNeuWyi+4msDGXbeMhpvkxrz72X
# WNmwDdzP5SHL5ByClsm1G+UxsX4o5utCr7wiwkQUG4RzWFlcdLYhOsg66bH+Cmxk
# FS9yVG6aF8G0uyNqlAAeZMK+DH+akPcAxMglj/LmOIrhLXrKmEEl+8+QL4GayKZy
# LR4USGX3VpnXP18ovrjFvV+ojMiOgWoYpKpC2aErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
