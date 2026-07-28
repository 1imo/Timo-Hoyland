class Elastic {
    hidden [string]$Url
    hidden [string]$UserPass
    hidden [string]$Env
    hidden [string]$Stream
    hidden [string]$Staging
    hidden [string]$ProjectName

    Elastic([string]$ProjectName, [string]$Env) {
        if (-not $env:ELASTIC_URL) { throw '[!] ELASTIC_URL is required' }
        if (-not $env:ELASTIC_USER) { throw '[!] ELASTIC_USER is required' }
        if (-not $env:ELASTIC_PASSWORD) { throw '[!] ELASTIC_PASSWORD is required' }
        $this.Url = $env:ELASTIC_URL
        $this.Env = $Env
        $this.UserPass = "$($env:ELASTIC_USER):$($env:ELASTIC_PASSWORD)"
        $this.ProjectName = $ProjectName
        $this.Staging = $Env
        $this.Stream = "$ProjectName-pipeline"
    }

    [void] Step([string]$Step, [string]$Status, [hashtable]$Extra = @{}) {
        $fields = [ordered]@{
            event                    = 'pipeline_step'
            'deployment.environment' = $this.Env
            pipeline                 = @{
                staging = $this.Staging
                step    = $Step
                status  = $Status
            }
            project                  = $this.ProjectName
        }
        foreach ($k in $Extra.Keys) { $fields[$k] = $Extra[$k] }
        $this.WriteDoc($this.Stream, $fields)
    }

    [void] Finding([string]$Scanner, [string]$Status, [int]$Count, [string]$ReportFile) {
        $fields = [ordered]@{
            event                    = 'pipeline_finding'
            'deployment.environment' = $this.Env
            scanner                  = $Scanner
            status                   = $Status
            finding_count            = $Count
            report                   = $ReportFile
            project                  = $this.ProjectName
            pipeline                 = @{ staging = $this.Staging }
        }
        $this.WriteDoc("$($this.ProjectName)-findings", $fields)
    }

    hidden [void] WriteDoc([string]$DataStream, [hashtable]$Fields) {
        $doc = [ordered]@{ '@timestamp' = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
        foreach ($k in $Fields.Keys) { $doc[$k] = $Fields[$k] }
        $headers = @{ 'Content-Type' = 'application/json' }
        $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($this.UserPass))
        $headers['Authorization'] = "Basic $b64"
        $body = ($doc | ConvertTo-Json -Depth 20 -Compress)
        Invoke-RestMethod -Method Post -Uri "$($this.Url)/$DataStream/_doc" -Headers $headers -Body $body | Out-Null
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCSf5WEUaJyRKaB
# mO/d6X0U+flFNTV61+gjSwsPhPSUA6CCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEA8YxCb
# Yrv38O1+jLugssPiUP//lsRc3S+5ueOZkDzYMAsGCSqGSIb3DQEBAQSCAgADizDT
# GwMuvr5r4AQohCxllBcCFT697dv0Dk79FocfhcbDG72hKbuv3pHE/8HNdpfE2s4A
# y9YV4NjkY2lrT6gmeQ1c3HcO/Oef8gLCMsT2LuZnJXX3GacMj4XLvP/F97Hd9dzB
# H/sQsJPUx463/+8+BgTAA/Xu1wcd2EBOE3Qkqk9dKJF/RG7Md4Jm6kiLLahRTG1l
# /ybpkrpA84holKhrg3lOb21eBI9HrT/opmJAFmRYRgoq6ttcFYt8FtUV0d4KX4X/
# pitivJZu7aKLwrF2yLiShOb0G9Z5LdR+OP8383hsCrd0kTpJrLE+NGO6W8jr47jZ
# TH9Td5b4Hcva64z53717S7CxChny/VR/L5P8W/uUlN39k/jrx5rqXM/EtJusRlOK
# IP3gQDRZd1XUszBkNHpFlMmQDHawKyIcpOkPKFlhallIDoQWG6CZGoTAa91J0mQ3
# /QrqG4+jF79t8F4ZnUshmPuqhp+iPEzzVduPImNjLqOEwB3uLPQfhhWXtr3Rwa1/
# oVa8mIOeUtE+ZUoVjbFZMpY/WlEvhtg0oVOKOc7aSeeIjTmQ1csfO1Q3zknyQDfJ
# z+PrkyM371v2oLKg9WhgWOplql6I4geuyrkP0Q7DaaF2IihCHGCWiBUt41rQj7wY
# vlWM+1XLUHLDt722oGGp7bRc6ybAn+BxC2G5NKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
