class Vault {
    [string]$Addr
    [string]$Token
    [string]$Prefix

    Vault() {
        if (-not $env:VAULT_URL) { throw '[!] VAULT_URL is required' }
        if (-not $env:VAULT_TOKEN) { throw '[!] VAULT_TOKEN is required' }
        if (-not $env:VAULT_SECRET_PREFIX) { throw '[!] VAULT_SECRET_PREFIX is required' }
        $this.Addr = $env:VAULT_URL.TrimEnd('/')
        $this.Token = $env:VAULT_TOKEN
        $this.Prefix = $env:VAULT_SECRET_PREFIX
    }

    [hashtable] ReadSecret([string]$Path) {
        $uri = "$($this.Addr)/v1/secret/data/$Path"
        try {
            $r = Invoke-RestMethod -Uri $uri -Headers @{ 'X-Vault-Token' = $this.Token }
            $data = $r.data.data
            if ($null -eq $data) { return @{} }
            if ($data -is [hashtable]) { return $data }
            $h = @{}
            foreach ($p in $data.PSObject.Properties) {
                $h[$p.Name] = $p.Value
            }
            return $h
        }
        catch {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -eq 404) { throw "[!] Vault secret missing: $Path" }
            throw "[!] Vault read failed: $uri ($($_.Exception.Message))"
        }
    }

    [void] LoadEnv([string]$ProjectName) {
        $path = "$($this.Prefix)-$ProjectName"
        $secret = $this.ReadSecret($path)
        foreach ($key in $secret.Keys) {
            Set-Item -Path "env:$key" -Value $secret[$key]
        }
        $env:VAULT_SECRET_PATH = $path
        Write-Host "[+] Vault secret/$path loaded ($($secret.Count) keys)"
    }
}
