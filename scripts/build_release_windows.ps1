# Build release package for Windows (run on Windows host)
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "== Flutter pub get ==" -ForegroundColor Cyan
flutter pub get

Write-Host "== build_runner ==" -ForegroundColor Cyan
dart run build_runner build

Write-Host "== tests ==" -ForegroundColor Cyan
flutter test

Write-Host "== build windows release ==" -ForegroundColor Cyan
flutter build windows --release

$release = "build\windows\x64\runner\Release"
if (!(Test-Path $release)) { throw "Release folder not found: $release" }

$out = "dist\LawyerOffice_v1.0.0_Windows"
New-Item -ItemType Directory -Force -Path $out | Out-Null
Copy-Item -Path "$release\*" -Destination $out -Recurse -Force
Copy-Item -Path "CLIENT_RUNBOOK.md","RELEASE_NOTES_v1.0.md","BUILD_RELEASE.md" -Destination $out -Force

# Zip package
New-Item -ItemType Directory -Force -Path dist | Out-Null
$zip = "dist\LawyerOffice_v1.0.0_Windows.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$out\*" -DestinationPath $zip
Write-Host "Created $zip" -ForegroundColor Green

# Optional Inno Setup if ISCC is available
$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (Test-Path $iscc) {
  Write-Host "Compiling installer..." -ForegroundColor Cyan
  & $iscc "installer\lawyer_office_setup.iss"
  Write-Host "Installer compiled to installer\" -ForegroundColor Green
} else {
  Write-Host "Inno Setup not found. ZIP package is ready. Install Inno Setup 6 to build Setup.exe." -ForegroundColor Yellow
}
