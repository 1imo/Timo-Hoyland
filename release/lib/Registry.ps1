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

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDoJ15JC4Ecs+4v
# zkX+fggQQcLrC2Gfl700d7auJaiduqCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINY6+gmf
# vWLmD99k/ivfw0ZKaAvdftw67bBuqu0rladYMAsGCSqGSIb3DQEBAQSCAgChJego
# vnmAhNRJU5mJbdTAtEbgOLFzdAm3LHAKm+RGzgAuML/iJMyasWr+TXPUnADEWhUr
# 5spI2d6mn2zN1FIDc7YJEwPciaRDnsPUZedKanFt0H6xcSrIPe8mdj1NF0jWQ03S
# VR6ls0WEshiSwIlLjobn4pC3kT7sU8kdeqZo04KRrEjVPCxBmfz3ozJTgrQcXdTi
# K8LaAyPFvh2whQXAZWSf/nXuLDlOZMlEFDGJ3x2p8R/oAqOwzYB8oyVS6SLoDodg
# 3owSYAoWb7men3x2/OBjMsxNsednHiY60eoFNLzikQi1EBwrSFvuXYpXy3RmtdfM
# nnu05QR5zVAuibaomiOGLUZHG447IHayOzlVwTArJbgz8+bcO/LcztrmqE7kG7GO
# PH1AyCv0cvPYnKMSBXyVB5eHBooLKSsZTDZsKM2UY8V7zqSqVSuoJJH3RNcGjXp4
# S1gQ7RsQm1lOBb0+CYJk26JmRpQIOrk8tSGhcPRpjXoE1fZGr/ri4YYdqC+xSNAD
# A55rmbfb6PIr+qAp3f6R+/K4MGSMcsk3KCfZhS9j16KXr6fOZH1GM7/mQvzCSg32
# APMwTfAaBIyfy15rkVktKYEOmePemzvT5o+vKrPNYJP6E0++xv9nqE/GNIfYjjZG
# 4l+yeuoIr0npvR4b41VjPOBfHk8L37ebrALkzqErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
