class PostgreSql {
    [string]$DbUrl
    [Env]$Env

    PostgreSql([Env]$Env, [object]$Settings, [object]$Project) {
        if (-not $Env) { throw '[!] PostgreSql requires Env' }
        $this.Env = $Env
        $this.Apply($Settings, $Project)
        $this.DbUrl = $this.Env.Require('DB_URL')
    }

    [void] Apply([object]$Settings, [object]$Project) {
        if (-not $this.Env) { throw '[!] PostgreSql.Apply requires Env' }
        if (-not $Settings -or -not $Settings.Loaded) { return }
        $network = if ($env:NETWORK) { $env:NETWORK } else { 'public' }
        $endpoint = $Settings.Endpoint('DB', $network)
        $user = $this.Env.Get('DB_USER')
        $pass = $this.Env.Get('DB_PASSWORD')
        if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($pass)) { return }
        if (-not $Project -or [string]::IsNullOrWhiteSpace([string]$Project.Name)) {
            throw '[!] PostgreSql requires project name for database'
        }
        if ([string]::IsNullOrWhiteSpace($this.Env.Name) -or $this.Env.Name -eq 'shared') {
            throw '[!] PostgreSql requires ENV (development, test, or live)'
        }
        $dbName = "$($Project.Name)-$($this.Env.Name)"
        $env:DB_URL = $this.BuildUrl([string]$endpoint, $user, $pass, $dbName)
    }

    [string] BuildUrl([string]$Endpoint, [string]$User, [string]$Password, [string]$DbName) {
        if ($Endpoint -notmatch '^(postgresql://)([^/?]+)(.*)$') {
            throw "[!] invalid DB endpoint (expected postgresql://host[:port]): $Endpoint"
        }
        $scheme = $Matches[1]
        $hostPart = $Matches[2]
        $rest = $Matches[3]
        if ($rest -match '^/') {
            throw "[!] DB endpoint must be host-only (no database path): $Endpoint"
        }
        $u = [Uri]::EscapeDataString($User)
        $p = [Uri]::EscapeDataString($Password)
        $url = "${scheme}${u}:${p}@${hostPart}${rest}"
        if (-not [string]::IsNullOrWhiteSpace($DbName)) {
            $url = "$($url.TrimEnd('/'))/$DbName"
        }
        return $url
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

    hidden [string] DbNameFromUrl([string]$Url) {
        if ($Url -match 'postgresql://[^/]+/([^?]+)') { return $Matches[1] }
        throw '[!] cannot parse database name from DB_URL'
    }

    hidden [string] AdminUrl([string]$Url) {
        $db = $this.DbNameFromUrl($Url)
        return $Url -replace "/$([regex]::Escape($db)).*$", '/postgres'
    }

    hidden [bool] Exists([string]$DbUrl, [string]$DbName) {
        $out = & psql $DbUrl -tAc "SELECT 1 FROM pg_database WHERE datname='$DbName'" 2>$null
        return ($out -match '1')
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA/GxmFgdJEmunj
# WS5ppQAAfRS6sogmDT10OTsZ6th1wKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIBoPXl8p
# ItsmIAI2w9CCftG25tcOQ8pWyzytQ+Ef76cFMAsGCSqGSIb3DQEBAQSCAgBYCiUn
# oo2GZFMJmPCM+5y3JihlcFCk86ILMi0mLHiwmkpo7YlN+aifYIZcREf24RcgLQz/
# w6ZDtJiWE9Jr0UKkgoNSUIESBt84bK4fRgw6qS2NKcsk09us4mh7L96hCXEyyM9B
# CxMvg8NFQfTcFotgQ+i6h0K5hzFJVul4RZra9V4r/pbQtx75+OmLtzVj+IQtwk9q
# eRMLAnnsIqh8mwkoqQGF09O3Iu1B4gimPP5sVFeOvNYDpi0Ar0AxcNvxuQv9+/Wz
# umr2aFKv+WIzwoLphWH/xIZnUT24+sd+n96sUtAFNEO/RCXP9PhNY7lfFfxwnx7p
# 7H7Jul8qpa3xSFZlDJhRD9VGTQpqYG4xj9wwGQp2cx82ceC+Pmw6dkKH/zBC4H11
# zodBW9Ga+O2Rda+e1x6AWlGRwykXFFuPlOpSaVlnowis+RsEuGkkyK86AXuFtlCt
# Ybjwd/5tS8FuodbF9kMOVxOvo1I6CRS7DeoPqwXmV+6EjfF5Koo+MI44RD744qRA
# ZCdFZ0VKZxVHoP2cgXQbLm04cyIXujRtU5ba2Ua1WDxWr4X7kARFkI7K6pw8SKZS
# XfDh6IYYkZek+H/APwbILsMcxYu6LgII4thUg0bnuXIz5hi0OC8OUkSjModLWxN6
# zKUrKoq3z7yXd4XY4oioCeCh4AjsiDr6WzA1X6ErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
