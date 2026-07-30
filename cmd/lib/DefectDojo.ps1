class DefectDojo {
    [string]$Url
    [string]$Token
    [int]$EngagementId
    [Config]$Project
    [Env]$Env

    DefectDojo([Config]$Project, [Env]$Env) {
        if (-not $Project -or -not $Project.Loaded) { throw '[!] DefectDojo requires project.cfg' }
        if (-not $Env) { throw '[!] DefectDojo requires Env' }
        $this.Project = $Project
        $this.Env = $Env
        $this.Url = $this.Env.Require('DEFECTDOJO_URL').TrimEnd('/')
        $this.Token = $this.Env.Require('DEFECT_DOJO_API_TOKEN')
        $engId = $this.Env.Get('DEFECT_DOJO_ENGAGEMENT_ID')
        if ($engId) { $this.EngagementId = [int]$engId }
    }

    [int] EnsureEngagement() {
        if ($this.EngagementId) { return $this.EngagementId }
        $staging = if ($this.Env.Name -eq 'live') { 'live' } else { 'test' }
        $engagementName = "$($this.Project.Name)-$staging"
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
        $title = "$($this.Project.Name)-$Staging-$StepName"
        $form = @{
            scan_type         = $ScanType
            test_title        = $title
            engagement        = $this.EngagementId
            file              = Get-Item -LiteralPath $ReportFile
            active            = 'true'
            verified          = 'true'
            minimum_severity  = 'Info'
        }
        Write-Host "[+] Defect Dojo import: $ScanType → $title"
        $r = Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v2/reimport-scan/" -Headers @{
            Authorization = "Token $($this.Token)"
            Accept        = 'application/json'
        } -Form $form
        if ($r.statistics) {
            Write-Host "[+] Defect Dojo: created=$($r.statistics.created) reactivated=$($r.statistics.reactivated)"
        }
    }

    hidden [int] EnsureProduct() {
        $headers = @{
            Authorization = "Token $($this.Token)"
            Accept        = 'application/json'
        }
        $name = $this.Project.Name
        $uri = "$($this.Url)/api/v2/products/?name=$([uri]::EscapeDataString($name))"
        $r = Invoke-RestMethod -Uri $uri -Headers $headers
        foreach ($p in $r.results) {
            if ($p.name -eq $name) {
                Write-Host "[+] Defect Dojo product: $name (id=$($p.id))"
                return [int]$p.id
            }
        }
        $body = (@{ name = $name; description = $name } | ConvertTo-Json -Compress)
        $created = Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v2/products/" `
            -Headers ($headers + @{ 'Content-Type' = 'application/json' }) -Body $body
        Write-Host "[+] Defect Dojo product created: $name (id=$($created.id))"
        return [int]$created.id
    }

    hidden [object] FindEngagement([int]$ProductId, [string]$Name) {
        $headers = @{
            Authorization = "Token $($this.Token)"
            Accept        = 'application/json'
        }
        $uri = "$($this.Url)/api/v2/engagements/?product=$ProductId&name=$([uri]::EscapeDataString($Name))"
        $r = Invoke-RestMethod -Uri $uri -Headers $headers
        foreach ($e in $r.results) {
            if ($e.name -eq $Name) { return $e }
        }
        return $null
    }

    hidden [object] CreateEngagement([int]$ProductId, [string]$Name) {
        $headers = @{
            Authorization  = "Token $($this.Token)"
            Accept         = 'application/json'
            'Content-Type' = 'application/json'
        }
        $start = (Get-Date).ToString('yyyy-MM-dd')
        $end = (Get-Date).AddYears(1).ToString('yyyy-MM-dd')
        $body = (@{
                product      = $ProductId
                name         = $Name
                target_start = $start
                target_end   = $end
                status       = 'In Progress'
            } | ConvertTo-Json -Compress)
        return Invoke-RestMethod -Method Post -Uri "$($this.Url)/api/v2/engagements/" -Headers $headers -Body $body
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAm5hiSJ7/+osbA
# kWP8hIOKzEfpkcyYIyVkc53IKhzl7KCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEkiJmwp
# dlos36Usn5fNAvHkG93s9CR8ZTO9yGzTcj67MAsGCSqGSIb3DQEBAQSCAgCDDlMz
# 44yCTkQ2xd5KMBsq5/aQ77KEeYtwrCNE7Wl9RgegzwWne19kQpkvy8Ra1tneszVB
# pL31s8j7qc9MKVZkbz2s8NyLUpiA2/dHsfL8XJthcieEM/3tZO5pArhCo+cPbxVN
# 5cd1XxpfYi5Rn3yEX5JUE04TlOGkayPGyUiC4y6XFC9rPn7v5PDm6yNfmxq2q6ja
# H+kmge5Woi+D7mhbwHHcRpWwFW43ZqdKNXS/LSeyC7u8wFkAeWCtrD2sEcFpNbnX
# +BXjFSTG7isBCQHY2gHfphrHZf0o5ReI7ZHx55FaCYus/B3q4nFs8ffYWOz3DFWC
# k96A7o1T4vR9ad4n2yXvsU2Ny9RPNpwevLfZ8chiRmBOEJwGH0uLgcPruN7uXN6H
# /IYfBu9C1RebkwS09DmdUWHE8/aoEZVxfHLvbnbjkXZnWttXJhQhKBA3XgDXSQj/
# M5iyl4gZEqdKskIyEgZPblAYnZ6En2x944e8mi0sBD4jKUjzzlImp1rXe8j1LMi7
# NLEzSyBZAvt3VIpJVdqqB4hPByN2eaF7tcWBZBjumNPC26syOm0SFwPpaNt+YGa6
# VP1SB79oaSQunxtB/k52TLIQueLZvv1fCyrNcGfY5CUxgDefRRzPPyt2p7Abcflv
# ioOeVrbgPdCoMVvDhCsDN2kFMyCt3pLO4mdbAKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
