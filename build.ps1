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

# ---------- Imágenes a partir de Icono.jpg ----------
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile((Join-Path $raiz 'Icono.jpg'))

# Recorte de la imagen original (x, y, ancho, alto) escalado a ancho x alto
function Recorte($x, $y, $w, $h, $ancho, $alto, $formato = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb) {
    $b = New-Object System.Drawing.Bitmap($ancho, $alto, $formato)
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $ancho, $alto)), (New-Object System.Drawing.Rectangle($x, $y, $w, $h)), 'Pixel')
    $g.Dispose()
    return $b
}

function Guardar-Jpg($bmp, $ruta, $calidad = 88) {
    $jpg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $par = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $par.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$calidad)
    $bmp.Save($ruta, $jpg, $par)
}

# .ico con varios tamaños: BMP de 32 bits hasta 128 (lo que lee bien .NET) y PNG en 256
function Guardar-Ico($tamanos, $ruta) {
    $entradas = foreach ($t in $tamanos) {
        $b = Recorte @recIcono $t $t
        if ($t -ge 256) {
            $ms = New-Object System.IO.MemoryStream
            $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $datos = $ms.ToArray()
        } else {
            $lb = $b.LockBits((New-Object System.Drawing.Rectangle(0, 0, $t, $t)), 'ReadOnly', 'Format32bppArgb')
            $pix = New-Object byte[] ($t * $t * 4)
            [System.Runtime.InteropServices.Marshal]::Copy($lb.Scan0, $pix, 0, $pix.Length)
            $b.UnlockBits($lb)
            $ms = New-Object System.IO.MemoryStream
            $w = New-Object System.IO.BinaryWriter($ms)
            $w.Write([int]40); $w.Write([int]$t); $w.Write([int]($t * 2)); $w.Write([int16]1); $w.Write([int16]32)
            $w.Write([int]0); $w.Write([int]0); $w.Write([int]0); $w.Write([int]0); $w.Write([int]0); $w.Write([int]0)
            for ($fila = $t - 1; $fila -ge 0; $fila--) { $w.Write($pix, $fila * $t * 4, $t * 4) }   # de abajo hacia arriba
            $w.Write((New-Object byte[] ([Math]::Ceiling($t / 32) * 4 * $t)))                          # máscara AND vacía
            $datos = $ms.ToArray()
        }
        $b.Dispose()
        [pscustomobject]@{ t = $t; datos = $datos }
    }
    $ms = New-Object System.IO.MemoryStream
    $w = New-Object System.IO.BinaryWriter($ms)
    $w.Write([int16]0); $w.Write([int16]1); $w.Write([int16]$entradas.Count)
    $offset = 6 + 16 * $entradas.Count
    foreach ($e in $entradas) {
        $lado = if ($e.t -ge 256) { 0 } else { $e.t }
        $w.Write([byte]$lado); $w.Write([byte]$lado); $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([int16]1); $w.Write([int16]32); $w.Write([int]$e.datos.Length); $w.Write([int]$offset)
        $offset += $e.datos.Length
    }
    foreach ($e in $entradas) { $w.Write($e.datos) }
    [System.IO.File]::WriteAllBytes($ruta, $ms.ToArray())
}

$recIcono = @(940, 140, 820, 820)          # el robot
Guardar-Ico @(16, 24, 32, 48, 64, 128, 256) (Join-Path $build 'TAB-Guardian.ico')

$logo = Recorte @recIcono 128 128
$logo.Save((Join-Path $build 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png); $logo.Dispose()

# Franja ancha para el encabezado de las ventanas
$banner = Recorte 0 160 2752 760 1600 442 ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
Guardar-Jpg $banner (Join-Path $build 'banner.jpg'); $banner.Dispose()

# Instalador: imagen vertical (izquierda) e imagen chica (arriba a la derecha), en varios DPI
$grandes = @(); $chicas = @()
foreach ($e in @(@(164, 314), @(205, 392), @(246, 471), @(328, 628))) {
    $b = Recorte 975 0 802 1536 $e[0] $e[1]
    $n = "wizard-$($e[0]).png"; $b.Save((Join-Path $build $n), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
    $grandes += "build\$n"
}
foreach ($t in 55, 69, 83, 110) {
    $b = Recorte @recIcono $t $t
    $n = "wizard-chica-$t.png"; $b.Save((Join-Path $build $n), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
    $chicas += "build\$n"
}
$src.Dispose()

# ---------- Ejecutable ----------
Import-Module ps2exe
Invoke-ps2exe -inputFile (Join-Path $raiz 'TAB-Guardian.ps1') `
    -outputFile (Join-Path $build 'TAB-Guardian.exe') `
    -iconFile (Join-Path $build 'TAB-Guardian.ico') `
    -noConsole -STA -winFormsDPIAware `
    -title 'TAB Guardian' -description 'Guardado automático para They Are Billions' `
    -product 'TAB Guardian' -company 'Tinisan' -copyright 'by Tinisan - tinisan.gesell@gmail.com' -version $Version

# ---------- Instalador ----------
$iscc = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'No encontré Inno Setup (ISCC.exe). Instalalo con: winget install JRSoftware.InnoSetup' }

& $iscc "/DMyVersion=$Version" "/DWizGrande=$($grandes -join ',')" "/DWizChica=$($chicas -join ',')" (Join-Path $raiz 'instalador.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC falló (código $LASTEXITCODE)" }
Write-Host "Listo: $(Join-Path $dist "TAB-Guardian-Setup-$Version.exe")"
