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
CloseApplications=yes
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "ffmpeg"; Description: "Install FFmpeg (video encoding without GStreamer)"; GroupDescription: "Optional tools:"; Flags: unchecked

[Files]
Source: "lumina-setup.ps1"; DestDir: "{app}\setup"; Flags: ignoreversion
Source: "{#IconSource}"; DestDir: "{app}\setup"; DestName: "lumina-studio.ico"; Flags: ignoreversion

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

procedure CurStepChanged(CurStep: TSetupStep);
var
  Extra: String;
  Show: Integer;
begin
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
  Extra := '-Uninstall';
  if FileExists(ExpandConstant('{localappdata}\Lumina\install-state.json')) and
    (SuppressibleMsgBox('Also remove the Flutter SDK that Lumina Studio installed in ' +
      ExpandConstant('{localappdata}\Lumina\flutter') + '?' + #13#10#13#10 +
      'Keep it if other projects use it.', mbConfirmation, MB_YESNO or MB_DEFBUTTON2, IDNO) = IDYES) then
    Extra := Extra + ' -RemoveFlutter';
  Exec(PowerShellExe, ScriptArgs(ExpandConstant('{app}\setup\lumina-setup.ps1'), Extra), '', SW_HIDE,
    ewWaitUntilTerminated, Code);
end;
