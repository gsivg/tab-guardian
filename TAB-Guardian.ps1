# ==================================================================
#  TAB Guardian - guardado automatico para They Are Billions
#
#  - Corre en segundo plano (icono al lado del reloj).
#  - Cada vez que el juego escribe la partida, guarda una copia
#    con fecha y hora en el historial.
#  - Ctrl+F5  -> "Guardar ya" (Esc + Guardar y salir + Continuar)
#  - Ctrl+F9  -> Volver al ultimo guardado (cierra y reabre el juego)
#  - Ctrl+F12 / Ctrl+F11 -> grabar puntos / terminar calibracion
#
#  Se abre con TAB-Guardian.vbs (sin ventana negra), o compilado
#  como TAB-Guardian.exe con build.ps1 (ver instalador.iss).
# ==================================================================

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, Microsoft.VisualBasic

# ---------- Una sola instancia ----------
$creado = $false
$mutex = New-Object System.Threading.Mutex($true, 'TABGuardian_SingleInstance', [ref]$creado)
if (-not $creado) {
    [System.Windows.Forms.MessageBox]::Show('TAB Guardian ya esta abierto (mira el icono al lado del reloj).', 'TAB Guardian') | Out-Null
    exit
}

# ---------- Funciones nativas de Windows ----------
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace TABG {
    public class HotkeyWin : NativeWindow {
        [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr h, int id, uint mod, uint vk);
        [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr h, int id);
        public Action<int> OnHotkey;
        public HotkeyWin() { CreateHandle(new CreateParams()); }
        public bool Register(int id, uint mod, uint vk) { return RegisterHotKey(Handle, id, mod, vk); }
        protected override void WndProc(ref Message m) {
            if (m.Msg == 0x0312 && OnHotkey != null) OnHotkey(m.WParam.ToInt32());
            base.WndProc(ref m);
        }
        public void Close() { for (int i = 1; i < 10; i++) UnregisterHotKey(Handle, i); DestroyHandle(); }
    }

    public static class Native {
        [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
        [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
        [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
        [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref POINT p);
        [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
        [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
        [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
        [DllImport("user32.dll")] static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
        [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint f, UIntPtr e);

        // Area de juego en pantalla: x, y, ancho, alto
        public static int[] ClientArea(IntPtr h) {
            RECT r; GetClientRect(h, out r);
            POINT p = new POINT(); ClientToScreen(h, ref p);
            return new int[] { p.X, p.Y, r.R, r.B };
        }
        public static int[] Cursor() { POINT p; GetCursorPos(out p); return new int[] { p.X, p.Y }; }

        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);

        // Foto del area de juego, achicada a maxAncho de ancho
        public static Bitmap Capturar(IntPtr h, int maxAncho) {
            int[] a = ClientArea(h);
            if (a[2] < 50 || a[3] < 50) return null;
            using (Bitmap full = new Bitmap(a[2], a[3])) {
                using (Graphics g = Graphics.FromImage(full))
                    g.CopyFromScreen(a[0], a[1], 0, 0, new Size(a[2], a[3]));
                int w = Math.Min(maxAncho, a[2]);
                int alto = (int)((long)a[3] * w / a[2]);
                Bitmap chica = new Bitmap(w, alto);
                using (Graphics g2 = Graphics.FromImage(chica)) {
                    g2.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g2.DrawImage(full, 0, 0, w, alto);
                }
                return chica;
            }
        }
        // En pantalla completa exclusiva la captura sale negra: no sirve
        public static bool EsNegra(Bitmap b) {
            for (int i = 1; i < 12; i++)
                for (int j = 1; j < 12; j++) {
                    Color c = b.GetPixel(b.Width * i / 12, b.Height * j / 12);
                    if (c.R + c.G + c.B > 45) return false;
                }
            return true;
        }

        // Espera a que sueltes Ctrl/Alt/Shift (si no, Esc se vuelve Ctrl+Esc)
        public static void WaitModifiersUp() {
            for (int i = 0; i < 60; i++) {
                if ((GetAsyncKeyState(0x11) & 0x8000) == 0 &&
                    (GetAsyncKeyState(0x12) & 0x8000) == 0 &&
                    (GetAsyncKeyState(0x10) & 0x8000) == 0) return;
                Thread.Sleep(50);
            }
        }
        public static void Esc() {
            keybd_event(0x1B, 0x01, 0x0008, UIntPtr.Zero); Thread.Sleep(60);
            keybd_event(0x1B, 0x01, 0x0008 | 0x0002, UIntPtr.Zero);
        }
        public static void Click(int x, int y) {
            SetCursorPos(x, y); Thread.Sleep(80);
            mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero); Thread.Sleep(70);
            mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero);
        }
    }
}
'@

# ---------- Rutas ----------
$docs     = [Environment]::GetFolderPath('MyDocuments')      # funciona con OneDrive
$gameDir  = Join-Path $docs 'My Games\They Are Billions'
$savesDir = Join-Path $gameDir 'Saves'
$baseDir  = Join-Path $gameDir 'SaveSlots'
$histDir  = Join-Path $baseDir 'Historial'
$cfgFile  = Join-Path $baseDir 'guardian-config.json'
$logFile  = Join-Path $baseDir 'guardian.log'
# Compilado con ps2exe no hay $PSScriptRoot: la carpeta es la del .exe
$exePath  = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$esExe    = $exePath -notmatch '\\(powershell|powershell_ise|pwsh)\.exe$'
$appDir   = if ($esExe) { Split-Path $exePath } else { $PSScriptRoot }
$vbsPath  = Join-Path $appDir 'TAB-Guardian.vbs'
$icoPath  = Join-Path $appDir 'TAB-Guardian.ico'
$startLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'TAB Guardian.lnk'
$steamId  = '644930'

if (-not (Test-Path $savesDir)) {
    [System.Windows.Forms.MessageBox]::Show("No encontré la carpeta de partidas:`n$savesDir`n`nAbrí el juego, guardá una partida y volvé a abrir TAB Guardian.", 'TAB Guardian', 'OK', 'Warning') | Out-Null
    exit
}
New-Item -ItemType Directory -Force -Path $histDir | Out-Null

# ---------- Configuracion ----------
$script:cfg = [pscustomobject]@{ clicks = @(); maxHistorial = 200; ayudaVista = $false }
if (Test-Path $cfgFile) {
    try {
        $c = Get-Content $cfgFile -Raw | ConvertFrom-Json
        if ($c.clicks)       { $script:cfg.clicks = @($c.clicks) }
        if ($c.maxHistorial) { $script:cfg.maxHistorial = [int]$c.maxHistorial }
        if ($c.ayudaVista)   { $script:cfg.ayudaVista = $true }
    } catch { }
}
function Save-Config { $script:cfg | ConvertTo-Json -Depth 5 | Set-Content $cfgFile -Encoding UTF8 }

function Write-Log($m) {
    try { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Add-Content $logFile -Encoding UTF8 } catch { }
}

# ---------- Estado ----------
$script:busy        = $false
$script:lastSig     = ''
$script:pendingSig  = $null
$script:pendingTime = Get-Date
$script:calibrando  = $false
$script:calib       = New-Object System.Collections.ArrayList
$script:histForm    = $null
$script:lv          = $null
$script:pb          = $null
$script:capturas    = New-Object System.Collections.ArrayList   # últimas fotos del juego {t, img}
$script:ultCaptura  = [datetime]::MinValue
$script:primerCambio = Get-Date

# ---------- Utilidades ----------
function Get-Firma($carpeta) {
    $f = Get-ChildItem $carpeta -File -Recurse -Force -ErrorAction SilentlyContinue |
         Sort-Object FullName |
         ForEach-Object { "$($_.Name)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }
    return ($f -join ';')
}

function Get-GameProcs {
    @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'TheyAreBillions|They Are Billions' })
}
function Get-GameWindowProc {
    Get-GameProcs | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
}

function Notify($titulo, $texto, $tipo = 'Info') {
    $script:tray.ShowBalloonTip(4000, $titulo, $texto, $tipo)
}

# Pitidos propios: los sonidos de Windows no suenan si el esquema es "Sin sonidos"
function Nuevo-Tono([int[]]$frecs, [int]$ms) {
    $rate = 22050; $porTono = [int]($rate * $ms / 1000)
    $datos = New-Object System.IO.MemoryStream
    $w = New-Object System.IO.BinaryWriter($datos)
    foreach ($f in $frecs) {
        for ($i = 0; $i -lt $porTono; $i++) {
            $env = [Math]::Min(1.0, [Math]::Min($i, $porTono - $i) / 200.0)   # sin "clic" al arrancar/cortar
            $w.Write([int16](9000 * $env * [Math]::Sin(2 * [Math]::PI * $f * $i / $rate)))
        }
    }
    $pcm = $datos.ToArray()
    $ms2 = New-Object System.IO.MemoryStream
    $h = New-Object System.IO.BinaryWriter($ms2)
    $h.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $h.Write([int](36 + $pcm.Length))
    $h.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt ')); $h.Write([int]16); $h.Write([int16]1); $h.Write([int16]1)
    $h.Write([int]$rate); $h.Write([int]($rate * 2)); $h.Write([int16]2); $h.Write([int16]16)
    $h.Write([Text.Encoding]::ASCII.GetBytes('data')); $h.Write([int]$pcm.Length); $h.Write($pcm)
    $ms2.Position = 0
    $p = New-Object System.Media.SoundPlayer($ms2)
    $p.Load()
    return $p
}
$script:sonidos = @{
    ok    = Nuevo-Tono @(1000) 110
    error = Nuevo-Tono @(300, 200) 170
    fin   = Nuevo-Tono @(660, 880, 1175) 100
}
function Sonar($tipo) { try { $script:sonidos[$tipo].Play() } catch { } }

function Tipo-Texto($t) {
    switch ($t) { 'guardar-ya' { 'Guardar ya' } default { 'Automático' } }
}

# ---------- Historial ----------
function Get-Snapshots {
    @(Get-ChildItem $histDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | ForEach-Object {
        $tipo = 'auto'; $nota = ''
        $mf = Join-Path $_.FullName '_meta.json'
        if (Test-Path $mf) { try { $j = Get-Content $mf -Raw | ConvertFrom-Json; $tipo = $j.tipo; $nota = $j.nota } catch { } }
        $fecha = $_.CreationTime
        try { $fecha = [datetime]::ParseExact($_.Name.Substring(0, 19), 'yyyy-MM-dd_HH-mm-ss', $null) } catch { }
        $cap = Join-Path $_.FullName '_captura.jpg'
        if (-not (Test-Path $cap)) { $cap = $null }
        [pscustomobject]@{ Name = $_.Name; Path = $_.FullName; Fecha = $fecha; Tipo = $tipo; Nota = "$nota"; Captura = $cap }
    })
}

function Save-Meta($snap, $tipo, $nota) {
    @{ tipo = $tipo; nota = $nota } | ConvertTo-Json | Set-Content (Join-Path $snap '_meta.json') -Encoding UTF8
}

# ---------- Capturas de pantalla ----------
# Solo si el juego es la ventana activa: si no, saldría lo que tenga encima
function Capturar-Juego {
    $p = Get-GameWindowProc
    if (-not $p) { return $null }
    $h = $p.MainWindowHandle
    if ([TABG.Native]::GetForegroundWindow() -ne $h -or [TABG.Native]::IsIconic($h)) { return $null }
    $b = [TABG.Native]::Capturar($h, 640)
    if ($b -and [TABG.Native]::EsNegra($b)) { $b.Dispose(); return $null }
    return $b
}

# Cada ~6 s mientras se juega; se guardan las últimas 5
function Capturar-Periodica {
    if (((Get-Date) - $script:ultCaptura).TotalSeconds -lt 6) { return }
    $script:ultCaptura = Get-Date
    $b = Capturar-Juego
    if (-not $b) { return }
    [void]$script:capturas.Add([pscustomobject]@{ t = Get-Date; img = $b })
    while ($script:capturas.Count -gt 5) { $script:capturas[0].img.Dispose(); $script:capturas.RemoveAt(0) }
}

# La foto de antes de que el juego empezara a guardar (no la pantalla de carga/menú)
function Captura-Antes($momento) {
    $c = @($script:capturas | Where-Object { $_.t -le $momento.AddSeconds(-2) -and $_.t -ge $momento.AddMinutes(-3) })
    if ($c.Count -gt 0) { return $c[-1].img }
    return $null
}

function Save-Captura($img, $dest) {
    $jpg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $par = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $par.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]82)
    $img.Save((Join-Path $dest '_captura.jpg'), $jpg, $par)
}

