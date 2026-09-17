@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls
echo ============================================================
echo FloriWeb V3 RC6.3 - Validar e publicar frontend
echo ============================================================
echo.
echo Antes deste passo confirme:
echo - migration RC6.3 executada e VALIDAR_RC6_3.sql sem falhas
echo - flori-public-contact publicada
echo - TURNSTILE_SECRET_KEY e PUBLIC_APP_ORIGINS configurados
echo - Supabase Auth ^> Bot and Abuse Protection ^> CAPTCHA habilitado
echo - VITE_TURNSTILE_SITE_KEY presente no .env antes do build
echo.
choice /C SN /N /M "Seguranca RC6.3 ja foi configurada? [S/N]: "
if errorlevel 2 exit /b 2
call node scripts\rc63-check.mjs
if errorlevel 1 goto :falha
call npm install
if errorlevel 1 goto :falha
call npm run validate
if errorlevel 1 goto :falha
call npx wrangler deploy
if errorlevel 1 goto :falha
echo.
echo RC6.3 publicada no Cloudflare Worker.
pause
exit /b 0
:falha
echo FALHA. O deploy foi interrompido.
pause
exit /b 1
