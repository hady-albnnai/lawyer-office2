@echo off
echo Downloading pdfium binaries manually to avoid network timeout issues...
echo.

REM Create necessary directories
if not exist "build\windows\x64\pdfium-download\x64" mkdir "build\windows\x64\pdfium-download\x64"

echo Downloading pdfium from GitHub releases...
echo URL: https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/6899/pdfium-win-x64.tgz
echo.

REM Use PowerShell to download with timeout and retry
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri 'https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/6899/pdfium-win-x64.tgz' -OutFile 'build\windows\x64\pdfium-download\x64\pdfium-win-x64.tgz' -TimeoutSec 300 }"

if %ERRORLEVEL% EQU 0 (
    echo Download completed successfully!
    echo Extracting files...
    powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; $tarPath = 'build\windows\x64\pdfium-download\x64\pdfium-win-x64.tgz'; $destPath = 'build\windows\x64\pdfium-download\x64\'; if (Get-Command tar -ErrorAction SilentlyContinue) { tar -xzf $tarPath -C $destPath } else { Write-Host 'tar not found, please extract manually' } }"
    echo.
    echo If extraction succeeded, you can now run flutter build.
    echo If not, manually extract the .tgz file to: build\windows\x64\pdfium-download\x64\
) else (
    echo Download failed. Please try downloading manually:
    echo 1. Visit: https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/6899/pdfium-win-x64.tgz
    echo 2. Download the tgz file
    echo 3. Extract it to: build\windows\x64\pdfium-download\x64\
)

pause