function Take-Snapshot($tipo, $captura = $null) {
    $files = @(Get-ChildItem $savesDir -File -Recurse -Force -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { return $null }
    $name = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $dest = Join-Path $histDir $name
    $k = 2
    while (Test-Path $dest) { $dest = Join-Path $histDir "${name}_$k"; $k++ }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -Path (Join-Path $savesDir '*') -Destination $dest -Recurse -Force
    Save-Meta $dest $tipo ''
    if ($captura) {
        try { Save-Captura $captura $dest } catch { Write-Log "Captura: $($_.Exception.Message)" }
    }
    Write-Log "Backup ($tipo): $dest"
    Limpiar-Historial
    Update-TrayText
    if ($script:histForm -and -not $script:histForm.IsDisposed) { Llenar-Lista }
    return $dest
}

function Limpiar-Historial {
    # Los guardados con nota no se borran nunca
    $sinNota = @(Get-Snapshots | Where-Object { -not $_.Nota })
    if ($sinNota.Count -gt $script:cfg.maxHistorial) {
        $sinNota | Select-Object -Skip $script:cfg.maxHistorial | ForEach-Object {
            Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Update-TrayText {
    $s = @(Get-Snapshots)
    if ($s.Count -gt 0) { $t = "TAB Guardian - ultimo: " + $s[0].Fecha.ToString('dd/MM HH:mm') }
    else { $t = 'TAB Guardian - sin backups todavia' }
    $script:tray.Text = $t.Substring(0, [Math]::Min(63, $t.Length))
}

# ---------- Restaurar ----------
function Restore-Snapshot($snap, [bool]$reiniciar) {
    $procs = Get-GameProcs
    $abierto = $procs.Count -gt 0
    $msg = "¿Restaurar el guardado del $($snap.Fecha.ToString('dd/MM/yyyy HH:mm:ss'))?"
    if ($snap.Nota) { $msg += "`n($($snap.Nota))" }
    if ($abierto -and $reiniciar) {
        $msg += "`n`nSe va a CERRAR el juego (perdés lo que no esté guardado) y se vuelve a abrir solo."
    } elseif ($abierto) {
        $msg += "`n`nEl juego está abierto: tenés que estar en el MENÚ PRINCIPAL, no dentro de una partida."
    }
    $r = [System.Windows.Forms.MessageBox]::Show($msg, 'TAB Guardian', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }

    $script:busy = $true
    try {
        if ($abierto -and $reiniciar) {
            $procs | ForEach-Object { try { $_.Kill() } catch { } }
            $procs | ForEach-Object { try { $_.WaitForExit(15000) | Out-Null } catch { } }
            Start-Sleep -Seconds 4    # deja que Steam termine de sincronizar
        }

        # Red de seguridad: lo que habia antes queda en _AntesDeRestaurar
        $safe = Join-Path $baseDir '_AntesDeRestaurar'
        if (Test-Path $safe) { Remove-Item $safe -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $safe | Out-Null
        if (Get-ChildItem $savesDir -Force) { Copy-Item -Path (Join-Path $savesDir '*') -Destination $safe -Recurse -Force }

        Get-ChildItem $savesDir -Force | Remove-Item -Recurse -Force
        Copy-Item -Path (Join-Path $snap.Path '*') -Destination $savesDir -Recurse -Force -Exclude '_meta.json', '_captura.jpg'

        # Fecha actual en los archivos, para que Steam Cloud los tome como los mas nuevos
        $ahora = Get-Date
        Get-ChildItem $savesDir -File -Recurse -Force | ForEach-Object { $_.LastWriteTime = $ahora }

        $script:lastSig = Get-Firma $savesDir
        $script:pendingSig = $null
        Write-Log "Restaurado: $($snap.Path)"

        if ($abierto -and $reiniciar) {
            Start-Process "steam://rungameid/$steamId"
            Notify 'Restaurado' 'Abriendo el juego... Dale a Continuar.'
        } else {
            Notify 'Restaurado' 'Listo. En el juego dale a Continuar.'
        }
    } finally {
        $script:busy = $false
    }
}

function Volver-Ultimo {
    $s = @(Get-Snapshots)
    if ($s.Count -eq 0) { Notify 'Sin backups' 'Todavía no hay ningún guardado en el historial.' 'Warning'; return }
    Restore-Snapshot $s[0] $true
}

# ---------- Guardar ya ----------
function Click-Rel($proc, $pt) {
    $proc.Refresh()
    $a = [TABG.Native]::ClientArea($proc.MainWindowHandle)
    $x = $a[0] + [int]([double]$pt.x * $a[2])
    $y = $a[1] + [int]([double]$pt.y * $a[3])
    [TABG.Native]::Click($x, $y)
}

function Guardar-Ya {
    $clicks = @($script:cfg.clicks)
    if ($clicks.Count -eq 0) {
        Notify 'Falta calibrar' 'Clic en el ícono > Calibrar "Guardar ya".' 'Warning'
        Sonar 'error'
        return
    }
    $proc = Get-GameWindowProc
    if (-not $proc) { Notify 'Juego cerrado' 'No encontré They Are Billions abierto.' 'Warning'; return }

    $script:busy = $true
    try {
        [TABG.Native]::WaitModifiersUp()
        [TABG.Native]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
        Start-Sleep -Milliseconds 400
        $sig0 = Get-Firma $savesDir
        $foto = $null
        try { $foto = Capturar-Juego } catch { }    # la partida tal cual, antes del menú

        [TABG.Native]::Esc()
        Start-Sleep -Milliseconds 900

        # Todos los clics menos el ultimo (el ultimo es "Continuar")
        $n = $clicks.Count
        $antes = if ($n -gt 1) { $n - 1 } else { $n }
        for ($i = 0; $i -lt $antes; $i++) {
            Click-Rel $proc $clicks[$i]
            Start-Sleep -Milliseconds 1200
        }

        # Esperar a que el juego termine de escribir la partida
        $t0 = Get-Date; $prev = $null; $desde = Get-Date; $ok = $false; $s = ''
        while (((Get-Date) - $t0).TotalSeconds -lt 45) {
            Start-Sleep -Milliseconds 500
            [System.Windows.Forms.Application]::DoEvents()
            $s = Get-Firma $savesDir
            if ($s -ne $sig0) {
                if ($s -ne $prev) { $prev = $s; $desde = Get-Date }
                elseif (((Get-Date) - $desde).TotalSeconds -ge 2.5) { $ok = $true; break }
            }
        }
        if (-not $ok) {
            Notify 'No se guardó' 'No detecté el guardado. Probá recalibrar.' 'Warning'
            Sonar 'error'
            return
        }

        Take-Snapshot 'guardar-ya' $foto | Out-Null
        if ($foto) { $foto.Dispose() }
        $script:lastSig = $s
        $script:pendingSig = $null

        if ($n -gt 1) {
            Start-Sleep -Milliseconds 2500     # que cargue el menu principal
            $p2 = Get-GameWindowProc
            if ($p2) {
                [TABG.Native]::SetForegroundWindow($p2.MainWindowHandle) | Out-Null
                Start-Sleep -Milliseconds 300
                Click-Rel $p2 $clicks[$n - 1]
            }
        }
        Sonar 'ok'
    } finally {
        $script:busy = $false
    }
}

# ---------- Calibracion ----------
function Calib-Empezar {
    $script:calib.Clear()
    $script:calibrando = $true
    $txt = @"
Calibración de "Guardar ya" (se hace una sola vez):

1) Entrá a una partida.
2) Apretá Esc para abrir el menú de pausa.
3) Poné el mouse ARRIBA de "Guardar y salir" y apretá Ctrl+F12
   (suena un ding). Después hacé clic vos, como siempre.
4) Si aparece una confirmación, lo mismo: mouse arriba del botón,
   Ctrl+F12, clic.
5) Ya en el menú principal: mouse arriba de "Continuar", Ctrl+F12, clic.
6) Apretá Ctrl+F11 para terminar.

