#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Tuf.ps1"
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
    $Settings = [Config]::new('settings.cfg', [Tuf]::new())
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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDAKVQsAtlH5OYN
# Wnm2LHFeObtf0QneBDLwPODNfuDVz6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIFFugjE3
# C27EwPB5fIKE3BKJmfGmsMi7ykE4nnbbG998MAsGCSqGSIb3DQEBAQSCAgBHDJgB
# YGgMRGeIFJNTi92NDboWQgnhiLvmhdTFeGkTizAli6BrKhwa79WFSy7wtdr6MBMO
# 6FgunKPhjYWg3Ti+FtKGpyjskYsOY2AqAyQlgkhef577jLkeANEdz9DH+JwSbNhq
# xDRlBAX1/C1wI06FJB78Tt6XUCChpfn8eb18HAwZ7Lcvhxw3/ZFd4iW54yB93hfB
# Io9ci/Tij+WAUJaFJILfQC3Ic4Onnb9NOvWX65alAlkuF+f44BF/G53H13KRsDtA
# qENs58mLYmPXjcZ7oAxHesAZ6oAexkGoAMlk6iwxGWSzU5TpYSWfT8gxUoAxnS24
# mElIKo5w1ZNT3xiAwUyc8MOAnLBTygVzmi9UD3uaWvkcEUpezESI/p8pM+Gt019A
# 0k1j7qsLoQl1FnuZOPnH/EUoq7tkVXoZkSV/iVNgh8Po3mWWgIhxDm377mKkmgQg
# q2SHP4qzP2ya1b4NtpqwScwmn5tOJDUw+ij0GSBWwK4ZvKKrzYm12c1Sqjj5zTBu
# t84vTV7+I5p3Kul9ChNAXtAfgHHy1vq2Pza9FtiwU8j69r8BGYHOAaxX+lOjRUHN
# AKnJ2xfuigzRcC8ptpzCEMoXWId6RbrlKXqknK2MmZ+qi0nAvPEC3wn2Uh19T7X0
# w/wAroRnwxJx0MI72HMlrVqxlQmr+gNdzm0oCqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
