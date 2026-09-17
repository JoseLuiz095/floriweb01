@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo FloriWeb V3 RC6.11 - Validacao final
echo ============================================================
echo.

where node >nul 2>&1
if errorlevel 1 (
  echo ERRO: Node.js nao encontrado no PATH.
  pause
  exit /b 1
)

node tools\validar_floriweb_rc611_ajustes.mjs
if errorlevel 1 goto :falha

echo.
if exist node_modules\typescript\bin\tsc (
  echo [1/3] TypeScript...
  call npm run typecheck
  if errorlevel 1 goto :falha
) else (
  echo AVISO: node_modules nao encontrado. TypeScript nao foi executado.
)

echo.
if exist scripts\smoke.mjs (
  echo [2/3] Smoke...
  call npm run smoke
  if errorlevel 1 goto :falha
) else (
  echo AVISO: scripts\smoke.mjs nao encontrado. Smoke ignorado.
)

echo.
if exist scripts\critical-flow.mjs (
  echo [3/3] Fluxo critico...
  call npm run test:critical
  if errorlevel 1 goto :falha
) else (
  echo AVISO: scripts\critical-flow.mjs nao encontrado. Fluxo critico ignorado.
)

echo.
echo ============================================================
echo SUCESSO - FloriWeb pronto para versionamento no GitHub.
echo ============================================================
pause
exit /b 0

:falha
echo.
echo ============================================================
echo FALHA - nao envie ao GitHub antes de corrigir o erro acima.
echo ============================================================
pause
exit /b 1