Si cambiás la resolución del juego no hace falta recalibrar.
"@
    [System.Windows.Forms.MessageBox]::Show($txt, 'TAB Guardian - Calibrar', 'OK', 'Information') | Out-Null
}

function Calib-Punto {
    if (-not $script:calibrando) { return }
    $proc = Get-GameWindowProc
    if (-not $proc) { Sonar 'error'; return }
    $a = [TABG.Native]::ClientArea($proc.MainWindowHandle)
    $c = [TABG.Native]::Cursor()
    if ($a[2] -le 0 -or $a[3] -le 0) { Sonar 'error'; return }
    $pt = [pscustomobject]@{
        x = [Math]::Round(($c[0] - $a[0]) / $a[2], 4)
        y = [Math]::Round(($c[1] - $a[1]) / $a[3], 4)
    }
    [void]$script:calib.Add($pt)
    Sonar 'ok'
    Write-Log "Calibracion punto $($script:calib.Count): $($pt.x), $($pt.y)"
}

function Calib-Fin {
    if (-not $script:calibrando) { return }
    $script:calibrando = $false
    if ($script:calib.Count -eq 0) {
        Notify 'Calibración cancelada' 'No se grabó ningún punto.' 'Warning'
        return
    }
    $script:cfg.clicks = @($script:calib.ToArray())
    Save-Config
    Sonar 'fin'
    Notify 'Calibración lista' "Se grabaron $($script:calib.Count) clics. Ya podés usar Ctrl+F5."
}

