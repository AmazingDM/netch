Set-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)

$version = 'v0.6.2'
$archive = "pcap2socks-$version-windows-amd64.zip"
$url = "https://github.com/zhxie/pcap2socks/releases/download/$version/$archive"
$sha256 = '59b3a2e5054c5a0252f3ac5f10b2862aa53a91e65b2e56e76d5706838d291953'

try {
    Invoke-WebRequest `
        -Uri $url `
        -OutFile 'pcap2socks.zip'
    $actual = (Get-FileHash 'pcap2socks.zip' -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $sha256) {
        throw "pcap2socks.zip checksum mismatch. expected=$sha256 actual=$actual"
    }
    Expand-Archive -Force -Path pcap2socks.zip -DestinationPath pcap2socks
}
catch {
    exit 1
}

mv -Force 'pcap2socks\pcap2socks.exe' '..\release\pcap2socks.exe'
exit 0
