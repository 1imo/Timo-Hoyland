class PostgreSql {
    [string]$DbUrl

    PostgreSql() {
        if (-not $env:DB_URL_PUBLIC) { throw '[!] DB_URL_PUBLIC is required' }
        $this.DbUrl = $env:DB_URL_PUBLIC
    }

    hidden [string] DbNameFromUrl([string]$Url) {
        if ($Url -match 'postgresql://[^/]+/([^?]+)') { return $Matches[1] }
        throw '[!] cannot parse database name from DB_URL_PUBLIC'
    }

    hidden [string] AdminUrl([string]$Url) {
        $db = $this.DbNameFromUrl($Url)
        return $Url -replace "/$([regex]::Escape($db)).*$", '/postgres'
    }

    hidden [bool] Exists([string]$DbUrl, [string]$DbName) {
        $out = & psql $DbUrl -tAc "SELECT 1 FROM pg_database WHERE datname='$DbName'" 2>$null
        return ($out -match '1')
    }

    [void] EnsureDatabase() {
        $db = $this.DbNameFromUrl($this.DbUrl)
        $admin = $this.AdminUrl($this.DbUrl)
        if ($this.Exists($admin, $db)) {
            Write-Host "[=] database $db exists"
            return
        }
        Write-Host "[+] creating database $db"
        & psql $admin -v ON_ERROR_STOP=1 -c "CREATE DATABASE `"$db`";"
        if ($LASTEXITCODE -ne 0) { throw "[!] CREATE DATABASE failed: $db" }
    }

    [void] ExecFile([string]$SqlFile) {
        & psql $this.DbUrl -v ON_ERROR_STOP=1 -f $SqlFile
        if ($LASTEXITCODE -ne 0) { throw "[!] psql failed: $SqlFile" }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBSC3CavDooztTD
# Eh5H1yI8GOmZJTrew4oRjjx59e9AGaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIDuVscn8
# IpFxctCoXSCMA2y6oaPJ1dKAJfCFnnO46zIOMAsGCSqGSIb3DQEBAQSCAgA0II99
# GTGo3g5SnCT6oVa1uKkb8hNPWKAC/udfUeEPrrTc3TL0p5nGjZ2RcazbTb4Fur+4
# L9F+WIhmvqjFFFE+a2vwMNSWp+fhAXslIggTtTo66LEhPL6J72TzRC7W5cuMdZYX
# GUjwX2qd7y1f9YOlz0ApMneH7ADlEaPF1vqyNtjOXvnKzLV1/i/OQJX1iF1AZ0js
# jSeGG2G0kJ/m2wn/kzrbuqdCPd2xKq4BAik2LgcT5W+SWWTzSKvn3Q0p5eVXrFAL
# htbpcWnUKrn4fEaLPMC0T6Ay1cbolb/KStq7zNuHElamZM/51lcd7sz+k6Q/pO6K
# wXoFMhUfdnDLBpzpTuyviKWe5dyc1b8AwQtGNpZQoU0KVT09jFLrfJjLSGEB+u0A
# DdlicKWiwlWmAWh4YNQEshXxtBlr3YtCglK6/ZtCoyA29HjAsVd7AJHnmushvYxJ
# psGIwXTgnDPXtYEf0KVK6RUYnU2IHelXQsR72LpoEmY7OWVnHQhHf52bUFPd990c
# kYYzslrt9HypwLTg6uXTFSgpiquFe2cbZWgvppi8SMjUA0tj4sTf+GLUR1v3wwvF
# lU9kISTb+KQJNPsp3Yb4lmS28q0tAry0a+8v0Twlinb8vTt91CguNq7596TwBOxp
# r4XQ4zIOA5qgfoxwVJcnJ2p1Y+31xqSMv8Yg1aErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
