param([ValidateSet('Debug', 'Release')][string]$Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$cmakeCommand = Get-Command cmake -ErrorAction SilentlyContinue
if ($cmakeCommand) {
    $cmakePath = $cmakeCommand.Source
} else {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (!(Test-Path -LiteralPath $vswhere)) { throw 'Install Visual Studio C++ Build Tools and CMake.' }
    $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (!$installation) { throw 'Visual Studio C++ Build Tools were not found.' }
    $cmakePath = Join-Path $installation 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
}
$buildPath = Join-Path $PSScriptRoot 'build'
& $cmakePath -S $PSScriptRoot -B $buildPath -A x64 -DBUILD_TESTING=ON
if ($LASTEXITCODE) { throw 'CMake configuration failed.' }
& $cmakePath --build $buildPath --config $Configuration --parallel 1 -- /nr:false
if ($LASTEXITCODE) { throw 'Build failed.' }
$ctestPath = Join-Path (Split-Path $cmakePath) 'ctest.exe'
& $ctestPath --test-dir $buildPath -C $Configuration --output-on-failure
if ($LASTEXITCODE) { throw 'Tests failed.' }
Write-Host "Built and tested: $buildPath\$Configuration\diatweaks-probe.exe"
