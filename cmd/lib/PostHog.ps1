class PostHog {
    [string]$BaseUrl
    [string]$Token
    [string]$ProjectId
    [string]$Env
    [string]$ProjectName
    [bool]$ResolvedProjectId

    PostHog([string]$ProjectName) {
        if (-not $env:POSTHOG_URL) { throw '[!] POSTHOG_URL is required' }
        if (-not $env:POSTHOG_API_KEY) { throw '[!] POSTHOG_API_KEY is required' }
        if (-not $env:ENV) { throw '[!] ENV is required' }
        $this.BaseUrl = $env:POSTHOG_URL.TrimEnd('/')
        $this.Token = $env:POSTHOG_API_KEY
        $this.Env = $env:ENV
        $this.ProjectName = $ProjectName
        $this.ResolvedProjectId = $false
        if ($env:POSTHOG_PROJECT_ID) {
            $this.ProjectId = $env:POSTHOG_PROJECT_ID
        }
        else {
            $this.ProjectId = $this.FindOrCreateProject()
            $this.ResolvedProjectId = $true
        }
    }

    hidden [string] FindOrCreateProject() {
        $headers = @{ Authorization = "Bearer $($this.Token)"; 'Content-Type' = 'application/json' }
        $r = Invoke-RestMethod -Uri "$($this.BaseUrl)/api/projects/" -Headers $headers
        foreach ($p in $r.results) {
            if ($p.name -eq $this.ProjectName) {
                Write-Host "[+] PostHog project: $($this.ProjectName) (id=$($p.id))"
                return [string]$p.id
            }
        }
        $body = (@{ name = $this.ProjectName } | ConvertTo-Json -Compress)
        $created = Invoke-RestMethod -Method Post -Uri "$($this.BaseUrl)/api/projects/" -Headers $headers -Body $body
        Write-Host "[+] PostHog project created: $($this.ProjectName) (id=$($created.id))"
        return [string]$created.id
    }

    hidden [object] FindDashboard([string]$Name) {
        $headers = @{ Authorization = "Bearer $($this.Token)"; 'Content-Type' = 'application/json' }
        $uri = "$($this.BaseUrl)/api/projects/$($this.ProjectId)/dashboards/?search=$([uri]::EscapeDataString($Name))"
        $r = Invoke-RestMethod -Uri $uri -Headers $headers
        foreach ($d in $r.results) {
            if ($d.name -eq $Name) { return $d }
        }
        return $null
    }

    [void] ImportDashboard([string]$File, [string]$Slug) {
        $name = "$($this.ProjectName) / $Slug"
        Write-Host "== PostHog import: $($this.BaseUrl) =="
        Write-Host "    $name ← $File"
        $template = Get-Content $File -Raw | ConvertFrom-Json
        if ($template.name) { $template.name = $name }
        else { $template | Add-Member -NotePropertyName name -NotePropertyValue $name -Force }
        $headers = @{ Authorization = "Bearer $($this.Token)"; 'Content-Type' = 'application/json' }
        $existing = $this.FindDashboard($name)
        if ($existing) {
            $uri = "$($this.BaseUrl)/api/projects/$($this.ProjectId)/dashboards/$($existing.id)/"
            Invoke-RestMethod -Method Patch -Uri $uri -Headers $headers -Body ($template | ConvertTo-Json -Depth 50 -Compress) | Out-Null
            Write-Host "[+] PostHog dashboard updated: $name"
            return
        }
        $uri = "$($this.BaseUrl)/api/projects/$($this.ProjectId)/dashboards/create_from_template_json/"
        Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body ($template | ConvertTo-Json -Depth 50 -Compress) | Out-Null
        Write-Host "[+] PostHog dashboard created: $name"
    }

    [void] ImportDir([string]$Dir) {
        if (-not (Test-Path $Dir)) { return }
        $files = Get-ChildItem $Dir -Filter '*.json' -File | Where-Object { $_.Length -gt 0 }
        if (-not $files) { Write-Host "[i] PostHog: no dashboards in $Dir"; return }
        foreach ($f in $files) {
            $slug = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            $this.ImportDashboard($f.FullName, $slug)
        }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBiWXOrENXQF74b
# fGQomIITOzv3Cy3PWpox1mJcLivIjKCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAuXjvgA
# bGlzBqRb7ap5ReCLn4TqbZ34HvWpi7tdS0o8MAsGCSqGSIb3DQEBAQSCAgAeWfai
# C1xHG5lCRHhobngr2gMXc9RmPuZ1ITN+3dA2l97oZIzaFuadi3Ts4/GERllUIfsg
# bujX4eSSHwcqxr5VY8WIvYPxoHinGRwer4yxgIwBjGXNq3sKKiuOLGKcmmDT4f8z
# JkKKZGQgADI6LxyogKOqdd9DTbveq6u5VWWjIVF84HMISaFghl7e7s3dSiUu2r2F
# dDABOOLVBBXERV9adlvLS7V9chQS1ChoEfae3dFxQ48kw/R82MEc1ah/4vclbJcI
# tEqH7ivR5jfkFbeArYO/s+TJqoOkNHqCgiKHMNQ1Q6nXYmX1DHOjiXopCCUojSBy
# DDJWD004os3anZGt9CVQX2gpQO6QIDCpZ5i8JO4+9VmvSh1j+hNslFDnZhY4Gqnj
# MOvIfscApe9yuB6+NTuEhTO5zLi8d5pwA0euQ15h824cK/51XdPSqk5Z4cG7negm
# zxdSsHtxImMFAqkjrSzxiNqxLTnhxJbnKrL50hURU+83n/3NfE+pKBX/zqq9BrIE
# WUiljtRUOtz2kH1iWkFelUWDfesPLTD69pDeDvI58OZljz30kulVyi80YfDzp1si
# 44B6kc6327SKH5kL6Tt9ggz5ZX73AO8VE2dRQQVePe8sEb+Rw2RnxMT31m2w+wwm
# zcMvv9cNrf0WNvLJtTW//dDqAHNJ9J3L0drcFaErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