# ---------- Ventana de historial ----------
function Llenar-Lista {
    $lv = $script:lv
    $lv.BeginUpdate()
    $lv.Items.Clear()
    foreach ($s in Get-Snapshots) {
        $it = New-Object System.Windows.Forms.ListViewItem($s.Fecha.ToString('dd/MM/yyyy  HH:mm:ss'))
        [void]$it.SubItems.Add((Tipo-Texto $s.Tipo))
        [void]$it.SubItems.Add($s.Nota)
        $it.Tag = $s
        if ($s.Nota) { $it.Font = New-Object System.Drawing.Font($lv.Font, [System.Drawing.FontStyle]::Bold) }
        [void]$lv.Items.Add($it)
    }
    $lv.EndUpdate()
    try { Mostrar-Preview } catch { }
}

function Mostrar-Preview {
    $pb = $script:pb
    if (-not $pb) { return }
    if ($pb.Image) { $pb.Image.Dispose(); $pb.Image = $null }
    $s = $null
    if ($script:lv.SelectedItems.Count -gt 0) { $s = $script:lv.SelectedItems[0].Tag }
    if ($s -and $s.Captura) {
        # Se lee a memoria para no dejar el .jpg bloqueado (si no, no se puede borrar)
        $ms = New-Object System.IO.MemoryStream(,[System.IO.File]::ReadAllBytes($s.Captura))
        $pb.Image = [System.Drawing.Image]::FromStream($ms)
        $script:pbTexto.Visible = $false
    } else {
        $script:pbTexto.Text = if ($s) { 'Este guardado no tiene captura' } else { 'Elegí un guardado para ver la captura' }
        $script:pbTexto.Visible = $true
    }
}

