# Copyright (C) CheshirCa 2026 https://t.me/cheshircanest
# Non-commercial use only. See LICENSE for complete terms.

$compiler = 'C:\Program Files\PureBasic\Compilers\pbcompiler.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw "Компилятор не найден: $compiler" }
Push-Location $PSScriptRoot
try {
  $version = & $compiler /VERSION
  $exePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'PaymentTracker.exe'
  $logPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Work\build.log'
  $resourcePath = Join-Path $PSScriptRoot 'version.rc'
  $output = & $compiler Main.pb /OUTPUT $exePath /ICON app.ico /RESOURCE $resourcePath 2>&1
  $result = $LASTEXITCODE
  @("$version", 'Команда: pbcompiler Main.pb /OUTPUT ../PaymentTracker.exe /ICON app.ico /RESOURCE version.rc', "Код выхода: $result", $output) | Set-Content -LiteralPath $logPath -Encoding utf8
  Get-Content -LiteralPath $logPath
  if ($result -ne 0) { exit $result }
} finally { Pop-Location }
