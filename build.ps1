param (
	[Parameter()]
	[ValidateSet('Debug', 'Release')]
	[string]
	$Configuration = 'Release',

	[Parameter()]
	[ValidateNotNullOrEmpty()]
	[string]
	$OutputPath = 'release',

	[Parameter()]
	[bool]
	$SelfContained = $True,

	[Parameter()]
	[bool]
	$PublishSingleFile = $True,

	[Parameter()]
	[bool]
	$PublishReadyToRun = $False
)

function Get-MSBuildPath {
	$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
	if ( -Not ( Test-Path -Path $vswhere -PathType Leaf ) ) {
		return $null
	}

	$msbuild = & $vswhere `
		-latest `
		-requires Microsoft.Component.MSBuild `
		-find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
	if ( $msbuild -and ( Test-Path -Path $msbuild -PathType Leaf ) ) {
		return $msbuild
	}

	return $null
}

function Invoke-CppBuild {
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$ProjectPath,

		[Parameter(Mandatory = $true)]
		[string]
		$Configuration
	)

	$msbuildPath = Get-MSBuildPath
	if ( $msbuildPath ) {
		& $msbuildPath `
			-property:Configuration=$Configuration `
			-property:Platform=x64 `
			$ProjectPath
	}
	else {
		Write-Host 'MSBuild.exe not found via vswhere, falling back to dotnet msbuild'
		dotnet msbuild `
			-property:Configuration=$Configuration `
			-property:Platform=x64 `
			$ProjectPath
	}

	if ( -Not $? ) {
		exit $lastExitCode
	}
}

function Assert-FileExists {
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)

	if ( -Not ( Test-Path -Path $Path -PathType Leaf ) ) {
		Write-Error "Required file not found: $Path"
		exit 1
	}
}

Push-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)

if ( Test-Path -Path $OutputPath ) {
    rm -Recurse -Force $OutputPath
}
New-Item -ItemType Directory -Name $OutputPath | Out-Null

Push-Location $OutputPath
New-Item -ItemType Directory -Name 'bin'  | Out-Null
cp -Recurse -Force '..\Storage\i18n' '.'  | Out-Null
cp -Recurse -Force '..\Storage\mode' '.'  | Out-Null
cp -Recurse -Force '..\Storage\stun.txt' 'bin'  | Out-Null
cp -Recurse -Force '..\Storage\nfdriver.sys' 'bin'  | Out-Null
cp -Recurse -Force '..\Storage\aiodns.conf' 'bin'  | Out-Null
try {
	Invoke-WebRequest `
		-Uri 'https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country.mmdb' `
		-OutFile 'bin\GeoLite2-Country.mmdb' `
		-ErrorAction Stop
}
catch {
	$localGeoIp = '..\Storage\GeoLite2-Country.mmdb'
	if ( Test-Path -Path $localGeoIp -PathType Leaf ) {
		Write-Warning "GeoIP download failed. Falling back to local file: $localGeoIp"
		cp -Force $localGeoIp 'bin\GeoLite2-Country.mmdb'
	}
	else {
		Write-Error 'GeoIP download failed and fallback file is missing: ..\Storage\GeoLite2-Country.mmdb'
		exit 1
	}
}
cp -Recurse -Force '..\Storage\tun2socks.bin' 'bin'  | Out-Null
cp -Recurse -Force '..\Storage\README.md' 'bin'  | Out-Null
Pop-Location

if ( -Not ( Test-Path '.\Other\release' ) ) {
	.\Other\build.ps1
	if ( -Not $? ) {
		exit $lastExitCode
	}
}
if ( -Not ( Test-Path '.\Other\release' ) ) {
	Write-Error 'Missing .\Other\release after running .\Other\build.ps1'
	exit 1
}
cp -Force '.\Other\release\*.bin' "$OutputPath\bin"
cp -Force '.\Other\release\*.dll' "$OutputPath\bin"
cp -Force '.\Other\release\*.exe' "$OutputPath\bin"

$netchExePath = ".\Netch\bin\$Configuration\Netch.exe"
if ( -Not ( Test-Path -Path $netchExePath -PathType Leaf ) ) {
	Write-Host
	Write-Host 'Building Netch'

	dotnet publish `
		-c $Configuration `
		-r 'win-x64' `
		-p:Platform='x64' `
		-p:SelfContained=$SelfContained `
		-p:PublishTrimmed=$PublishReadyToRun `
		-p:PublishSingleFile=$PublishSingleFile `
		-p:PublishReadyToRun=$PublishReadyToRun `
		-p:PublishReadyToRunShowWarnings=$PublishReadyToRun `
		-p:IncludeNativeLibrariesForSelfExtract=$SelfContained `
		-o ".\Netch\bin\$Configuration" `
		'.\Netch\Netch.csproj'
	if ( -Not $? ) { exit $lastExitCode }
}
Assert-FileExists $netchExePath
cp -Force $netchExePath $OutputPath

$redirectorBinPath = ".\Redirector\bin\$Configuration\Redirector.bin"
$redirectorNfapiPath = ".\Redirector\bin\$Configuration\nfapi.dll"
if (
	( -Not ( Test-Path -Path $redirectorBinPath -PathType Leaf ) ) -or
	( -Not ( Test-Path -Path $redirectorNfapiPath -PathType Leaf ) )
) {
	Write-Host
	Write-Host 'Building Redirector'

	Invoke-CppBuild `
		-ProjectPath '.\Redirector\Redirector.vcxproj' `
		-Configuration $Configuration
}
Assert-FileExists $redirectorNfapiPath
Assert-FileExists $redirectorBinPath
cp -Force $redirectorNfapiPath "$OutputPath\bin"
cp -Force $redirectorBinPath   "$OutputPath\bin"

$routeHelperBinPath = ".\RouteHelper\bin\$Configuration\RouteHelper.bin"
if ( -Not ( Test-Path -Path $routeHelperBinPath -PathType Leaf ) ) {
	Write-Host
	Write-Host 'Building RouteHelper'

	Invoke-CppBuild `
		-ProjectPath '.\RouteHelper\RouteHelper.vcxproj' `
		-Configuration $Configuration
}
Assert-FileExists $routeHelperBinPath
cp -Force $routeHelperBinPath "$OutputPath\bin"

if ( $Configuration.Equals('Release') ) {
	rm -Force "$OutputPath\*.pdb"
	rm -Force "$OutputPath\*.xml"
}

Pop-Location
exit 0
