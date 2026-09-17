@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls
echo ============================================================
echo FloriWeb V3 RC6.3 - Publicar Edge Function de contato
echo ============================================================
echo.
echo Pre-requisitos no Supabase Edge Functions Secrets:
echo   TURNSTILE_SECRET_KEY
echo   PUBLIC_APP_ORIGINS=https://floriweb.joseluizacama.workers.dev
echo   CONTACT_FINGERPRINT_SALT ^(opcional, recomendado^)
echo.
echo Nao coloque service_role no frontend.
echo.
call npx supabase@2.116.0 functions deploy flori-public-contact --no-verify-jwt
if errorlevel 1 goto :falha
echo.
echo Edge Function flori-public-contact publicada.
pause
exit /b 0
:falha
echo FALHA ao publicar a Edge Function.
pause
exit /b 1
