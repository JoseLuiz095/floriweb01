@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo FloriWeb V3 RC6.11 - HOTFIX recebimento + pedidos
echo ============================================================
echo.

if not exist package.json (
  echo ERRO: execute este BAT na raiz do FloriWeb.
  pause
  exit /b 1
)

if not exist PUBLICAR_RC6_11.bat (
  echo ERRO: PUBLICAR_RC6_11.bat nao foi encontrado na raiz.
  pause
  exit /b 1
)

set BACKUP=_backup_hotfix_rc611_recebimento
if not exist "%BACKUP%" mkdir "%BACKUP%"
if not exist "%BACKUP%\Orders.tsx" copy /Y "src\pages\admin\Orders.tsx" "%BACKUP%\Orders.tsx" >nul
if not exist "%BACKUP%\types-index.ts" copy /Y "src\types\index.ts" "%BACKUP%\types-index.ts" >nul
if exist "scripts\rc611-check.mjs" if not exist "%BACKUP%\rc611-check.mjs" copy /Y "scripts\rc611-check.mjs" "%BACKUP%\rc611-check.mjs" >nul

echo [1/3] Aplicando correcao...
copy /Y "payload\src\pages\admin\Orders.tsx" "src\pages\admin\Orders.tsx" >nul || goto :fail
copy /Y "payload\src\types\index.ts" "src\types\index.ts" >nul || goto :fail
copy /Y "payload\scripts\rc611-check.mjs" "scripts\rc611-check.mjs" >nul || goto :fail

echo [2/3] Validando RC6.11...
node scripts\rc611-check.mjs || goto :fail
npm run smoke || goto :fail

echo [3/3] Chamando publicador de producao...
call PUBLICAR_RC6_11.bat
exit /b %errorlevel%

:fail
echo.
echo ============================================================
echo FALHA - hotfix interrompido antes da publicacao.
echo O .env nao foi alterado.
echo Backup: %BACKUP%
echo ============================================================
pause
exit /b 1
