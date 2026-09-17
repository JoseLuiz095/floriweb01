@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.9 - HOTFIX V2 suporte / TypeScript
echo ============================================================
echo.
echo Corrige PlatformHelpButton preservando compatibilidade com:
echo - uso sem parametros no Admin/Master
echo - context="store" e storeName no StoreLayout
echo.
echo Preserva .env, Supabase, Wrangler e configuracoes existentes.
echo.

if not exist "package.json" goto :raiz_invalida
if not exist "src\components\PlatformHelpButton.tsx" goto :raiz_invalida
if not exist "payload\src\components\PlatformHelpButton.tsx" goto :payload_invalido
if not exist "payload\src\services\supportApi.ts" goto :payload_invalido

set "BACKUP=_backup_hotfix_rc69_suporte_v2"
if not exist "%BACKUP%\src\components" mkdir "%BACKUP%\src\components"
if not exist "%BACKUP%\src\services" mkdir "%BACKUP%\src\services"

if exist "src\components\PlatformHelpButton.tsx" copy /Y "src\components\PlatformHelpButton.tsx" "%BACKUP%\src\components\PlatformHelpButton.tsx" >nul
if exist "src\services\supportApi.ts" copy /Y "src\services\supportApi.ts" "%BACKUP%\src\services\supportApi.ts" >nul

echo [1/5] Aplicando correcao de compatibilidade...
copy /Y "payload\src\components\PlatformHelpButton.tsx" "src\components\PlatformHelpButton.tsx" >nul
copy /Y "payload\src\services\supportApi.ts" "src\services\supportApi.ts" >nul

echo [2/5] Conferindo propriedades esperadas...
findstr /C:"context?:" "src\components\PlatformHelpButton.tsx" >nul || goto :falha
findstr /C:"storeName?:" "src\components\PlatformHelpButton.tsx" >nul || goto :falha
findstr /C:"loadAdminSupportContact" "src\components\PlatformHelpButton.tsx" >nul || goto :falha
findstr /C:"get_admin_support_contact_v1" "src\services\supportApi.ts" >nul || goto :falha

echo [3/5] Executando TypeScript...
call npm run typecheck
if errorlevel 1 goto :falha

echo [4/5] TypeScript aprovado.
echo [5/5] Continuando publicacao RC6.9...
if not exist "PUBLICAR_RC6_9.bat" goto :sem_publicador
call PUBLICAR_RC6_9.bat
exit /b %errorlevel%

:raiz_invalida
echo.
echo ERRO: extraia este HOTFIX V2 diretamente na raiz atual do FloriWeb RC6.9.
echo A pasta deve conter package.json, src e PUBLICAR_RC6_9.bat.
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
echo FALHA - HOTFIX V2 nao passou na validacao
echo ============================================================
echo O .env nao foi alterado.
echo Backup: %BACKUP%
echo.
echo Envie o erro exibido imediatamente acima se houver nova falha.
pause
exit /b 1
