Set-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)

$version = '0.13'
$archive = "wintun-$version.zip"
$url = "https://www.wintun.net/builds/$archive"
$sha256 = '34afe7d0de1fdb781af3defc0a75fd8c97daa756279b42dd6be6a1bd8ccdc7f0'

try {
    Invoke-WebRequest `
        -Uri $url `
        -OutFile 'wintun.zip'
    $actual = (Get-FileHash 'wintun.zip' -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $sha256) {
        throw "wintun.zip checksum mismatch. expected=$sha256 actual=$actual"
    }
}
catch {
    exit 1
}

7z x 'wintun.zip'
if ( -Not $? ) { exit $lastExitCode }

mv -Force 'wintun\bin\amd64\wintun.dll' '..\release\wintun.dll'

rm -Recurse -Force 'wintun'
rm -Recurse -Force 'wintun.zip'
exit 0
