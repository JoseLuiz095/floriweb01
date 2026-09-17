@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo FloriWeb V3 RC6.8 - Validar e publicar
echo ============================================================
echo.
echo Esta versao adiciona:
echo - botao Confirmar recebimento nos pedidos
echo - entrada automatica e idempotente no Financeiro
echo - recebimento separado do status operacional do pedido
echo.
echo O .env atual sera preservado.
echo.

if not exist "package.json" goto :falha_raiz
if not exist "scripts\rc68-check.mjs" goto :falha_raiz
if not exist ".env" if not exist ".env.production" if not exist ".env.local" goto :falha_env

node scripts\rc68-check.mjs
if errorlevel 1 goto :falha

echo.
set /p MIG_OK=Migration RC6.8 executada e VALIDAR_RC6_8.sql sem falhas? [S/N]: 
if /I not "%MIG_OK%"=="S" (
  echo Publicacao cancelada. Execute a migration antes do frontend.
  pause
  exit /b 1
)

echo.
echo [1/6] Instalando/atualizando dependencias...
call npm install
if errorlevel 1 goto :falha

echo.
echo [2/6] Smoke test...
call npm run smoke
if errorlevel 1 goto :falha

echo.
echo [3/6] Fluxo critico...
call npm run test:critical
if errorlevel 1 goto :falha

echo.
echo [4/6] TypeScript...
call npm run typecheck
if errorlevel 1 goto :falha

echo.
echo [5/6] Build limpo...
if exist "dist" rmdir /s /q "dist"
call npx vite build
if errorlevel 1 goto :falha

echo.
echo [6/6] Publicando no Cloudflare...
call npx wrangler deploy
if errorlevel 1 goto :falha

echo.
echo ============================================================
echo SUCESSO - FloriWeb RC6.8 publicado
echo ============================================================
echo.
echo Teste sugerido:
echo 1. Abra Pedidos.
echo 2. Clique Confirmar recebimento em um pedido pendente.
echo 3. Abra Financeiro e confirme a entrada Pedido # correspondente.
echo 4. Clique novamente/atualize e confirme que nao houve duplicidade.
echo.
pause
exit /b 0

:falha_raiz
echo ERRO: RC6.8 nao foi aplicado nesta raiz.
pause
exit /b 1

:falha_env
echo ERRO: nenhum arquivo .env existente foi localizado.
echo O BAT nao cria nem altera credenciais.
pause
exit /b 1

:falha
echo.
echo ============================================================
echo FALHA - publicacao interrompida antes da conclusao
echo ============================================================
echo O .env existente nao foi alterado por este BAT.
pause
exit /b 1
