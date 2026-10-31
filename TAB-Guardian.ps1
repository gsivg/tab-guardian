# ==================================================================
#  TAB Guardian - guardado automatico para They Are Billions
#  by Tinisan - tinisan.gesell@gmail.com
#
#  - Corre en segundo plano (icono al lado del reloj).
#  - Cada vez que el juego escribe la partida, guarda una copia
#    con fecha, hora y captura de pantalla en el historial.
#  - Ctrl+F5  -> "Guardar ya" (Esc + Guardar y salir + Continuar)
#  - Ctrl+F9  -> Volver al ultimo guardado (cierra y reabre el juego)
#  - Ctrl+F12 / Ctrl+F11 -> grabar puntos / terminar calibracion
#  - Espanol / ingles (idioma de Windows, del instalador o elegido).
#
#  Se abre con TAB-Guardian.vbs (sin ventana negra), o compilado
#  como TAB-Guardian.exe con build.ps1 (ver instalador.iss).
# ==================================================================

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# ---------- Funciones nativas y controles con tema oscuro ----------
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
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
        [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int val, int size);
        [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] static extern int SetWindowTheme(IntPtr h, string app, string id);

        // Barra de titulo oscura (Windows 10 2004+ / 11)
        public static void DarkTitle(IntPtr h) {
            int on = 1;
            if (DwmSetWindowAttribute(h, 20, ref on, 4) != 0) DwmSetWindowAttribute(h, 19, ref on, 4);
        }
        // Barras de desplazamiento oscuras
        public static void DarkScroll(IntPtr h) { SetWindowTheme(h, "DarkMode_Explorer", null); }
        // En listas, "DarkMode_Explorer" dibuja lineas de columna en la parte vacia
        public static void DarkList(IntPtr h) { SetWindowTheme(h, "DarkMode_ItemsView", null); }

        // Area de juego en pantalla: x, y, ancho, alto
        public static int[] ClientArea(IntPtr h) {
            RECT r; GetClientRect(h, out r);
            POINT p = new POINT(); ClientToScreen(h, ref p);
            return new int[] { p.X, p.Y, r.R, r.B };
        }
        public static int[] Cursor() { POINT p; GetCursorPos(out p); return new int[] { p.X, p.Y }; }

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

    public static class Paleta {
        public static Color Fondo   = Color.FromArgb(27, 27, 30);
        public static Color Panel   = Color.FromArgb(36, 36, 40);
        public static Color Alterno = Color.FromArgb(32, 32, 36);
        public static Color Sup     = Color.FromArgb(50, 50, 56);
        public static Color Hover   = Color.FromArgb(64, 64, 72);
        public static Color Borde   = Color.FromArgb(66, 66, 74);
        public static Color Texto   = Color.FromArgb(236, 236, 236);
        public static Color Tenue   = Color.FromArgb(150, 150, 158);
        public static Color Acento  = Color.FromArgb(224, 112, 31);
        public static Color AcentoH = Color.FromArgb(242, 138, 58);
        public static Color Peligro = Color.FromArgb(214, 72, 60);
        public static Color Exito   = Color.FromArgb(76, 175, 80);
    }

    // Menu del icono con tema oscuro
    public class DarkColors : ProfessionalColorTable {
        public override Color ToolStripDropDownBackground { get { return Paleta.Panel; } }
        public override Color MenuBorder { get { return Paleta.Borde; } }
        public override Color MenuItemBorder { get { return Paleta.Hover; } }
        public override Color MenuItemSelected { get { return Paleta.Hover; } }
        public override Color MenuItemSelectedGradientBegin { get { return Paleta.Hover; } }
        public override Color MenuItemSelectedGradientEnd { get { return Paleta.Hover; } }
        public override Color MenuItemPressedGradientBegin { get { return Paleta.Hover; } }
        public override Color MenuItemPressedGradientEnd { get { return Paleta.Hover; } }
        public override Color ImageMarginGradientBegin { get { return Paleta.Panel; } }
        public override Color ImageMarginGradientMiddle { get { return Paleta.Panel; } }
        public override Color ImageMarginGradientEnd { get { return Paleta.Panel; } }
        public override Color SeparatorDark { get { return Paleta.Borde; } }
        public override Color SeparatorLight { get { return Paleta.Panel; } }
    }
    public class DarkRenderer : ToolStripProfessionalRenderer {
        public DarkRenderer() : base(new DarkColors()) { RoundedEdges = false; }
        protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e) {
            if (e.Item.Tag is Color) e.TextColor = (Color)e.Item.Tag;
            else e.TextColor = e.Item.Enabled ? Paleta.Texto : Paleta.Tenue;
            base.OnRenderItemText(e);
        }
    }

    // Lista del historial con tema oscuro
    public class DarkListView : ListView {
        Font negrita, cabecera;
        Font Negrita { get { if (negrita == null) negrita = new Font(Font, FontStyle.Bold); return negrita; } }
        Font Cabecera { get { if (cabecera == null) cabecera = new Font(Font.FontFamily, 8f, FontStyle.Bold); return cabecera; } }
        protected override void OnFontChanged(EventArgs e) { negrita = null; cabecera = null; base.OnFontChanged(e); }
        public DarkListView() {
            OwnerDraw = true; View = View.Details; FullRowSelect = true; MultiSelect = false;
            HideSelection = false; DoubleBuffered = true; BorderStyle = BorderStyle.None;
            HeaderStyle = ColumnHeaderStyle.Nonclickable;
            BackColor = Paleta.Fondo; ForeColor = Paleta.Texto;
            SmallImageList = new ImageList(); SmallImageList.ImageSize = new Size(1, 30);   // filas mas altas
        }
        protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); Native.DarkList(Handle); }
        protected override void OnDrawColumnHeader(DrawListViewColumnHeaderEventArgs e) {
            using (SolidBrush b = new SolidBrush(Paleta.Panel)) e.Graphics.FillRectangle(b, e.Bounds);
            using (Pen p = new Pen(Paleta.Borde)) e.Graphics.DrawLine(p, e.Bounds.Left, e.Bounds.Bottom - 1, e.Bounds.Right, e.Bounds.Bottom - 1);
            Rectangle r = new Rectangle(e.Bounds.X + 10, e.Bounds.Y, e.Bounds.Width - 12, e.Bounds.Height);
            TextRenderer.DrawText(e.Graphics, e.Header.Text.ToUpper(), Cabecera, r, Paleta.Tenue,
                TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix);
        }
        protected override void OnDrawItem(DrawListViewItemEventArgs e) { }
        protected override void OnDrawSubItem(DrawListViewSubItemEventArgs e) {
            bool sel = e.Item.Selected;
            Color fondo = sel ? Paleta.Hover : (e.ItemIndex % 2 == 0 ? Paleta.Fondo : Paleta.Alterno);
            using (SolidBrush b = new SolidBrush(fondo)) e.Graphics.FillRectangle(b, e.Bounds);
            if (sel && e.ColumnIndex == 0)
                using (SolidBrush b = new SolidBrush(Paleta.Acento)) e.Graphics.FillRectangle(b, e.Bounds.X, e.Bounds.Y, 3, e.Bounds.Height);
            bool conNota = e.Item.SubItems.Count > 2 && e.Item.SubItems[2].Text.Length > 0;
            Color color = Paleta.Texto;
            if (e.ColumnIndex == 1) color = Paleta.Tenue;
            if (e.ColumnIndex == 2) color = Paleta.Acento;
            string txt = e.SubItem.Text;
            if (e.ColumnIndex == 2 && conNota) txt = "\u2605  " + txt;
            Font f = (conNota && e.ColumnIndex != 1) ? Negrita : Font;
            Rectangle r = new Rectangle(e.Bounds.X + 10, e.Bounds.Y, e.Bounds.Width - 12, e.Bounds.Height);
            TextRenderer.DrawText(e.Graphics, txt, f, r, color,
                TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix);
        }
    }

    // Encabezado con la imagen, degradado y titulo
    public class Banner : Panel {
        public Image Imagen;
        public string Titulo = "", Sub = "", Autor = "";
        public Banner() { DoubleBuffered = true; ResizeRedraw = true; BackColor = Color.FromArgb(18, 18, 20); }
        protected override void OnPaint(PaintEventArgs e) {
            Graphics g = e.Graphics;
            if (Width < 4 || Height < 4) return;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            if (Imagen != null) {
                float s = Math.Max((float)Width / Imagen.Width, (float)Height / Imagen.Height);
                int w = (int)(Imagen.Width * s), h = (int)(Imagen.Height * s);
                g.DrawImage(Imagen, (Width - w) / 2, (int)((Height - h) * 0.35), w, h);
            }
            using (LinearGradientBrush br = new LinearGradientBrush(ClientRectangle,
                    Color.FromArgb(245, 18, 18, 20), Color.FromArgb(40, 18, 18, 20), 0f))
                g.FillRectangle(br, ClientRectangle);
            using (SolidBrush b = new SolidBrush(Paleta.Acento)) g.FillRectangle(b, 0, Height - 3, Width, 3);
            using (Font ft = new Font("Segoe UI", 20f, FontStyle.Bold))
                TextRenderer.DrawText(g, Titulo, ft, new Point(22, Height / 2 - 30), Color.White, TextFormatFlags.NoPrefix);
            using (Font fs = new Font("Segoe UI", 10f))
                TextRenderer.DrawText(g, Sub, fs, new Point(25, Height / 2 + 8), Color.FromArgb(205, 205, 210), TextFormatFlags.NoPrefix);
            using (Font fa = new Font("Segoe UI", 9f, FontStyle.Bold)) {
                Size sz = TextRenderer.MeasureText(Autor, fa);
                TextRenderer.DrawText(g, Autor, fa, new Point(Width - sz.Width - 16, Height - sz.Height - 10), Paleta.AcentoH, TextFormatFlags.NoPrefix);
            }
        }
    }

    // Aviso propio abajo a la derecha (no roba el foco del juego)
    public class Toast : Form {
        static Toast actual;
        System.Windows.Forms.Timer t;
        int ticks;
        Color acento; string titulo, texto; Image icono;

        public static void Mostrar(string titulo, string texto, Color acento, Image icono) {
            if (actual != null && !actual.IsDisposed) actual.Close();
            actual = new Toast(titulo, texto, acento, icono);
            actual.Show();
        }
        Toast(string titulo, string texto, Color acento, Image icono) {
            this.titulo = titulo; this.texto = texto; this.acento = acento; this.icono = icono;
            FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true;
            StartPosition = FormStartPosition.Manual; BackColor = Paleta.Panel; DoubleBuffered = true;
            Size = new Size(380, 86);
            Rectangle wa = Screen.PrimaryScreen.WorkingArea;
            Location = new Point(wa.Right - Width - 18, wa.Bottom - Height - 18);
            Cursor = Cursors.Hand;
            Click += delegate { Close(); };
            t = new System.Windows.Forms.Timer(); t.Interval = 50; t.Tick += OnTick; t.Start();
        }
        protected override bool ShowWithoutActivation { get { return true; } }
        protected override CreateParams CreateParams {
            get { CreateParams cp = base.CreateParams; cp.ExStyle |= 0x08000000 | 0x80 | 0x8; return cp; }
        }
        void OnTick(object s, EventArgs e) {
            ticks++;
            if (ticks > 90) { Opacity -= 0.1; if (Opacity <= 0.05) { t.Stop(); Close(); } }
        }
        protected override void OnPaint(PaintEventArgs e) {
            Graphics g = e.Graphics;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            using (Pen p = new Pen(Paleta.Borde)) g.DrawRectangle(p, 0, 0, Width - 1, Height - 1);
            using (SolidBrush b = new SolidBrush(acento)) g.FillRectangle(b, 0, 0, 5, Height);
            int x = 20;
            if (icono != null) { g.DrawImage(icono, 20, (Height - 44) / 2, 44, 44); x = 76; }
            using (Font ft = new Font("Segoe UI", 10.5f, FontStyle.Bold))
                TextRenderer.DrawText(g, titulo, ft, new Rectangle(x, 14, Width - x - 14, 24), Paleta.Texto,
                    TextFormatFlags.Left | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix);
            using (Font fx = new Font("Segoe UI", 9.5f))
                TextRenderer.DrawText(g, texto, fx, new Rectangle(x, 38, Width - x - 14, Height - 44), Paleta.Tenue,
                    TextFormatFlags.Left | TextFormatFlags.WordBreak | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix);
        }
        protected override void Dispose(bool d) { if (d && t != null) t.Dispose(); base.Dispose(d); }
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
$startLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'TAB Guardian.lnk'
$steamId  = '644930'
$repo     = 'gsivg/tab-guardian'
$script:version = if ($esExe) { [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath).FileVersion } else { 'dev' }

# Imagenes al lado del programa (sin compilar: las que genera build.ps1 en build\)
function Recurso($nombre) {
    foreach ($d in $appDir, (Join-Path $appDir 'build')) {
        $p = Join-Path $d $nombre
        if (Test-Path $p) { return $p }
    }
    return $null
}

# ---------- Configuracion ----------
$script:cfg = [pscustomobject]@{
    clicks = @(); maxHistorial = 200; ayudaVista = $false
    idioma = ''; sonidos = $true; capturas = $true; avisos = $true; actualizaciones = $true
}
if (Test-Path $cfgFile) {
    try {
        $c = Get-Content $cfgFile -Raw | ConvertFrom-Json
        foreach ($p in $c.PSObject.Properties) {
            if ($script:cfg.PSObject.Properties[$p.Name]) { $script:cfg.($p.Name) = $p.Value }
        }
        $script:cfg.clicks = @($script:cfg.clicks)
    } catch { }
}
function Save-Config {
    New-Item -ItemType Directory -Force -Path $baseDir | Out-Null
    $script:cfg | ConvertTo-Json -Depth 5 | Set-Content $cfgFile -Encoding UTF8
}

function Write-Log($m) {
    try { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Add-Content $logFile -Encoding UTF8 } catch { }
}

# ---------- Textos (es / en) ----------
$script:textos = @{
es = @{
    yaAbierto        = 'TAB Guardian ya está abierto. Buscá el ícono al lado del reloj.'
    sinCarpeta       = "No encontré la carpeta de partidas:`n{0}`n`nAbrí el juego, guardá una partida y volvé a abrir TAB Guardian."
    bannerSub        = 'Guardado automático para They Are Billions'
    tipoGuardarYa    = 'Guardar ya'
    tipoAuto         = 'Automático'
    fmtFecha         = 'dd/MM/yyyy   HH:mm:ss'
    fmtCorta         = 'dd/MM HH:mm'
    trayUltimo       = 'TAB Guardian - último: {0}'
    traySin          = 'TAB Guardian - sin backups todavía'
    restaurarTit     = 'Restaurar guardado'
    restaurarPreg    = '¿Restaurar el guardado del {0}?'
    restaurarCierra  = 'Se va a CERRAR el juego (perdés lo que no esté guardado) y se vuelve a abrir solo.'
    restaurarMenu    = 'El juego está abierto: tenés que estar en el MENÚ PRINCIPAL, no dentro de una partida.'
    restauradoTit    = 'Restaurado'
    restauradoAbre   = 'Abriendo el juego... Dale a Continuar.'
    restauradoListo  = 'Listo. En el juego dale a Continuar.'
    sinBackupsTit    = 'Sin backups'
    sinBackupsTxt    = 'Todavía no hay ningún guardado en el historial.'
    faltaCalibTit    = 'Falta calibrar'
    faltaCalibTxt    = 'Clic en el ícono > Calibrar "Guardar ya".'
    juegoCerradoTit  = 'Juego cerrado'
    juegoCerradoTxt  = 'No encontré They Are Billions abierto.'
    noGuardoTit      = 'No se guardó'
    noGuardoTxt      = 'No detecté el guardado. Probá recalibrar.'
    guardadoTit      = 'Partida guardada'
    guardadoTxt      = '{0}  ·  {1}'
    calibTit         = 'Calibrar "Guardar ya"'
    calibTxt         = @'
Se hace una sola vez:

1)  Entrá a una partida y apretá Esc para abrir el menú de pausa.
2)  Poné el mouse ARRIBA de "Guardar y salir" y apretá Ctrl+F12 (suena un pitido). Después hacé clic vos, como siempre.
3)  Si aparece una confirmación, lo mismo: mouse arriba del botón, Ctrl+F12, clic.
4)  Ya en el menú principal: mouse arriba de "Continuar", Ctrl+F12, clic.
5)  Apretá Ctrl+F11 para terminar.

