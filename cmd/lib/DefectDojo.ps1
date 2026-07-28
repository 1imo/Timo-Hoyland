class DefectDojo {
    [string]$Url
    [string]$Token
    [string]$ProjectName
    [int]$EngagementId

    DefectDojo([string]$ProjectName) {
        if (-not $env:DEFECT_DOJO_URL_PUBLIC) { throw '[!] DEFECT_DOJO_URL_PUBLIC is required' }
        if (-not $env:DEFECT_DOJO_API_TOKEN) { throw '[!] DEFECT_DOJO_API_TOKEN is required' }
        $this.Url = $env:DEFECT_DOJO_URL_PUBLIC.TrimEnd('/')
        $this.Token = $env:DEFECT_DOJO_API_TOKEN
        $this.ProjectName = $ProjectName
        if ($env:DEFECT_DOJO_ENGAGEMENT_ID) {
            $this.EngagementId = [int]$env:DEFECT_DOJO_ENGAGEMENT_ID
        }
    }

    [int] EnsureEngagement() {
        if ($this.EngagementId) { return $this.EngagementId }
        $staging = $this.StagingFromEnv()
        $engagementName = "$($this.ProjectName)-$staging"
        $productId = $this.EnsureProduct()
        $existing = $this.FindEngagement($productId, $engagementName)
        if ($existing) {
            $this.EngagementId = [int]$existing.id
            Write-Host "[+] Defect Dojo engagement: $engagementName (id=$($this.EngagementId))"
            return $this.EngagementId
        }
        $created = $this.CreateEngagement($productId, $engagementName)
        $this.EngagementId = [int]$created.id
        Write-Host "[+] Defect Dojo engagement created: $engagementName (id=$($this.EngagementId))"
        return $this.EngagementId
    }

    [void] ImportScan([string]$Staging, [string]$ScanType, [string]$ReportFile, [string]$StepName) {
        if (-not $this.EngagementId) { throw '[!] DEFECT_DOJO_ENGAGEMENT_ID is required' }
        if (-not (Test-Path $ReportFile)) { throw "[!] report missing: $ReportFile" }
        $title = "$($this.ProjectName)-$Staging-$StepName"
        $form = @{
            scan_type        = $ScanType
            test_title       = $title
            engagement       = $this.EngagementId
            file             = Get-Item -LiteralPath $ReportFile
            active           = 'true'
            verified         = 'true'
            minimum_severity = 'Info'
        }
        $uri = "$($this.Url)/api/v2/reimport-scan/"
        Write-Host "[+] Defect Dojo import: $ScanType → $title"
        $r = Invoke-RestMethod -Method Post -Uri $uri -Headers $this.Headers() -Form $form
        if ($r.statistics) {
            Write-Host "[+] Defect Dojo: created=$($r.statistics.created) reactivated=$($r.statistics.reactivated)"
        }
    }

    hidden [hashtable] Headers() {
        return @{
            Authorization = "Token $($this.Token)"
            Accept        = 'application/json'
        }
    }

    hidden [string] StagingFromEnv() {
        switch ($env:ENV.ToLower()) {
            'live' { return 'live' }
            { $_ -in @('test', 'development') } { return 'test' }
            default { throw "[!] ENV must be development, test, or live (got $env:ENV)" }
        }
    }

    hidden [int] EnsureProduct() {
        $uri = "$($this.Url)/api/v2/products/?name=$([uri]::EscapeDataString($this.ProjectName))"
        $r = Invoke-RestMethod -Uri $uri -Headers $this.Headers()
        foreach ($p in $r.results) {
            if ($p.name -eq $this.ProjectName) {
                Write-Host "[+] Defect Dojo product: $($this.ProjectName) (id=$($p.id))"
                return [int]$p.id
            }
        }
        $body = (@{ name = $this.ProjectName; description = $this.ProjectName } | ConvertTo-Json -Compress)
        $created = Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v2/products/" `
            -Headers ($this.Headers() + @{ 'Content-Type' = 'application/json' }) -Body $body
        Write-Host "[+] Defect Dojo product created: $($this.ProjectName) (id=$($created.id))"
        return [int]$created.id
    }

    hidden [object] FindEngagement([int]$ProductId, [string]$Name) {
        $uri = "$($this.Url)/api/v2/engagements/?product=$ProductId&name=$([uri]::EscapeDataString($Name))"
        $r = Invoke-RestMethod -Uri $uri -Headers $this.Headers()
        foreach ($e in $r.results) {
            if ($e.name -eq $Name) { return $e }
        }
        return $null
    }

    hidden [object] CreateEngagement([int]$ProductId, [string]$Name) {
        $start = (Get-Date).ToString('yyyy-MM-dd')
        $end = (Get-Date).AddYears(1).ToString('yyyy-MM-dd')
        $body = (@{
            product      = $ProductId
            name         = $Name
            target_start = $start
            target_end   = $end
            status       = 'In Progress'
        } | ConvertTo-Json -Compress)
        return Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v2/engagements/" `
            -Headers ($this.Headers() + @{ 'Content-Type' = 'application/json' }) -Body $body
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDjWS4EDPw/r/AU
# 1jpSNd6b55flV4uqNz9FPBpKsD2RbaCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJXcjKcq
# N4NYeyEIIoWa0LonscEmt3qbhKdEX4qhD7JiMAsGCSqGSIb3DQEBAQSCAgApyyYN
# InaDsHcX5cVQcCyAq4HULOuy4j7BqkI3WE/d5OL2suEGEPH8lag5iS22W9xXrrZM
# p91Rp7638OlzSGfiYahUofnr1FR6Ypz4OW0OXFnQdyr884ylth7eKYEGNqqcjLNR
# xfIw+vGP2hgBawzxuUB/DtfUvUyWmG4Z2ib6oKl752aikylbZYhdGP7Ii6X81XA2
# Zso3SjpyntPzFNhkJ5sBq7RUghWMZY0QQAmw+CPy+19fVUMkF+WwXY94Yp+bI6mb
# ir1EDPn/dwzYERG9IybGYTUgk7CZJlIacXSAsM0MVIMQ627aEv1VcvpoIomFYG0I
# bdxYCy3M7hU3Ti2DgDNxmhKEx/iyA+lzYq9L5xbl9kv725m//T03bv9BMx+5rE/U
# hCbjaHxSbyUhcUuK4aPlJNWfxiXvqvP8arR6pxZo+xHgwowyfQhn3+pDr3PzJygX
# akfC1PbBVgWQZdSxKIKgXma078CtmQKdokcLEQU+QX8laRpeYAYM61O+wn0K+UEX
# L3ybP25TZcdIsmmQqsdbbpO/oI2eX3MdgmK5q460ND6fkKGJhTxbFCI28OlKTHXX
# LFdnrwIzmuwBZfy0iZs7wd9J8mCun/cT0UhteQOY1qd8FDLpbA6+iD5HvWKauXuK
# xSukIlZv9s8aTrL8Ub9uo5wBEpHsYhxbzFyR6aErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