function Seleccionado {
    if ($script:lv.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Elegí un guardado de la lista.', 'TAB Guardian') | Out-Null
        return $null
    }
    return $script:lv.SelectedItems[0].Tag
}

function Safe([scriptblock]$b) {
    try { & $b }
    catch {
        Write-Log "ERROR: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)", 'TAB Guardian', 'OK', 'Error') | Out-Null
    }
}

function Nuevo-Boton($texto, $accion) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $texto
    $b.AutoSize = $true
    $b.Padding = New-Object System.Windows.Forms.Padding(6, 2, 6, 2)
    $b.Margin = New-Object System.Windows.Forms.Padding(4)
    $b.add_Click($accion)
    return $b
}

function Mostrar-Historial {
    if ($script:histForm -and -not $script:histForm.IsDisposed) {
        Llenar-Lista; $script:histForm.Activate(); return
    }
    $f = New-Object System.Windows.Forms.Form
    $f.Text = 'TAB Guardian by Tinisan - Historial de guardados'
    $f.Size = New-Object System.Drawing.Size(1100, 580)
    $f.MinimumSize = New-Object System.Drawing.Size(800, 400)
    $f.StartPosition = 'CenterScreen'
    $f.Icon = $script:icon
    $f.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $lv = New-Object System.Windows.Forms.ListView
    $lv.View = 'Details'; $lv.FullRowSelect = $true; $lv.MultiSelect = $false
    $lv.HideSelection = $false; $lv.Dock = 'Fill'
    [void]$lv.Columns.Add('Fecha', 160)
    [void]$lv.Columns.Add('Tipo', 95)
    [void]$lv.Columns.Add('Nota', 230)
    $lv.add_DoubleClick({ Safe { $s = Seleccionado; if ($s) { Restore-Snapshot $s $true } } })
    $lv.add_SelectedIndexChanged({ try { Mostrar-Preview } catch { } })
    $script:lv = $lv

    # Captura del guardado elegido (a la derecha)
    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Dock = 'Fill'; $pb.SizeMode = 'Zoom'; $pb.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 24)
    $pb.Cursor = [System.Windows.Forms.Cursors]::Hand
    $pb.add_DoubleClick({
        if ($script:lv.SelectedItems.Count -gt 0 -and $script:lv.SelectedItems[0].Tag.Captura) {
            Start-Process $script:lv.SelectedItems[0].Tag.Captura
        }
    })
    $script:pb = $pb
    $pbTexto = New-Object System.Windows.Forms.Label
    $pbTexto.Dock = 'Fill'; $pbTexto.TextAlign = 'MiddleCenter'
    $pbTexto.ForeColor = [System.Drawing.Color]::Gainsboro; $pbTexto.BackColor = $pb.BackColor
    $script:pbTexto = $pbTexto

    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = 'Fill'
    $split.Panel1.Controls.Add($lv)
    $split.Panel2.Controls.Add($pbTexto)
    $split.Panel2.Controls.Add($pb)

    $info = New-Object System.Windows.Forms.Label
    $info.Text = 'Doble clic = restaurar (cierra y reabre el juego). Con nota (en negrita) no se borran nunca. Doble clic en la foto = verla en grande.'
    $info.Dock = 'Top'; $info.Height = 28; $info.TextAlign = 'MiddleLeft'
    $info.Padding = New-Object System.Windows.Forms.Padding(6, 0, 0, 0)

    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = 'Bottom'; $panel.AutoSize = $true; $panel.Padding = New-Object System.Windows.Forms.Padding(4)
    $panel.Controls.Add((Nuevo-Boton 'Restaurar (cierra y abre el juego)' { Safe { $s = Seleccionado; if ($s) { Restore-Snapshot $s $true } } }))
    $panel.Controls.Add((Nuevo-Boton 'Restaurar (ya estoy en el menú)' { Safe { $s = Seleccionado; if ($s) { Restore-Snapshot $s $false } } }))
    $panel.Controls.Add((Nuevo-Boton 'Nota...' {
        Safe {
            $s = Seleccionado
            if ($s) {
                $n = [Microsoft.VisualBasic.Interaction]::InputBox('Nota para este guardado (ej: "día 40, antes de la horda"):', 'TAB Guardian', $s.Nota)
                Save-Meta $s.Path $s.Tipo $n
                Llenar-Lista
            }
        }
    }))
    $panel.Controls.Add((Nuevo-Boton 'Borrar' {
        Safe {
            $s = Seleccionado
            if ($s) {
                $r = [System.Windows.Forms.MessageBox]::Show("¿Borrar el guardado del $($s.Fecha.ToString('dd/MM HH:mm:ss'))?", 'TAB Guardian', 'YesNo', 'Warning')
                if ($r -eq 'Yes') { Remove-Item $s.Path -Recurse -Force; Llenar-Lista; Update-TrayText }
            }
        }
    }))
    $panel.Controls.Add((Nuevo-Boton 'Abrir carpeta' { Start-Process explorer.exe $histDir }))
    $panel.Controls.Add((Nuevo-Boton 'Cómo se usa' { Safe { Mostrar-Ayuda } }))

    $f.Controls.Add($split)
    $f.Controls.Add($info)
    $f.Controls.Add($panel)
    $script:histForm = $f
    Llenar-Lista
    $f.Show()
    $split.SplitterDistance = 500
    if ($lv.Items.Count -gt 0) { $lv.Items[0].Selected = $true }   # muestra la foto del último
}