Si cambiás la resolución del juego no hace falta recalibrar.
'@
    calibCancelTit   = 'Calibración cancelada'
    calibCancelTxt   = 'No se grabó ningún punto.'
    calibListaTit    = 'Calibración lista'
    calibListaTxt    = 'Se grabaron {0} clics. Ya podés usar Ctrl+F5.'
    noCaptura        = 'Este guardado no tiene captura'
    elegiCaptura     = 'Elegí un guardado para ver la captura'
    elegiGuardado    = 'Elegí un guardado de la lista.'
    histTit          = 'Historial de guardados'
    colFecha         = 'Fecha'
    colTipo          = 'Tipo'
    colNota          = 'Nota'
    histInfo         = 'Doble clic = restaurar  ·  ★ con nota: no se borran nunca  ·  Doble clic en la foto = verla en grande'
    btnRestaurar     = '▶  Restaurar'
    btnRestMenu      = 'Restaurar (ya estoy en el menú)'
    btnNota          = 'Nota…'
    btnBorrar        = 'Borrar'
    btnCarpeta       = 'Abrir carpeta'
    btnAyuda         = 'Cómo se usa'
    notaTit          = 'Nota'
    notaPreg         = 'Nota para este guardado (ej: "día 40, antes de la horda"):'
    borrarTit        = 'Borrar guardado'
    borrarPreg       = '¿Borrar el guardado del {0}?'
    ayudaTit         = 'Cómo se usa'
    ayudaTxt         = @'
