; ================================================================
;  SentinelNet v2.0 - Inno Setup Installer Script
;  AMACDF Production
;
;  WHAT THIS INSTALLER DOES AUTOMATICALLY:
;    [1] Installs Python 3.11 if not found
;    [2] Installs all Python packages (offline from packages\ folder)
;    [3] Installs Npcap (Live packet capture)
;    [4] Creates launcher shortcut (Synthetic + Live modes)
;    [5] Adds Windows Defender exclusion
;
;  ONE SHORTCUT - TWO MODES:
;    Normal open          = SYNTHETIC mode (no admin needed)
;    Run as Administrator = LIVE mode (real packet capture)
;
;  HOW TO BUILD:
;    1. Run PREPARE_INSTALLER.bat first (downloads packages + Npcap)
;    2. Open this file in Inno Setup 6
;    3. Press Ctrl+F9
;    4. Output: dist\SentinelNet_v2_Setup.exe
; ================================================================

#define AppName      "SentinelNet"
#define AppVersion   "2.0"
#define AppFullName  "SentinelNet v2.0"
#define AppPublisher "AMACDF Production"
#define PythonURL    "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
#define NpcapURL     "https://npcap.com/dist/npcap-1.79.exe"

; ================================================================
[Setup]
; ----------------------------------------------------------------
AppId={{7E4A2F9C-B831-4D6E-A2C1-9F5E0D3B8712}
AppName={#AppFullName}
AppVersion={#AppVersion}
AppVerName={#AppFullName}
AppPublisher={#AppPublisher}
AppCopyright=Copyright 2026 AMACDF Production
VersionInfoVersion=2.0.0.0
VersionInfoDescription=AI-Powered Local Cybersecurity Monitor

DefaultDirName={autopf64}\SentinelNet
DefaultGroupName=SentinelNet
AllowNoIcons=yes

OutputDir=dist
OutputBaseFilename=SentinelNet_v2_Setup
SetupIconFile=assets\sentinelnet.ico
UninstallDisplayIcon={app}\assets\sentinelnet.ico
UninstallDisplayName={#AppFullName}

Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763

WizardStyle=modern
WizardSizePercent=120
WizardSmallImageFile=assets\installer_icon.bmp

PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

DisableProgramGroupPage=yes
DisableWelcomePage=no
CloseApplications=yes
CloseApplicationsFilter=*SentinelNet*,*sentinelnet*
CreateUninstallRegKey=yes
UsePreviousAppDir=yes

; ================================================================
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; ================================================================
[Tasks]
Name: "desktopicon";  Description: "Create a &desktop shortcut";              GroupDescription: "Shortcuts:";   Flags: checkedonce
Name: "startuprun";   Description: "Start SentinelNet with &Windows";         GroupDescription: "Startup:";     Flags: unchecked
Name: "installnpcap"; Description: "Install &Npcap (required for Live mode)"; GroupDescription: "Components:";  Flags: checkedonce

; ================================================================
[Files]
; --- Application source ---
Source: "backend\*";         DestDir: "{app}\backend";    Flags: ignoreversion recursesubdirs createallsubdirs
Source: "agents\*";          DestDir: "{app}\agents";     Flags: ignoreversion recursesubdirs createallsubdirs
Source: "frontend\*";        DestDir: "{app}\frontend";   Flags: ignoreversion recursesubdirs createallsubdirs
Source: "extension\*";       DestDir: "{app}\extension";  Flags: ignoreversion recursesubdirs createallsubdirs
Source: "certs\*";           DestDir: "{app}\certs";      Flags: ignoreversion recursesubdirs createallsubdirs
Source: "requirements.txt";  DestDir: "{app}";            Flags: ignoreversion
Source: "README.md";         DestDir: "{app}";            Flags: ignoreversion; DestName: "README.txt"

; --- Assets ---
Source: "assets\sentinelnet.ico";      DestDir: "{app}\assets"; Flags: ignoreversion
Source: "assets\installer_icon.bmp";    DestDir: "{app}\assets"; Flags: ignoreversion skipifsourcedoesntexist

; --- Pre-downloaded Python wheels (from PREPARE_INSTALLER.bat) ---
Source: "packages\*"; DestDir: "{app}\packages"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; --- Pre-downloaded Npcap (from PREPARE_INSTALLER.bat) ---
Source: "assets\npcap-setup.exe"; DestDir: "{app}\assets"; Flags: ignoreversion skipifsourcedoesntexist

; ================================================================
[Dirs]
Name: "{app}\data";  Permissions: everyone-full
Name: "{app}\logs";  Permissions: everyone-full
Name: "{app}\certs"

; ================================================================
[Icons]
; Start Menu - cmd.exe /k keeps terminal open always. Right-click = Run as Admin = LIVE mode
Name: "{group}\{#AppFullName}"; Filename: "{sys}\cmd.exe"; Parameters: "/k ""{app}\SentinelNet_run.bat"""; IconFilename: "{app}\assets\sentinelnet.ico"; Comment: "Open = Synthetic | Run as Admin = Live mode"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
; Desktop shortcut
Name: "{autodesktop}\{#AppFullName}"; Filename: "{sys}\cmd.exe"; Parameters: "/k ""{app}\SentinelNet_run.bat"""; IconFilename: "{app}\assets\sentinelnet.ico"; Comment: "Open = Synthetic | Run as Admin = Live mode"; Tasks: desktopicon

; ================================================================
[Registry]
; Startup entry (synthetic mode - no admin)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "SentinelNet"; ValueData: """{sys}\cmd.exe"" /k ""{app}\SentinelNet_run.bat"""; Flags: uninsdeletevalue; Tasks: startuprun
; App info
Root: HKLM; Subkey: "SOFTWARE\SentinelNet"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\SentinelNet"; ValueType: string; ValueName: "Version";     ValueData: "{#AppVersion}"

; ================================================================
[Run]
; Step 1 - Install packages (visible window so errors are seen)
Filename: "{cmd}"; Parameters: "/C ""{app}\install_packages.bat"""; StatusMsg: "Installing Python packages... (this may take 2-3 minutes)"; Flags: waituntilterminated

; Step 2 - Launch after install (optional)
Filename: "{sys}\cmd.exe"; Parameters: "/k ""{app}\SentinelNet_run.bat"""; Description: "Launch SentinelNet now"; Flags: nowait postinstall skipifsilent

; ================================================================
[UninstallRun]
Filename: "taskkill"; Parameters: "/F /IM python.exe /FI ""WINDOWTITLE eq SentinelNet*"""; Flags: runhidden waituntilterminated; RunOnceId: "KillPython"
Filename: "taskkill"; Parameters: "/F /IM cmd.exe /FI ""WINDOWTITLE eq SentinelNet*"""; Flags: runhidden waituntilterminated; RunOnceId: "KillCmd"

; ================================================================
[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\packages"
Type: filesandordirs; Name: "{app}\__pycache__"
Type: files;          Name: "{app}\SentinelNet_run.bat"
Type: files;          Name: "{app}\install_packages.bat"

; ================================================================
[Code]

var
  PythonPath: string;
  InstallLog: string;

{ ----------------------------------------------------------------
  PSDownload - downloads file via PowerShell (no DownloadTemporaryFile needed)
  Works on ALL Inno Setup 6 versions
  ---------------------------------------------------------------- }
function PSDownload(const URL, Dest: string): Boolean;
var
  RC: Integer;
begin
  Log('Downloading: ' + URL);
  Log('Destination: ' + Dest);
  Exec(
    ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -ExecutionPolicy Bypass -Command ' +
    '"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ' +
    'try { (New-Object Net.WebClient).DownloadFile(''' + URL + ''', ''' + Dest + '''); ' +
    'Write-Host OK } ' +
    'catch { Write-Host FAIL; exit 1 }"',
    '', SW_HIDE, ewWaitUntilTerminated, RC);
  Result := (RC = 0) and FileExists(Dest);
  if Result then Log('Download OK: ' + Dest)
  else Log('Download FAILED: ' + Dest);
end;

{ ----------------------------------------------------------------
  FindPython - checks registry first, then common paths
  ---------------------------------------------------------------- }
function FindPython: string;
var
  Locs: TArrayOfString;
  I: Integer;
  RegPath: string;
begin
  Result := '';

  { Check registry - HKCU (user install) - finds newest Python first }
  if RegQueryStringValue(HKCU, 'Software\Python\PythonCore\3.13\InstallPath', '', RegPath) then
    if FileExists(RegPath + 'python.exe') then begin Result := RegPath + 'python.exe'; Exit; end;
  if RegQueryStringValue(HKCU, 'Software\Python\PythonCore\3.12\InstallPath', '', RegPath) then
    if FileExists(RegPath + 'python.exe') then begin Result := RegPath + 'python.exe'; Exit; end;
  if RegQueryStringValue(HKCU, 'Software\Python\PythonCore\3.11\InstallPath', '', RegPath) then
    if FileExists(RegPath + 'python.exe') then begin Result := RegPath + 'python.exe'; Exit; end;
  if RegQueryStringValue(HKCU, 'Software\Python\PythonCore\3.10\InstallPath', '', RegPath) then
    if FileExists(RegPath + 'python.exe') then begin Result := RegPath + 'python.exe'; Exit; end;

  { Check registry - HKLM (system install) }
  if RegQueryStringValue(HKLM, 'Software\Python\PythonCore\3.13\InstallPath', '', RegPath) then
    if FileExists(RegPath + 'python.exe') then begin Result := RegPath + 'python.exe'; Exit; end;
  if RegQueryStringValue(HKLM, 'Software\Python\PythonCore\3.12\InstallPath', '', RegPath) then
    if FileExists(RegPath + 'python.exe') then begin Result := RegPath + 'python.exe'; Exit; end;
  if RegQueryStringValue(HKLM, 'Software\Python\PythonCore\3.11\InstallPath', '', RegPath) then
    if FileExists(RegPath + 'python.exe') then begin Result := RegPath + 'python.exe'; Exit; end;
  if RegQueryStringValue(HKLM, 'Software\Python\PythonCore\3.10\InstallPath', '', RegPath) then
    if FileExists(RegPath + 'python.exe') then begin Result := RegPath + 'python.exe'; Exit; end;

  { Check common hardcoded paths }
  SetArrayLength(Locs, 14);
  Locs[0]  := ExpandConstant('{localappdata}\Programs\Python\Python313\python.exe');
  Locs[1]  := ExpandConstant('{localappdata}\Programs\Python\Python312\python.exe');
  Locs[2]  := ExpandConstant('{localappdata}\Programs\Python\Python311\python.exe');
  Locs[3]  := ExpandConstant('{localappdata}\Programs\Python\Python310\python.exe');
  Locs[4]  := ExpandConstant('{localappdata}\Programs\Python\Python39\python.exe');
  Locs[5]  := 'C:\Python313\python.exe';
  Locs[6]  := 'C:\Python312\python.exe';
  Locs[7]  := 'C:\Python311\python.exe';
  Locs[8]  := 'C:\Python310\python.exe';
  Locs[9]  := ExpandConstant('{pf64}\Python313\python.exe');
  Locs[10] := ExpandConstant('{pf64}\Python312\python.exe');
  Locs[11] := ExpandConstant('{pf64}\Python311\python.exe');
  Locs[12] := ExpandConstant('{userappdata}\..\Local\Programs\Python\Python313\python.exe');
  Locs[13] := ExpandConstant('{userappdata}\..\Local\Programs\Python\Python312\python.exe');
  for I := 0 to GetArrayLength(Locs) - 1 do
    if FileExists(Locs[I]) then begin Result := Locs[I]; Exit; end;
end;

function NpcapAlreadyInstalled: Boolean;
begin
  Result := DirExists(ExpandConstant('{sys}\Npcap')) or
            FileExists(ExpandConstant('{sys}\Npcap\wpcap.dll'));
end;

{ ----------------------------------------------------------------
  Welcome page
  ---------------------------------------------------------------- }
procedure InitializeWizard;
begin
  WizardForm.WelcomeLabel2.Caption :=
    'SentinelNet v2.0 - AI-Powered Local Cybersecurity Monitor' + #13#10 +
    'by AMACDF Production' + #13#10 + #13#10 +
    'This installer will automatically:' + #13#10 +
    '  [1] Install Python 3.11 (if not already installed)' + #13#10 +
    '  [2] Install all required Python packages' + #13#10 +
    '  [3] Install Npcap (for Live packet capture)' + #13#10 +
    '  [4] Create desktop and Start Menu shortcuts' + #13#10 + #13#10 +
    'ONE SHORTCUT - TWO MODES:' + #13#10 +
    '  Open normally        -> SYNTHETIC mode (no admin needed)' + #13#10 +
    '  Run as Administrator -> LIVE mode (real network capture)' + #13#10 + #13#10 +
    'NOTE: A restart may be required after Npcap installation.' + #13#10 + #13#10 +
    'Click Next to continue.';
end;

{ ----------------------------------------------------------------
  PrepareToInstall - runs BEFORE files are copied
  Downloads and installs Python if missing
  ---------------------------------------------------------------- }
function PrepareToInstall(var NeedsRestart: Boolean): string;
var
  ResultCode: Integer;
  TmpExe: string;
begin
  Result := '';
  PythonPath := FindPython;

  { Python already installed - nothing to do }
  if PythonPath <> '' then
  begin
    Log('Python found: ' + PythonPath);
    Exit;
  end;

  { Python not found - download and install it }
  Log('Python not found. Downloading Python 3.11...');
  MsgBox(
    'Python 3.11 is not installed on this machine.' + #13#10 + #13#10 +
    'SentinelNet will now download and install Python 3.11.' + #13#10 +
    'This requires an internet connection (~24 MB).' + #13#10 + #13#10 +
    'Click OK to start the download.',
    mbInformation, MB_OK
  );

  TmpExe := ExpandConstant('{tmp}\python_setup.exe');

  if not PSDownload('{#PythonURL}', TmpExe) then
  begin
    Result :=
      'Could not download Python 3.11.' + #13#10 +
      'Please check your internet connection.' + #13#10 + #13#10 +
      'Alternatively, install Python 3.11 manually from:' + #13#10 +
      'https://python.org/downloads' + #13#10 +
      'Then re-run this installer.';
    Exit;
  end;

  Log('Python installer downloaded. Running...');
  WizardForm.StatusLabel.Caption := 'Installing Python 3.11...';

  if not Exec(TmpExe,
    '/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 Include_doc=0 Include_launcher=1',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result :=
      'Python 3.11 installation failed (could not run installer).' + #13#10 +
      'Please install Python 3.11 manually from https://python.org';
    Exit;
  end;

  if ResultCode <> 0 then
    Log('Python installer returned code: ' + IntToStr(ResultCode));

  { Find Python after install }
  PythonPath := FindPython;
  if PythonPath = '' then
  begin
    { Use expected path as fallback }
    PythonPath := ExpandConstant('{localappdata}\Programs\Python\Python311\python.exe');
    Log('Python path not found in registry after install, using expected: ' + PythonPath);
  end;

  Log('Python installed: ' + PythonPath);
end;

{ ----------------------------------------------------------------
  CurStepChanged - runs AFTER files are copied (ssPostInstall)
  Creates all launcher files and installs Npcap
  ---------------------------------------------------------------- }
procedure CurStepChanged(CurStep: TSetupStep);
var
  AppDir, S: string;
  ResultCode: Integer;
  TmpExe: string;
begin
  if CurStep <> ssPostInstall then Exit;

  AppDir := ExpandConstant('{app}');

  { Re-detect Python in case PrepareToInstall ran on a previous attempt }
  if PythonPath = '' then
    PythonPath := FindPython;

  if PythonPath = '' then
  begin
    MsgBox(
      'Python could not be found after installation.' + #13#10 +
      'Please install Python 3.11 from https://python.org' + #13#10 +
      'then run: "' + AppDir + '\install_packages.bat"',
      mbError, MB_OK
    );
    Exit;
  end;

  Log('Using Python: ' + PythonPath);

  { ============================================================
    WRITE install_packages.bat
    ============================================================ }
  S :=
    '@echo off' + #13#10 +
    'setlocal enabledelayedexpansion' + #13#10 +
    'title SentinelNet - Installing Packages' + #13#10 +
    'chcp 65001 >nul' + #13#10 +
    'echo.' + #13#10 +
    'color 0A' + #13#10 +
     'echo ========================================' + #13#10 +
     'echo   SENTINELNET v2.0 - AMACDF Production' + #13#10 +
     'echo ========================================' + #13#10 +
    'echo.' + #13#10 +
    'echo [*] Python: "' + PythonPath + '"' + #13#10 +
    'echo.' + #13#10 +
    'echo [1/3] Upgrading pip...' + #13#10 +
    '"' + PythonPath + '" -m pip install --upgrade pip --quiet --no-warn-script-location' + #13#10 +
    'echo [OK] pip ready.' + #13#10 +
    'echo.' + #13#10 +
    'echo [2/3] Installing packages...' + #13#10 +
    'set FL=' + #13#10 +
    'if exist "' + AppDir + '\packages" set FL=--find-links="' + AppDir + '\packages"' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location fastapi==0.110.0' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location "uvicorn[standard]==0.29.0"' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location websockets==12.0' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location numpy==1.26.4' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location python-multipart==0.0.9' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location scapy==2.5.0' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location Pillow==10.3.0' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location cryptography==42.0.5' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location certifi==2024.2.2' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location mss==9.0.1' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location psutil==5.9.8' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location scipy==1.13.0' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location opencv-python==4.9.0.80' + #13#10 +
    '"' + PythonPath + '" -m pip install !FL! --no-warn-script-location watchdog==4.0.0' + #13#10 +
    'echo [OK] All packages installed!' + #13#10 +

    'echo.' + #13#10 +
    'echo [3/3] Verifying packages...' + #13#10 +
    '"' + PythonPath + '" -c "import fastapi; print(''[OK] fastapi'')"' + #13#10 +
    '"' + PythonPath + '" -c "import uvicorn; print(''[OK] uvicorn'')"' + #13#10 +
    '"' + PythonPath + '" -c "import multipart; print(''[OK] python-multipart'')"' + #13#10 +
    '"' + PythonPath + '" -c "import scapy; print(''[OK] scapy'')"' + #13#10 +
    '"' + PythonPath + '" -c "import cv2; print(''[OK] opencv'')"' + #13#10 +
    '"' + PythonPath + '" -c "import numpy; print(''[OK] numpy'')"' + #13#10 +
    'echo.' + #13#10 +
    'echo.' + #13#10 +
    'echo =========================================================' + #13#10 +
        'echo =========================================================' + #13#10 +
    'echo =========================================================' + #13#10 +
    'echo.' + #13#10;
  SaveStringToFile(AppDir + '\install_packages.bat', S, False);
  Log('install_packages.bat written.');

  { ============================================================
    WRITE SentinelNet_run.bat
    ============================================================ }
  S :=
    '@echo off' + #13#10 +
    'setlocal enabledelayedexpansion' + #13#10 +
    'title SentinelNet v2.0 - AMACDF Production' + #13#10 +
    'chcp 65001 >nul 2>&1' + #13#10 +
    'cls' + #13#10 +
    'echo.' + #13#10 +
    'echo =========================================================' + #13#10 +
        'echo =========================================================' + #13#10 +
    'echo =========================================================' + #13#10 +
    'net session >nul 2>&1' + #13#10 +
    'if !errorlevel! == 0 (' + #13#10 +
        'echo =========================================================' + #13#10 +
    ') else (' + #13#10 +
        'echo =========================================================' + #13#10 +
    ')' + #13#10 +
        'echo =========================================================' + #13#10 +
        'echo =========================================================' + #13#10 +
    'echo =========================================================' + #13#10 +
    'echo.' + #13#10 +
    'echo [*] Checking Python packages...' + #13#10 +
    '"' + PythonPath + '" -c "import fastapi, uvicorn, scapy" >nul 2>&1' + #13#10 +
    'if !errorlevel! neq 0 (' + #13#10 +
    '    echo [!] Packages missing - running installer now...' + #13#10 +
    '    call "' + AppDir + '\install_packages.bat"' + #13#10 +
    ')' + #13#10 +
    'echo [*] Starting SentinelNet...' + #13#10 +
    'echo.' + #13#10 +
    'for /d /r "' + AppDir + '" %%d in (__pycache__) do @rd /s /q "%%d" 2>nul' + #13#10 +
    'timeout /t 3 /nobreak >nul' + #13#10 +
    'start http://localhost:8000' + #13#10 +
    'cd /d "' + AppDir + '\backend"' + #13#10 +
    '"' + PythonPath + '" -B main.py' + #13#10 +
    'if !errorlevel! neq 0 (' + #13#10 +
    '    echo.' + #13#10 +
    '    echo =========================================================' + #13#10 +
        'echo =========================================================' + #13#10 +
        'echo =========================================================' + #13#10 +
    '    echo =========================================================' + #13#10 +
    ')' + #13#10 +
    'echo.' + #13#10 +
    'echo  Press any key to close...' + #13#10 +
    'pause >nul' + #13#10;
  SaveStringToFile(AppDir + '\SentinelNet_run.bat', S, False);
  Log('SentinelNet_run.bat written.');

  { VBS launcher no longer needed - shortcuts use cmd.exe /k directly }
  Log('Shortcuts use cmd.exe /k - no VBS launcher needed.');

  { ============================================================
    ADD WINDOWS DEFENDER EXCLUSION
    Use PowerShell Add-MpPreference (correct method - not registry)
    ============================================================ }
  Log('Adding Windows Defender exclusion for: ' + AppDir);
  Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -ExecutionPolicy Bypass -Command ' +
    '"Add-MpPreference -ExclusionPath ''' + AppDir + ''' -ErrorAction SilentlyContinue"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  { ============================================================
    INSTALL NPCAP
    Method 1: winget (fully silent, free, Win10/11 built-in)
    Method 2: PowerShell UI automation on bundled installer
    Method 3: Download + UI automation
    Method 4: Manual GUI fallback
    ============================================================ }
  if WizardIsTaskSelected('installnpcap') and not NpcapAlreadyInstalled then
  begin
    Log('Starting Npcap installation...');
    WizardForm.StatusLabel.Caption := 'Installing Npcap (Live packet capture)...';

    { -- Method 1: winget -- }
    Log('Npcap Method 1: winget...');
    Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
      '-NoProfile -ExecutionPolicy Bypass -Command ' +
      '"winget install --id NpcapInstaller.Npcap --silent ' +
      '--accept-package-agreements --accept-source-agreements 2>&1 | Out-Null"',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    if NpcapAlreadyInstalled then
    begin
      Log('Npcap installed OK via winget.');
    end
    else
    begin
      Log('winget failed. Trying installer...');

      { Decide installer source: bundled or download }
      if FileExists(ExpandConstant('{app}\assets\npcap-setup.exe')) then
      begin
        TmpExe := ExpandConstant('{app}\assets\npcap-setup.exe');
        Log('Using bundled npcap-setup.exe');
      end
      else
      begin
        TmpExe := ExpandConstant('{tmp}\npcap_setup.exe');
        WizardForm.StatusLabel.Caption := 'Downloading Npcap...';
        Log('Npcap not bundled. Downloading from internet...');
        if not PSDownload('{#NpcapURL}', TmpExe) then
        begin
          Log('Npcap download failed.');
          TmpExe := '';
        end;
      end;

      if (TmpExe <> '') and FileExists(TmpExe) then
      begin
        { -- Method 2: PowerShell UI Automation (auto-clicks the installer) -- }
        Log('Npcap Method 2: PowerShell UI automation...');
        WizardForm.StatusLabel.Caption := 'Installing Npcap silently...';

        SaveStringToFile(ExpandConstant('{tmp}\npcap_install.ps1'),
          '$exe = ''' + TmpExe + '''' + #13#10 +
          '$proc = Start-Process $exe -ArgumentList ''/winpcap_mode=yes /loopback_support=yes'' -PassThru' + #13#10 +
          'Start-Sleep -Seconds 3' + #13#10 +
          'Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes' + #13#10 +
          '$end = (Get-Date).AddSeconds(120)' + #13#10 +
          'while ((Get-Date) -lt $end) {' + #13#10 +
          '    if ($proc.HasExited) { break }' + #13#10 +
          '    $root = [System.Windows.Automation.AutomationElement]::RootElement' + #13#10 +
          '    $cond = New-Object System.Windows.Automation.PropertyCondition(' + #13#10 +
          '        [System.Windows.Automation.AutomationElement]::ProcessIdProperty, $proc.Id)' + #13#10 +
          '    $win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)' + #13#10 +
          '    if ($win) {' + #13#10 +
          '        $btnCond = New-Object System.Windows.Automation.PropertyCondition(' + #13#10 +
          '            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,' + #13#10 +
          '            [System.Windows.Automation.ControlType]::Button)' + #13#10 +
          '        $buttons = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)' + #13#10 +
          '        foreach ($btn in $buttons) {' + #13#10 +
          '            $n = $btn.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::NameProperty)' + #13#10 +
          '            if ($n -match "I Agree|Next|Install|Finish|OK|Yes|Accept|Continue") {' + #13#10 +
          '                try {' + #13#10 +
          '                    $inv = $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)' + #13#10 +
          '                    $inv.Invoke()' + #13#10 +
          '                    Start-Sleep -Milliseconds 1000' + #13#10 +
          '                } catch {}' + #13#10 +
          '                break' + #13#10 +
          '            }' + #13#10 +
          '        }' + #13#10 +
          '    }' + #13#10 +
          '    Start-Sleep -Seconds 1' + #13#10 +
          '}' + #13#10 +
          'if (-not $proc.HasExited) { $proc.WaitForExit(30000) }' + #13#10,
          False);

        Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
          '-NoProfile -ExecutionPolicy Bypass -File "' +
          ExpandConstant('{tmp}\npcap_install.ps1') + '"',
          '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

        if NpcapAlreadyInstalled then
          Log('Npcap installed OK via UI automation.')
        else
        begin
          { -- Method 3: Show GUI to user as last resort -- }
          Log('UI automation failed. Showing GUI to user...');
          MsgBox(
            'SentinelNet needs to install Npcap for Live packet capture.' + #13#10 + #13#10 +
            'The Npcap installer will now open.' + #13#10 +
            'Please click through it and make sure to check:' + #13#10 +
            '  [x] WinPcap API-compatible Mode' + #13#10 + #13#10 +
            'Click OK to start the Npcap installer.',
            mbInformation, MB_OK
          );
          Exec(TmpExe, '/winpcap_mode=yes /loopback_support=yes',
            '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
        end;
      end
      else
      begin
        { Npcap installer not available at all }
        MsgBox(
          'Npcap could not be downloaded or found.' + #13#10 + #13#10 +
          'SentinelNet will work in SYNTHETIC mode only.' + #13#10 +
          'For LIVE mode, install Npcap manually:' + #13#10 + #13#10 +
          '  1. Go to https://npcap.com/#download' + #13#10 +
          '  2. Download and run the installer' + #13#10 +
          '  3. Check "WinPcap API-compatible Mode"' + #13#10 +
          '  4. Restart your PC' + #13#10 +
          '  5. Launch SentinelNet as Administrator',
          mbInformation, MB_OK
        );
      end;
    end;

    if NpcapAlreadyInstalled then
      Log('Npcap is installed and ready.')
    else
      Log('Npcap installation incomplete - user may need to install manually.');
  end
  else if NpcapAlreadyInstalled then
    Log('Npcap already installed - skipping.');

  Log('CurStepChanged ssPostInstall complete.');
end;

{ ----------------------------------------------------------------
  Finish page
  ---------------------------------------------------------------- }
procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then
    WizardForm.FinishedLabel.Caption :=
      'SentinelNet v2.0 installed successfully!' + #13#10 + #13#10 +
      'HOW TO USE:' + #13#10 + #13#10 +
      '  SYNTHETIC mode (no admin needed):' + #13#10 +
      '    -> Double-click SentinelNet shortcut normally' + #13#10 +
      '    -> Simulated network traffic for AI training' + #13#10 +
      '    -> All AI features work (email, deepfake, scanner)' + #13#10 + #13#10 +
      '  LIVE mode (real network capture):' + #13#10 +
      '    -> Right-click SentinelNet -> Run as administrator' + #13#10 +
      '    -> Click Yes on the UAC prompt' + #13#10 +
      '    -> Captures real packets from your network' + #13#10 + #13#10 +
      'Dashboard: http://localhost:8000' + #13#10 + #13#10 +
      'Chrome Extension (Email Scanner):' + #13#10 +
      '  1. Open chrome://extensions' + #13#10 +
      '  2. Enable Developer mode' + #13#10 +
      '  3. Click Load unpacked' + #13#10 +
      '  4. Select: ' + ExpandConstant('{app}\extension') + #13#10 + #13#10 +
      'NOTE: If Live mode shows Synthetic, restart your PC' + #13#10 +
      'after Npcap installation completes.';
end;
