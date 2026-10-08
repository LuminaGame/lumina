; Lumina Studio setup for Windows (Inno Setup 6).
;
; A small per-user setup.exe: it installs the prerequisites to build and run
; Lumina projects through winget (Git, the Visual Studio 2022 C++ Build Tools,
; GStreamer, optionally FFmpeg), installs Flutter (stable) unless one is on
; PATH, then downloads the latest Lumina Studio release from GitHub into
; {app}. The editor itself is not embedded. The work is done by
; lumina-setup.ps1, which is installed next to the editor and backs the
; "Update Lumina Studio" shortcut.
;
; Command line (besides the standard Inno Setup switches):
;   /DRYRUN              list what would be installed and downloaded, change nothing
;   /DRYRUNLOG=<file>    where the dry run writes its report
;                        (default: %TEMP%\lumina-studio-setup-dryrun.txt)
;   /FFMPEG              also install FFmpeg (the "Install FFmpeg" task)
;
; Build: installer\windows\build.ps1 -Version 1.2.3 -Tag v1.2.3
;   (ISCC /DAppVersion=1.2.3 /DAppTag=v1.2.3 lumina-studio.iss)
;
; Signed build: build.ps1 -SignToolCommand "<sign tool command with $f>"
; passes ISCC /Slumina=<command> /DSignToolName=lumina. Setup.exe and the
; uninstaller it embeds are then both Authenticode-signed; without the define
; nothing is signed.
;
; 3D model files (the "modelfiles" task, on by default): .glb, .gltf, .fbx and
; .obj get Lumina Studio in Explorer's "Open with" (OpenWithProgids and
; Applications\lumina_ui.exe\SupportedTypes; the default program of those
; types is never changed), and, when build.ps1 passes
; /DThumbnailProviderDir=<dir> (thumbnail_provider\build.ps1 built it), a shell
; thumbnail provider that renders them with the editor
; ({app}\setup\shell\lumina_thumbnails.dll, registered under
; SystemFileAssociations so a default program's own thumbnails keep priority).
; Lumina assets (the "luminaassets" task, on by default): .lmas opens with
; Lumina Studio (its project, then the asset's editor) and becomes its
; default program when no other program claims it (Lumina's own type), and
; the same provider shows the Content Browser's thumbnail of the asset.
; All of it is per-user and removed on uninstall.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef AppTag
  #define AppTag "v" + AppVersion
#endif
#ifndef NumericVersion
  #define NumericVersion "0.0.0.0"
#endif
#ifndef Repository
  #define Repository "LuminaGame/lumina"
#endif

#define AppName "Lumina Studio"
#define AppExe "lumina_ui.exe"
#define IconSource "..\..\lumina_ui\windows\runner\resources\app_icon.ico"
; The ProgID "Open with" lists, and the thumbnail provider's class
; (lumina_thumbnail_provider.cpp kClsid) and the shell's thumbnail handler
; key, with "{{" because "{" opens an Inno Setup constant.
#define ModelProgId "LuminaStudio.Model"
#define AssetProgId "LuminaStudio.Asset"
#define ThumbnailClsid "{{4C2F5D1E-8A3B-4E7C-9D21-6B0A5F3E7C18}"
#define ThumbnailHandler "{{e357fccd-a995-4576-b01f-234630154e96}"
#define ProviderDll "lumina_thumbnails.dll"

[Setup]
AppId={{6C1F7E52-3B8A-4E0D-9A57-5D2C4B8E9F13}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Lumina
AppPublisherURL=https://github.com/{#Repository}
AppSupportURL=https://github.com/{#Repository}/issues
AppUpdatesURL=https://github.com/{#Repository}/releases
VersionInfoVersion={#NumericVersion}
VersionInfoProductName={#AppName}
VersionInfoDescription={#AppName} Setup
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputBaseFilename=lumina-studio-setup-{#AppTag}-windows-x64
SetupIconFile={#IconSource}
UninstallDisplayIcon={app}\setup\lumina-studio.ico
UninstallDisplayName={#AppName}
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
ChangesEnvironment=yes
; Explorer re-reads "Open with" and the thumbnail handlers after install and
; uninstall.
ChangesAssociations=yes
CloseApplications=yes
SetupLogging=yes
; Off: Windows hands the mitigation on to every process setup starts (the
; PowerShell helper, and Lumina Studio from the finish page), which then
; cannot traverse the junctions the editor makes for its engine checkout and
; projects. A per-user setup that never elevates gains nothing from it.
RedirectionGuard=no
#ifdef SignToolName
SignTool={#SignToolName}
SignedUninstaller=yes
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "ffmpeg"; Description: "Install FFmpeg (video encoding without GStreamer)"; GroupDescription: "Optional tools:"; Flags: unchecked
#ifdef ThumbnailProviderDir
Name: "modelfiles"; Description: "Add Lumina Studio to ""Open with"" for .glb, .gltf, .fbx and .obj files and show their 3D previews as thumbnails"; GroupDescription: "3D model files:"
Name: "luminaassets"; Description: "Open Lumina assets (.lmas) with Lumina Studio and show their Content Browser thumbnails"; GroupDescription: "3D model files:"
#else
Name: "modelfiles"; Description: "Add Lumina Studio to ""Open with"" for .glb, .gltf, .fbx and .obj files"; GroupDescription: "3D model files:"
Name: "luminaassets"; Description: "Open Lumina assets (.lmas) with Lumina Studio"; GroupDescription: "3D model files:"
#endif

[Files]
Source: "lumina-setup.ps1"; DestDir: "{app}\setup"; Flags: ignoreversion
Source: "{#IconSource}"; DestDir: "{app}\setup"; DestName: "lumina-studio.ico"; Flags: ignoreversion
#ifdef ThumbnailProviderDir
  #ifdef SignToolName
Source: "{#ThumbnailProviderDir}\{#ProviderDll}"; DestDir: "{app}\setup\shell"; Flags: ignoreversion sign; Tasks: modelfiles or luminaassets
  #else
Source: "{#ThumbnailProviderDir}\{#ProviderDll}"; DestDir: "{app}\setup\shell"; Flags: ignoreversion; Tasks: modelfiles or luminaassets
  #endif
#endif

[Registry]
; "Open with" for 3D model files: a ProgID listed under each extension's
; OpenWithProgids, and the editor under Applications with its SupportedTypes.
; No extension's default value is written: the default program stays.
Root: HKA; Subkey: "Software\Classes\{#ModelProgId}"; ValueType: string; ValueName: ""; ValueData: "3D model"; Flags: uninsdeletekey; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\{#ModelProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\setup\lumina-studio.ico,0"; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\{#ModelProgId}\shell\open"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\{#ModelProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Flags: uninsdeletekey; Tasks: modelfiles or luminaassets
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\setup\lumina-studio.ico,0"; Tasks: modelfiles or luminaassets
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: modelfiles or luminaassets
Root: HKA; Subkey: "Software\Classes\.glb"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\.glb\OpenWithProgids"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\.glb\OpenWithProgids"; ValueType: none; ValueName: "{#ModelProgId}"; Flags: uninsdeletevalue; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\SupportedTypes"; ValueType: string; ValueName: ".glb"; ValueData: ""; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\.gltf"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\.gltf\OpenWithProgids"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\.gltf\OpenWithProgids"; ValueType: none; ValueName: "{#ModelProgId}"; Flags: uninsdeletevalue; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\SupportedTypes"; ValueType: string; ValueName: ".gltf"; ValueData: ""; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\.fbx"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\.fbx\OpenWithProgids"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\.fbx\OpenWithProgids"; ValueType: none; ValueName: "{#ModelProgId}"; Flags: uninsdeletevalue; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\SupportedTypes"; ValueType: string; ValueName: ".fbx"; ValueData: ""; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\.obj"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\.obj\OpenWithProgids"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\.obj\OpenWithProgids"; ValueType: none; ValueName: "{#ModelProgId}"; Flags: uninsdeletevalue; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\SupportedTypes"; ValueType: string; ValueName: ".obj"; ValueData: ""; Tasks: modelfiles
; Lumina assets: Lumina's own type, so Lumina Studio becomes the default
; program of .lmas unless another program already is.
Root: HKA; Subkey: "Software\Classes\{#AssetProgId}"; ValueType: string; ValueName: ""; ValueData: "Lumina asset"; Flags: uninsdeletekey; Tasks: luminaassets
Root: HKA; Subkey: "Software\Classes\{#AssetProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\setup\lumina-studio.ico,0"; Tasks: luminaassets
Root: HKA; Subkey: "Software\Classes\{#AssetProgId}\shell\open"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Tasks: luminaassets
Root: HKA; Subkey: "Software\Classes\{#AssetProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: luminaassets
Root: HKA; Subkey: "Software\Classes\.lmas"; Flags: uninsdeletekeyifempty; Tasks: luminaassets
Root: HKA; Subkey: "Software\Classes\.lmas"; ValueType: string; ValueName: ""; ValueData: "{#AssetProgId}"; Flags: createvalueifdoesntexist uninsdeletevalue; Tasks: luminaassets
Root: HKA; Subkey: "Software\Classes\.lmas\OpenWithProgids"; Flags: uninsdeletekeyifempty; Tasks: luminaassets
Root: HKA; Subkey: "Software\Classes\.lmas\OpenWithProgids"; ValueType: none; ValueName: "{#AssetProgId}"; Flags: uninsdeletevalue; Tasks: luminaassets
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\SupportedTypes"; ValueType: string; ValueName: ".lmas"; ValueData: ""; Tasks: luminaassets
#ifdef ThumbnailProviderDir
; The shell thumbnail provider: an in-process COM class (the shell runs it in
; its isolated surrogate), the thumbnail handler of each type under
; SystemFileAssociations.
Root: HKA; Subkey: "Software\Classes\CLSID\{#ThumbnailClsid}"; ValueType: string; ValueName: ""; ValueData: "Lumina Studio 3D model thumbnail provider"; Flags: uninsdeletekey; Tasks: modelfiles or luminaassets
Root: HKA; Subkey: "Software\Classes\CLSID\{#ThumbnailClsid}\InprocServer32"; ValueType: string; ValueName: ""; ValueData: "{app}\setup\shell\{#ProviderDll}"; Tasks: modelfiles or luminaassets
Root: HKA; Subkey: "Software\Classes\CLSID\{#ThumbnailClsid}\InprocServer32"; ValueType: string; ValueName: "ThreadingModel"; ValueData: "Apartment"; Tasks: modelfiles or luminaassets
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.glb"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.glb\ShellEx"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.glb\ShellEx\{#ThumbnailHandler}"; ValueType: string; ValueName: ""; ValueData: "{#ThumbnailClsid}"; Flags: uninsdeletekey; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.gltf"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.gltf\ShellEx"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.gltf\ShellEx\{#ThumbnailHandler}"; ValueType: string; ValueName: ""; ValueData: "{#ThumbnailClsid}"; Flags: uninsdeletekey; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.fbx"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.fbx\ShellEx"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.fbx\ShellEx\{#ThumbnailHandler}"; ValueType: string; ValueName: ""; ValueData: "{#ThumbnailClsid}"; Flags: uninsdeletekey; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.obj"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.obj\ShellEx"; Flags: uninsdeletekeyifempty; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.obj\ShellEx\{#ThumbnailHandler}"; ValueType: string; ValueName: ""; ValueData: "{#ThumbnailClsid}"; Flags: uninsdeletekey; Tasks: modelfiles
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.lmas"; Flags: uninsdeletekeyifempty; Tasks: luminaassets
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.lmas\ShellEx"; Flags: uninsdeletekeyifempty; Tasks: luminaassets
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.lmas\ShellEx\{#ThumbnailHandler}"; ValueType: string; ValueName: ""; ValueData: "{#ThumbnailClsid}"; Flags: uninsdeletekey; Tasks: luminaassets
#endif

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; IconFilename: "{app}\setup\lumina-studio.ico"
Name: "{group}\Update {#AppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\setup\lumina-setup.ps1"" -StudioOnly -InstallDir ""{app}"" -Repository {#Repository}"; IconFilename: "{app}\setup\lumina-studio.ico"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; IconFilename: "{app}\setup\lumina-studio.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent; Check: StudioInstalled

[UninstallDelete]
; The downloaded editor is not in Inno Setup's file list.
Type: filesandordirs; Name: "{app}"

[Code]
const
  ExitPrerequisites = 10;
  ExitFlutter = 20;
  ExitDownload = 30;

procedure ExitProcess(uExitCode: Integer); external 'ExitProcess@kernel32.dll stdcall';

var
  SetupResult: Integer;

function HasSwitch(const Name: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), Name) = 0 then
      Result := True;
end;

function SwitchValue(const Name, Default: String): String;
var
  I: Integer;
  P: String;
begin
  Result := Default;
  for I := 1 to ParamCount do
  begin
    P := ParamStr(I);
    if CompareText(Copy(P, 1, Length(Name) + 1), Name + '=') = 0 then
      Result := RemoveQuotes(Copy(P, Length(Name) + 2, MaxInt));
  end;
end;

function PowerShellExe: String;
begin
  Result := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
end;

function ScriptArgs(const Script, Extra: String): String;
begin
  Result := '-NoProfile -ExecutionPolicy Bypass -File ' + AddQuotes(Script) +
    ' -Repository {#Repository} ' + Extra;
end;

function StudioInstalled: Boolean;
begin
  Result := FileExists(ExpandConstant('{app}\{#AppExe}'));
end;

// /DRYRUN: run the script's dry run before any wizard page and exit.
function InitializeSetup: Boolean;
var
  Script, Log, Extra, Report: String;
  Code: Integer;
  Lines: AnsiString;
begin
  Result := True;
  if not HasSwitch('/DRYRUN') then
    Exit;
  Log := SwitchValue('/DRYRUNLOG', ExpandConstant('{%TEMP}\lumina-studio-setup-dryrun.txt'));
  ExtractTemporaryFile('lumina-setup.ps1');
  Script := ExpandConstant('{tmp}\lumina-setup.ps1');
  Extra := '-DryRun -InstallDir ' + AddQuotes(ExpandConstant('{localappdata}\Programs\{#AppName}')) +
    ' -LogPath ' + AddQuotes(Log);
  if HasSwitch('/FFMPEG') then
    Extra := Extra + ' -WithFfmpeg';
  if not Exec(PowerShellExe, ScriptArgs(Script, Extra), '', SW_HIDE, ewWaitUntilTerminated, Code) then
    Code := 1;
  if not WizardSilent then
  begin
    if LoadStringFromFile(Log, Lines) then
      Report := String(Lines)
    else
      Report := 'The dry run wrote no report to ' + Log;
    MsgBox(Report, mbInformation, MB_OK);
  end;
  // ExitProcess skips Setup's own clean-up of its temporary folder.
  DelTree(ExpandConstant('{tmp}'), True, True, True);
  // Leave with the script's exit code (0 for a completed dry run).
  ExitProcess(Code);
end;

function RunSetupScript(const Extra: String; Show: Integer): Integer;
var
  Code: Integer;
begin
  if not Exec(PowerShellExe,
    ScriptArgs(ExpandConstant('{app}\setup\lumina-setup.ps1'),
      '-InstallDir ' + AddQuotes(ExpandConstant('{app}')) +
      ' -LogPath ' + AddQuotes(ExpandConstant('{app}\setup\install.log')) +
      ' -Tag {#AppTag} ' + Extra),
    ExpandConstant('{app}'), Show, ewWaitUntilTerminated, Code) then
    Code := 1;
  Result := Code;
end;

// The thumbnail provider may be loaded by the shell's surrogate process: a
// loaded DLL cannot be overwritten or deleted, but it can be renamed. Moved
// aside into [Folder] it frees its own name; leftovers from earlier runs are
// deleted once nothing holds them.
procedure MoveProviderAside(const Folder: String);
var
  Dll: String;
begin
  Dll := ExpandConstant('{app}\setup\shell\{#ProviderDll}');
  DelTree(AddBackslash(Folder) + 'lumina_thumbnails-*.old', False, True, False);
  if FileExists(Dll) and not DeleteFile(Dll) then
  begin
    ForceDirectories(Folder);
    RenameFile(Dll, AddBackslash(Folder) + 'lumina_thumbnails-' + GetDateTimeString('yyyymmddhhnnsszzz', #0, #0) + '.old');
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Extra: String;
  Show: Integer;
begin
  if CurStep = ssInstall then
    MoveProviderAside(ExpandConstant('{app}\setup\shell'));
  if CurStep <> ssPostInstall then
    Exit;
  Extra := '';
  if WizardIsTaskSelected('ffmpeg') or HasSwitch('/FFMPEG') then
    Extra := '-WithFfmpeg';
  // A visible console: winget and git report their progress there.
  if WizardSilent then Show := SW_HIDE else Show := SW_SHOWNORMAL;
  WizardForm.StatusLabel.Caption := 'Installing prerequisites and downloading Lumina Studio...';
  SetupResult := RunSetupScript(Extra, Show);
  while SetupResult = ExitDownload do
  begin
    if SuppressibleMsgBox('Lumina Studio could not be downloaded from GitHub.' + #13#10#13#10 +
      'Check the internet connection and try again. You can also download it later with ' +
      '"Update Lumina Studio" in the Start menu.' + #13#10#13#10 +
      'Details: ' + ExpandConstant('{app}\setup\install.log'),
      mbError, MB_RETRYCANCEL, IDCANCEL) <> IDRETRY then
      Break;
    SetupResult := RunSetupScript('-StudioOnly', Show);
  end;
  if (SetupResult = ExitPrerequisites) or (SetupResult = ExitFlutter) or (SetupResult = 1) then
    SuppressibleMsgBox('Some prerequisites could not be installed. Lumina Studio may not build projects until they are.' + #13#10#13#10 +
      'Details: ' + ExpandConstant('{app}\setup\install.log'), mbInformation, MB_OK, IDOK);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Extra: String;
  Code: Integer;
begin
  if CurUninstallStep <> usUninstall then
    Exit;
  // Out of {app}, so the folder goes even while the shell holds the DLL.
  MoveProviderAside(ExpandConstant('{%TEMP}\LuminaThumbnails'));
  Extra := '-Uninstall';
  if FileExists(ExpandConstant('{localappdata}\Lumina\install-state.json')) and
    (SuppressibleMsgBox('Also remove the Flutter SDK that Lumina Studio installed in ' +
      ExpandConstant('{localappdata}\Lumina\flutter') + '?' + #13#10#13#10 +
      'Keep it if other projects use it.', mbConfirmation, MB_YESNO or MB_DEFBUTTON2, IDNO) = IDYES) then
    Extra := Extra + ' -RemoveFlutter';
  Exec(PowerShellExe, ScriptArgs(ExpandConstant('{app}\setup\lumina-setup.ps1'), Extra), '', SW_HIDE,
    ewWaitUntilTerminated, Code);
end;
