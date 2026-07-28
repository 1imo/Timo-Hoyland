class Gitleaks {
    hidden [string]$WorkDir

    Gitleaks() {
        $this.WorkDir = (Get-Location).Path
    }

    [void] Scan() {
        $src = $this.WorkDir
        Write-Host "[+] gitleaks workdir=$src"
        & docker run --rm `
            -v "${src}:${src}" `
            -w $src `
            zricethezav/gitleaks:v8.21.2 `
            detect --source=$src --no-banner
        if ($LASTEXITCODE -ne 0) { throw '[!] gitleaks failed' }
    }
}

# SIG # Begin signature block
# MIIHBQYJKoZIhvcNAQcCoIIG9jCCBvICAQMxDTALBglghkgBZQMEAgEwewYKKwYB
# BAGCNwIBBKBtBGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC8ElXhsyrhZz2X
# PCe4GFWB+4A6Xno7EUs6jdV3I/lx8qCCA1QwggNQMIIC9qADAgECAhEAn7eSCz3E
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
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIBCT4nLy
# Arbf5pf0fIae+GHzqXMyqVXxPnUGzA7vgcq0MAsGCSqGSIb3DQEBAQSCAgBgXcvy
# 84CV/UXvyuDebLsaiNS0rD5s8udEKr/GHtUaXxGgVwtOh984KL/QXu+ooG5lFxOu
# c7jo/s+23LczGMMWlKR+enp7LjeQ2J4HwUDnEueRx4eXhwVYtdBYhi9zuo4shmqm
# l/s6q5pulCKiSmiW/0zrDTxDs5PJdhqpJmxyoy9vh6bnXNILnzV2NglG2ny8xkE7
# IqDn361TUx2hE1TS32UpzgXF7wkNYZtiYwrmrEvIYUsXLkJr6LqpN3Y+ruPUn0hX
# 24hVPv1M0waE+Qw3GJEwW/mI1dAXWX1jEQZ2RQftlASp8ilNi+jJE/+syl+2VPvp
# 1UEZpwke2A+EF84fx6PRg3sKqu4iLu1ChIcMOZa7WT3H6LoCqqu1jBWobM+9Hw3q
# y8s4+wrUG8yoRozyCGQ1y7y4ShcoQTgcxa2p+j+/nEnSFgNX1TRvvhVbK7s1Di9w
# NvS+BAnVonxujFZD/0byhJ3BbooNZCsUAIqoRtiDQntIIMbzr94hXdbrL2s4HjBT
# z6M+9XSH50ZPMqvefnsWXJK+sF7gBwSt3cKloHQ6tdERHpKUt+hr3cder9BFNZrK
# NzdVQ+Vhl3z9Mk5P5hZCqMvQzlc3Av1o2O0MhrNgeYQHWWINqKeXrrfRI6A5MThJ
# qFSksP2mlbSmCA01+VLIl8FdsEpXpMsOKzyEsKErMCkGDCsGAQQBgoxMCgABAzEZ
# BBdodHRwczovL25vdHRpbmZyYS5jby51aw==
# SIG # End signature block