# Qué hace
TAB Guardian queda al lado del reloj. Cada vez que They Are Billions guarda la partida ("Guardar y salir" o el backup automático), saca una copia con fecha, hora y una captura de pantalla. Así tenés un historial para volver atrás si te comen.

# Primera vez: calibrar "Guardar ya" (una sola vez)
1)  Clic en el ícono (al lado del reloj) > Calibrar "Guardar ya"…
2)  Entrá a una partida y apretá Esc.
3)  Mouse arriba de "Guardar y salir" > Ctrl+F12 (suena un pitido) > hacé clic vos.
4)  Si aparece una confirmación: mouse arriba del botón > Ctrl+F12 > clic.
5)  En el menú principal: mouse arriba de "Continuar" > Ctrl+F12 > clic.
6)  Apretá Ctrl+F11 para terminar.

# Atajos mientras jugás
Ctrl+F5    Guardar ya: guarda, copia la partida y vuelve a entrar solo.
Ctrl+F9    Volver al último guardado: cierra el juego, restaura y lo reabre. Después dale a Continuar.

# Volver a un guardado más viejo
Clic en el ícono > Ver historial. A la derecha ves la captura de cada guardado (doble clic en la foto la abre en grande).
•  Restaurar: sirve aunque estés jugando (cierra y abre el juego).
•  Restaurar (ya estoy en el menú): si ya estás en el menú principal.
•  Nota…: ponele un nombre (ej: "día 40, antes de la horda"). Los que tienen nota se marcan con ★ y no se borran nunca.
•  Borrar / Abrir carpeta.

# Tené en cuenta
•  No restaures con una partida abierta sin cerrar el juego: al salir, el juego pisa los archivos (las opciones de restaurar ya lo manejan).
•  Si Ctrl+F5 no hace nada o las capturas no aparecen, poné el juego en "ventana sin bordes" (en pantalla completa la foto sale negra y se descarta).
•  Si Steam muestra un conflicto de guardado en la nube, elegí los archivos LOCALES.
•  Antes de cada restauración, lo que había queda en SaveSlots\_AntesDeRestaurar.
•  Se guardan hasta {0} backups sin nota; los más viejos se borran solos (se cambia en Opciones).
•  Backups y registro (guardian.log) en:
   {1}

Esta ayuda la volvés a ver con clic en el ícono > Cómo se usa.
'@
    btnEntendido     = 'Entendido'
    btnCalibrar      = 'Calibrar "Guardar ya"…'
    autostartDesc    = 'TAB Guardian - backups de They Are Billions'
    menuTitulo       = 'TAB Guardian  ·  vigilando partidas'
    menuHistorial    = 'Ver historial…'
    menuGuardarYa    = 'Guardar ya'
    menuVolver       = 'Volver al último guardado'
    menuCalibrar     = 'Calibrar "Guardar ya"…'
    menuOpciones     = 'Opciones…'
    menuAyuda        = 'Cómo se usa'
    menuAcerca       = 'Acerca de TAB Guardian'
    menuCarpeta      = 'Abrir carpeta de backups'
    menuSalir        = 'Salir'
    menuUpdate       = '⬆  Descargar versión {0}'
    atajosTit        = 'Atajos ocupados'
    atajosTxt        = 'Otro programa usa: {0}. Usá el menú del ícono.'
    activoTit        = 'TAB Guardian activo'
    activoSinCalib   = 'Ya guardo cada partida sola. Para usar Ctrl+F5 (Guardar ya), calibrá desde el menú del ícono.'
    activoTxt        = 'Ctrl+F5 guardar ya  ·  Ctrl+F9 volver al último guardado'
    errorTxt         = 'Error: {0}'
    btnOk            = 'Aceptar'
    btnSi            = 'Sí'
    btnNo            = 'No'
    btnCancelar      = 'Cancelar'
    btnGuardar       = 'Guardar'
    btnCerrar        = 'Cerrar'
    optTit           = 'Opciones'
    optIdioma        = 'Idioma'
    optIdiomaAuto    = 'Automático (idioma de Windows)'
    optMax           = 'Guardados a conservar (los que tienen nota no cuentan)'
    optInicio        = 'Iniciar TAB Guardian con Windows'
    optSonidos       = 'Pitidos al guardar y calibrar'
    optCapturas      = 'Sacar captura de pantalla en cada guardado'
    optAvisos        = 'Mostrar aviso en pantalla cuando se guarda'
    optUpdates       = 'Avisar si hay una versión nueva (consulta GitHub)'
    optCalib         = 'Clics de "Guardar ya" calibrados: {0}'
    acercaTit        = 'Acerca de'
    acercaDesc       = 'Guardado automático e historial de partidas para They Are Billions.'
    acercaVersion    = 'Versión {0}'
    acercaAutor      = 'Hecho por Tinisan'
    acercaFan        = 'Proyecto de fan, sin relación con Numantian Games.'
    btnBuscarUpd     = 'Buscar actualizaciones'
    updAlDiaTit      = 'Estás al día'
    updAlDiaTxt      = 'Tenés la última versión ({0}).'
    updNuevaTit      = 'Hay una versión nueva'
    updNuevaTxt      = 'TAB Guardian {0} ya está disponible. Clic en el ícono > Descargar.'
    updErrorTit      = 'Sin conexión'
    updErrorTxt      = 'No se pudo consultar GitHub. Probá más tarde.'
    updDev           = 'Las actualizaciones se buscan solo en la versión instalada.'
}
en = @{
    yaAbierto        = 'TAB Guardian is already running. Look for the icon next to the clock.'
    sinCarpeta       = "Couldn't find the saves folder:`n{0}`n`nOpen the game, save a game and start TAB Guardian again."
    bannerSub        = 'Auto-save & save history for They Are Billions'
    tipoGuardarYa    = 'Quick save'
    tipoAuto         = 'Automatic'
    fmtFecha         = 'MMM d, yyyy   HH:mm:ss'
    fmtCorta         = 'MMM d HH:mm'
    trayUltimo       = 'TAB Guardian - last: {0}'
    traySin          = 'TAB Guardian - no backups yet'
    restaurarTit     = 'Restore save'
    restaurarPreg    = 'Restore the save from {0}?'
    restaurarCierra  = 'The game will be CLOSED (anything unsaved is lost) and reopened automatically.'
    restaurarMenu    = 'The game is open: you must be on the MAIN MENU, not inside a game.'
    restauradoTit    = 'Restored'
    restauradoAbre   = 'Opening the game... Click Continue.'
    restauradoListo  = 'Done. Click Continue in the game.'
    sinBackupsTit    = 'No backups'
    sinBackupsTxt    = 'There are no saves in the history yet.'
    faltaCalibTit    = 'Calibration needed'
    faltaCalibTxt    = 'Click the icon > Calibrate "Quick save".'
    juegoCerradoTit  = 'Game not running'
    juegoCerradoTxt  = "Couldn't find They Are Billions running."
    noGuardoTit      = 'Not saved'
    noGuardoTxt      = "Didn't detect the save. Try calibrating again."
    guardadoTit      = 'Game saved'
    guardadoTxt      = '{0}  ·  {1}'
    calibTit         = 'Calibrate "Quick save"'
    calibTxt         = @'
You only need to do this once:

1)  Start a game and press Esc to open the pause menu.
2)  Hover the mouse OVER "Save and Exit" and press Ctrl+F12 (you'll hear a beep). Then click it yourself, as usual.
3)  If a confirmation shows up, same thing: hover over the button, Ctrl+F12, click.
4)  On the main menu: hover over "Continue", Ctrl+F12, click.
5)  Press Ctrl+F11 to finish.

