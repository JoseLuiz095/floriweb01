@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.5 - Aplicar patch NA RAIZ DO PROJETO
echo ============================================================
echo.
echo Este patch NAO substitui:
echo - .env / .env.local / .env.production
echo - wrangler.jsonc
echo - supabase\config.toml
echo - .git
echo - secrets do Supabase/Cloudflare
echo.

if not exist "package.json" (
  echo ERRO: package.json nao encontrado nesta pasta.
  echo Extraia este ZIP DENTRO da pasta raiz atual do FloriWeb.
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
if not exist "%~dp0payload\src\pages\master\Stores.tsx" (
  echo ERRO: payload RC6.5 nao encontrado.
  pause
  exit /b 1
)

echo Projeto detectado:
echo %CD%
echo.

echo [1/7] Criando backup local dos arquivos alterados...
set "BACKUP=_backup_rc6_5"
if exist "%BACKUP%" rmdir /s /q "%BACKUP%"
mkdir "%BACKUP%\src\services" >nul 2>&1
mkdir "%BACKUP%\src\layouts" >nul 2>&1
mkdir "%BACKUP%\src\pages\master" >nul 2>&1
mkdir "%BACKUP%\src\pages\admin" >nul 2>&1
mkdir "%BACKUP%\src\utils" >nul 2>&1
mkdir "%BACKUP%\scripts" >nul 2>&1
mkdir "%BACKUP%\public" >nul 2>&1
mkdir "%BACKUP%\.github\workflows" >nul 2>&1
mkdir "%BACKUP%\config_preservada" >nul 2>&1
if exist "package.json" copy /y "package.json" "%BACKUP%\package.json" >nul
if exist "package-lock.json" copy /y "package-lock.json" "%BACKUP%\package-lock.json" >nul
if exist "index.html" copy /y "index.html" "%BACKUP%\index.html" >nul
if exist "src\services\billingFinanceApi.ts" copy /y "src\services\billingFinanceApi.ts" "%BACKUP%\src\services\billingFinanceApi.ts" >nul
if exist "src\services\platformApi.ts" copy /y "src\services\platformApi.ts" "%BACKUP%\src\services\platformApi.ts" >nul
if exist "src\layouts\AdminLayout.tsx" copy /y "src\layouts\AdminLayout.tsx" "%BACKUP%\src\layouts\AdminLayout.tsx" >nul
if exist "src\pages\master\Stores.tsx" copy /y "src\pages\master\Stores.tsx" "%BACKUP%\src\pages\master\Stores.tsx" >nul
if exist "src\pages\master\Payments.tsx" copy /y "src\pages\master\Payments.tsx" "%BACKUP%\src\pages\master\Payments.tsx" >nul
if exist "src\pages\admin\Billing.tsx" copy /y "src\pages\admin\Billing.tsx" "%BACKUP%\src\pages\admin\Billing.tsx" >nul
if exist "src\utils\localFinancialDocumentReader.ts" copy /y "src\utils\localFinancialDocumentReader.ts" "%BACKUP%\src\utils\localFinancialDocumentReader.ts" >nul
if exist "scripts\smoke.mjs" copy /y "scripts\smoke.mjs" "%BACKUP%\scripts\smoke.mjs" >nul
if exist "src\styles.css" copy /y "src\styles.css" "%BACKUP%\styles.css" >nul
if exist "public\favicon.svg" copy /y "public\favicon.svg" "%BACKUP%\public\favicon.svg" >nul
if exist ".github\workflows\deploy-supabase-functions.yml" copy /y ".github\workflows\deploy-supabase-functions.yml" "%BACKUP%\.github\workflows\deploy-supabase-functions.yml" >nul
if exist ".env" copy /y ".env" "%BACKUP%\config_preservada\.env" >nul
if exist ".env.local" copy /y ".env.local" "%BACKUP%\config_preservada\.env.local" >nul
if exist ".env.production" copy /y ".env.production" "%BACKUP%\config_preservada\.env.production" >nul
if exist "wrangler.jsonc" copy /y "wrangler.jsonc" "%BACKUP%\config_preservada\wrangler.jsonc" >nul
if exist "supabase\config.toml" copy /y "supabase\config.toml" "%BACKUP%\config_preservada\supabase-config.toml" >nul

echo [2/7] Aplicando codigo RC6.5 sem tocar no .env...
for %%F in (
  "package.json"
  "package-lock.json"
  "index.html"
  "src\services\billingFinanceApi.ts"
  "src\services\platformApi.ts"
  "src\layouts\AdminLayout.tsx"
  "src\pages\master\Stores.tsx"
  "src\pages\master\Payments.tsx"
  "src\pages\admin\Billing.tsx"
  "scripts\smoke.mjs"
  "scripts\rc65-check.mjs"
  "scripts\rc65-patch-existing.mjs"
  ".github\workflows\deploy-supabase-functions.yml"
) do (
  if not exist "%%~dpF" mkdir "%%~dpF" >nul 2>&1
  copy /y "%~dp0payload\%%~F" "%%~F" >nul
  if errorlevel 1 goto :falha
)

echo [3/7] Aplicando migration, validacao e Edge Function RC6.5...
if not exist "supabase\migrations" mkdir "supabase\migrations" >nul 2>&1
if not exist "supabase\functions\platform-manage-store-user" mkdir "supabase\functions\platform-manage-store-user" >nul 2>&1
copy /y "%~dp0payload\supabase\migrations\202609032030_floriweb_rc6_5_billing_access.sql" "supabase\migrations\202609032030_floriweb_rc6_5_billing_access.sql" >nul
if errorlevel 1 goto :falha
copy /y "%~dp0payload\supabase\VALIDAR_RC6_5.sql" "supabase\VALIDAR_RC6_5.sql" >nul
if errorlevel 1 goto :falha
copy /y "%~dp0payload\supabase\functions\platform-manage-store-user\index.ts" "supabase\functions\platform-manage-store-user\index.ts" >nul
if errorlevel 1 goto :falha

echo [4/7] Aplicando estilos sem substituir o CSS inteiro...
findstr /c:"FloriWeb V3 RC6.5: mensalidade, vencimento e gestao de acesso" "src\styles.css" >nul 2>&1
if errorlevel 1 type "%~dp0payload\styles_rc65_append.css" >> "src\styles.css"

echo [5/7] Preservando o hotfix PDF.js da RC6.4...
node scripts\rc65-patch-existing.mjs
if errorlevel 1 goto :falha

echo [6/7] Forcando novamente o favicon correto do FloriWeb...
if not exist "public" mkdir "public" >nul 2>&1
copy /y "%~dp0payload\public\favicon.svg" "public\favicon.svg" >nul
if errorlevel 1 goto :falha
copy /y "%~dp0payload\public\favicon-floriweb-rc65.svg" "public\favicon-floriweb-rc65.svg" >nul
if errorlevel 1 goto :falha
if exist "dist" rmdir /s /q "dist"

echo [7/7] Validando patch e configuracao preservada...
node scripts\rc65-check.mjs
if errorlevel 1 goto :falha_verificacao

echo.
echo ============================================================
echo RC6.5 APLICADO COM SUCESSO
echo ============================================================
echo.
echo Incluido:
echo - Admin Master altera e-mail e redefine senha do lojista
echo - coluna Vencimento na tabela de lojas
echo - opcao de negar mensalidade/alteracao de plano
echo - indicador verde/vermelho de mensalidade no topo do Admin
echo - ultimo pagamento detalhado para o lojista
echo - vencimento respeita o dia configurado no Admin Master
echo - pagamento confirmado registra data/hora real de hoje
echo - mensalidade nao confirmada NAO avanca o vencimento
echo - favicon FloriWeb RC6.5 forcado novamente
echo.
echo IMPORTANTE: esta versao POSSUI migration nova.
echo Execute no SQL Editor do Supabase:
echo   supabase\migrations\202609032030_floriweb_rc6_5_billing_access.sql
echo Depois execute:
echo   supabase\VALIDAR_RC6_5.sql
echo.
echo Backup: %BACKUP%
echo.
echo Depois execute PUBLICAR_RC6_5.bat
pause
exit /b 0

:falha_verificacao
echo.
echo ERRO: o patch foi copiado, mas a verificacao RC6.5 encontrou problema.
echo Nao publique ate corrigir a mensagem acima.
echo Backup: %BACKUP%
pause
exit /b 1

:falha
echo.
echo ERRO ao aplicar o patch RC6.5.
echo O .env e as configuracoes existentes nao foram substituidos.
echo Backup: %BACKUP%
pause
exit /b 1
