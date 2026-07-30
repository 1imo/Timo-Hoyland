class OpenSearch {
    [string]$Url
    [Env]$Env
    [Config]$Project
    [string]$Stream
    hidden [hashtable]$AuthHeaders
    hidden [int]$TimeoutSec = 30

    OpenSearch([Env]$Env, [Config]$Project, [string]$Stream) {
        if (-not $Env) { throw '[!] OpenSearch requires Env' }
        if (-not $Project -or -not $Project.Loaded) { throw '[!] OpenSearch requires project.cfg' }
        if ([string]::IsNullOrWhiteSpace($Stream)) { throw '[!] stream required' }
        $this.Env = $Env
        $this.Project = $Project
        $this.Stream = $Stream
        $opensearchUrl = $this.Env.Get('OPENSEARCH_URL')
        if (-not [string]::IsNullOrWhiteSpace($opensearchUrl)) { $this.Url = $opensearchUrl.TrimEnd('/') }
        $this.AuthHeaders = $this.BuildAuthHeaders()
    }

    hidden [hashtable] BuildAuthHeaders() {
        $user = $this.Env.Get('OPENSEARCH_USER')
        $pass = $this.Env.Get('OPENSEARCH_PASSWORD')
        if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($pass)) {
            return @{}
        }
        $token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${pass}"))
        return @{ Authorization = "Basic $token" }
    }

    hidden [hashtable] Headers() {
        return $this.Headers(@{})
    }

    hidden [hashtable] Headers([hashtable]$Extra) {
        $h = @{}
        foreach ($k in $this.AuthHeaders.Keys) { $h[$k] = $this.AuthHeaders[$k] }
        if ($Extra) {
            foreach ($k in $Extra.Keys) { $h[$k] = $Extra[$k] }
        }
        return $h
    }

    [void] Ensure() {
        if (-not $this.Url) { throw '[!] OPENSEARCH_URL is required' }
        $template = @{
            index_patterns = @("$($this.Stream)*")
            data_stream    = @{}
            priority       = 10000
            template       = @{ mappings = @{ dynamic = $true } }
        } | ConvertTo-Json -Depth 10 -Compress

        Write-Host "== OpenSearch: $($this.Url) =="
        Write-Host "== index template ($($this.Stream)) =="
        Invoke-RestMethod -Method Put -Uri "$($this.Url)/_index_template/$($this.Stream)" `
            -Headers $this.Headers() -ContentType 'application/json' -Body $template -TimeoutSec $this.TimeoutSec | Out-Null

        Write-Host "== bootstrap document → $($this.Stream) =="
        $doc = (@{
                '@timestamp'             = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                event                    = 'import_bootstrap'
                'deployment.environment' = $this.Env.Name
            } | ConvertTo-Json -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/$($this.Stream)/_doc?refresh=wait_for" `
            -Headers $this.Headers() -ContentType 'application/json' -Body $doc -TimeoutSec $this.TimeoutSec | Out-Null

        Write-Host '== data stream =='
        Invoke-RestMethod -Method Get -Uri "$($this.Url)/_data_stream/$($this.Stream)" `
            -Headers $this.Headers() -TimeoutSec $this.TimeoutSec | Out-Null
    }

    [void] Step([string]$Script, [string]$Status) {
        $this.Step($Script, $Status, @{})
    }

    [void] Step([string]$Script, [string]$Status, [hashtable]$Extra) {
        if (-not $Extra) { $Extra = @{} }
        if (-not $this.Url) { return }
        $fields = [ordered]@{
            event                    = 'cmd_step'
            'deployment.environment' = $this.Env.Name
            cmd                      = @{
                script = $Script
                status = $Status
            }
            project                  = $this.Project.Name
        }
        foreach ($k in $Extra.Keys) { $fields[$k] = $Extra[$k] }
        $doc = [ordered]@{ '@timestamp' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
        foreach ($k in $fields.Keys) { $doc[$k] = $fields[$k] }
        $body = ($doc | ConvertTo-Json -Depth 20 -Compress)
        try {
            Invoke-RestMethod -Method Post -Uri "$($this.Url)/$($this.Stream)/_doc" `
                -Headers $this.Headers() -ContentType 'application/json' -Body $body -TimeoutSec $this.TimeoutSec | Out-Null
        }
        catch {
            Write-Host "[!] OpenSearch cmd log failed ($($this.Stream)): $($_.Exception.Message)"
        }
    }

    [void] ApplyAlertingMonitors() {
        if (-not $this.Url) { throw '[!] OPENSEARCH_URL is required' }
        if (-not (Test-Path 'alerts/opensearch.json')) { throw '[!] Missing alerts/opensearch.json' }
        Write-Host "== OpenSearch alerting monitors: $($this.Url) (ENV=$($this.Env.Name)) =="
        $raw = Get-Content 'alerts/opensearch.json' -Raw
        $raw = $raw -replace '__ENV__', $this.Env.Name -replace '__PROJECT__', $this.Project.Name
        $monitors = $raw | ConvertFrom-Json
        foreach ($monitor in @($monitors)) {
            $logicalId = [string]$monitor.id
            $name = [string]$monitor.name
            Write-Host "   → $logicalId ($name)"
            $bodyObj = $monitor | Select-Object * -ExcludeProperty id
            $body = $bodyObj | ConvertTo-Json -Depth 40 -Compress
            $existingId = $this.FindMonitorIdByName($name)
            if ($existingId) {
                Invoke-RestMethod -Method Put -Uri "$($this.Url)/_plugins/_alerting/monitors/$existingId" `
                    -Headers $this.Headers() -ContentType 'application/json' -Body $body -TimeoutSec $this.TimeoutSec | Out-Null
                Write-Host "[+] OpenSearch monitor updated: $logicalId ($existingId)"
            }
            else {
                $created = Invoke-RestMethod -Method Post -Uri "$($this.Url)/_plugins/_alerting/monitors" `
                    -Headers $this.Headers() -ContentType 'application/json' -Body $body -TimeoutSec $this.TimeoutSec
                $newId = [string]$created._id
                Write-Host "[+] OpenSearch monitor created: $logicalId ($newId)"
            }
        }
    }

    hidden [string] FindMonitorIdByName([string]$Name) {
        $search = (@{
                query = @{ match_phrase = @{ 'monitor.name' = $Name } }
                size  = 1
            } | ConvertTo-Json -Depth 10 -Compress)
        try {
            $r = Invoke-RestMethod -Method Post -Uri "$($this.Url)/_plugins/_alerting/monitors/_search" `
                -Headers $this.Headers() -ContentType 'application/json' -Body $search -TimeoutSec $this.TimeoutSec
        }
        catch {
            $msg = $_.Exception.Message
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $msg = $_.ErrorDetails.Message }
            if ($msg -match 'opendistro-alerting-config|alerting-config') {
                throw '[!] OpenSearch Alerting is not initialized (missing .opendistro-alerting-config). Enable/install the alerting plugin, then retry.'
            }
            throw
        }
        $hits = @()
        if ($r -and $r.hits -and $r.hits.hits) { $hits = @($r.hits.hits) }
        if ($hits.Count -eq 0) { return '' }
        return [string]$hits[0]._id
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD9Bzr5rgc5y2JK
# MyPn8D3ZIftlqvJQ6IGuEbcTYXkKbqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIORtz8Rz
# +eVl7bV5EfMH77Sd4gvZ4A+U95lLiaGFz25tMAsGCSqGSIb3DQEBAQSCAgAkzhZI
# dH9L6wqv53dTEo7XQgar1lYiRGtMHou7dxRagFgfVMj5DJEEaqF3K9yPE4/feCbX
# DA2moQN05TDUGi8ewRqRqJByMgJHjDjR0jRi5obvTf4rI8YpGwdmpWTSbUMpwCTe
# gD+d5x62nTs2n1frfylQ7aWxH59x+Pfnd82+z5p7tZUvHDBdqjflhL2YA+TkI847
# H3XGsYL9fyBqE4I171g3pIXLcMfEovpUVh7ymOOfB33fQQ28mFGdGOaQ1tEAVQSq
# kS8dUthWD6wncRxohqBG56MtmK5mvuSmyG00FK6/qG3Ij/XXxvkUf/TRR8kEFdgV
# 4FHoX6fU0+xDb7LJQ+2w19GR9I3d/7mITe/zsfuHNFvCPGJAgkM3jhZdecRlf0Gy
# HZ+EqUAf863gcphGnjj9PNh83heV6qrO3tNgPHCsk0jAj8iSarJcfL8rP4xG6iA4
# 9+aXP5coUj9jLxuJ0Bb2+7cAy1NHuEhpjeeSD6OhyBSKvxDvlAt+nn8eLgpsNTBf
# IOXGU8ZrCSVzwFKEACqcnzvBeEmrhJ/TR6zUNTgj6l2gwGRJFGLuVyyDPAo/QIMX
# MU/AMqrWE3UKIcr4XC4HQTAUH0dTxbDpapfzvSFE5SVY+x73qaJlFs+l+q7gDBsQ
# ey12oqIDXXFZj6asMNan7UAV8Wlq49VAVCg5YKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
