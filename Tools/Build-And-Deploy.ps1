[CmdletBinding()]
param(
    [string]$GameDirectory = (Join-Path $PSScriptRoot '..\..'),
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [ValidateRange(1, 64)]
    [int]$Parallel = [Math]::Min([Environment]::ProcessorCount, 64)
)

$ErrorActionPreference = 'Stop'
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$game = [IO.Path]::GetFullPath($GameDirectory)
$client = Join-Path $game 'WowClient64.exe'
$build = Join-Path $repository 'build\x64'

if (!(Test-Path -LiteralPath $game -PathType Container)) {
    throw "Game directory does not exist: $game"
}
if (!(Test-Path -LiteralPath $client -PathType Leaf)) {
    throw "Expected existing game client was not found: $client"
}

$runningClient = Get-Process -Name 'WowClient64' -ErrorAction SilentlyContinue |
    Where-Object { !$_.Path -or $_.Path -eq $client }
if ($runningClient) {
    throw "Close WowClient64 before replacing it: $client"
}

$cmake = (Get-Command cmake -ErrorAction Stop).Source
& $cmake -S $repository -B $build '-DWOWDECOMP_ALLOW_MODIFIED_INTERFACE=ON'
if ($LASTEXITCODE -ne 0) {
    throw 'CMake configuration failed.'
}

& $cmake --build $build --config $Configuration --target WowClient --parallel $Parallel
if ($LASTEXITCODE -ne 0) {
    throw 'WowClient build failed.'
}

$builtClient = Join-Path $repository 'bin\Win\WowClient64.exe'
if (!(Test-Path -LiteralPath $builtClient -PathType Leaf)) {
    throw "Build output was not found: $builtClient"
}

$backupRoot = Join-Path $game 'Backup\wowdecomp'
$backup = Join-Path $backupRoot (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $client -Destination (Join-Path $backup 'WowClient64.exe')
Copy-Item -LiteralPath $builtClient -Destination $client -Force

$installedHash = (Get-FileHash -LiteralPath $client -Algorithm SHA256).Hash
$builtHash = (Get-FileHash -LiteralPath $builtClient -Algorithm SHA256).Hash
if ($installedHash -ne $builtHash) {
    throw "Installed executable hash does not match the build. Original backup: $backup"
}

Write-Output "Installed $client"
Write-Output "Original backed up to $(Join-Path $backup 'WowClient64.exe')"