Changing the game resolution doesn't require calibrating again.
'@
    calibCancelTit   = 'Calibration cancelled'
    calibCancelTxt   = 'No points were recorded.'
    calibListaTit    = 'Calibration done'
    calibListaTxt    = '{0} clicks recorded. You can now use Ctrl+F5.'
    noCaptura        = 'This save has no screenshot'
    elegiCaptura     = 'Pick a save to see its screenshot'
    elegiGuardado    = 'Pick a save from the list.'
    histTit          = 'Save history'
    colFecha         = 'Date'
    colTipo          = 'Type'
    colNota          = 'Note'
    histInfo         = 'Double-click = restore  ·  ★ with a note: never deleted  ·  Double-click the picture = enlarge'
    btnRestaurar     = '▶  Restore'
    btnRestMenu      = "Restore (I'm on the menu)"
    btnNota          = 'Note…'
    btnBorrar        = 'Delete'
    btnCarpeta       = 'Open folder'
    btnAyuda         = 'How to use'
    notaTit          = 'Note'
    notaPreg         = 'Note for this save (e.g. "day 40, before the horde"):'
    borrarTit        = 'Delete save'
    borrarPreg       = 'Delete the save from {0}?'
    ayudaTit         = 'How to use'
    ayudaTxt         = @'
# What it does
TAB Guardian sits next to the clock. Every time They Are Billions saves your game ("Save and Exit" or the automatic backup), it keeps a copy with date, time and a screenshot. So you have a history to go back to if the infected overrun you.

# First time: calibrate "Quick save" (only once)
1)  Click the icon (next to the clock) > Calibrate "Quick save"…
2)  Start a game and press Esc.
3)  Hover over "Save and Exit" > Ctrl+F12 (you'll hear a beep) > click it yourself.
4)  If a confirmation shows up: hover over its button > Ctrl+F12 > click.
5)  On the main menu: hover over "Continue" > Ctrl+F12 > click.
6)  Press Ctrl+F11 to finish.

# Shortcuts while playing
Ctrl+F5    Quick save: saves, keeps a copy and jumps back into the game.
Ctrl+F9    Back to last save: closes the game, restores and reopens it. Then click Continue.

# Going back to an older save
Click the icon > Save history. On the right you see each save's screenshot (double-click it to enlarge).
•  Restore: works even while you're playing (closes and reopens the game).
•  Restore (I'm on the menu): if you're already on the main menu.
•  Note…: give it a name (e.g. "day 40, before the horde"). Saves with a note are marked with ★ and never deleted.
•  Delete / Open folder.

# Keep in mind
•  Don't restore with a game open without closing it: when you exit, the game overwrites the files (the restore options handle this for you).
•  If Ctrl+F5 does nothing or screenshots don't show up, set the game to "borderless window" (in exclusive fullscreen the screenshot comes out black and is discarded).
•  If Steam reports a cloud save conflict, choose the LOCAL files.
•  Before every restore, whatever was there is kept in SaveSlots\_AntesDeRestaurar.
•  Up to {0} saves without a note are kept; older ones are deleted automatically (change it in Options).
•  Backups and log (guardian.log) are in:
   {1}

You can open this help again from the icon > How to use.
'@
    btnEntendido     = 'Got it'
    btnCalibrar      = 'Calibrate "Quick save"…'
    autostartDesc    = 'TAB Guardian - They Are Billions backups'
    menuTitulo       = 'TAB Guardian  ·  watching your saves'
    menuHistorial    = 'Save history…'
    menuGuardarYa    = 'Quick save'
    menuVolver       = 'Back to last save'
    menuCalibrar     = 'Calibrate "Quick save"…'
    menuOpciones     = 'Options…'
    menuAyuda        = 'How to use'
    menuAcerca       = 'About TAB Guardian'
    menuCarpeta      = 'Open backups folder'
    menuSalir        = 'Exit'
    menuUpdate       = '⬆  Download version {0}'
    atajosTit        = 'Shortcuts in use'
    atajosTxt        = 'Another program is using: {0}. Use the icon menu.'
    activoTit        = 'TAB Guardian is running'
    activoSinCalib   = 'Every save is backed up automatically. To use Ctrl+F5 (Quick save), calibrate it from the icon menu.'
    activoTxt        = 'Ctrl+F5 quick save  ·  Ctrl+F9 back to last save'
    errorTxt         = 'Error: {0}'
    btnOk            = 'OK'
    btnSi            = 'Yes'
    btnNo            = 'No'
    btnCancelar      = 'Cancel'
    btnGuardar       = 'Save'
    btnCerrar        = 'Close'
    optTit           = 'Options'
    optIdioma        = 'Language'
    optIdiomaAuto    = 'Automatic (Windows language)'
    optMax           = 'Saves to keep (saves with a note do not count)'
    optInicio        = 'Start TAB Guardian with Windows'
    optSonidos       = 'Beep when saving and calibrating'
    optCapturas      = 'Take a screenshot on every save'
    optAvisos        = 'Show an on-screen notice when a game is saved'
    optUpdates       = 'Tell me when a new version is out (checks GitHub)'
    optCalib         = '"Quick save" clicks calibrated: {0}'
    acercaTit        = 'About'
    acercaDesc       = 'Automatic backups and save history for They Are Billions.'
    acercaVersion    = 'Version {0}'
    acercaAutor      = 'Made by Tinisan'
    acercaFan        = 'Fan project, not affiliated with Numantian Games.'
    btnBuscarUpd     = 'Check for updates'
    updAlDiaTit      = "You're up to date"
    updAlDiaTxt      = 'You have the latest version ({0}).'
    updNuevaTit      = 'New version available'
    updNuevaTxt      = 'TAB Guardian {0} is out. Click the icon > Download.'
    updErrorTit      = 'No connection'
    updErrorTxt      = "Couldn't reach GitHub. Try again later."
    updDev           = 'Updates are only checked in the installed version.'
}
}

function T([string]$k) {
    $s = $script:textos[$script:idioma][$k]
    if ($null -eq $s) { $s = $script:textos['es'][$k] }
    if ($args.Count -gt 0) { $s = $s -f $args }
    return $s
}

# Idioma: el elegido en Opciones > el del instalador > el de Windows
function Resolver-Idioma {
    $i = $script:cfg.idioma
    if ($i -notin 'es', 'en') {
        $reg = $null
        if ($i -ne 'auto') {
            try { $reg = (Get-ItemProperty 'HKCU:\Software\TAB Guardian' -Name Language -ErrorAction Stop).Language } catch { }
        }
        if ($reg -in 'es', 'en') { $i = $reg }
        elseif ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'es') { $i = 'es' }
        else { $i = 'en' }
    }
    $script:idioma = $i
    $script:cultura = [Globalization.CultureInfo]::GetCultureInfo($(if ($i -eq 'es') { 'es-AR' } else { 'en-US' }))
}
Resolver-Idioma

function Fecha($d, $fmt = 'fmtFecha') { $d.ToString((T $fmt), $script:cultura) }

# ---------- Imagenes ----------
$script:icoPath = Recurso 'TAB-Guardian.ico'
$script:formIcon = $null; $script:trayIcon = $null
if ($script:icoPath) {
    try {
        $script:formIcon = New-Object System.Drawing.Icon($script:icoPath)
        $script:trayIcon = New-Object System.Drawing.Icon($script:icoPath, [System.Windows.Forms.SystemInformation]::SmallIconSize)
    } catch { }
}
if (-not $script:trayIcon) {
    # Sin .ico: el "TB" naranja dibujado
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.FillEllipse((New-Object System.Drawing.SolidBrush ([TABG.Paleta]::Acento)), 1, 1, 30, 30)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
    $g.DrawString('TB', (New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)), [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 1, 32, 32)), $fmt)
    $g.Dispose()
    $script:trayIcon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $script:formIcon = $script:trayIcon
}
function Cargar-Imagen($nombre) {
    $p = Recurso $nombre
    if (-not $p) { return $null }
    # A memoria, para no dejar el archivo bloqueado
    [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, [System.IO.File]::ReadAllBytes($p))))
}
$script:logoImg   = Cargar-Imagen 'logo.png'
$script:bannerImg = Cargar-Imagen 'banner.jpg'

# ---------- Tema y ventanas comunes ----------
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:fuente      = New-Object System.Drawing.Font('Segoe UI', 9.75)
$script:fuenteBold  = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold)
$script:fuenteChica = New-Object System.Drawing.Font('Segoe UI', 8.75)

function Size($w, $h) { New-Object System.Drawing.Size($w, $h) }
function Point($x, $y) { New-Object System.Drawing.Point($x, $y) }
function Pad($l, $t, $r, $b) { New-Object System.Windows.Forms.Padding($l, $t, $r, $b) }

