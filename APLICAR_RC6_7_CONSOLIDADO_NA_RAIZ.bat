@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.7 CONSOLIDADO - Aplicar na raiz
echo ============================================================
echo.
echo Este pacote JA INCLUI os ajustes da RC6.6 + RC6.7.
echo Nao e necessario publicar a RC6.6 separadamente.
echo.
echo Preservados:
echo - .env / .env.local / .env.production
echo - wrangler.jsonc
echo - supabase\config.toml
echo - .git
echo - secrets Supabase/Cloudflare
echo.

if not exist "package.json" goto :raiz_falha
findstr /c:"floriweb" "package.json" >nul 2>&1
if errorlevel 1 goto :raiz_falha
if not exist "src\App.tsx" goto :raiz_falha
if not exist "src\pages\admin\Finance.tsx" goto :raiz_falha
if not exist "supabase\migrations\202609032030_floriweb_rc6_5_billing_access.sql" (
  echo ERRO: a base RC6.5 nao foi encontrada.
  echo Aplique a RC6.5 e sua migration antes deste consolidado.
  pause
  exit /b 1
)
if not exist "%~dp0payload\src\utils\localFinancialDocumentReader.ts" (
  echo ERRO: payload consolidado nao encontrado.
  pause
  exit /b 1
)

echo Projeto detectado: %CD%
echo.

echo [1/6] Criando backup dos arquivos que serao alterados...
set "BACKUP=_backup_rc6_7_consolidado"
if exist "%BACKUP%" rmdir /s /q "%BACKUP%"
mkdir "%BACKUP%\src\layouts" >nul 2>&1
mkdir "%BACKUP%\src\pages\admin" >nul 2>&1
mkdir "%BACKUP%\src\utils" >nul 2>&1
mkdir "%BACKUP%\scripts" >nul 2>&1
mkdir "%BACKUP%\public" >nul 2>&1
mkdir "%BACKUP%\config_preservada" >nul 2>&1
for %%F in ("package.json" "package-lock.json" "index.html") do if exist %%F copy /y %%F "%BACKUP%\" >nul
if exist "src\App.tsx" copy /y "src\App.tsx" "%BACKUP%\src\App.tsx" >nul
if exist "src\layouts\AdminLayout.tsx" copy /y "src\layouts\AdminLayout.tsx" "%BACKUP%\src\layouts\AdminLayout.tsx" >nul
if exist "src\pages\admin\Plan.tsx" copy /y "src\pages\admin\Plan.tsx" "%BACKUP%\src\pages\admin\Plan.tsx" >nul
if exist "src\pages\admin\Finance.tsx" copy /y "src\pages\admin\Finance.tsx" "%BACKUP%\src\pages\admin\Finance.tsx" >nul
if exist "src\utils\localFinancialDocumentReader.ts" copy /y "src\utils\localFinancialDocumentReader.ts" "%BACKUP%\src\utils\localFinancialDocumentReader.ts" >nul
if exist "src\styles.css" copy /y "src\styles.css" "%BACKUP%\styles.css" >nul
if exist "scripts\smoke.mjs" copy /y "scripts\smoke.mjs" "%BACKUP%\scripts\smoke.mjs" >nul
if exist "public\favicon.svg" copy /y "public\favicon.svg" "%BACKUP%\public\favicon.svg" >nul
if exist ".env" copy /y ".env" "%BACKUP%\config_preservada\.env" >nul
if exist ".env.local" copy /y ".env.local" "%BACKUP%\config_preservada\.env.local" >nul
if exist ".env.production" copy /y ".env.production" "%BACKUP%\config_preservada\.env.production" >nul
if exist "wrangler.jsonc" copy /y "wrangler.jsonc" "%BACKUP%\config_preservada\wrangler.jsonc" >nul
if exist "supabase\config.toml" copy /y "supabase\config.toml" "%BACKUP%\config_preservada\supabase-config.toml" >nul

echo [2/6] Aplicando RC6.6 + RC6.7 em uma unica etapa...
copy /y "%~dp0payload\package.json" "package.json" >nul || goto :falha
copy /y "%~dp0payload\package-lock.json" "package-lock.json" >nul || goto :falha
copy /y "%~dp0payload\index.html" "index.html" >nul || goto :falha
copy /y "%~dp0payload\src\App.tsx" "src\App.tsx" >nul || goto :falha
copy /y "%~dp0payload\src\layouts\AdminLayout.tsx" "src\layouts\AdminLayout.tsx" >nul || goto :falha
copy /y "%~dp0payload\src\pages\admin\Plan.tsx" "src\pages\admin\Plan.tsx" >nul || goto :falha
copy /y "%~dp0payload\src\pages\admin\Finance.tsx" "src\pages\admin\Finance.tsx" >nul || goto :falha
copy /y "%~dp0payload\src\utils\localFinancialDocumentReader.ts" "src\utils\localFinancialDocumentReader.ts" >nul || goto :falha
copy /y "%~dp0payload\scripts\smoke.mjs" "scripts\smoke.mjs" >nul || goto :falha
copy /y "%~dp0payload\scripts\rc67-consolidado-check.mjs" "scripts\rc67-consolidado-check.mjs" >nul || goto :falha

echo [3/6] Aplicando estilos da RC6.6 e RC6.7 sem apagar seu CSS...
findstr /c:"FloriWeb V3 RC6.6: Meu plano unificado, status de vencimento e OCR reforcado" "src\styles.css" >nul 2>&1
if errorlevel 1 type "%~dp0payload\styles_rc66_append.css" >> "src\styles.css"
findstr /c:"FloriWeb V3 RC6.7: leitura financeira compacta" "src\styles.css" >nul 2>&1
if errorlevel 1 type "%~dp0payload\styles_rc67_append.css" >> "src\styles.css"

echo [4/6] Forcando favicon correto do FloriWeb...
if not exist "public" mkdir "public" >nul 2>&1
copy /y "%~dp0payload\public\favicon.svg" "public\favicon.svg" >nul || goto :falha
copy /y "%~dp0payload\public\favicon-floriweb-rc67.svg" "public\favicon-floriweb-rc67.svg" >nul || goto :falha

echo [5/6] Limpando build antigo...
if exist "dist" rmdir /s /q "dist"

echo [6/6] Conferindo instalacao consolidada...
call node scripts\rc67-consolidado-check.mjs
if errorlevel 1 goto :falha_verificacao

echo.
echo ============================================================
echo RC6.7 CONSOLIDADO APLICADO COM SUCESSO
echo ============================================================
echo.
echo Este pacote substitui a necessidade de PUBLICAR_RC6_6.bat.
echo Agora execute apenas: PUBLICAR_RC6_7.bat
echo.
echo Backup: %BACKUP%
pause
exit /b 0

:raiz_falha
echo ERRO: este BAT deve ser executado na raiz atual do FloriWeb.
pause
exit /b 1

:falha_verificacao
echo.
echo ERRO: arquivos foram copiados, mas a verificacao consolidada falhou.
echo Nao publique. Consulte as mensagens acima.
echo Backup: %BACKUP%
pause
exit /b 1

:falha
echo.
echo ERRO ao copiar o patch consolidado.
echo O .env e as configuracoes existentes nao foram substituidos.
echo Backup: %BACKUP%
pause
exit /b 1