# ---------- Ayuda ----------
$script:ayudaTexto = @"
QUÉ HACE
TAB Guardian queda al lado del reloj (con el ícono del juego). Cada vez que They Are Billions guarda la partida ("Guardar y salir" o el backup automático), saca una copia con fecha y hora. Así tenés un historial para volver atrás si te comen.

PRIMERA VEZ: CALIBRAR "GUARDAR YA" (una sola vez)
1) Clic en el ícono (al lado del reloj) > Calibrar "Guardar ya"...
2) Entrá a una partida y apretá Esc.
3) Mouse arriba de "Guardar y salir" > Ctrl+F12 (suena un ding) > hacé clic vos.
4) Si aparece una confirmación: mouse arriba del botón > Ctrl+F12 > clic.
5) En el menú principal: mouse arriba de "Continuar" > Ctrl+F12 > clic.
6) Apretá Ctrl+F11 para terminar.

ATAJOS MIENTRAS JUGÁS
Ctrl+F5   Guardar ya: guarda, copia la partida y vuelve a entrar solo.
Ctrl+F9   Volver al último guardado: cierra el juego, restaura y lo reabre. Después dale a Continuar.

VOLVER A UN GUARDADO MÁS VIEJO
Clic en el ícono > Ver historial. A la derecha ves una captura de la partida de cada guardado (para saber cuál es cuál; doble clic en la foto la abre en grande):
- Restaurar (cierra y abre el juego): sirve aunque estés jugando.
- Restaurar (ya estoy en el menú): si ya estás en el menú principal.
- Nota...: ponele un nombre (ej: "día 40, antes de la horda"). Los que tienen nota se ven en negrita y no se borran nunca.
- Borrar / Abrir carpeta.

