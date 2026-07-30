class Syft {
    [string]$ReportFile
    hidden [string]$Image
    hidden [string]$ScanDir

    Syft([string]$Image) {
        $this.Image = $Image
        $dirPath = Join-Path ([System.IO.Path]::GetTempPath()) 'release-scan'
        if ($env:ARTIFACT_DIR) {
            $dirPath = (New-Item -ItemType Directory -Path $env:ARTIFACT_DIR -Force).FullName
        }
        $this.ScanDir = $dirPath
        if (-not (Test-Path $this.ScanDir)) { New-Item -ItemType Directory -Path $this.ScanDir -Force | Out-Null }
        $this.ReportFile = Join-Path $this.ScanDir 'sbom.cyclonedx.json'
    }

    [string] ScanImage() {
        Write-Host "[+] syft image=$($this.Image)"
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$($this.ScanDir):$($this.ScanDir)" anchore/syft:1.18.0 $this.Image -o "cyclonedx-json=$($this.ReportFile)"
        if ($LASTEXITCODE -ne 0) { throw '[!] syft scan failed' }
        if (-not (Test-Path $this.ReportFile)) { throw "[!] syft report missing: $($this.ReportFile)" }
        $report = $this.ReportFile
        return $report
    }
}
