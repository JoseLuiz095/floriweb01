@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo FloriWeb V3 RC6.10 - Validar e publicar
echo ============================================================
echo.
echo Inclui o hotfix de suporte/TypeScript da RC6.9.
echo O .env existente sera preservado.
echo.

if not exist package.json (
  echo ERRO: package.json nao encontrado. Execute na raiz do projeto.
  pause
  exit /b 1
)

set STEP=1/8 - Conferindo RC6.10
 echo [%STEP%]
node scripts\rc610-check.mjs
if errorlevel 1 goto :fail

set /p MIG=Migration RC6.10 executada e VALIDAR_RC6_10.sql sem falhas? [S/N]: 
if /I not "%MIG%"=="S" (
  echo Publicacao cancelada. Execute primeiro a migration e a validacao no Supabase.
  pause
  exit /b 2
)

echo.
echo [2/8] Instalando/atualizando dependencias...
call npm install
if errorlevel 1 goto :fail
echo OBS: npm warn allow-scripts e apenas aviso se o npm retornar codigo 0.
echo.

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

echo [7/8] Conferindo favicon RC6.10...
if not exist dist\favicon-floriweb-rc610.svg (
  echo ERRO: dist\favicon-floriweb-rc610.svg nao foi gerado.
  goto :fail
)
findstr /C:"favicon-floriweb-rc610.svg" dist\index.html >nul
if errorlevel 1 (
  echo ERRO: dist\index.html nao referencia o favicon RC6.10.
  goto :fail
)

echo [8/8] Publicando no Cloudflare...
call npx wrangler deploy
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo SUCESSO - FloriWeb RC6.10 publicado.
echo ============================================================
pause
exit /b 0

:fail
echo.
echo ============================================================
echo FALHA - publicacao interrompida antes do deploy final.
echo A etapa que falhou aparece imediatamente acima.
echo O .env existente nao foi alterado.
echo ============================================================
pause
exit /b 1