function Nueva-Ventana($titulo, $ancho, $alto) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = "TAB Guardian  ·  $titulo"
    $f.ClientSize = Size $ancho $alto
    $f.StartPosition = 'CenterScreen'
    $f.BackColor = [TABG.Paleta]::Fondo
    $f.ForeColor = [TABG.Paleta]::Texto
    $f.Font = $script:fuente
    $f.Icon = $script:formIcon
    $f.add_HandleCreated({ [TABG.Native]::DarkTitle($this.Handle) })
    return $f
}

function Boton($texto, $accion, [switch]$primario, [switch]$peligro) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $texto
    $b.AutoSize = $true
    $b.MinimumSize = Size 100 36
    $b.Padding = Pad 12 0 12 0
    $b.Margin = Pad 0 0 8 0
    $b.FlatStyle = 'Flat'
    $b.UseVisualStyleBackColor = $false
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.FlatAppearance.BorderSize = 0
    if ($primario) {
        $b.BackColor = [TABG.Paleta]::Acento; $b.ForeColor = [System.Drawing.Color]::White; $b.Font = $script:fuenteBold
        $b.FlatAppearance.MouseOverBackColor = [TABG.Paleta]::AcentoH
        $b.FlatAppearance.MouseDownBackColor = [TABG.Paleta]::AcentoH
    } else {
        $b.BackColor = [TABG.Paleta]::Sup
        $b.ForeColor = if ($peligro) { [TABG.Paleta]::Peligro } else { [TABG.Paleta]::Texto }
        $b.FlatAppearance.MouseOverBackColor = [TABG.Paleta]::Hover
        $b.FlatAppearance.MouseDownBackColor = [TABG.Paleta]::Borde
    }
    if ($accion) { $b.add_Click($accion) }
    return $b
}

function Nuevo-Banner($alto, $sub = $null) {
    $bn = New-Object TABG.Banner
    $bn.Dock = 'Top'; $bn.Height = $alto
    $bn.Imagen = $script:bannerImg
    $bn.Titulo = 'TAB GUARDIAN'
    $bn.Sub = if ($sub) { $sub } else { T 'bannerSub' }
    $bn.Autor = 'by Tinisan'
    return $bn
}

function Barra-Botones {
    $p = New-Object System.Windows.Forms.FlowLayoutPanel
    $p.Dock = 'Bottom'; $p.Height = 64
    $p.Padding = Pad 16 14 8 14
    $p.BackColor = [TABG.Paleta]::Panel
    $p.WrapContents = $false
    return $p
}

# Dialogo oscuro: reemplaza MessageBox e InputBox
function Dialogo($titulo, $texto, $btnOk, $btnNo = $null, [switch]$entrada, $valor = '', [switch]$peligro) {
    $ancho = 440
    $alto = [System.Windows.Forms.TextRenderer]::MeasureText($texto, $script:fuente, (Size $ancho 0), [System.Windows.Forms.TextFormatFlags]::WordBreak).Height
    $f = Nueva-Ventana $titulo ($ancho + 56) 100
    $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false; $f.TopMost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $texto; $lbl.Location = Point 28 26; $lbl.Size = Size $ancho ($alto + 4)
    $f.Controls.Add($lbl)
    $y = 26 + $alto + 22
    $tb = $null
    if ($entrada) {
        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Text = $valor; $tb.Location = Point 28 $y; $tb.Width = $ancho
        $tb.BackColor = [TABG.Paleta]::Sup; $tb.ForeColor = [TABG.Paleta]::Texto; $tb.BorderStyle = 'FixedSingle'
        $f.Controls.Add($tb)
        $y += 44
    }
    $barra = Barra-Botones
    $barra.FlowDirection = 'RightToLeft'
    $ok = Boton $btnOk $null -primario
    if ($peligro) { $ok.BackColor = [TABG.Paleta]::Peligro; $ok.FlatAppearance.MouseOverBackColor = [TABG.Paleta]::Peligro }
    $ok.DialogResult = 'OK'
    $barra.Controls.Add($ok)
    $f.AcceptButton = $ok
    if ($btnNo) {
        $no = Boton $btnNo $null
        $no.DialogResult = 'Cancel'
        $barra.Controls.Add($no)
        $f.CancelButton = $no
    } else { $f.CancelButton = $ok }
    $f.Controls.Add($barra)
    $f.ClientSize = Size ($ancho + 56) ($y + $barra.Height)
    if ($tb) { $f.ActiveControl = $tb } else { $f.ActiveControl = $ok }

    $r = $f.ShowDialog()
    $res = [pscustomobject]@{ Ok = ($r -eq 'OK'); Texto = $(if ($tb) { $tb.Text }) }
    $f.Dispose()
    return $res
}
function Avisar($titulo, $texto) { [void](Dialogo $titulo $texto (T 'btnOk')) }
function Confirmar($titulo, $texto, $si, $no, [switch]$peligro) { (Dialogo $titulo $texto $si $no -peligro:$peligro).Ok }

# ---------- Una sola instancia ----------
$creado = $false
$mutex = New-Object System.Threading.Mutex($true, 'TABGuardian_SingleInstance', [ref]$creado)
if (-not $creado) {
    Avisar 'TAB Guardian' (T 'yaAbierto')
    exit
}

if (-not (Test-Path $savesDir)) {
    Avisar 'TAB Guardian' (T 'sinCarpeta' $savesDir)
    exit
}
New-Item -ItemType Directory -Force -Path $histDir | Out-Null

# ---------- Estado ----------
$script:busy         = $false
$script:lastSig      = ''
$script:pendingSig   = $null
$script:pendingTime  = Get-Date
$script:calibrando   = $false
$script:calib        = New-Object System.Collections.ArrayList
$script:histForm     = $null
$script:lv           = $null
$script:pb           = $null
$script:capturas     = New-Object System.Collections.ArrayList   # últimas fotos del juego {t, img}
$script:ultCaptura   = [datetime]::MinValue
$script:primerCambio = Get-Date
$script:updVer       = $null
$script:updUrl       = $null

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

# Aviso abajo a la derecha: info (naranja), ok (verde), warn (rojo)
function Notify($titulo, $texto, $tipo = 'info') {
    $c = switch ($tipo) { 'ok' { [TABG.Paleta]::Exito } 'warn' { [TABG.Paleta]::Peligro } default { [TABG.Paleta]::Acento } }
    try { [TABG.Toast]::Mostrar($titulo, $texto, $c, $script:logoImg) }
    catch { $script:tray.ShowBalloonTip(4000, $titulo, $texto, 'Info') }
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
function Sonar($tipo) {
    # El de calibración suena siempre: es la única forma de saber que se grabó el punto
    if (-not $script:cfg.sonidos -and -not $script:calibrando) { return }
    try { $script:sonidos[$tipo].Play() } catch { }
}

function Tipo-Texto($t) {
    switch ($t) { 'guardar-ya' { T 'tipoGuardarYa' } default { T 'tipoAuto' } }
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
    if (-not $script:cfg.capturas) { return $null }
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

function Aviso-Guardado($tipo) {
    if ($script:cfg.avisos) { Notify (T 'guardadoTit') (T 'guardadoTxt' (Tipo-Texto $tipo) (Fecha (Get-Date) 'fmtCorta')) 'ok' }
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
    if ($s.Count -gt 0) { $t = T 'trayUltimo' (Fecha $s[0].Fecha 'fmtCorta') }
    else { $t = T 'traySin' }
    $script:tray.Text = $t.Substring(0, [Math]::Min(63, $t.Length))
}

# ---------- Restaurar ----------
function Restore-Snapshot($snap, [bool]$reiniciar) {
    $procs = Get-GameProcs
    $abierto = $procs.Count -gt 0
    $msg = T 'restaurarPreg' (Fecha $snap.Fecha)
    if ($snap.Nota) { $msg += "`n★ $($snap.Nota)" }
    if ($abierto -and $reiniciar) { $msg += "`n`n" + (T 'restaurarCierra') }
    elseif ($abierto) { $msg += "`n`n" + (T 'restaurarMenu') }
    if (-not (Confirmar (T 'restaurarTit') $msg (T 'btnSi') (T 'btnNo'))) { return }

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
            Notify (T 'restauradoTit') (T 'restauradoAbre') 'ok'
        } else {
            Notify (T 'restauradoTit') (T 'restauradoListo') 'ok'
        }
    } finally {
        $script:busy = $false
    }
}

