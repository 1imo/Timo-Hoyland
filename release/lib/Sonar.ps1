class Sonar {
    hidden [string]$Name
    hidden [string]$Root
    hidden [string]$Token
    hidden [string]$Url
    hidden [string]$WorkDir
    hidden [bool]$Gated
    hidden [string]$BaseBranch
    hidden [string]$Image = 'sonarsource/sonar-scanner-cli:11.1.1.1669_6.2.1'

    Sonar([string]$Name, [string]$Root, [bool]$Gated, [string]$BaseBranch) {
        if (-not $env:SONAR_TOKEN) { throw '[!] SONAR_TOKEN is required' }
        if (-not $env:SONAR_URL) { throw '[!] SONAR_URL is required' }
        $this.Name = $Name
        $this.Root = $Root
        $this.Token = $env:SONAR_TOKEN
        $this.Url = $env:SONAR_URL
        $this.WorkDir = (Resolve-Path $Root).Path
        $this.Gated = $Gated
        $this.BaseBranch = $BaseBranch
    }

    hidden [string[]] ScannerArgs() {
        $args = @("-Dsonar.projectKey=$($this.Name)")
        if (-not $this.Gated) { return $args }

        $branch = if ($env:CI_COMMIT_REF_NAME) { $env:CI_COMMIT_REF_NAME } else {
            & git -C $this.Root rev-parse --abbrev-ref HEAD 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { throw '[!] cannot resolve current branch for sonar pull request analysis' }
            (& git -C $this.Root rev-parse --abbrev-ref HEAD).Trim()
        }
        $key = if ($env:CI_MERGE_REQUEST_IID) { $env:CI_MERGE_REQUEST_IID } else { $branch }
        $base = if ($env:CI_MERGE_REQUEST_TARGET_BRANCH_NAME) { $env:CI_MERGE_REQUEST_TARGET_BRANCH_NAME } else { $this.BaseBranch }

        $args += "-Dsonar.pullrequest.key=$key"
        $args += "-Dsonar.pullrequest.branch=$branch"
        $args += "-Dsonar.pullrequest.base=$base"
        return $args
    }

    [void] Scan() {
        $props = Join-Path $this.Root 'sonar-project.properties'
        if (-not (Test-Path $props)) { throw "[!] sonar-project.properties missing in $($this.Root)" }

        $mode = if ($this.Gated) { 'pull-request' } else { 'branch' }
        Write-Host "[+] sonar-scanner workdir=$($this.WorkDir) mode=$mode"

        & docker run --rm `
            -e "SONAR_HOST_URL=$($this.Url)" `
            -e "SONAR_TOKEN=$($this.Token)" `
            -v "$($this.WorkDir):/usr/src" `
            -w /usr/src `
            $this.Image `
            @($this.ScannerArgs())

        if ($LASTEXITCODE -ne 0) { throw '[!] sonar-scanner failed' }
    }
}
