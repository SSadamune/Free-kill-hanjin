param([ValidateSet('sync', 'play')][string]$Action = 'sync')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeRoot = Join-Path $projectRoot '.dev/runtime/FreeKill-release'
$executable = Join-Path $runtimeRoot 'FreeKill.exe'
if (-not (Test-Path -LiteralPath $executable)) {
  throw 'Missing runtime. Extract official FreeKill v0.5.25 into .dev/runtime/FreeKill-release first.'
}
if (Get-Process FreeKill -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $executable }) {
  throw 'Close the development FreeKill before syncing, then retry.'
}
if ($Action -eq 'play') {
  & python (Join-Path $PSScriptRoot 'setup_dependencies.py') --check
  if ($LASTEXITCODE -ne 0) { throw 'Dependency check failed. Run python scripts/setup_dependencies.py first.' }
}
& python (Join-Path $PSScriptRoot 'prepare_runtime.py')
if ($LASTEXITCODE -ne 0) { throw 'Runtime compatibility setup failed.' }
# The v0.5.25 Windows client requests the packaged name even when its
# installation ships the module at ltk/client/util.lua. Use the existing
# Lua fallback search path without creating a second loadable extension.
$clientUtil = 'ltk/client/util.lua'
$modulePath = "packages/freekill-core/$clientUtil"
$fallback = Join-Path $runtimeRoot "lua/lib/$modulePath"
if ((Test-Path -LiteralPath (Join-Path $runtimeRoot $clientUtil)) -and
    -not (Test-Path -LiteralPath (Join-Path $runtimeRoot $modulePath)) -and
    -not (Test-Path -LiteralPath $fallback)) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fallback) | Out-Null
  Set-Content -LiteralPath $fallback -Encoding Ascii -Value 'return require "ltk.client.util"'
}
$packageRoot = Join-Path $runtimeRoot 'packages/hanjin'
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
# Only copy release assets; never copy the workspace or .dev into itself.
# No deletions: renamed/deleted source files require reviewing the dev copy.
foreach ($entry in @('init.lua', 'pkg', 'audio', 'image')) {
  $source = Join-Path $projectRoot $entry
  if (Test-Path -LiteralPath $source) {
    Copy-Item -LiteralPath $source -Destination $packageRoot -Recurse -Force
  }
}
Write-Host "Synced hanjin -> $packageRoot"
if ($Action -eq 'play') {
  Start-Process -FilePath $executable -WorkingDirectory $runtimeRoot
}
