class Semgrep {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$WorkDir
    hidden [string]$ScanDir

    Semgrep() {
        $this.ScanDir = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'semgrep.json'
        $this.WorkDir = (Get-Location).Path
    }

    [string] Scan() {
        Write-Host "[+] semgrep workdir=$($this.WorkDir)"
        & docker run --rm `
            -v "$($this.WorkDir):$($this.WorkDir)" `
            -v "$($this.ScanDir):$($this.ScanDir)" `
            -w $this.WorkDir `
            semgrep/semgrep:1.96.0 `
            semgrep scan --config auto --json --output $this.ReportFile $this.WorkDir
        if ($LASTEXITCODE -ne 0) { throw '[!] semgrep scan failed' }
        if (-not (Test-Path $this.ReportFile)) { throw "[!] semgrep report missing: $($this.ReportFile)" }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        return $this.ReportFile
    }

    hidden [int] CountFindings([string]$Report) {
        $data = Get-Content $Report -Raw | ConvertFrom-Json
        if ($data.results) { return @($data.results).Count }
        return 0
    }
}
