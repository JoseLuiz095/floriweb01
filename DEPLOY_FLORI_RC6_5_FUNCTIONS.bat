@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.5 - Publicar Edge Function de gestao de acesso
echo ============================================================
echo.
echo Esta funcao permite ao Admin Master alterar e-mail/senha do lojista.
echo Ela usa as variaveis internas do proprio Supabase e NAO exige nova
echo chave no .env do frontend.
echo.

if not exist "supabase\functions\platform-manage-store-user\index.ts" (
  echo ERRO: platform-manage-store-user nao encontrada.
  pause
  exit /b 1
)

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

:falha
echo.
echo FALHA ao publicar platform-manage-store-user.
echo Se o projeto ainda nao estiver vinculado, execute:
echo   npx supabase@2.116.0 login
echo   npx supabase@2.116.0 link --project-ref SEU_PROJECT_REF
pause
exit /b 1
