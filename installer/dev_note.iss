; Script Inno Setup pour Dev Note.
;
; Le binaire n'est pas signé (voir README), donc SmartScreen avertira quand
; meme a l'installation et au premier lancement : c'est attendu pour une
; preversion et n'a rien a voir avec ce script.
;
; Compiler :
;   iscc installer\dev_note.iss
; ou, si le compilateur n'est pas sur le PATH :
;   "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" installer\dev_note.iss
;
; Le resultat est ecrit dans dist\, qui est deja ignore par git.

#define MyAppName "Dev Note"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "Samson BADAYODI"
#define MyAppURL "https://github.com/samson28/dev_note"
#define MyAppExeName "dev_note.exe"
; Chemin, relatif a ce fichier .iss, vers le dossier produit par
; `flutter build windows --release`.
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
; Genere une fois pour toutes avec `iscc /GUID` ou un generateur de GUID en
; ligne ; reste stable d'une version a l'autre pour que Windows reconnaisse
; les mises a jour comme le meme logiciel plutot que d'en installer un second.
AppId={{9E6D9D6C-6F2B-4E5F-9C1A-2E5C9B1A0F3D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
; Pas d'admin requis : installe dans le profil utilisateur si lance sans
; elevation, ce qui evite un second avertissement UAC en plus de SmartScreen.
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=dev_note-{#MyAppVersion}-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
LicenseFile=..\LICENSE
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "Lancer Dev Note au demarrage de Windows"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Tout le contenu du build release : l'exe, data\, et les DLL des plugins.
; L'app ne fonctionne pas sans ce dossier complet, d'ou recursesubdirs.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Le desinstalleur retire le programme mais jamais le coffre : les notes de
; l'utilisateur vivent dans %USERPROFILE%\JotVault, en dehors de {app}, et ce
; n'est deliberement pas nettoye ici.
Type: filesandordirs; Name: "{app}"
