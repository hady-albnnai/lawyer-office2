#!/usr/bin/env bash
# Cross helper notes (actual Windows build must run on Windows)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "This script documents the Windows release pipeline."
echo "On a Windows machine run: powershell -ExecutionPolicy Bypass -File scripts/build_release_windows.ps1"
echo
echo "Expected commands:"
echo "  flutter pub get"
echo "  dart run build_runner build"
echo "  flutter test"
echo "  flutter build windows --release"
echo "  package build/windows/x64/runner/Release + docs into dist/"
echo "  optional: ISCC installer/lawyer_office_setup.iss"