function Volver-Ultimo {
    $s = @(Get-Snapshots)
    if ($s.Count -eq 0) { Notify (T 'sinBackupsTit') (T 'sinBackupsTxt') 'warn'; return }
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
        Notify (T 'faltaCalibTit') (T 'faltaCalibTxt') 'warn'
        Sonar 'error'
        return
    }
    $proc = Get-GameWindowProc
    if (-not $proc) { Notify (T 'juegoCerradoTit') (T 'juegoCerradoTxt') 'warn'; return }

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
            Notify (T 'noGuardoTit') (T 'noGuardoTxt') 'warn'
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
        Aviso-Guardado 'guardar-ya'
    } finally {
        $script:busy = $false
    }
}

# ---------- Calibracion ----------
function Calib-Empezar {
    $script:calib.Clear()
    $script:calibrando = $true
    Avisar (T 'calibTit') (T 'calibTxt')
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
    if ($script:calib.Count -eq 0) {
        $script:calibrando = $false
        Notify (T 'calibCancelTit') (T 'calibCancelTxt') 'warn'
        return
    }
    $script:cfg.clicks = @($script:calib.ToArray())
    Save-Config
    Sonar 'fin'
    $script:calibrando = $false
    Notify (T 'calibListaTit') (T 'calibListaTxt' $script:calib.Count) 'ok'
}

# ---------- Ventana de historial ----------
function Llenar-Lista {
    $lv = $script:lv
    $lv.BeginUpdate()
    $lv.Items.Clear()
    foreach ($s in Get-Snapshots) {
        $it = New-Object System.Windows.Forms.ListViewItem((Fecha $s.Fecha))
        [void]$it.SubItems.Add((Tipo-Texto $s.Tipo))
        [void]$it.SubItems.Add($s.Nota)
        $it.Tag = $s
        [void]$lv.Items.Add($it)
    }
    $lv.EndUpdate()
    Ajustar-Columnas
    try { Mostrar-Preview } catch { }
}

# La última columna ocupa el resto (si no, queda un hueco claro en la cabecera)
function Ajustar-Columnas {
    $lv = $script:lv
    if (-not $lv -or $lv.Columns.Count -lt 3) { return }
    $resto = $lv.ClientSize.Width - $lv.Columns[0].Width - $lv.Columns[1].Width
    $lv.Columns[2].Width = [Math]::Max(120, $resto)
}

function Mostrar-Preview {
    $pb = $script:pb
    if (-not $pb) { return }
    if ($pb.Image) { $pb.Image.Dispose(); $pb.Image = $null }
    $s = $null
    if ($script:lv.SelectedItems.Count -gt 0) { $s = $script:lv.SelectedItems[0].Tag }
    if ($s -and $s.Captura) {
        # Se lee a memoria para no dejar el .jpg bloqueado (si no, no se puede borrar)
        $ms = New-Object System.IO.MemoryStream(, [System.IO.File]::ReadAllBytes($s.Captura))
        $pb.Image = [System.Drawing.Image]::FromStream($ms)
        $script:pbTexto.Visible = $false
    } else {
        $script:pbTexto.Text = if ($s) { T 'noCaptura' } else { T 'elegiCaptura' }
        $script:pbTexto.Visible = $true
    }
    if ($s) {
        $script:pbPie.Text = "$(Fecha $s.Fecha)   ·   $(Tipo-Texto $s.Tipo)" + $(if ($s.Nota) { "`n★ $($s.Nota)" } else { '' })
    } else { $script:pbPie.Text = '' }
}

function Seleccionado {
    if ($script:lv.SelectedItems.Count -eq 0) {
        Avisar (T 'histTit') (T 'elegiGuardado')
        return $null
    }
    return $script:lv.SelectedItems[0].Tag
}

function Safe([scriptblock]$b) {
    try { & $b }
    catch {
        Write-Log "ERROR: $($_.Exception.Message)"
        Avisar 'TAB Guardian' (T 'errorTxt' $_.Exception.Message)
    }
}

function Mostrar-Historial {
    if ($script:histForm -and -not $script:histForm.IsDisposed) {
        Llenar-Lista; $script:histForm.Activate(); return
    }
    $f = Nueva-Ventana (T 'histTit') 1120 660
    $f.MinimumSize = Size 860 520

    $lv = New-Object TABG.DarkListView
    $lv.Dock = 'Fill'
    $lv.Font = $script:fuente
    [void]$lv.Columns.Add((T 'colFecha'), 200)
    [void]$lv.Columns.Add((T 'colTipo'), 110)
    [void]$lv.Columns.Add((T 'colNota'), 200)
    $lv.add_DoubleClick({ Safe { $s = Seleccionado; if ($s) { Restore-Snapshot $s $true } } })
    $lv.add_SelectedIndexChanged({ try { Mostrar-Preview } catch { } })
    $lv.add_Resize({ Ajustar-Columnas })
    $script:lv = $lv

    # Captura del guardado elegido (a la derecha)
    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Dock = 'Fill'; $pb.SizeMode = 'Zoom'; $pb.BackColor = [TABG.Paleta]::Panel
    $pb.Cursor = [System.Windows.Forms.Cursors]::Hand
    $pb.add_DoubleClick({
        if ($script:lv.SelectedItems.Count -gt 0 -and $script:lv.SelectedItems[0].Tag.Captura) {
            Start-Process $script:lv.SelectedItems[0].Tag.Captura
        }
    })
    $script:pb = $pb
    $pbTexto = New-Object System.Windows.Forms.Label
    $pbTexto.Dock = 'Fill'; $pbTexto.TextAlign = 'MiddleCenter'
    $pbTexto.ForeColor = [TABG.Paleta]::Tenue; $pbTexto.BackColor = [TABG.Paleta]::Panel
    $script:pbTexto = $pbTexto
    $pie = New-Object System.Windows.Forms.Label
    $pie.Dock = 'Bottom'; $pie.Height = 52; $pie.Padding = Pad 4 10 4 0
    $pie.ForeColor = [TABG.Paleta]::Texto; $pie.Font = $script:fuenteBold
    $script:pbPie = $pie

    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = 'Fill'
    $split.BackColor = [TABG.Paleta]::Fondo
    $split.SplitterWidth = 8
    $split.Panel1.Padding = Pad 16 16 0 8
    $split.Panel2.Padding = Pad 0 16 16 8
    $split.Panel1.Controls.Add($lv)
    $split.Panel2.Controls.Add($pbTexto)
    $split.Panel2.Controls.Add($pb)
    $split.Panel2.Controls.Add($pie)

    $info = New-Object System.Windows.Forms.Label
    $info.Text = T 'histInfo'
    $info.Dock = 'Bottom'; $info.Height = 26; $info.Padding = Pad 18 0 0 6
    $info.ForeColor = [TABG.Paleta]::Tenue; $info.Font = $script:fuenteChica

    $barra = Barra-Botones
    $barra.Controls.Add((Boton (T 'btnRestaurar') { Safe { $s = Seleccionado; if ($s) { Restore-Snapshot $s $true } } } -primario))
    $barra.Controls.Add((Boton (T 'btnRestMenu') { Safe { $s = Seleccionado; if ($s) { Restore-Snapshot $s $false } } }))
    $barra.Controls.Add((Boton (T 'btnNota') {
        Safe {
            $s = Seleccionado
            if ($s) {
                $r = Dialogo (T 'notaTit') (T 'notaPreg') (T 'btnGuardar') (T 'btnCancelar') -entrada -valor $s.Nota
                if ($r.Ok) { Save-Meta $s.Path $s.Tipo $r.Texto; Llenar-Lista }
            }
        }
    }))
    $barra.Controls.Add((Boton (T 'btnBorrar') {
        Safe {
            $s = Seleccionado
            if ($s -and (Confirmar (T 'borrarTit') (T 'borrarPreg' (Fecha $s.Fecha)) (T 'btnBorrar') (T 'btnCancelar') -peligro)) {
                Remove-Item $s.Path -Recurse -Force; Llenar-Lista; Update-TrayText
            }
        }
    } -peligro))
    $barra.Controls.Add((Boton (T 'btnCarpeta') { Start-Process explorer.exe $histDir }))
    $barra.Controls.Add((Boton (T 'btnAyuda') { Safe { Mostrar-Ayuda } }))

    # Orden de Dock: lo último agregado se acomoda primero
    $f.Controls.Add($split)
    $f.Controls.Add($info)
    $f.Controls.Add($barra)
    $f.Controls.Add((Nuevo-Banner 104))
    $f.add_FormClosed({ if ($script:pb -and $script:pb.Image) { $script:pb.Image.Dispose() }; $script:pb = $null })
    $script:histForm = $f
    $f.Show()
    $split.SplitterDistance = 560
    Llenar-Lista
    if ($lv.Items.Count -gt 0) { $lv.Items[0].Selected = $true }   # muestra la foto del último
}

