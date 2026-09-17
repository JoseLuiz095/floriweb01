@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "PREVIEW_NAME=floriweb-preview-rc611"
set "PREVIEW_URL=https://floriweb-preview-rc611.joseluizacama.workers.dev"

echo ============================================================
echo FloriWeb V3 RC6.11 - Validar e publicar PREVIA
echo ============================================================
echo.
echo PRODUCAO NAO SERA SUBSTITUIDA.
echo Worker de previa: %PREVIEW_NAME%
echo URL: %PREVIEW_URL%
echo.
echo ATENCAO: o build usa o .env atual do projeto.
echo Se ele apontar para o Supabase de producao, o preview pode gravar dados reais.
echo.
set /p CONT=Continuar com a publicacao da previa? [S/N]: 
if /I not "%CONT%"=="S" exit /b 0

if not exist package.json (
  echo ERRO: package.json nao encontrado. Execute na raiz do projeto.
  pause
  exit /b 1
)
if not exist wrangler.jsonc (
  echo ERRO: wrangler.jsonc nao encontrado.
  pause
  exit /b 1
)

echo [1/5] Instalando/atualizando dependencias...
call npm install
if errorlevel 1 goto :fail

echo [2/5] TypeScript...
call npm run typecheck
if errorlevel 1 goto :fail

echo [3/5] Build Vite limpo...
if exist dist rmdir /S /Q dist
call npx vite build
if errorlevel 1 goto :fail

echo [4/5] Conferindo build...
if not exist dist\index.html (
  echo ERRO: dist\index.html nao foi gerado.
  goto :fail
)

echo [5/5] Publicando Worker separado de PREVIA...
call npx wrangler deploy --name %PREVIEW_NAME%
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo SUCESSO - PREVIA RC6.11 publicada.
echo Producao "floriweb" permaneceu intacta.
echo %PREVIEW_URL%
echo ============================================================
start "" "%PREVIEW_URL%"
pause
exit /b 0

:fail
echo.
echo ============================================================
echo FALHA - previa nao foi publicada.
echo A producao nao foi alterada.
echo O .env existente nao foi alterado.
echo ============================================================
pause
exit /b 1
