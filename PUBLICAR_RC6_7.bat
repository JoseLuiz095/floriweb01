@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.7 CONSOLIDADO - Validar e publicar
echo ============================================================
echo.
echo Este publicador JA contempla RC6.6 + RC6.7.
echo NAO execute PUBLICAR_RC6_6.bat antes dele.
echo.
echo Preserva o .env existente e nao executa migration.
echo.

if not exist "package.json" goto :raiz_falha
if not exist "scripts\rc67-consolidado-check.mjs" (
  echo ERRO: RC6.7 consolidado ainda nao foi aplicado.
  echo Execute primeiro APLICAR_RC6_7_CONSOLIDADO_NA_RAIZ.bat
  pause
  exit /b 1
)
set "HAS_ENV="
if exist ".env" set "HAS_ENV=1"
if exist ".env.local" set "HAS_ENV=1"
if exist ".env.production" set "HAS_ENV=1"
if not defined HAS_ENV (
  echo ERRO: nenhum .env existente foi localizado.
  echo O BAT nao cria .env automaticamente para nao substituir suas chaves.
  pause
  exit /b 1
)

echo [1/8] Conferindo RC6.6 + RC6.7 e configuracoes preservadas...
call node scripts\rc67-consolidado-check.mjs
if errorlevel 1 goto :falha

echo.
echo [2/8] Instalando/atualizando dependencias...
call npm install
if errorlevel 1 goto :falha

echo.
echo OBS: mensagens "npm warn allow-scripts" sao avisos e nao representam falha
echo se o npm continuar normalmente e retornar codigo 0.
echo.

echo [3/8] Executando smoke test...
call npm run smoke
if errorlevel 1 goto :falha

echo.
echo [4/8] Executando fluxo critico...
call npm run test:critical
if errorlevel 1 goto :falha

echo.
echo [5/8] Executando TypeScript separadamente...
call npm run typecheck
if errorlevel 1 goto :falha

echo.
echo [6/8] Gerando build Vite limpo...
if exist "dist" rmdir /s /q "dist"
call npx vite build
if errorlevel 1 goto :falha

echo.
echo [7/8] Confirmando favicon RC6.7 no build...
if not exist "dist\favicon-floriweb-rc67.svg" goto :icone_falha
findstr /c:"favicon-floriweb-rc67.svg" "dist\index.html" >nul 2>&1
if errorlevel 1 goto :icone_falha

echo.
echo [8/8] Publicando Cloudflare Worker...
call npx wrangler deploy
if errorlevel 1 goto :falha

echo.
echo ============================================================
echo SUCESSO - FloriWeb V3 RC6.7 CONSOLIDADO publicado
echo ============================================================
echo.
echo Validado nesta publicacao:
echo - status mensalidade verde/amarelo/vermelho
echo - Meu plano unificado
echo - OCR reforcado RC6.6
echo - PDF.js com canvas corrigido
echo - Financeiro visual RC6.7 sem inputs Procurar...
echo - favicon RC6.7 novo no dist
echo.
echo O .env existente nao foi alterado.
pause
exit /b 0

:icone_falha
echo.
echo ERRO: build concluido, mas favicon RC6.7 nao foi localizado no dist.
echo Deploy interrompido para evitar publicar cache/icone antigo.
pause
exit /b 1

:raiz_falha
echo ERRO: execute este BAT na raiz atual do FloriWeb.
pause
exit /b 1

:falha
echo.
echo ============================================================
echo FALHA - publicacao interrompida antes do deploy final
echo ============================================================
echo.
echo A etapa que falhou aparece imediatamente acima.
echo O .env existente nao foi alterado por este BAT.
pause
exit /b 1
