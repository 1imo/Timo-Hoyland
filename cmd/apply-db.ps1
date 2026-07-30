#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/lib/Env.ps1"
. "$PSScriptRoot/lib/Config.ps1"
. "$PSScriptRoot/lib/OpenSearch.ps1"
. "$PSScriptRoot/lib/PostgreSql.ps1"

$Env = [Env]::new()
$Project = [Config]::new('project.cfg')
$os = $null
try {
    $Settings = [Config]::new('settings.cfg')
    $Env.BindConfig($Settings, $Project)
    $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd")
    $os.Step('apply-db', 'started')
    if (-not (Test-Path 'assets/db.sql')) { throw '[!] Missing assets/db.sql' }
    if (-not (Get-Command psql -ErrorAction SilentlyContinue)) { throw '[!] psql required' }

    $pg = [PostgreSql]::new($Env, $Settings, $Project)
    $pg.EnsureDatabase()
    Write-Host '[+] Applying schema → assets/db.sql'
    $pg.ExecFile('assets/db.sql')
    Write-Host '[+] Done — db schema'
    $os.Step('apply-db', 'succeeded')
}
catch {
    if ($_.Exception.Message -like '*UNSIGNED_SETTINGS_CFG*') {
        if (-not $os) { $os = [OpenSearch]::new($Env, $Project, "$($Project.Name)-cmd") }
        if (-not $os.Url) { $os.Url = $Project.PinnedOpenSearchPublicUrl.TrimEnd('/') }
        $os.Step('apply-db', 'failed', @{ event = 'unsigned_settings_cfg'; error = $_.Exception.Message })
    }
    elseif ($os) {
        $os.Step('apply-db', 'failed', @{ error = $_.Exception.Message })
    }
    throw
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDPVUgQUECZMS+z
# G0nr3trUJfAsDHQruBYE0CvEk4lJh6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIO+A3a2G
# CrlgJjSzVvDLdfsb/RuvR2H/Q1+qVguz0xruMAsGCSqGSIb3DQEBAQSCAgCJqkDO
# qaMUC9of8ICWxXznKRqU2b/3qsj+GfaRg6clfUZTyG9h1BKIl3N/ln33/dqqgLlW
# tNIJdyKgeVzOUzKwgLYmTJyQIz3Kn2jLqfCZxduF0to2YGLqlzOSUVGEgSB6Wx3h
# K0J/o3uEi1hCqIUyquZcQVXFAgNsbPWKaz2Ed/no6vRG4FVizKuyGt6KU3JVFiFf
# kluB8r+sbxrIzTcd14Hvrg8jTv5a2Tz7TSQKUng6KlqanVrlazz8/uZokJXFc7+w
# eCR8lb61im9W7E16K5M9U2d0s6DPVUHhGYO8yFia4wL6xaOIu+jcArbOb2hy1SeP
# 0EiulQqkUNFFwqXm1wfj39umTfV1PcgGUxSwrf2YqsyTOtPz+UQCL2VZYpP6CsgW
# vJDX9E5NhTVn+6cUVixSSAn5t4eZAed5qcJcNvvgHlKN6kBjghrsenvQPyA2iJsp
# aaQJX0GFqeDkTEe/jPyyQiwU20FIuh16HxOR+SaYASKT6+M0l8FODVAhd+3JGrmC
# jQgay1knVHZGjW9JnXe650bGeBaHmUDmS9mnmXn9X381No6+BHF9qI8FGbHCTMab
# asoaYTBOyQkVQE5LKvmC5cGFfbXpECAOTqfmEh8Tj8L1pRdQlo0HdAE7kdzMk4Bf
# r63dF/DvA3cb8R+RyVnQxNReZyNFFSs9d7wr7qErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
