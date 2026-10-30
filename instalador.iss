; Instalador de TAB Guardian (Inno Setup 6). Se compila con build.ps1.
; Instala para el usuario actual, sin pedir permisos de administrador.

#ifndef MyVersion
  #define MyVersion "1.0.0"
#endif

[Setup]
AppId={{151A6091-8466-4BDE-8920-43EE8839782B}
AppName=TAB Guardian
AppVersion={#MyVersion}
AppVerName=TAB Guardian {#MyVersion} by Tinisan
AppPublisher=Tinisan
AppContact=tinisan.gesell@gmail.com
AppSupportURL=mailto:tinisan.gesell@gmail.com
AppCopyright=by Tinisan - tinisan.gesell@gmail.com
AppComments=Guardado automático para They Are Billions
VersionInfoCompany=Tinisan
DefaultDirName={localappdata}\Programs\TAB Guardian
DefaultGroupName=TAB Guardian
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=dist
OutputBaseFilename=TAB-Guardian-Setup-{#MyVersion}
SetupIconFile=build\TAB-Guardian.ico
UninstallDisplayIcon={app}\TAB-Guardian.exe
UninstallDisplayName=TAB Guardian
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=force
RestartApplications=no

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "inicio";  Description: "Iniciar TAB Guardian con Windows (recomendado)"
Name: "escritorio"; Description: "Crear acceso directo en el escritorio"; Flags: unchecked

[Files]
Source: "build\TAB-Guardian.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\TAB-Guardian.exe.config"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\TAB-Guardian.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\TAB Guardian"; Filename: "{app}\TAB-Guardian.exe"; WorkingDir: "{app}"
Name: "{group}\Desinstalar TAB Guardian"; Filename: "{uninstallexe}"
Name: "{userdesktop}\TAB Guardian"; Filename: "{app}\TAB-Guardian.exe"; WorkingDir: "{app}"; Tasks: escritorio
; Mismo nombre que usa el programa en "Iniciar con Windows", así el tilde del menú coincide
Name: "{userstartup}\TAB Guardian"; Filename: "{app}\TAB-Guardian.exe"; WorkingDir: "{app}"; Comment: "TAB Guardian - backups de They Are Billions"; Tasks: inicio

[Run]
Filename: "{app}\TAB-Guardian.exe"; Description: "Abrir TAB Guardian ahora"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM TAB-Guardian.exe"; Flags: runhidden; RunOnceId: "CerrarGuardian"

[UninstallDelete]
; Por si lo activaron desde el menú del icono. Los backups (Documentos\My Games\...\SaveSlots) NO se tocan.
Type: files; Name: "{userstartup}\TAB Guardian.lnk"
