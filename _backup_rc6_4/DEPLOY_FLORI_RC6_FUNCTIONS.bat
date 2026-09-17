@echo off
setlocal
cd /d "%~dp0"
echo Publicando somente a nova Edge Function financeira do FloriWeb...
set /p PROJECT_REF=Informe o Project Ref do Supabase: 
if "%PROJECT_REF%"=="" exit /b 1
npx supabase@2.116.0 functions deploy flori-finance-document-extract --project-ref %PROJECT_REF%
if errorlevel 1 goto :fail
echo Edge Function publicada com sucesso.
pause
exit /b 0
:fail
echo FALHA ao publicar a Edge Function.
pause
exit /b 1
