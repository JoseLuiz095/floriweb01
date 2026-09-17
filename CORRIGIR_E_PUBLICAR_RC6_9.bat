@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.9 - HOTFIX suporte / TypeScript
echo ============================================================
echo.
echo Corrige PlatformHelpButton para usar o RPC autenticado de suporte.
echo Preserva .env, Supabase, Wrangler e configuracoes existentes.
echo.

if not exist "package.json" goto :raiz_invalida
if not exist "src\components\PlatformHelpButton.tsx" goto :raiz_invalida
if not exist "payload\src\components\PlatformHelpButton.tsx" goto :payload_invalido
if not exist "payload\src\services\supportApi.ts" goto :payload_invalido

set "BACKUP=_backup_hotfix_rc69_suporte"
if not exist "%BACKUP%\src\components" mkdir "%BACKUP%\src\components"
if not exist "%BACKUP%\src\services" mkdir "%BACKUP%\src\services"

if exist "src\components\PlatformHelpButton.tsx" copy /Y "src\components\PlatformHelpButton.tsx" "%BACKUP%\src\components\PlatformHelpButton.tsx" >nul
if exist "src\services\supportApi.ts" copy /Y "src\services\supportApi.ts" "%BACKUP%\src\services\supportApi.ts" >nul

echo [1/4] Aplicando correcao...
copy /Y "payload\src\components\PlatformHelpButton.tsx" "src\components\PlatformHelpButton.tsx" >nul
copy /Y "payload\src\services\supportApi.ts" "src\services\supportApi.ts" >nul

echo [2/4] Conferindo correcao...
findstr /C:"loadAdminSupportContact" "src\components\PlatformHelpButton.tsx" >nul || goto :falha
findstr /C:"get_admin_support_contact_v1" "src\services\supportApi.ts" >nul || goto :falha

echo [3/4] Executando TypeScript...
call npm run typecheck
if errorlevel 1 goto :falha

echo [4/4] Continuando publicacao RC6.9...
if not exist "PUBLICAR_RC6_9.bat" goto :sem_publicador
call PUBLICAR_RC6_9.bat
exit /b %errorlevel%

:raiz_invalida
echo ERRO: extraia este HOTFIX diretamente na raiz atual do FloriWeb RC6.9.
pause
exit /b 1

:payload_invalido
echo ERRO: payload do hotfix incompleto.
pause
exit /b 1

:sem_publicador
echo ERRO: PUBLICAR_RC6_9.bat nao foi encontrado nesta raiz.
pause
exit /b 1

:falha
echo.
echo ============================================================
echo FALHA - hotfix nao passou na validacao
echo ============================================================
echo O .env nao foi alterado.
echo Backup: %BACKUP%
pause
exit /b 1
