@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.2.1 - Aplicar patch NA RAIZ DO PROJETO
echo ============================================================
echo.

if not exist "package.json" (
  echo ERRO: package.json nao encontrado nesta pasta.
  echo.
  echo Extraia este ZIP DENTRO da pasta raiz do seu projeto FloriWeb,
  echo na mesma pasta onde existem package.json, src e supabase.
  echo.
  pause
  exit /b 1
)

if not exist "src\App.tsx" (
  echo ERRO: src\App.tsx nao encontrado. Esta nao parece ser a raiz do FloriWeb.
  pause
  exit /b 1
)

if not exist "%~dp0payload\src\App.tsx" (
  echo ERRO: payload do patch nao encontrado.
  pause
  exit /b 1
)

echo Projeto detectado:
echo %CD%
echo.

echo [1/5] Criando backup local dos arquivos alterados...
set "BACKUP=_backup_rc6_2_1"
if exist "%BACKUP%" rmdir /s /q "%BACKUP%"
mkdir "%BACKUP%\src\layouts" >nul 2>&1
mkdir "%BACKUP%\src\pages\store" >nul 2>&1
mkdir "%BACKUP%\src\pages\admin" >nul 2>&1
mkdir "%BACKUP%\src\pages\master" >nul 2>&1
mkdir "%BACKUP%\src\lib" >nul 2>&1
if exist "src\App.tsx" copy /y "src\App.tsx" "%BACKUP%\src\App.tsx" >nul
if exist "src\styles.css" copy /y "src\styles.css" "%BACKUP%\src\styles.css" >nul
if exist "src\layouts\AdminLayout.tsx" copy /y "src\layouts\AdminLayout.tsx" "%BACKUP%\src\layouts\AdminLayout.tsx" >nul
if exist "src\layouts\MasterLayout.tsx" copy /y "src\layouts\MasterLayout.tsx" "%BACKUP%\src\layouts\MasterLayout.tsx" >nul
if exist "src\layouts\StoreLayout.tsx" copy /y "src\layouts\StoreLayout.tsx" "%BACKUP%\src\layouts\StoreLayout.tsx" >nul
if exist "src\pages\store\Home.tsx" copy /y "src\pages\store\Home.tsx" "%BACKUP%\src\pages\store\Home.tsx" >nul
if exist "src\lib\config.ts" copy /y "src\lib\config.ts" "%BACKUP%\src\lib\config.ts" >nul

echo [2/5] Aplicando arquivos ativos do RC6.2.1...
for %%F in (
  "src\App.tsx"
  "src\layouts\StoreLayout.tsx"
  "src\layouts\AdminLayout.tsx"
  "src\layouts\MasterLayout.tsx"
  "src\pages\store\Home.tsx"
  "src\pages\store\Landing.tsx"
  "src\pages\admin\Billing.tsx"
  "src\pages\admin\Finance.tsx"
  "src\pages\master\Billing.tsx"
  "src\pages\master\Payments.tsx"
  "src\services\billingFinanceApi.ts"
  "src\utils\pix.ts"
  "src\lib\config.ts"
  "src\components\PlatformHelpButton.tsx"
) do (
  if not exist "%%~dpF" mkdir "%%~dpF" >nul 2>&1
  copy /y "%~dp0payload\%%~F" "%%~F" >nul
  if errorlevel 1 goto :falha
)

