class Grype {
    [int]$FindingCount
    [string]$ReportFile
    hidden [string]$ScanDir

    Grype() {
        $dirPath = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if ($env:ARTIFACT_DIR) {
            $dirPath = (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
        }
        $this.ScanDir = $dirPath
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'grype.json'
    }

    [string] Scan() {
        $sbom = Join-Path $this.ScanDir 'sbom.cyclonedx.json'
        if (-not (Test-Path $sbom)) { throw "[!] grype sbom missing: $sbom (run syft first)" }
        Write-Host "[+] grype sbom=$sbom"
        docker run --rm -v "$($this.ScanDir):$($this.ScanDir)" anchore/grype:0.84.0 "sbom:$sbom" -o "json=$($this.ReportFile)"
        if ($LASTEXITCODE -ne 0) { throw '[!] grype scan failed' }
        if (-not (Test-Path $this.ReportFile)) { throw "[!] grype report missing: $($this.ReportFile)" }
        $this.FindingCount = $this.CountFindings($this.ReportFile)
        $report = $this.ReportFile
        return $report
    }

    hidden [int] CountFindings([string]$Report) {
        $matches = @(Get-Content $Report -Raw | ConvertFrom-Json | Select-Object -ExpandProperty matches -ErrorAction SilentlyContinue)
        if ($matches) { return $matches.Count }
        return 0
    }
}
