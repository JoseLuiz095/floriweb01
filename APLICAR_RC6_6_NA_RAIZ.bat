@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.6 - Aplicar patch NA RAIZ DO PROJETO
echo ============================================================
echo.
echo Este patch NAO substitui:
echo - .env / .env.local / .env.production
echo - wrangler.jsonc
echo - supabase\config.toml
echo - .git
echo - secrets do Supabase/Cloudflare
echo.
echo RC6.6 NAO possui migration nova nem Edge Function nova.
echo Ele reaproveita a estrutura de mensalidade/acesso da RC6.5.
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
if not exist "supabase\migrations\202609032030_floriweb_rc6_5_billing_access.sql" (
  echo ERRO: a base RC6.5 de mensalidade nao foi encontrada.
  echo Aplique primeiro o FloriWeb V3 RC6.5 e sua migration.
  pause
  exit /b 1
)
if not exist "%~dp0payload\src\utils\localFinancialDocumentReader.ts" (
  echo ERRO: payload RC6.6 nao encontrado.
  pause
  exit /b 1
)

echo Projeto detectado:
echo %CD%
echo.

echo [1/6] Criando backup local dos arquivos alterados...
set "BACKUP=_backup_rc6_6"
if exist "%BACKUP%" rmdir /s /q "%BACKUP%"
mkdir "%BACKUP%\src\layouts" >nul 2>&1
mkdir "%BACKUP%\src\pages\admin" >nul 2>&1
mkdir "%BACKUP%\src\utils" >nul 2>&1
mkdir "%BACKUP%\scripts" >nul 2>&1
mkdir "%BACKUP%\public" >nul 2>&1
mkdir "%BACKUP%\config_preservada" >nul 2>&1
if exist "package.json" copy /y "package.json" "%BACKUP%\package.json" >nul
if exist "package-lock.json" copy /y "package-lock.json" "%BACKUP%\package-lock.json" >nul
if exist "index.html" copy /y "index.html" "%BACKUP%\index.html" >nul
if exist "src\App.tsx" copy /y "src\App.tsx" "%BACKUP%\src\App.tsx" >nul
if exist "src\layouts\AdminLayout.tsx" copy /y "src\layouts\AdminLayout.tsx" "%BACKUP%\src\layouts\AdminLayout.tsx" >nul
if exist "src\pages\admin\Plan.tsx" copy /y "src\pages\admin\Plan.tsx" "%BACKUP%\src\pages\admin\Plan.tsx" >nul
if exist "src\utils\localFinancialDocumentReader.ts" copy /y "src\utils\localFinancialDocumentReader.ts" "%BACKUP%\src\utils\localFinancialDocumentReader.ts" >nul
if exist "scripts\smoke.mjs" copy /y "scripts\smoke.mjs" "%BACKUP%\scripts\smoke.mjs" >nul
if exist "src\styles.css" copy /y "src\styles.css" "%BACKUP%\styles.css" >nul
if exist "public\favicon.svg" copy /y "public\favicon.svg" "%BACKUP%\public\favicon.svg" >nul
if exist ".env" copy /y ".env" "%BACKUP%\config_preservada\.env" >nul
if exist ".env.local" copy /y ".env.local" "%BACKUP%\config_preservada\.env.local" >nul
if exist ".env.production" copy /y ".env.production" "%BACKUP%\config_preservada\.env.production" >nul
if exist "wrangler.jsonc" copy /y "wrangler.jsonc" "%BACKUP%\config_preservada\wrangler.jsonc" >nul
if exist "supabase\config.toml" copy /y "supabase\config.toml" "%BACKUP%\config_preservada\supabase-config.toml" >nul

echo [2/6] Aplicando codigo RC6.6 sem tocar nas configuracoes...
copy /y "%~dp0payload\package.json" "package.json" >nul || goto :falha
copy /y "%~dp0payload\package-lock.json" "package-lock.json" >nul || goto :falha
copy /y "%~dp0payload\index.html" "index.html" >nul || goto :falha
copy /y "%~dp0payload\src\App.tsx" "src\App.tsx" >nul || goto :falha
copy /y "%~dp0payload\src\layouts\AdminLayout.tsx" "src\layouts\AdminLayout.tsx" >nul || goto :falha
copy /y "%~dp0payload\src\pages\admin\Plan.tsx" "src\pages\admin\Plan.tsx" >nul || goto :falha
copy /y "%~dp0payload\src\utils\localFinancialDocumentReader.ts" "src\utils\localFinancialDocumentReader.ts" >nul || goto :falha
copy /y "%~dp0payload\scripts\smoke.mjs" "scripts\smoke.mjs" >nul || goto :falha
copy /y "%~dp0payload\scripts\rc66-check.mjs" "scripts\rc66-check.mjs" >nul || goto :falha

echo [3/6] Concentrando plano e mensalidade em Meu plano...
findstr /c:"/admin/plano#vencimento" "src\App.tsx" >nul 2>&1
if errorlevel 1 goto :falha

echo [4/6] Aplicando estilos RC6.6 sem substituir o CSS inteiro...
findstr /c:"FloriWeb V3 RC6.6: Meu plano unificado, status de vencimento e OCR reforcado" "src\styles.css" >nul 2>&1
if errorlevel 1 type "%~dp0payload\styles_rc66_append.css" >> "src\styles.css"

echo [5/6] Forcando novamente o favicon correto do FloriWeb...
if not exist "public" mkdir "public" >nul 2>&1
copy /y "%~dp0payload\public\favicon.svg" "public\favicon.svg" >nul || goto :falha
copy /y "%~dp0payload\public\favicon-floriweb-rc66.svg" "public\favicon-floriweb-rc66.svg" >nul || goto :falha
if exist "dist" rmdir /s /q "dist"

echo [6/6] Validando patch e configuracao preservada...
call node scripts\rc66-check.mjs
if errorlevel 1 goto :falha_verificacao

echo.
echo ============================================================
echo RC6.6 APLICADO COM SUCESSO
echo ============================================================
echo.
echo Incluido:
echo - status da mensalidade no topo: verde, amarelo ou vermelho
echo - clique no status abre Meu plano direto no vencimento
echo - FloriWeb concentra plano, mensalidade, PIX e historico em Meu plano
echo - OCR local reforcado sem IA, inclusive para boleto e cupom
echo - segunda leitura OCR somente quando faltam campos/valor
echo - favicon FloriWeb RC6.6 forcado novamente
echo.
echo NAO ha migration nova nesta versao.
echo NAO ha Edge Function nova nesta versao.
echo Backup: %BACKUP%
echo.
echo Agora execute PUBLICAR_RC6_6.bat
pause
exit /b 0

:falha_verificacao
echo.
echo ERRO: o patch foi copiado, mas a verificacao RC6.6 encontrou problema.
echo Nao publique ate corrigir a mensagem acima.
echo Backup: %BACKUP%
pause
exit /b 1

:falha
echo.
echo ERRO ao aplicar o patch RC6.6.
echo O .env e as configuracoes existentes nao foram substituidos.
echo Backup: %BACKUP%
pause
exit /b 1