# ---------- Ayuda ----------
function Mostrar-Ayuda {
    $f = Nueva-Ventana (T 'ayudaTit') 720 680
    $f.MinimumSize = Size 560 480

    $rt = New-Object System.Windows.Forms.RichTextBox
    $rt.Dock = 'Fill'; $rt.ReadOnly = $true; $rt.BorderStyle = 'None'
    $rt.BackColor = [TABG.Paleta]::Fondo; $rt.ForeColor = [TABG.Paleta]::Texto
    $rt.Font = $script:fuente; $rt.DetectUrls = $false
    $rt.add_HandleCreated({ [TABG.Native]::DarkScroll($this.Handle) })
    $titulo = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $texto = T 'ayudaTxt' $script:cfg.maxHistorial $baseDir
    foreach ($linea in ($texto -split "`r?`n")) {
        if ($linea.StartsWith('# ')) {
            $rt.SelectionFont = $titulo; $rt.SelectionColor = [TABG.Paleta]::AcentoH
            $rt.AppendText($linea.Substring(2) + "`n")
        } else {
            $rt.SelectionFont = $script:fuente; $rt.SelectionColor = [TABG.Paleta]::Texto
            $rt.AppendText($linea + "`n")
        }
    }
    $rt.SelectionFont = $script:fuenteChica; $rt.SelectionColor = [TABG.Paleta]::Tenue
    $rt.AppendText("`nTAB Guardian by Tinisan  ·  tinisan.gesell@gmail.com")
    $rt.Select(0, 0)

    $cuerpo = New-Object System.Windows.Forms.Panel
    $cuerpo.Dock = 'Fill'; $cuerpo.Padding = Pad 28 18 12 8
    $cuerpo.Controls.Add($rt)

    $barra = Barra-Botones
    $barra.FlowDirection = 'RightToLeft'
    # En los eventos $this es el botón ($f ya no existe cuando se hace clic)
    $ok = Boton (T 'btnEntendido') { $this.FindForm().Close() } -primario
    $barra.Controls.Add($ok)
    $barra.Controls.Add((Boton (T 'btnCalibrar') { $this.FindForm().Close(); Safe { Calib-Empezar } }))

    $f.Controls.Add($cuerpo)
    $f.Controls.Add($barra)
    $f.Controls.Add((Nuevo-Banner 96 (T 'ayudaTit')))
    $f.AcceptButton = $ok
    $f.ActiveControl = $ok    # si no, el texto aparece todo seleccionado
    $f.Show()
    $f.Activate()
}

# ---------- Opciones ----------
function Nuevo-Check($texto, $valor, $y) {
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $texto; $c.Checked = [bool]$valor
    $c.Location = Point 28 $y; $c.AutoSize = $true
    $c.FlatStyle = 'Flat'; $c.Cursor = [System.Windows.Forms.Cursors]::Hand
    $c.FlatAppearance.BorderColor = [TABG.Paleta]::Tenue
    $c.FlatAppearance.CheckedBackColor = [TABG.Paleta]::Acento
    return $c
}
function Nueva-Etiqueta($texto, $y, [switch]$tenue) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $texto; $l.Location = Point 28 $y; $l.AutoSize = $true
    if ($tenue) { $l.ForeColor = [TABG.Paleta]::Tenue }
    return $l
}

function Mostrar-Opciones {
    $f = Nueva-Ventana (T 'optTit') 520 520
    $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $cuerpo = New-Object System.Windows.Forms.Panel
    $cuerpo.Dock = 'Fill'

    $y = 22
    $cuerpo.Controls.Add((Nueva-Etiqueta (T 'optIdioma') $y -tenue)); $y += 24
    $cb = New-Object System.Windows.Forms.ComboBox
    $cb.DropDownStyle = 'DropDownList'; $cb.FlatStyle = 'Flat'
    $cb.BackColor = [TABG.Paleta]::Sup; $cb.ForeColor = [TABG.Paleta]::Texto
    $cb.Location = Point 28 $y; $cb.Width = 300
    [void]$cb.Items.AddRange(@((T 'optIdiomaAuto'), 'Español', 'English'))
    $cb.SelectedIndex = switch ($script:cfg.idioma) { 'es' { 1 } 'en' { 2 } 'auto' { 0 } default { if ($script:idioma -eq 'es') { 1 } else { 2 } } }
    $cuerpo.Controls.Add($cb); $y += 46

    $cuerpo.Controls.Add((Nueva-Etiqueta (T 'optMax') $y -tenue)); $y += 24
    $num = New-Object System.Windows.Forms.NumericUpDown
    $num.Minimum = 10; $num.Maximum = 2000; $num.Increment = 10
    $num.Value = [Math]::Min(2000, [Math]::Max(10, [int]$script:cfg.maxHistorial))
    $num.Location = Point 28 $y; $num.Width = 120
    $num.BackColor = [TABG.Paleta]::Sup; $num.ForeColor = [TABG.Paleta]::Texto; $num.BorderStyle = 'FixedSingle'
    $cuerpo.Controls.Add($num); $y += 50

    $chInicio = Nuevo-Check (T 'optInicio') (Test-Path $startLnk) $y; $y += 34
    $chSon    = Nuevo-Check (T 'optSonidos') $script:cfg.sonidos $y; $y += 34
    $chCap    = Nuevo-Check (T 'optCapturas') $script:cfg.capturas $y; $y += 34
    $chAvi    = Nuevo-Check (T 'optAvisos') $script:cfg.avisos $y; $y += 34
    $chUpd    = Nuevo-Check (T 'optUpdates') $script:cfg.actualizaciones $y; $y += 46
    $cuerpo.Controls.AddRange(@($chInicio, $chSon, $chCap, $chAvi, $chUpd))

    $cuerpo.Controls.Add((Nueva-Etiqueta (T 'optCalib' @($script:cfg.clicks).Count) $y -tenue)); $y += 26
    $rec = Boton (T 'btnCalibrar') { $this.FindForm().Close(); Safe { Calib-Empezar } }
    $rec.Location = Point 28 $y
    $cuerpo.Controls.Add($rec)

    # Una sola ventana de opciones a la vez: los controles quedan a mano para "Guardar"
    $script:opt = @{ cb = $cb; num = $num; inicio = $chInicio; son = $chSon; cap = $chCap; avi = $chAvi; upd = $chUpd }

    $barra = Barra-Botones
    $barra.FlowDirection = 'RightToLeft'
    $ok = Boton (T 'btnGuardar') {
        Safe {
            $o = $script:opt
            $antes = $script:idioma
            $script:cfg.idioma = @('auto', 'es', 'en')[$o.cb.SelectedIndex]
            $script:cfg.maxHistorial = [int]$o.num.Value
            $script:cfg.sonidos = $o.son.Checked
            $script:cfg.capturas = $o.cap.Checked
            $script:cfg.avisos = $o.avi.Checked
            $script:cfg.actualizaciones = $o.upd.Checked
            Save-Config
            Set-Autostart $o.inicio.Checked
            Resolver-Idioma
            if ($script:idioma -ne $antes) {
                if ($script:histForm -and -not $script:histForm.IsDisposed) { $script:histForm.Close() }
                Armar-Menu
            }
            Limpiar-Historial
            Update-TrayText
            $this.FindForm().Close()
        }
    } -primario
    $barra.Controls.Add($ok)
    $barra.Controls.Add((Boton (T 'btnCancelar') { $this.FindForm().Close() }))

    $f.Controls.Add($cuerpo)
    $f.Controls.Add($barra)
    $f.ClientSize = Size 520 ($y + 60 + $barra.Height)
    $f.AcceptButton = $ok
    $f.ActiveControl = $ok
    $f.Show()
    $f.Activate()
}

