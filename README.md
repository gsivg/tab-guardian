# TAB Guardian

**Guardado automático e historial de partidas para *They Are Billions*** — by Tinisan

They Are Billions no tiene guardado manual: solo guarda al hacer "Guardar y salir" y cada tanto un backup automático. Si te comen, perdiste la partida. TAB Guardian queda al lado del reloj y guarda una copia de cada partida que el juego escribe, con fecha, hora y una captura de pantalla, para que puedas volver atrás cuando quieras.

## Descarga

👉 Bajá el instalador desde **[Releases](../../releases/latest)** (`TAB-Guardian-Setup-x.y.z.exe`).

- No necesita permisos de administrador (se instala para tu usuario).
- Opcional: iniciar con Windows.
- Al desinstalar, tus backups **no** se borran.

> Windows SmartScreen o algún antivirus pueden avisar porque el programa no está firmado digitalmente. Es normal en herramientas chicas: "Más información" → "Ejecutar de todas formas".

## Qué hace

- **Historial automático**: cada vez que el juego guarda, copia la partida (`.zxsav` + `.zxcheck`) a `Documentos\My Games\They Are Billions\SaveSlots\Historial`. Guarda hasta 200; los que tienen nota no se borran nunca.
- **Captura de pantalla** de la partida en cada guardado, para distinguir cuál es cuál.
- **Ctrl+F5 — Guardar ya**: hace "Guardar y salir" + "Continuar" solo, en segundos.
- **Ctrl+F9 — Volver al último guardado**: cierra el juego, restaura y lo vuelve a abrir.
- **Ventana de historial**: restaurar cualquier guardado, ponerle nota, borrar.

## Cómo se usa

1. Instalalo y abrilo. Aparece el ícono al lado del reloj (la primera vez se abre la ayuda).
2. **Calibrar "Guardar ya"** (una sola vez): clic en el ícono → *Calibrar "Guardar ya"...*
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

## Compilar desde el código

Requisitos: Windows, PowerShell 5.1, [ps2exe](https://github.com/MScholtes/PS2EXE) e [Inno Setup 6](https://jrsoftware.org/isinfo.php).

```powershell
Install-Module ps2exe -Scope CurrentUser
winget install JRSoftware.InnoSetup
.\build.ps1 -Version 1.1.0
```

Genera `build\TAB-Guardian.exe` y `dist\TAB-Guardian-Setup-1.1.0.exe`. También se puede correr sin compilar con `TAB-Guardian.vbs`.

`TAB-Guardian.ps1` está guardado en UTF-8 con BOM y CRLF (PowerShell 5.1 lo necesita para los acentos).

## Autor

**Tinisan** — tinisan.gesell@gmail.com

Proyecto de fan, sin relación con Numantian Games. *They Are Billions* y su ícono son de sus respectivos dueños.

Licencia [MIT](LICENSE).