TENÉ EN CUENTA
- No restaures con una partida abierta sin cerrar el juego: al salir, el juego pisa los archivos (las opciones de restaurar ya lo manejan).
- Si Ctrl+F5 no hace nada o las capturas no aparecen, poné el juego en "ventana sin bordes" (en pantalla completa la foto sale negra y se descarta).
- Si Steam muestra un conflicto de guardado en la nube, elegí los archivos LOCALES.
- Antes de cada restauración, lo que había queda en SaveSlots\_AntesDeRestaurar.
- Se guardan hasta $($script:cfg.maxHistorial) backups sin nota; los más viejos se borran solos.
- Backups y registro (guardian.log) en:
  $baseDir

Esta ayuda la volvés a ver con clic en el ícono > Cómo se usa.

------------------------------------------------------------
TAB Guardian by Tinisan
Consultas, errores o ideas: tinisan.gesell@gmail.com
"@

function Mostrar-Ayuda {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = 'TAB Guardian by Tinisan - Cómo se usa'
    $f.Size = New-Object System.Drawing.Size(640, 600)
    $f.StartPosition = 'CenterScreen'
    $f.Icon = $script:icon
    $f.Font = New-Object System.Drawing.Font('Segoe UI', 10)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true; $tb.ReadOnly = $true; $tb.ScrollBars = 'Vertical'
    $tb.Dock = 'Fill'; $tb.BackColor = [System.Drawing.SystemColors]::Window
    $tb.Text = $script:ayudaTexto -replace "(?<!`r)`n", "`r`n"

    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = 'Bottom'; $panel.AutoSize = $true; $panel.FlowDirection = 'RightToLeft'
    $panel.Padding = New-Object System.Windows.Forms.Padding(4)
    # En los eventos $this es el botón ($f ya no existe cuando se hace clic)
    $ok = Nuevo-Boton 'Entendido' { $this.FindForm().Close() }
    $panel.Controls.Add($ok)
    $panel.Controls.Add((Nuevo-Boton 'Calibrar "Guardar ya"...' { $this.FindForm().Close(); Safe { Calib-Empezar } }))

    $f.Controls.Add($tb)
    $f.Controls.Add($panel)
    $f.AcceptButton = $ok
    $f.ActiveControl = $ok    # si no, el texto aparece todo seleccionado
    $f.Show()
    $f.Activate()
}