# ---------- Acerca de ----------
function Mostrar-Acerca {
    $f = Nueva-Ventana (T 'acercaTit') 520 360
    $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false

    $pic = New-Object System.Windows.Forms.PictureBox
    $pic.Location = Point 28 28; $pic.Size = Size 112 112; $pic.SizeMode = 'Zoom'
    $pic.Image = if ($script:logoImg) { $script:logoImg } else { $script:formIcon.ToBitmap() }
    $f.Controls.Add($pic)

    $x = 164
    $nombre = New-Object System.Windows.Forms.Label
    $nombre.Text = 'TAB Guardian'; $nombre.Location = Point $x 30; $nombre.AutoSize = $true
    $nombre.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $f.Controls.Add($nombre)
    $ver = New-Object System.Windows.Forms.Label
    $ver.Text = T 'acercaVersion' $script:version; $ver.Location = Point ($x + 2) 72; $ver.AutoSize = $true
    $ver.ForeColor = [TABG.Paleta]::AcentoH; $ver.Font = $script:fuenteBold
    $f.Controls.Add($ver)
    $desc = New-Object System.Windows.Forms.Label
    $desc.Text = T 'acercaDesc'; $desc.Location = Point ($x + 2) 100; $desc.Size = Size 330 44
    $desc.ForeColor = [TABG.Paleta]::Tenue
    $f.Controls.Add($desc)

    $autor = New-Object System.Windows.Forms.Label
    $autor.Text = T 'acercaAutor'; $autor.Location = Point 28 166; $autor.AutoSize = $true; $autor.Font = $script:fuenteBold
    $f.Controls.Add($autor)
    $y = 192
    foreach ($l in @(
        @{ t = 'tinisan.gesell@gmail.com'; u = 'mailto:tinisan.gesell@gmail.com' },
        @{ t = "github.com/$repo"; u = "https://github.com/$repo" }
    )) {
        $ll = New-Object System.Windows.Forms.LinkLabel
        $ll.Text = $l.t; $ll.Tag = $l.u; $ll.Location = Point 28 $y; $ll.AutoSize = $true
        $ll.LinkColor = [TABG.Paleta]::AcentoH; $ll.ActiveLinkColor = [TABG.Paleta]::Acento
        $ll.LinkBehavior = 'HoverUnderline'
        $ll.add_LinkClicked({ Start-Process $this.Tag })
        $f.Controls.Add($ll)
        $y += 24
    }
    $fan = Nueva-Etiqueta (T 'acercaFan') ($y + 8) -tenue
    $fan.Font = $script:fuenteChica
    $f.Controls.Add($fan)

    $barra = Barra-Botones
    $barra.FlowDirection = 'RightToLeft'
    $ok = Boton (T 'btnCerrar') { $this.FindForm().Close() } -primario
    $barra.Controls.Add($ok)
    $barra.Controls.Add((Boton (T 'btnBuscarUpd') { Safe { Buscar-Actualizacion $true } }))
    $f.Controls.Add($barra)
    $f.ClientSize = Size 520 ($y + 44 + $barra.Height)
    $f.AcceptButton = $ok; $f.CancelButton = $ok
    $f.Show()
    $f.Activate()
}

# ---------- Actualizaciones (GitHub) ----------
function Ver($s) {
    $v = [version]("$s" -replace '^v', '')
    New-Object System.Version($v.Major, $v.Minor, [Math]::Max(0, $v.Build))
}

function Buscar-Actualizacion([bool]$manual) {
    if ($script:version -eq 'dev') {
        if ($manual) { Notify 'TAB Guardian' (T 'updDev') }
        return
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', 'TAB-Guardian')
    $wc.Encoding = [Text.Encoding]::UTF8
    $script:updManual = $manual
    # Se llama desde el bucle de WinForms, así que la respuesta vuelve al mismo hilo
    $wc.add_DownloadStringCompleted({
        param($s, $e)
        try {
            if ($e.Error) { throw $e.Error }
            $j = $e.Result | ConvertFrom-Json
            $nueva = Ver $j.tag_name
            if ($nueva -gt (Ver $script:version)) {
                $script:updVer = "$nueva"; $script:updUrl = $j.html_url
                Armar-Menu
                Notify (T 'updNuevaTit') (T 'updNuevaTxt' $script:updVer)
                Write-Log "Hay versión nueva: $nueva"
            } elseif ($script:updManual) {
                Notify (T 'updAlDiaTit') (T 'updAlDiaTxt' $script:version) 'ok'
            }
        } catch {
            Write-Log "Actualizaciones: $($_.Exception.Message)"
            if ($script:updManual) { Notify (T 'updErrorTit') (T 'updErrorTxt') 'warn' }
        }
        $s.Dispose()
    })
    $wc.DownloadStringAsync([uri]"https://api.github.com/repos/$repo/releases/latest")
}

# ---------- Inicio con Windows ----------
function Set-Autostart([bool]$on) {
    if ($on) {
        if (Test-Path $startLnk) { return }
        $sh = New-Object -ComObject WScript.Shell
        $l = $sh.CreateShortcut($startLnk)
        if ($esExe) {
            $l.TargetPath = $exePath
        } else {
            $l.TargetPath = 'wscript.exe'
            $l.Arguments = "`"$vbsPath`""
        }
        $l.WorkingDirectory = $appDir
        $l.Description = T 'autostartDesc'
        $l.Save()
    } else {
        Remove-Item $startLnk -ErrorAction SilentlyContinue
    }
}

# ---------- Bandeja del sistema ----------
$script:tray = New-Object System.Windows.Forms.NotifyIcon
$script:tray.Icon = $script:trayIcon
$script:tray.Visible = $true

function Salir {
    $script:timer.Stop()
    $script:tray.Visible = $false
    $script:hk.Close()
    try { $mutex.ReleaseMutex() } catch { }
    [System.Windows.Forms.Application]::Exit()
}

function Armar-Menu {
    $m = New-Object System.Windows.Forms.ContextMenuStrip
    $m.Renderer = New-Object TABG.DarkRenderer
    $m.Font = $script:fuente
    $m.ShowImageMargin = $false
    $m.Padding = Pad 2 6 2 6

    function Item($texto, $accion, $atajo = $null) {
        $i = New-Object System.Windows.Forms.ToolStripMenuItem($texto)
        $i.Padding = Pad 8 5 8 5
        if ($atajo) { $i.ShortcutKeyDisplayString = $atajo }
        if ($accion) { $i.add_Click($accion) }
        [void]$m.Items.Add($i)
        return $i
    }
    function Separador { [void]$m.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) }

    $titulo = Item (T 'menuTitulo') $null
    $titulo.Enabled = $false
    if ($script:updVer) {
        $u = Item (T 'menuUpdate' $script:updVer) { Start-Process $script:updUrl }
        $u.Tag = [TABG.Paleta]::AcentoH; $u.Font = $script:fuenteBold
    }
    Separador
    $h = Item (T 'menuHistorial') { Safe { Mostrar-Historial } }
    $h.Font = $script:fuenteBold
    [void](Item (T 'menuGuardarYa') { Safe { Guardar-Ya } } 'Ctrl+F5')
    [void](Item (T 'menuVolver') { Safe { Volver-Ultimo } } 'Ctrl+F9')
    Separador
    [void](Item (T 'menuCalibrar') { Safe { Calib-Empezar } })
    [void](Item (T 'menuOpciones') { Safe { Mostrar-Opciones } })
    [void](Item (T 'menuCarpeta') { Start-Process explorer.exe $histDir })
    Separador
    [void](Item (T 'menuAyuda') { Safe { Mostrar-Ayuda } })
    [void](Item (T 'menuAcerca') { Safe { Mostrar-Acerca } })
    Separador
    [void](Item (T 'menuSalir') { Salir })

    $viejo = $script:tray.ContextMenuStrip
    $script:tray.ContextMenuStrip = $m
    if ($viejo) { $viejo.Dispose() }
}
Armar-Menu

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
        if (Take-Snapshot 'auto' (Captura-Antes $script:primerCambio)) {
            Sonar 'ok'
            Aviso-Guardado 'auto'
        }
    }
}

$script:lastSig = Get-Firma $savesDir
if (@(Get-Snapshots).Count -eq 0) { Take-Snapshot 'auto' | Out-Null }
Update-TrayText

$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 2000
$script:timer.add_Tick({ try { Tick } catch { Write-Log "Tick: $($_.Exception.Message)" } })
$script:timer.Start()

# Buscar versión nueva una vez, 20 s después de arrancar
if ($script:cfg.actualizaciones) {
    $script:updTimer = New-Object System.Windows.Forms.Timer
    $script:updTimer.Interval = 20000
    $script:updTimer.add_Tick({ $script:updTimer.Stop(); try { Buscar-Actualizacion $false } catch { } })
    $script:updTimer.Start()
}

Write-Log "TAB Guardian $($script:version) iniciado ($($script:idioma))"
if ($fallidas.Count -gt 0) {
    Notify (T 'atajosTit') (T 'atajosTxt' ($fallidas -join ', ')) 'warn'
} elseif (@($script:cfg.clicks).Count -eq 0) {
    Notify (T 'activoTit') (T 'activoSinCalib')
} else {
    Notify (T 'activoTit') (T 'activoTxt')
}

# La primera vez que se abre, mostrar cómo se usa
if (-not $script:cfg.ayudaVista) {
    $script:cfg.ayudaVista = $true
    Save-Config
    Safe { Mostrar-Ayuda }
}

$ctx = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($ctx)
