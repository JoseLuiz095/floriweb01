@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo FloriWeb V3 RC6.12 - AUTO CADASTRO E APROVACAO MASTER - REV2
echo ============================================================
echo.

where node >nul 2>&1
if errorlevel 1 (
  echo ERRO: Node.js nao encontrado no PATH.
  goto :fail
)

if not exist "package.json" (
  echo ERRO: package.json nao encontrado.
  echo Extraia este pacote diretamente na RAIZ do FloriWeb atual.
  goto :fail
)

if not exist "scripts\apply-flori-rc612.mjs" (
  echo ERRO: scripts\apply-flori-rc612.mjs nao encontrado.
  goto :fail
)

echo [1/3] Aplicando arquivos e criando backup...
node "scripts\apply-flori-rc612.mjs"
if errorlevel 1 goto :fail

echo.
echo [2/3] Executando smoke e fluxo critico...
call npm run smoke
if errorlevel 1 goto :fail
call npm run test:critical
if errorlevel 1 goto :fail

echo.
echo [3/3] Conferencia concluida.
echo.
echo IMPORTANTE - BANCO AINDA NAO FOI ALTERADO POR ESTE BAT.
echo Execute no SQL Editor do Supabase, nesta ordem:
echo   1. supabase\migrations\202609171945_floriweb_rc612_self_service_signup.sql
echo   2. supabase\migrations\202609180800_floriweb_rc612_trial_eligibility_hardening.sql
echo   3. supabase\VALIDAR_RC612_REV2.sql
echo.
echo Todos os campos da validacao REV2 devem retornar true.
echo Depois execute npm run validate antes de publicar.
echo ============================================================
pause
exit /b 0

:fail
echo.
echo ============================================================
echo FALHA - aplicacao interrompida.
echo Verifique a mensagem imediatamente acima.
echo ============================================================
pause
exit /b 1
