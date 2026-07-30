class Google {
    hidden [hashtable]$TokenCache = @{}
    hidden [string[]]$UserScopes = @(
        'https://www.googleapis.com/auth/analytics.edit'
        'https://www.googleapis.com/auth/siteverification'
        'https://www.googleapis.com/auth/webmasters'
    )

    [Env]$Env
    [Config]$Settings

    Google([Env]$Env, [Config]$Settings) {
        if (-not $Env) { throw '[!] Google requires Env' }
        if (-not $Settings -or -not $Settings.Loaded) { throw '[!] Google requires settings.cfg' }
        $this.Env = $Env
        $this.Settings = $Settings
    }

    [hashtable] AuthHeaders() {
        $token = $this.UserAccessToken($this.UserScopes)
        return @{
            Authorization  = "Bearer $token"
            'Content-Type' = 'application/json'
            Accept         = 'application/json'
        }
    }

    [string] UserAccessToken([string[]]$Scopes) {
        $key = ($Scopes | Sort-Object) -join ' '
        $cached = $this.TokenCache[$key]
        if ($cached -and [datetime]$cached.Expires -gt (Get-Date).AddMinutes(2)) {
            return [string]$cached.Token
        }

        $clientId = $this.Env.Require('GOOGLE_OAUTH_CLIENT_ID')
        $clientSecret = $this.Env.Require('GOOGLE_OAUTH_CLIENT_SECRET')
        $redirect = $this.Settings.Require('GOOGLE.OAUTH_REDIRECT_URL').TrimEnd('/')

        $listenPrefix = $redirect.TrimEnd('/') + '/'
        $listener = [System.Net.HttpListener]::new()
        $listener.Prefixes.Add($listenPrefix)
        try {
            $listener.Start()
        }
        catch {
            throw "[!] cannot bind OAuth callback $listenPrefix — $($_.Exception.Message)"
        }

        $state = [guid]::NewGuid().ToString('N')
        $authUrl = 'https://accounts.google.com/o/oauth2/v2/auth?' + (@(
                "client_id=$([uri]::EscapeDataString($clientId))"
                "redirect_uri=$([uri]::EscapeDataString($redirect))"
                'response_type=code'
                "scope=$([uri]::EscapeDataString($key))"
                "state=$state"
                'access_type=online'
                'prompt=select_account'
            ) -join '&')

        Write-Host "[+] Google user OAuth — opening browser (callback $redirect)"
        if (Get-Command open -ErrorAction SilentlyContinue) { & open $authUrl }
        else { Write-Host "[!] Open: $authUrl" }

        $code = $null
        try {
            $ctx = $listener.GetContext()
            $req = $ctx.Request
            $res = $ctx.Response
            $qsState = [string]$req.QueryString['state']
            $qsCode = [string]$req.QueryString['code']
            $qsErr = [string]$req.QueryString['error']
            $html = '<html><body><h2>Google auth complete — return to the terminal.</h2></body></html>'
            $bytes = [Text.Encoding]::UTF8.GetBytes($html)
            $res.ContentType = 'text/html; charset=utf-8'
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.OutputStream.Close()
            if ($qsErr) { throw "[!] Google OAuth error: $qsErr" }
            if ($qsState -ne $state) { throw '[!] Google OAuth state mismatch' }
            if (-not $qsCode) { throw '[!] Google OAuth missing code' }
            $code = $qsCode
        }
        finally {
            $listener.Stop()
            $listener.Close()
        }

        $token = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -ContentType 'application/x-www-form-urlencoded' -Body @{
            code          = $code
            client_id     = $clientId
            client_secret = $clientSecret
            redirect_uri  = $redirect
            grant_type    = 'authorization_code'
        }
        if (-not $token.access_token) { throw '[!] Google user OAuth token exchange failed' }

        $this.TokenCache[$key] = @{
            Token   = $token.access_token
            Expires = (Get-Date).AddSeconds([int]$token.expires_in)
        }
        Write-Host '[+] Google user OAuth OK'
        return [string]$token.access_token
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCARgZLMyDQhQyWa
# C4typQIuV7xw8A+Q0cgxY1BDFmFA86CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIMmMOwpq
# /vXB6LuehrwCVDzVARvRr8a52DF2lDeMmHpUMAsGCSqGSIb3DQEBAQSCAgCN9H5p
# VVMJJKsQgch2V+b39az37dBAgZnAXy7AQ915jq34wsOanGqFg56tMBvzNtQWr6m6
# 3weSb9cBDkZWjzEfCOAmxFGkJoRYHQqJejLZYa0BS0h/nrjU3dp81SjVY/PQbir1
# o4pr/wnRmeHSN/yAeW7yTHbvbLBhYELdxhOah+9WokMtsfDEHj3wB7l3P3eQh7Ao
# CjHRR7fncFhMLkDcNHcZXutwC5ASrUxd+zxtSXchsw1jP/xBKW8kiDgNiT/NO5SQ
# DX+nrtL3g3NLXrb+sjDciaYVwrnKhfXsWLan93kdh/r7FX4PsU/rtqWrpRFPHxS+
# MOBhqmncXv4My1yBpt7Mwb/YeBvfhVe/0A1Bm6IloFeRDqc5yB2eeo1xtFyKkKi3
# 6c1IExL0BJ4XIYd6A97TuisAST4JXRELrxNTl0IUAQWZpLuhuBcuWwUphKwZa5mm
# DHISFXbvJDU/jmF3+siNXMfmYiBIzuWmCl2CUsfhf0qO+6p9FhmpIxaW+Gsa/lWd
# 0dlLlHX33+kZVWrrKdHLfdqz3yr0P6XCcJqHvXlkw8fJRxNbrWtP8Qprejdzw/jd
# WqLGR5qujnvepXo4glBLIMwh586tWDfvt6A12LZ5hyMnEgfa4mlycxpOLWhnUrVp
# 8zn4mcRWH97AvryilspVM3rUpwZzGvxfb4H5gqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
