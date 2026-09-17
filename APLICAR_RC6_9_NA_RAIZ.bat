@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.9 - Aplicar na raiz atual
echo Estabilidade, cobranca e diagnostico
echo ============================================================
echo.
echo Este pacote PRESERVA .env, Wrangler, Supabase config e Git.
echo Requer a base RC6.8 ja aplicada no projeto.
echo.

if not exist "package.json" goto :raiz_invalida
if not exist "src\pages\master\Payments.tsx" goto :raiz_invalida
if not exist "src\pages\admin\Finance.tsx" goto :raiz_invalida
if not exist "supabase\migrations\202609041600_floriweb_rc6_8_order_payment_finance.sql" goto :base_invalida
if not exist "payload\package.json" goto :payload_invalido
if not exist "payload\scripts\rc69-check.mjs" goto :payload_invalido

node -e "const v=require('./package.json').version;process.exit(v==='3.0.0-rc.6.8'||v==='3.0.0-rc.6.9'?0:1)"
if errorlevel 1 goto :versao_invalida

set "BACKUP=_backup_rc6_9"
if not exist "%BACKUP%" mkdir "%BACKUP%"

echo [1/4] Criando backup dos arquivos atuais...
if exist "src" xcopy "src" "%BACKUP%\src" /E /I /Y /Q >nul
if exist "package.json" copy /Y "package.json" "%BACKUP%\package.json" >nul
if exist "index.html" copy /Y "index.html" "%BACKUP%\index.html" >nul
if exist "public\favicon.svg" (
  if not exist "%BACKUP%\public" mkdir "%BACKUP%\public"
  copy /Y "public\favicon.svg" "%BACKUP%\public\favicon.svg" >nul
)
if exist "scripts\smoke.mjs" (
  if not exist "%BACKUP%\scripts" mkdir "%BACKUP%\scripts"
  copy /Y "scripts\smoke.mjs" "%BACKUP%\scripts\smoke.mjs" >nul
)
if exist "supabase\functions\platform-manage-store-user\index.ts" (
  if not exist "%BACKUP%\supabase\functions\platform-manage-store-user" mkdir "%BACKUP%\supabase\functions\platform-manage-store-user"
  copy /Y "supabase\functions\platform-manage-store-user\index.ts" "%BACKUP%\supabase\functions\platform-manage-store-user\index.ts" >nul
)

echo [2/4] Aplicando RC6.9 sem tocar nas configuracoes locais...
xcopy "payload\*" "." /E /I /Y /Q >nul
if errorlevel 2 goto :falha_copia

rem Forca novamente o icone FloriWeb correto e o caminho versionado.
copy /Y "payload\public\favicon.svg" "public\favicon.svg" >nul
copy /Y "payload\public\favicon-floriweb-rc69.svg" "public\favicon-floriweb-rc69.svg" >nul

echo [3/4] Conferindo os arquivos aplicados...
call node scripts\rc69-check.mjs
if errorlevel 1 goto :falha

echo [4/4] Conferindo preservacao do ambiente...
if exist ".env" echo OK   .env preservado
if exist ".env.local" echo OK   .env.local preservado
if exist ".env.production" echo OK   .env.production preservado
if exist "wrangler.jsonc" echo OK   wrangler.jsonc preservado
if exist "supabase\config.toml" echo OK   supabase\config.toml preservado

echo.
echo ============================================================
echo RC6.9 APLICADO COM SUCESSO
ECHO ============================================================
echo Backup: %BACKUP%
echo.
echo PROXIMOS PASSOS NO SUPABASE SQL EDITOR:
echo 1. Execute:
echo    supabase\migrations\202609151030_floriweb_rc6_9_stability_billing_audit.sql
echo 2. Execute:
echo    supabase\VALIDAR_RC6_9.sql
echo 3. Se a validacao passar, execute PUBLICAR_RC6_9.bat
pause
exit /b 0

:raiz_invalida
echo ERRO: extraia este pacote diretamente na raiz atual do FloriWeb.
echo A raiz precisa conter package.json, src e supabase.
pause
exit /b 1

:base_invalida
echo ERRO: a base RC6.8 nao foi encontrada nesta raiz.
echo Aplique primeiro o RC6.8, incluindo a migration de recebimento-financeiro.
pause
exit /b 1

:versao_invalida
echo ERRO: este patch espera FloriWeb 3.0.0-rc.6.8.
echo Se estiver em uma versao anterior, aplique as atualizacoes anteriores primeiro.
pause
exit /b 1

:payload_invalido
echo ERRO: pasta payload do RC6.9 incompleta.
pause
exit /b 1

:falha_copia
echo ERRO: falha ao copiar os arquivos do payload.
echo Consulte o backup em %BACKUP%.
pause
exit /b 1

:falha
echo.
echo FALHA ao validar o RC6.9 aplicado.
echo Nenhum deploy foi executado e o .env nao foi alterado.
pause
exit /b 1
