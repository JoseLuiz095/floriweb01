@echo off
setlocal
cd /d "%~dp0"
cls
echo ============================================================
echo FloriWeb V3 RC2 - Deploy das Edge Functions do Supabase
echo ============================================================
echo.
set "PROJECT_REF=%SUPABASE_PROJECT_REF%"
if "%PROJECT_REF%"=="" (
  set /p PROJECT_REF=Informe o Project Ref do Supabase: 
)
if "%PROJECT_REF%"=="" (
  echo.
  echo ERRO: Project Ref nao informado.
  pause
  exit /b 1
)

echo.
echo Project Ref: %PROJECT_REF%
echo.
echo Se esta for a primeira execucao, o Supabase CLI podera solicitar login.
echo.
call npx supabase@2.116.0 functions deploy platform-create-store --project-ref "%PROJECT_REF%"
if errorlevel 1 (
  echo.
  echo FALHA ao publicar platform-create-store.
  echo Execute antes: npx supabase@2.116.0 login
  pause
  exit /b 1
)

echo.
echo Publicando public-checkout...
echo A configuracao supabase/config.toml define verify_jwt=false apenas para esta funcao publica.
call npx supabase@2.116.0 functions deploy public-checkout --project-ref "%PROJECT_REF%" --no-verify-jwt
if errorlevel 1 (
  echo.
  echo FALHA ao publicar public-checkout.
  pause
  exit /b 1
)

echo.
echo Listando Edge Functions publicadas...
call npx supabase@2.116.0 functions list --project-ref "%PROJECT_REF%"

echo.
echo ============================================================
echo CONCLUIDO
echo Abra /admin-master/diagnostico e execute a validacao novamente.
echo ============================================================
pause
