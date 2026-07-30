class Registry {
    hidden [string]$Root
    hidden [string]$Image

    Registry([string]$Root, [string]$Image) {
        $this.Root = $Root
        $this.Image = $Image
    }

    # Misleading ik
    [void] Build() {
        & docker build -t $this.Image $this.Root
        if ($LASTEXITCODE -ne 0) { throw '[!] docker build failed' }
    }

    [void] Pull() {
        & docker pull $this.Image
        if ($LASTEXITCODE -ne 0) { throw "[!] docker pull failed: $($this.Image)" }
    }

    [void] Push() {
        & docker push $this.Image
        if ($LASTEXITCODE -ne 0) { throw "[!] docker push failed: $($this.Image)" }
    }

    [void] Tag([string]$TargetImage) {
        & docker tag $this.Image $TargetImage
        if ($LASTEXITCODE -ne 0) { throw "[!] docker tag failed: $($this.Image) -> $TargetImage" }
    }
}
