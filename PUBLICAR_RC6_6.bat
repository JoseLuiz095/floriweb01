@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.6 - Validar e publicar FRONTEND
echo ============================================================
echo.
echo Esta versao:
echo - preserva o .env atual
echo - nao possui migration nova
echo - nao possui Edge Function nova
echo - preserva a infraestrutura RC6.5 de mensalidade e acesso
echo - usa OCR local reforcado, sem IA
echo - forca favicon FloriWeb RC6.6 no novo build
echo.

if not exist "package.json" (
  echo ERRO: execute este BAT na raiz do FloriWeb.
  pause
  exit /b 1
)
set "HAS_ENV="
if exist ".env" set "HAS_ENV=1"
if exist ".env.local" set "HAS_ENV=1"
if exist ".env.production" set "HAS_ENV=1"
if not defined HAS_ENV (
  echo ERRO: nenhum arquivo .env foi encontrado.
  echo Este BAT NAO cria .env para nao substituir suas chaves.
  pause
  exit /b 1
)

echo [1/5] Conferindo RC6.6 e configuracoes existentes...
call node scripts\rc66-check.mjs
if errorlevel 1 goto :falha

echo.
echo [2/5] Instalando/atualizando dependencias...
call npm install
if errorlevel 1 goto :falha

echo.
echo [3/5] Limpando build antigo e validando projeto...
if exist "dist" rmdir /s /q "dist"
call npm run validate
if errorlevel 1 goto :falha

echo.
echo [4/5] Confirmando favicon RC6.6 no build...
if not exist "dist\favicon-floriweb-rc66.svg" goto :icone_falha
findstr /c:"favicon-floriweb-rc66.svg" "dist\index.html" >nul 2>&1
if errorlevel 1 goto :icone_falha

echo.
echo [5/5] Publicando Cloudflare Worker...
call npx wrangler deploy
if errorlevel 1 goto :falha

echo.
echo ============================================================
echo SUCESSO - FloriWeb V3 RC6.6 publicado
echo ============================================================
echo.
echo Testes recomendados:
echo - topo do Admin: verde se em dia
echo - topo do Admin: amarelo nos 7 dias anteriores ao vencimento
echo - topo do Admin: vermelho apos vencer sem confirmacao
echo - clicar no indicador deve abrir Meu plano no vencimento
echo - Meu plano deve conter plano, mensalidade, PIX e ultimo pagamento
echo - Financeiro: testar boleto e cupom com valor
echo.
echo O .env existente nao foi substituido.
pause
exit /b 0

:icone_falha
echo.
echo ERRO: o build terminou, mas o favicon RC6.6 nao entrou no dist.
echo O deploy foi interrompido para nao publicar o icone antigo.
pause
exit /b 1

:falha
echo.
echo FALHA. A publicacao foi interrompida.
echo O .env existente nao foi alterado por este BAT.
pause
exit /b 1
