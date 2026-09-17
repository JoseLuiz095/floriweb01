@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.2.1 - Validar e publicar
ECHO ============================================================
echo.
if not exist "package.json" (
  echo ERRO: execute este arquivo na raiz do projeto FloriWeb.
  pause
  exit /b 1
)

findstr /c:"/admin/financeiro" "src\layouts\AdminLayout.tsx" >nul 2>&1 || goto :patch_missing
findstr /c:"/admin-master/cobranca" "src\layouts\MasterLayout.tsx" >nul 2>&1 || goto :patch_missing
findstr /c:"AdminBilling" "src\App.tsx" >nul 2>&1 || goto :patch_missing

echo ATENCAO: este BAT nao executa SQL automaticamente.
echo.
echo Antes de publicar, confirme que o Supabase recebeu:
echo   - 202609021130_floriweb_rc6_billing_finance_landing.sql
ECHO   - 202609021730_floriweb_rc6_2_marketing_whatsapp_landing.sql
ECHO   - e que VALIDAR_RC6_2.sql foi executado sem erro.
echo.
set /p DBOK=Banco RC6/RC6.2 ja foi atualizado e validado? [S/N]: 
if /I not "%DBOK%"=="S" (
  echo Publicacao cancelada.
  pause
  exit /b 1
)

echo.
echo [1/4] Instalando dependencias...
call npm install
if errorlevel 1 goto :falha

echo.
echo [2/4] Verificacao especifica RC6.2...
node scripts\rc62-check.mjs
if errorlevel 1 goto :falha

echo.
echo [3/4] Validacao completa...
call npm run validate
if errorlevel 1 goto :falha

echo.
echo [4/4] Publicando Cloudflare Worker...
call npx wrangler deploy
if errorlevel 1 goto :falha

echo.
echo ============================================================
echo PUBLICACAO CONCLUIDA
ECHO ============================================================
echo.
echo Teste depois:
echo   https://floriweb.joseluizacama.workers.dev/
echo   /admin/financeiro
ECHO   /admin/mensalidade
ECHO   /admin-master/cobranca
ECHO   /admin-master/pagamentos
ECHO.
pause
exit /b 0

:patch_missing
echo.
echo ERRO: RC6.2 nao esta aplicado nos arquivos ativos desta pasta.
echo Rode primeiro APLICAR_RC6_2_1_NA_RAIZ.bat.
pause
exit /b 1

:falha
echo.
echo FALHA. O deploy foi interrompido.
pause
exit /b 1
