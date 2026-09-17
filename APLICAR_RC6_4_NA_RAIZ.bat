@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.4 - Aplicar patch NA RAIZ DO PROJETO
echo ============================================================
echo.
echo Este patch NAO substitui:
echo - .env / .env.local / .env.production
echo - wrangler.jsonc
echo - supabase\config.toml
echo - .git
echo - configuracoes ja feitas no Supabase/Cloudflare
echo.

if not exist "package.json" (
  echo ERRO: package.json nao encontrado nesta pasta.
  echo Extraia este ZIP DENTRO da pasta raiz do FloriWeb.
  pause
  exit /b 1
)

findstr /c:"floriweb" "package.json" >nul 2>&1
if errorlevel 1 (
  echo ERRO: este projeto nao parece ser o FloriWeb.
  pause
  exit /b 1
)

if not exist "src\App.tsx" (
  echo ERRO: src\App.tsx nao encontrado. Esta nao parece ser a raiz do projeto.
  pause
  exit /b 1
)

if not exist "%~dp0payload\src\pages\admin\Finance.tsx" (
  echo ERRO: payload RC6.4 nao encontrado.
  pause
  exit /b 1
)

echo Projeto detectado:
echo %CD%
echo.

echo [1/6] Criando backup local dos arquivos alterados...
set "BACKUP=_backup_rc6_4"
if exist "%BACKUP%" rmdir /s /q "%BACKUP%"
mkdir "%BACKUP%\src\pages\admin" >nul 2>&1
mkdir "%BACKUP%\src\pages\store" >nul 2>&1
mkdir "%BACKUP%\src\services" >nul 2>&1
mkdir "%BACKUP%\src\utils" >nul 2>&1
mkdir "%BACKUP%\scripts" >nul 2>&1
mkdir "%BACKUP%\public" >nul 2>&1
mkdir "%BACKUP%\config_preservada" >nul 2>&1
if exist "package.json" copy /y "package.json" "%BACKUP%\package.json" >nul
if exist "index.html" copy /y "index.html" "%BACKUP%\index.html" >nul
if exist "src\pages\admin\Finance.tsx" copy /y "src\pages\admin\Finance.tsx" "%BACKUP%\src\pages\admin\Finance.tsx" >nul
if exist "src\pages\store\Landing.tsx" copy /y "src\pages\store\Landing.tsx" "%BACKUP%\src\pages\store\Landing.tsx" >nul
if exist "src\services\billingFinanceApi.ts" copy /y "src\services\billingFinanceApi.ts" "%BACKUP%\src\services\billingFinanceApi.ts" >nul
if exist "src\utils\localFinancialDocumentReader.ts" copy /y "src\utils\localFinancialDocumentReader.ts" "%BACKUP%\src\utils\localFinancialDocumentReader.ts" >nul
if exist "src\styles.css" copy /y "src\styles.css" "%BACKUP%\src\styles.css" >nul
if exist "scripts\smoke.mjs" copy /y "scripts\smoke.mjs" "%BACKUP%\scripts\smoke.mjs" >nul
if exist "public\favicon.svg" copy /y "public\favicon.svg" "%BACKUP%\public\favicon.svg" >nul
if exist "public\_headers" copy /y "public\_headers" "%BACKUP%\public\_headers" >nul
if exist "DEPLOY_FLORI_RC6_FUNCTIONS.bat" copy /y "DEPLOY_FLORI_RC6_FUNCTIONS.bat" "%BACKUP%\DEPLOY_FLORI_RC6_FUNCTIONS.bat" >nul
if exist ".env" copy /y ".env" "%BACKUP%\config_preservada\.env" >nul
if exist ".env.local" copy /y ".env.local" "%BACKUP%\config_preservada\.env.local" >nul
if exist ".env.production" copy /y ".env.production" "%BACKUP%\config_preservada\.env.production" >nul
if exist "wrangler.jsonc" copy /y "wrangler.jsonc" "%BACKUP%\config_preservada\wrangler.jsonc" >nul
if exist "supabase\config.toml" copy /y "supabase\config.toml" "%BACKUP%\config_preservada\supabase-config.toml" >nul
if exist "supabase\functions\flori-finance-document-extract" xcopy /e /i /y "supabase\functions\flori-finance-document-extract" "%BACKUP%\flori-finance-document-extract" >nul

echo [2/6] Aplicando codigo RC6.4 sem tocar no .env...
for %%F in (
  "package.json"
  "index.html"
  "src\pages\admin\Finance.tsx"
  "src\pages\store\Landing.tsx"
  "src\services\billingFinanceApi.ts"
  "src\utils\localFinancialDocumentReader.ts"
  "scripts\smoke.mjs"
  "scripts\rc64-check.mjs"
  "public\_headers"
  "DEPLOY_FLORI_RC6_FUNCTIONS.bat"
) do (
  if not exist "%%~dpF" mkdir "%%~dpF" >nul 2>&1
  copy /y "%~dp0payload\%%~F" "%%~F" >nul
  if errorlevel 1 goto :falha
)

echo [3/6] Aplicando estilos RC6.4 sem substituir o CSS inteiro...
findstr /c:"FloriWeb V3 RC6.4: OCR local + CTA final" "src\styles.css" >nul 2>&1
if errorlevel 1 type "%~dp0payload\styles_rc64_append.css" >> "src\styles.css"

echo [4/6] Forcando os icones locais do FloriWeb...
if not exist "public" mkdir "public" >nul 2>&1
copy /y "%~dp0payload\public\favicon.svg" "public\favicon.svg" >nul
if errorlevel 1 goto :falha
copy /y "%~dp0payload\public\favicon-floriweb-rc64.svg" "public\favicon-floriweb-rc64.svg" >nul
if errorlevel 1 goto :falha
if exist "dist" rmdir /s /q "dist"

echo [5/6] Removendo somente o OCR/IA antigo do financeiro...
if exist "supabase\functions\flori-finance-document-extract" rmdir /s /q "supabase\functions\flori-finance-document-extract"

echo [6/6] Validando patch e configuracao preservada...
node scripts\rc64-check.mjs
if errorlevel 1 goto :falha_verificacao

echo.
echo ============================================================
echo RC6.4 APLICADO COM SUCESSO
ECHO ============================================================
echo.
echo Confirmado:
echo - .env e configuracoes existentes NAO foram substituidos
echo - leitura de foto/PDF agora e local, sem IA
echo - CSP/Permissions-Policy ajustados para Worker, WebAssembly e camera local
echo - categoria pode reaproveitar fornecedor ja conhecido
echo - CTA final da landing foi corrigido
echo - favicon local foi copiado e ganhou URL nova para quebrar cache
echo - Edge Function antiga de OCR/IA foi removida do projeto local
echo.
echo Backup: %BACKUP%
echo.
echo PROXIMO PASSO:
echo   execute PUBLICAR_RC6_4.bat
echo.
pause
exit /b 0

:falha_verificacao
echo.
echo ERRO: o patch foi copiado, mas a verificacao RC6.4 encontrou problema.
echo Nao publique ate corrigir a mensagem acima.
echo Backup: %BACKUP%
pause
exit /b 1

:falha
echo.
echo ERRO ao aplicar o patch RC6.4.
echo O .env nao foi substituido.
echo Backup: %BACKUP%
pause
exit /b 1
