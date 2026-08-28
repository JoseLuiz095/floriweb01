@echo off
setlocal
cd /d "%~dp0"
title FloriWeb - Build

echo ============================================================
echo FloriWeb 2.0 - Validacao e build
echo ============================================================
call npm run build
if errorlevel 1 (
  echo.
  echo FALHA no build. Revise os erros acima.
  pause
  exit /b 1
)
echo.
echo Build concluido. Pasta gerada: dist
echo Para testar: npm run preview
pause
