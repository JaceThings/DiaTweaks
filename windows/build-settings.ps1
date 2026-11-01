param([ValidateSet('Debug', 'Release')][string]$Configuration = 'Release', [string]$DiaPath,
    [string]$MetadataPath, [string]$BuildDirectory = (Join-Path $PSScriptRoot 'build/settings'))
$ErrorActionPreference = 'Stop'
if (!$MetadataPath -and !$DiaPath) {
    $package = Get-AppxPackage -Name TheBrowserCompany.Dia | Sort-Object Version -Descending | Select-Object -First 1
    if (!$package) { throw 'Install Dia first or pass -DiaPath with its installed package directory.' }
    $DiaPath = $package.InstallLocation
}
if (!$MetadataPath) { $MetadataPath = $DiaPath }
$metadata = Join-Path $MetadataPath 'Microsoft.UI.Xaml.winmd'
if (!(Test-Path -LiteralPath $metadata)) { throw 'Microsoft.UI.Xaml.winmd was not found in the Dia package.' }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$installation) { throw 'Install Visual Studio C++ Build Tools and CMake.' }
$cmakePath = Join-Path $installation 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$sdkVersion = Get-ChildItem -LiteralPath $sdkRoot -Directory | Where-Object Name -Match '^10\.0\.\d+\.0$' | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$cppwinrt = Join-Path $sdkVersion.FullName 'x64\cppwinrt.exe'
if (!(Test-Path -LiteralPath $cppwinrt)) { throw 'Install the Windows SDK C++/WinRT tools.' }
$buildRoot = Join-Path $PSScriptRoot 'build'
$referenceRoot = Join-Path $buildRoot 'webview2-reference'
New-Item -ItemType Directory -Path $referenceRoot -Force > $null
$coreMetadata = Join-Path $referenceRoot 'Microsoft.Web.WebView2.Core.winmd'
if (!(Test-Path -LiteralPath $coreMetadata)) {
    # SDK metadata only; no WebView is created by this panel.
    $sdkPackage = Join-Path $referenceRoot 'microsoft.web.webview2.1.0.4314.35.nupkg'
    Invoke-WebRequest 'https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/1.0.4314.35/microsoft.web.webview2.1.0.4314.35.nupkg' -OutFile $sdkPackage
    $archive = [System.IO.Compression.ZipFile]::OpenRead($sdkPackage)
    try {
        $entry = $archive.GetEntry('lib/Microsoft.Web.WebView2.Core.winmd')
        if (!$entry) { throw 'WebView2 SDK metadata was missing from the package.' }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $coreMetadata, $true)
    } finally { $archive.Dispose() }
}
$projections = Join-Path $BuildDirectory 'projections'
New-Item -ItemType Directory -Path $projections -Force > $null
& $cppwinrt -input $MetadataPath -input $coreMetadata -reference sdk -output $projections
if ($LASTEXITCODE) { throw 'WinUI projection generation failed.' }
$buildPath = $BuildDirectory
& $cmakePath -S $PSScriptRoot -B $buildPath -A x64 "-DDIATWEAKS_WINUI_PROJECTIONS=$projections" -DBUILD_TESTING=ON
if ($LASTEXITCODE) { throw 'CMake configuration failed.' }
& $cmakePath --build $buildPath --config $Configuration --parallel 1 -- /nr:false
if ($LASTEXITCODE) { throw 'Settings build failed.' }
& (Join-Path (Split-Path $cmakePath) 'ctest.exe') --test-dir $buildPath -C $Configuration --output-on-failure
if ($LASTEXITCODE) { throw 'Settings tests failed.' }
Write-Host "Built: $buildPath\$Configuration\DiaTweaks.exe"
