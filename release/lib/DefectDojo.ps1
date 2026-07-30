class DefectDojo {
    hidden [string]$Url
    hidden [string]$Token
    hidden [int]$EngagementId
    hidden [string]$ProjectName

    DefectDojo([string]$ProjectName) {
        if (-not $env:DEFECT_DOJO_URL) { throw '[!] DEFECT_DOJO_URL is required' }
        if (-not $env:DEFECT_DOJO_API_TOKEN) { throw '[!] DEFECT_DOJO_API_TOKEN is required' }
        if (-not $env:DEFECT_DOJO_ENGAGEMENT_ID) { throw '[!] DEFECT_DOJO_ENGAGEMENT_ID is required' }
        $this.Url = $env:DEFECT_DOJO_URL.TrimEnd('/')
        $this.Token = $env:DEFECT_DOJO_API_TOKEN
        $this.EngagementId = [int]$env:DEFECT_DOJO_ENGAGEMENT_ID
        $this.ProjectName = $ProjectName
    }

    [void] ImportScan([string]$Staging, [string]$ScanType, [string]$ReportFile, [string]$StepName) {
        if (-not (Test-Path $ReportFile)) { throw "[!] report missing: $ReportFile" }
        $title = "$($this.ProjectName)-$Staging-$StepName"
        $headers = @{
            Authorization = "Token $($this.Token)"
            Accept        = 'application/json'
        }
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
        $r = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Form $form
        if ($r.statistics) {
            Write-Host "[+] Defect Dojo: created=$($r.statistics.created) reactivated=$($r.statistics.reactivated)"
        }
    }
}
