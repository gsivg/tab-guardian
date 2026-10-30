# ==================================================================
#  Compila TAB-Guardian.exe (ps2exe) y arma el instalador (Inno Setup)
#  Resultado: dist\TAB-Guardian-Setup-<version>.exe
#
#  Requisitos (una sola vez):
#    Install-Module ps2exe -Scope CurrentUser
#    winget install JRSoftware.InnoSetup
# ==================================================================

param([string]$Version = '1.0.0')

$ErrorActionPreference = 'Stop'
$raiz  = $PSScriptRoot
$build = Join-Path $raiz 'build'
$dist  = Join-Path $raiz 'dist'
New-Item -ItemType Directory -Force -Path $build, $dist | Out-Null

# Icono del juego con nombre fijo (el programa lo busca al lado del .exe)
Copy-Item (Join-Path $raiz 'theyarebillions_2324193_1600x900.ico') (Join-Path $build 'TAB-Guardian.ico') -Force

Import-Module ps2exe
Invoke-ps2exe -inputFile (Join-Path $raiz 'TAB-Guardian.ps1') `
    -outputFile (Join-Path $build 'TAB-Guardian.exe') `
    -iconFile (Join-Path $build 'TAB-Guardian.ico') `
    -noConsole -STA -winFormsDPIAware `
    -title 'TAB Guardian' -description 'Guardado automático para They Are Billions' `
    -product 'TAB Guardian' -company 'Tinisan' -copyright 'by Tinisan - tinisan.gesell@gmail.com' -version $Version

$iscc = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'No encontré Inno Setup (ISCC.exe). Instalalo con: winget install JRSoftware.InnoSetup' }

& $iscc "/DMyVersion=$Version" (Join-Path $raiz 'instalador.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC falló (código $LASTEXITCODE)" }
Write-Host "Listo: $(Join-Path $dist "TAB-Guardian-Setup-$Version.exe")"
