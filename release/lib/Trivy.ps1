class Trivy {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$Image
    hidden [string]$ScanDir
    hidden [string]$CacheDir

    Trivy([string]$Image) {
        $this.Image = $Image
        $dirPath = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if ($env:ARTIFACT_DIR) {
            $dirPath = (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
        }
        $this.ScanDir = $dirPath
        $this.CacheDir = Join-Path ([System.IO.Path]::GetTempPath()) 'trivy-cache'
        foreach ($dir in @($this.ScanDir, $this.CacheDir)) {
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        }
        $this.ReportFile = Join-Path $this.ScanDir 'trivy.json'
    }

    [string] ScanImage() {
        & docker run --rm `
            -v '/var/run/docker.sock:/var/run/docker.sock' `
            -v "$($this.CacheDir):/root/.cache/trivy" `
            -v "$($this.ScanDir):$($this.ScanDir)" `
            aquasec/trivy:0.58.1 image `
            --scanners vuln `
            --severity HIGH,CRITICAL `
            --format json `
            --output $this.ReportFile `
            --exit-code 1 `
            $this.Image
        $exit = $LASTEXITCODE
        if (-not (Test-Path $this.ReportFile)) { throw "[!] trivy report missing: $($this.ReportFile)" }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        if ($exit -ne 0) { throw "[!] trivy scan failed (findings=$($this.FindingCount))" }
        return $this.ReportFile
    }

    hidden [int] CountFindings([string]$Report) {
        $data = Get-Content $Report -Raw | ConvertFrom-Json
        $count = 0
        foreach ($r in @($data.Results)) {
            if ($r.Vulnerabilities) { $count += @($r.Vulnerabilities).Count }
        }
        return $count
    }
}
