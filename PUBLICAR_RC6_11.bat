@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo FloriWeb V3 RC6.11 - Validar e publicar em PRODUCAO
echo ============================================================
echo.
echo Este BAT usa o wrangler.jsonc EXISTENTE do projeto.
echo Portanto o deploy vai para o Worker de PRODUCAO ja configurado.
echo O .env existente sera preservado.
echo Nao executa migration.
echo.
set /p CONF=Publicar RC6.11 diretamente em PRODUCAO? [S/N]: 
if /I not "%CONF%"=="S" exit /b 0

if not exist package.json (
  echo ERRO: package.json nao encontrado.
  pause
  exit /b 1
)

echo [1/8] Conferindo RC6.11...
node scripts\rc611-check.mjs
if errorlevel 1 goto :fail

echo [2/8] Instalando/atualizando dependencias...
call npm install
if errorlevel 1 goto :fail
echo OBS: npm warn allow-scripts e aviso se o npm retornar codigo 0.

echo [3/8] Smoke test...
call npm run smoke
if errorlevel 1 goto :fail

echo [4/8] Fluxo critico...
call npm run test:critical
if errorlevel 1 goto :fail

echo [5/8] TypeScript...
call npm run typecheck
if errorlevel 1 goto :fail

echo [6/8] Build Vite limpo...
if exist dist rmdir /S /Q dist
call npx vite build
if errorlevel 1 goto :fail

echo [7/8] Conferindo favicon RC6.11...
if not exist dist\favicon-floriweb-rc611.svg (
  echo ERRO: dist\favicon-floriweb-rc611.svg nao foi gerado.
  goto :fail
)
findstr /C:"favicon-floriweb-rc611.svg" dist\index.html >nul
if errorlevel 1 (
  echo ERRO: dist\index.html nao referencia o favicon RC6.11.
  goto :fail
)

echo [8/8] Publicando no Worker de PRODUCAO configurado...
call npx wrangler deploy
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo SUCESSO - FloriWeb RC6.11 publicado em PRODUCAO.
echo ============================================================
pause
exit /b 0

:fail
echo.
echo ============================================================
echo FALHA - publicacao interrompida ANTES do deploy final ou durante ele.
echo Veja a etapa imediatamente acima.
echo O .env existente nao foi alterado.
echo ============================================================
pause
exit /b 1
