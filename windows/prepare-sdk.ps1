param([string]$OutputPath = (Join-Path $PSScriptRoot 'build/public-sdk'))
$ErrorActionPreference = 'Stop'
# Build-time metadata only. None of these SDK files goes into the tester ZIP.
$packages = @(
    @{ Id = 'microsoft.windowsappsdk.winui'; Version = '1.8.250906003'; Prefix = 'metadata/' },
    @{ Id = 'microsoft.windowsappsdk.interactiveexperiences'; Version = '1.8.250906004'; Prefix = 'metadata/10.0.18362.0/' },
    @{ Id = 'microsoft.windowsappsdk.foundation'; Version = '1.8.250906002'; Prefix = 'metadata/' }
)
New-Item -ItemType Directory -Path $OutputPath -Force > $null
$cache = Join-Path $PSScriptRoot 'build/sdk-packages'
New-Item -ItemType Directory -Path $cache -Force > $null
foreach ($package in $packages) {
    $archivePath = Join-Path $cache ($package.Id + '.' + $package.Version + '.nupkg')
    if (!(Test-Path -LiteralPath $archivePath)) {
        Invoke-WebRequest ('https://api.nuget.org/v3-flatcontainer/' + $package.Id + '/' + $package.Version + '/' + $package.Id + '.' + $package.Version + '.nupkg') -OutFile $archivePath
    }
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName.StartsWith($package.Prefix) -and $entry.FullName.EndsWith('.winmd')) {
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $OutputPath $entry.Name), $true)
            }
        }
    } finally { $archive.Dispose() }
}
Write-Host "SDK metadata: $OutputPath"
