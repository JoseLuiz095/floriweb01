@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls
echo ============================================================
echo FloriWeb V3 RC6.4 - Financeiro sem Edge Function de OCR
echo ============================================================
echo.
echo A leitura de nota, boleto, cupom e PDF agora ocorre LOCALMENTE
echo no navegador usando OCR no aparelho do lojista.
echo.
echo Esta versao NAO publica flori-finance-document-extract.
echo Nenhuma chave de IA e necessaria.
echo.
echo Se precisar republicar o contato protegido do RC6.3, execute:
echo   DEPLOY_FLORI_RC6_3_FUNCTIONS.bat
echo.
pause
exit /b 0