if not exist "supabase\migrations" mkdir "supabase\migrations" >nul 2>&1
copy /y "%~dp0payload\supabase\migrations\202609021130_floriweb_rc6_billing_finance_landing.sql" "supabase\migrations\" >nul
copy /y "%~dp0payload\supabase\migrations\202609021730_floriweb_rc6_2_marketing_whatsapp_landing.sql" "supabase\migrations\" >nul
copy /y "%~dp0payload\supabase\VALIDAR_RC6.sql" "supabase\VALIDAR_RC6.sql" >nul
copy /y "%~dp0payload\supabase\VALIDAR_RC6_2.sql" "supabase\VALIDAR_RC6_2.sql" >nul
if not exist "supabase\functions\flori-finance-document-extract" mkdir "supabase\functions\flori-finance-document-extract" >nul 2>&1
copy /y "%~dp0payload\supabase\functions\flori-finance-document-extract\index.ts" "supabase\functions\flori-finance-document-extract\index.ts" >nul
if not exist "scripts" mkdir "scripts" >nul 2>&1
copy /y "%~dp0payload\scripts\rc62-check.mjs" "scripts\rc62-check.mjs" >nul
copy /y "%~dp0payload\DEPLOY_FLORI_RC6_FUNCTIONS.bat" "DEPLOY_FLORI_RC6_FUNCTIONS.bat" >nul

echo [3/5] Aplicando estilos RC6 e RC6.2...
findstr /c:"FloriWeb V3 RC6: landing comercial" "src\styles.css" >nul 2>&1
if errorlevel 1 type "%~dp0payload\styles_rc6_append.css" >> "src\styles.css"
findstr /c:"FloriWeb V3 RC6.2: landing comercial" "src\styles.css" >nul 2>&1
if errorlevel 1 type "%~dp0payload\styles_rc6_2_append.css" >> "src\styles.css"

echo [4/5] Verificando se os arquivos ATIVOS foram realmente alterados...
set "FAIL=0"
findstr /c:"AdminBilling" "src\App.tsx" >nul || set "FAIL=1"
findstr /c:"AdminFinance" "src\App.tsx" >nul || set "FAIL=1"
findstr /c:"MasterBilling" "src\App.tsx" >nul || set "FAIL=1"
findstr /c:"MasterPayments" "src\App.tsx" >nul || set "FAIL=1"
findstr /c:"Landing" "src\App.tsx" >nul || set "FAIL=1"
findstr /c:"/admin/financeiro" "src\layouts\AdminLayout.tsx" >nul || set "FAIL=1"
findstr /c:"/admin/mensalidade" "src\layouts\AdminLayout.tsx" >nul || set "FAIL=1"
findstr /c:"/admin-master/cobranca" "src\layouts\MasterLayout.tsx" >nul || set "FAIL=1"
findstr /c:"/admin-master/pagamentos" "src\layouts\MasterLayout.tsx" >nul || set "FAIL=1"
if "!FAIL!"=="1" goto :falha_verificacao

echo [5/5] Conferindo alteracoes no Git...
where git >nul 2>&1
if not errorlevel 1 (
  git status --short
) else (
  echo Git nao encontrado no PATH. A verificacao dos arquivos foi concluida mesmo assim.
)

echo.
echo ============================================================
echo RC6.2.1 APLICADO COM SUCESSO NOS ARQUIVOS ATIVOS
ECHO ============================================================
echo.
echo Confirmado pelo script:
echo - raiz comercial usa Landing
ECHO - /admin/financeiro existe
ECHO - /admin/mensalidade existe
ECHO - /admin-master/cobranca existe
ECHO - /admin-master/pagamentos existe
ECHO - botao Ajuda e WhatsApp fazem parte do patch
ECHO.
echo Backup dos arquivos antigos: %BACKUP%
echo.
echo PROXIMO PASSO:
echo   1. execute as migrations no Supabase, se ainda nao executou;
echo   2. rode PUBLICAR_RC6_2_1.bat.
echo.
pause
exit /b 0

:falha_verificacao
echo.
echo ERRO: a copia terminou, mas os marcadores RC6.2 nao apareceram nos arquivos ativos.
echo Nao publique. Envie esta tela para o ChatGPT.
pause
exit /b 1

:falha
echo.
echo ERRO ao copiar os arquivos RC6.2.1.
echo Nao publique. O backup ficou em %BACKUP%.
pause
exit /b 1
