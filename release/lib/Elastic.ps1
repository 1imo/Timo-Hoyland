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