# ---------- Inicio con Windows ----------
function Set-Autostart([bool]$on) {
    if ($on) {
        $sh = New-Object -ComObject WScript.Shell
        $l = $sh.CreateShortcut($startLnk)
        if ($esExe) {
            $l.TargetPath = $exePath
        } else {
            $l.TargetPath = 'wscript.exe'
            $l.Arguments = "`"$vbsPath`""
        }
        $l.WorkingDirectory = $appDir
        $l.Description = 'TAB Guardian - backups de They Are Billions'
        $l.Save()
    } else {
        Remove-Item $startLnk -ErrorAction SilentlyContinue
    }
}

# ---------- Icono ----------
function Icono-Generado {
$bmp = New-Object System.Drawing.Bitmap 32, 32
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(176, 96, 24))), 1, 1, 30, 30)
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
$g.DrawString('TB', (New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)), [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 1, 32, 32)), $fmt)
$g.Dispose()
return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}
# El .ico del juego si está al lado del programa; si no, el "TB" naranja dibujado
$script:icon = $null
if (Test-Path $icoPath) {
    try { $script:icon = New-Object System.Drawing.Icon($icoPath, [System.Windows.Forms.SystemInformation]::SmallIconSize) } catch { }
}
if (-not $script:icon) { $script:icon = Icono-Generado }

# ---------- Bandeja del sistema ----------
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:tray = New-Object System.Windows.Forms.NotifyIcon
$script:tray.Icon = $script:icon
$script:tray.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
function Item($texto, $accion) {
    $i = New-Object System.Windows.Forms.ToolStripMenuItem($texto)
    if ($accion) { $i.add_Click($accion) }
    [void]$menu.Items.Add($i)
    return $i
}
$titulo = Item 'TAB Guardian by Tinisan - vigilando partidas' $null
$titulo.Enabled = $false
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$verHist = Item 'Ver historial...' { Safe { Mostrar-Historial } }
$verHist.Font = New-Object System.Drawing.Font($verHist.Font, [System.Drawing.FontStyle]::Bold)
[void](Item 'Guardar ya   (Ctrl+F5)' { Safe { Guardar-Ya } })
[void](Item 'Volver al último guardado   (Ctrl+F9)' { Safe { Volver-Ultimo } })
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
[void](Item 'Calibrar "Guardar ya"...' { Safe { Calib-Empezar } })
[void](Item 'Cómo se usa...' { Safe { Mostrar-Ayuda } })
$auto = Item 'Iniciar con Windows' $null
$auto.CheckOnClick = $true
$auto.Checked = (Test-Path $startLnk)
$auto.add_CheckedChanged({ Safe { Set-Autostart $auto.Checked } })
[void](Item 'Abrir carpeta de backups' { Start-Process explorer.exe $histDir })
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
[void](Item 'Salir' {
    $script:timer.Stop()
    $script:tray.Visible = $false
    $script:hk.Close()
    try { $mutex.ReleaseMutex() } catch { }
    [System.Windows.Forms.Application]::Exit()
})
$script:tray.ContextMenuStrip = $menu
# El menú se abre con cualquier clic (izquierdo o derecho)
$script:tray.add_MouseUp({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [System.Windows.Forms.NotifyIcon].GetMethod('ShowContextMenu', [Reflection.BindingFlags]'Instance,NonPublic').Invoke($script:tray, $null)
    }
})

# ---------- Teclas rapidas ----------
$script:hk = New-Object TABG.HotkeyWin
$MOD_CTRL = 0x0002; $NOREPEAT = 0x4000
$teclas = @(
    @{ id = 1; vk = 0x74; nombre = 'Ctrl+F5'  },
    @{ id = 2; vk = 0x78; nombre = 'Ctrl+F9'  },
    @{ id = 3; vk = 0x7B; nombre = 'Ctrl+F12' },
    @{ id = 4; vk = 0x7A; nombre = 'Ctrl+F11' }
)
$fallidas = @()
foreach ($t in $teclas) {
    if (-not $script:hk.Register($t.id, $MOD_CTRL -bor $NOREPEAT, $t.vk)) { $fallidas += $t.nombre }
}
$script:hk.OnHotkey = [Action[int]] {
    param($id)
    Safe {
        switch ($id) {
            1 { Guardar-Ya }
            2 { Volver-Ultimo }
            3 { Calib-Punto }
            4 { Calib-Fin }
        }
    }
}

# ---------- Vigilancia de la carpeta Saves ----------
function Tick {
    if ($script:busy) { return }
    $s = Get-Firma $savesDir
    if ($s -eq $script:lastSig) {
        $script:pendingSig = $null
        try { Capturar-Periodica } catch { }
        return
    }
    if ($s -ne $script:pendingSig) {
        if (-not $script:pendingSig) { $script:primerCambio = Get-Date }   # cuando empezó a guardar
        $script:pendingSig = $s; $script:pendingTime = Get-Date; return
    }
    # Esperamos 4 s sin cambios para no copiar a mitad de escritura
    if (((Get-Date) - $script:pendingTime).TotalSeconds -ge 4) {
        $script:lastSig = $s
        $script:pendingSig = $null
        Take-Snapshot 'auto' (Captura-Antes $script:primerCambio) | Out-Null
    }
}

$script:lastSig = Get-Firma $savesDir
if (@(Get-Snapshots).Count -eq 0) { Take-Snapshot 'auto' | Out-Null }
Update-TrayText

$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 2000
$script:timer.add_Tick({ try { Tick } catch { Write-Log "Tick: $($_.Exception.Message)" } })
$script:timer.Start()

Write-Log 'TAB Guardian iniciado'
if ($fallidas.Count -gt 0) {
    Notify 'Atajos ocupados' "Otro programa usa: $($fallidas -join ', '). Usá el menú del icono." 'Warning'
} elseif (@($script:cfg.clicks).Count -eq 0) {
    Notify 'TAB Guardian activo' 'Ya guardo cada partida sola. Para usar Ctrl+F5 (Guardar ya), calibrá desde el menú del icono.'
} else {
    Notify 'TAB Guardian activo' 'Ctrl+F5 guardar ya · Ctrl+F9 volver al último guardado.'
}

# La primera vez que se abre, mostrar cómo se usa
if (-not $script:cfg.ayudaVista) {
    $script:cfg.ayudaVista = $true
    Save-Config
    Safe { Mostrar-Ayuda }
}

$ctx = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($ctx)
