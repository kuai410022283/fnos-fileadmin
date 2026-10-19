@echo off
setlocal EnableExtensions

rem One-command local build: FileAdmin source -> Linux binaries -> fnOS .fpk
set "ROOT=%~dp0"
if defined FILEADMIN_SRC (
  set "SOURCE=%FILEADMIN_SRC%"
) else (
  set "SOURCE=%ROOT%..\fileAdmin"
)
for %%I in ("%SOURCE%") do set "SOURCE=%%~fI"

if not exist "%SOURCE%\go.mod" (
  echo FileAdmin source not found: %SOURCE%
  echo Clone FileAdmin next to this repository, or set FILEADMIN_SRC=C:\path\to\fileAdmin.
  exit /b 1
)

for /f "tokens=2 delims==" %%V in ('findstr /b /c:"version" "%ROOT%package\manifest"') do set "VERSION=%%V"
set "VERSION=%VERSION: =%"
if "%VERSION%"=="" (
  echo Could not read version from package\manifest.
  exit /b 1
)

where go >nul 2>nul
if errorlevel 1 (
  echo Go is not installed or not in PATH.
  exit /b 1
)

set "FNPACK=%ROOT%fnpack.exe"
if not exist "%FNPACK%" (
  echo Downloading fnpack...
  where curl >nul 2>nul
  if errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri 'https://static2.fnnas.com/fnpack/fnpack-1.2.3-windows-amd64' -OutFile '%FNPACK%'"
  ) else (
    curl.exe -fL --retry 3 -o "%FNPACK%" "https://static2.fnnas.com/fnpack/fnpack-1.2.3-windows-amd64"
  )
  if errorlevel 1 (
    echo Failed to download fnpack.
    exit /b 1
  )
)

echo Building FileAdmin %VERSION% from %SOURCE%
if not exist "%ROOT%package\app\server" mkdir "%ROOT%package\app\server"

cd /d "%SOURCE%"
set "CGO_ENABLED=0"
set "GOOS=linux"

set "GOARCH=amd64"
go build -trimpath -ldflags "-s -w -X main.version=v%VERSION%" -o "%ROOT%package\app\server\fileadmin_x86_64" ./cmd/fileadmin
if errorlevel 1 goto :fail

set "GOARCH=arm64"
go build -trimpath -ldflags "-s -w -X main.version=v%VERSION%" -o "%ROOT%package\app\server\fileadmin_aarch64" ./cmd/fileadmin
if errorlevel 1 goto :fail

cd /d "%ROOT%"
echo Running fnpack...
"%FNPACK%" build --directory "%ROOT%package"
if errorlevel 1 goto :fail

if not exist "%ROOT%fileadmin.fpk" (
  echo fnpack did not produce fileadmin.fpk.
  goto :fail
)

set "OUT=%ROOT%fileadmin_all_v%VERSION%.fpk"
move /Y "%ROOT%fileadmin.fpk" "%OUT%" >nul
if errorlevel 1 goto :fail

for /f "usebackq delims=" %%H in (`powershell -NoProfile -Command "(Get-FileHash -LiteralPath '%OUT%' -Algorithm SHA256).Hash.ToLower()"`) do set "HASH=%%H"
> "%OUT%.sha256" echo %HASH%  fileadmin_all_v%VERSION%.fpk

echo Built %OUT%
exit /b 0

:fail
echo.
echo Build failed.
exit /b 1
