@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo FloriWeb V3 RC6.11 - Hotfix usuario e interacoes
echo ============================================================
echo.

where node >nul 2>&1
if errorlevel 1 (
  echo ERRO: Node.js nao encontrado no PATH.
  pause
  exit /b 1
)

node tools\aplicar_floriweb_rc611_ajustes.mjs
if errorlevel 1 goto :falha

echo.
echo Validando ajustes...
node tools\validar_floriweb_rc611_ajustes.mjs
if errorlevel 1 goto :falha

echo.
echo ============================================================
echo SUCESSO - ajustes aplicados.
echo Agora execute VALIDAR_FLORIWEB_RC611_AJUSTES.bat.
echo ============================================================
pause
exit /b 0

:falha
echo.
echo ============================================================
echo FALHA - ajuste interrompido.
echo Consulte a mensagem acima. O backup foi criado antes da alteracao.
echo ============================================================
pause
exit /b 1
