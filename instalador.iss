; Instalador de TAB Guardian (Inno Setup 6.7+). Se compila con build.ps1.
; Instala para el usuario actual, sin pedir permisos de administrador.
; Bilingüe: pregunta el idioma al empezar y se lo pasa al programa (registro).

#ifndef MyVersion
  #define MyVersion "1.0.0"
#endif
#ifndef WizGrande
  #define WizGrande "build\wizard-164.png"
#endif
#ifndef WizChica
  #define WizChica "build\wizard-chica-55.png"
#endif

[Setup]
AppId={{151A6091-8466-4BDE-8920-43EE8839782B}
AppName=TAB Guardian
AppVersion={#MyVersion}
AppVerName=TAB Guardian {#MyVersion} by Tinisan
AppPublisher=Tinisan
AppContact=tinisan.gesell@gmail.com
AppSupportURL=mailto:tinisan.gesell@gmail.com
AppPublisherURL=https://github.com/gsivg/tab-guardian
AppUpdatesURL=https://github.com/gsivg/tab-guardian/releases
AppCopyright=by Tinisan - tinisan.gesell@gmail.com
AppComments=Auto-save & save history for They Are Billions
VersionInfoCompany=Tinisan
DefaultDirName={localappdata}\Programs\TAB Guardian
DefaultGroupName=TAB Guardian
DisableProgramGroupPage=yes
DisableWelcomePage=no
PrivilegesRequired=lowest
OutputDir=dist
OutputBaseFilename=TAB-Guardian-Setup-{#MyVersion}
SetupIconFile=build\TAB-Guardian.ico
UninstallDisplayIcon={app}\TAB-Guardian.exe
UninstallDisplayName=TAB Guardian
Compression=lzma2
SolidCompression=yes
; Oscuro siempre, como la app
WizardStyle=modern dark
WizardImageFile={#WizGrande}
WizardSmallImageFile={#WizChica}
WizardImageStretch=yes
ShowLanguageDialog=yes
CloseApplications=force
RestartApplications=no

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
es.TareaInicio=Iniciar TAB Guardian con Windows (recomendado)
en.TareaInicio=Start TAB Guardian with Windows (recommended)
es.TareaEscritorio=Crear acceso directo en el escritorio
en.TareaEscritorio=Create a desktop shortcut
es.AbrirAhora=Abrir TAB Guardian ahora
en.AbrirAhora=Launch TAB Guardian now
es.Desinstalar=Desinstalar TAB Guardian
en.Desinstalar=Uninstall TAB Guardian
es.Descripcion=TAB Guardian - backups de They Are Billions
en.Descripcion=TAB Guardian - They Are Billions backups

[Tasks]
Name: "inicio"; Description: "{cm:TareaInicio}"
Name: "escritorio"; Description: "{cm:TareaEscritorio}"; Flags: unchecked

[Files]
Source: "build\TAB-Guardian.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\TAB-Guardian.exe.config"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\TAB-Guardian.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\logo.png"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\banner.jpg"; DestDir: "{app}"; Flags: ignoreversion

[Registry]
; El programa usa este idioma mientras no se elija otro en Opciones
Root: HKCU; Subkey: "Software\TAB Guardian"; ValueType: string; ValueName: "Language"; ValueData: "{language}"; Flags: uninsdeletekey

[Icons]
Name: "{group}\TAB Guardian"; Filename: "{app}\TAB-Guardian.exe"; WorkingDir: "{app}"
Name: "{group}\{cm:Desinstalar}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\TAB Guardian"; Filename: "{app}\TAB-Guardian.exe"; WorkingDir: "{app}"; Tasks: escritorio
; Mismo nombre que usa el programa en "Iniciar con Windows", así la opción coincide
Name: "{userstartup}\TAB Guardian"; Filename: "{app}\TAB-Guardian.exe"; WorkingDir: "{app}"; Comment: "{cm:Descripcion}"; Tasks: inicio

[Run]
Filename: "{app}\TAB-Guardian.exe"; Description: "{cm:AbrirAhora}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM TAB-Guardian.exe"; Flags: runhidden; RunOnceId: "CerrarGuardian"

[UninstallDelete]
; Por si lo activaron desde Opciones. Los backups (Documentos\My Games\...\SaveSlots) NO se tocan.
Type: files; Name: "{userstartup}\TAB Guardian.lnk"
