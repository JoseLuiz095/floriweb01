@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.9 - Publicar Edge Function atualizada
echo ============================================================
echo.
echo Esta versao atualiza platform-manage-store-user para registrar
ECHO auditoria segura das alteracoes de credenciais do lojista.
echo.

if not exist "supabase\functions\platform-manage-store-user\index.ts" goto :falha_arquivo

if defined SUPABASE_PROJECT_REF (
  call npx supabase@2.116.0 functions deploy platform-manage-store-user --project-ref "%SUPABASE_PROJECT_REF%"
) else (
  call npx supabase@2.116.0 functions deploy platform-manage-store-user
)
if errorlevel 1 goto :falha

echo.
echo SUCESSO - platform-manage-store-user publicada.
pause
exit /b 0

:falha_arquivo
echo ERRO: Edge Function platform-manage-store-user nao encontrada.
pause
exit /b 1

:falha
echo.
echo FALHA ao publicar platform-manage-store-user.
echo Se necessario, execute antes:
echo   npx supabase@2.116.0 login
echo   npx supabase@2.116.0 link --project-ref SEU_PROJECT_REF
pause
exit /b 1
