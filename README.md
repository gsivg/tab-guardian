# TAB Guardian

**Guardado automático e historial de partidas para *They Are Billions*** — by Tinisan

🇬🇧 *English version below.*

They Are Billions no tiene guardado manual: solo guarda al hacer "Guardar y salir" y cada tanto un backup automático. Si te comen, perdiste la partida. TAB Guardian queda al lado del reloj y guarda una copia de cada partida que el juego escribe, con fecha, hora y una captura de pantalla, para que puedas volver atrás cuando quieras.

## Descarga

👉 Bajá el instalador desde **[Releases](../../releases/latest)** (`TAB-Guardian-Setup-x.y.z.exe`).

- En español o inglés (el instalador pregunta; después se cambia en Opciones).
- No necesita permisos de administrador (se instala para tu usuario).
- Opcional: iniciar con Windows.
- Avisa solo cuando hay una versión nueva.
- Al desinstalar, tus backups **no** se borran.

> Windows SmartScreen o algún antivirus pueden avisar porque el programa no está firmado digitalmente. Es normal en herramientas chicas: "Más información" → "Ejecutar de todas formas".

## Qué hace

- **Historial automático**: cada vez que el juego guarda, copia la partida (`.zxsav` + `.zxcheck`) a `Documentos\My Games\They Are Billions\SaveSlots\Historial`. Guarda hasta 200 (configurable); los que tienen nota no se borran nunca.
- **Captura de pantalla** de la partida en cada guardado, para distinguir cuál es cuál.
- **Ctrl+F5 — Guardar ya**: hace "Guardar y salir" + "Continuar" solo, en segundos.
- **Ctrl+F9 — Volver al último guardado**: cierra el juego, restaura y lo vuelve a abrir.
- **Historial** con tema oscuro: lista a la izquierda, captura a la derecha; restaurar, ponerle nota, borrar.
- **Aviso en pantalla** cuando se guarda, sin sacarte del juego.
- **Opciones**: idioma, cantidad de guardados, inicio con Windows, pitidos, capturas, avisos y actualizaciones.

## Cómo se usa

1. Instalalo y abrilo. Aparece el ícono al lado del reloj (la primera vez se abre la ayuda).
2. **Calibrar "Guardar ya"** (una sola vez): clic en el ícono → *Calibrar "Guardar ya"…*
   - En una partida apretá Esc. Mouse arriba de **"Guardar y salir"** → **Ctrl+F12** (pitido) → clic.
   - Si hay confirmación, lo mismo con ese botón.
   - En el menú principal, mouse arriba de **"Continuar"** → **Ctrl+F12** → clic.
   - **Ctrl+F11** para terminar.
3. Jugá. Usá **Ctrl+F5** para guardar cuando quieras y **Ctrl+F9** para volver atrás.
4. Clic en el ícono → **Ver historial** para elegir un guardado más viejo.

### Consejos

- Jugá en **ventana sin bordes**: en pantalla completa exclusiva Ctrl+F5 puede no funcionar y las capturas salen negras.
- No restaures con una partida abierta sin cerrar el juego (al salir, el juego pisa los archivos). Las opciones de restaurar ya lo manejan.
- Si Steam muestra un conflicto de guardado en la nube, elegí los archivos **locales**.
- Antes de cada restauración, lo que había queda en `SaveSlots\_AntesDeRestaurar`.
- Registro de lo que hace: `SaveSlots\guardian.log`.

## Limitaciones

El juego no tiene API ni soporte de mods: TAB Guardian solo puede copiar lo que el juego ya escribió a disco. "Guardar ya" funciona simulando teclado y mouse. Todavía no cubre la campaña (`.zxcampaign`).

---

## English

TAB Guardian keeps a copy of every save They Are Billions writes — with date, time and a screenshot — so you can go back when the infected overrun your colony. The game only saves on "Save and Exit" and with a periodic backup; this gives you a real save history.

**Download** the installer from **[Releases](../../releases/latest)**. It asks for the language (English / Spanish), needs no admin rights, and your backups are kept if you uninstall.

- **Automatic history** of every save (up to 200 by default; saves with a note are never deleted), with a screenshot each.
- **Ctrl+F5 — Quick save**: does "Save and Exit" + "Continue" for you.
- **Ctrl+F9 — Back to last save**: closes the game, restores and reopens it.
- Dark-themed **history window**, on-screen notices, options, and update notifications.

First time: click the tray icon → *Calibrate "Quick save"* and follow the steps (hover each button, press Ctrl+F12, click; Ctrl+F11 to finish). Play in **borderless window** mode for Quick save and screenshots to work. If Steam reports a cloud conflict after a restore, choose the **local** files.

---

## Compilar desde el código / Building

Requisitos: Windows, PowerShell 5.1, [ps2exe](https://github.com/MScholtes/PS2EXE) e [Inno Setup 6.7+](https://jrsoftware.org/isinfo.php).

```powershell
Install-Module ps2exe -Scope CurrentUser
winget install JRSoftware.InnoSetup
.\build.ps1 -Version 1.2.0
```

`build.ps1` genera el ícono, el banner y las imágenes del instalador a partir de `Icono.jpg`, compila `build\TAB-Guardian.exe` y arma `dist\TAB-Guardian-Setup-1.2.0.exe`. También se puede correr sin compilar con `TAB-Guardian.vbs` (después de un build, para tener las imágenes).

`TAB-Guardian.ps1` está guardado en UTF-8 con BOM y CRLF (PowerShell 5.1 lo necesita para los acentos). Los textos de la app están en la tabla `$script:textos` (`es` / `en`).

## Autor

**Tinisan** — tinisan.gesell@gmail.com

Proyecto de fan, sin relación con Numantian Games. *They Are Billions* es de sus respectivos dueños.

Licencia [MIT](LICENSE).
