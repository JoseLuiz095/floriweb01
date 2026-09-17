@echo off
setlocal EnableExtensions
cd /d "%~dp0"
cls

echo ============================================================
echo FloriWeb V3 RC6.7 - Hotfix TypeScript Meu Plano
echo ============================================================
echo.
echo Este hotfix corrige o erro TS18049 em src\pages\admin\Plan.tsx.
echo O .env, Supabase, Wrangler, Turnstile, migrations e secrets
echo existentes NAO sao alterados.
echo.

if not exist "package.json" goto :raiz_invalida
if not exist "src\pages\admin" goto :raiz_invalida

if not exist "_backup_hotfix_rc67_plan" mkdir "_backup_hotfix_rc67_plan" >nul 2>&1
if exist "src\pages\admin\Plan.tsx" (
  copy /y "src\pages\admin\Plan.tsx" "_backup_hotfix_rc67_plan\Plan.tsx" >nul
  if errorlevel 1 goto :falha
)
if exist "scripts\rc67-consolidado-check.mjs" (
  copy /y "scripts\rc67-consolidado-check.mjs" "_backup_hotfix_rc67_plan\rc67-consolidado-check.mjs" >nul
  if errorlevel 1 goto :falha
)

echo [1/4] Corrigindo acesso nulo da assinatura em Meu plano...
copy /y "%~dp0payload\src\pages\admin\Plan.tsx" "src\pages\admin\Plan.tsx" >nul
if errorlevel 1 goto :falha

if exist "scripts\rc67-consolidado-check.mjs" (
  copy /y "%~dp0payload\scripts\rc67-consolidado-check.mjs" "scripts\rc67-consolidado-check.mjs" >nul
  if errorlevel 1 goto :falha
)

findstr /c:"const daysOverdue = subscription?.daysOverdue ?? 0;" "src\pages\admin\Plan.tsx" >nul 2>&1
if errorlevel 1 goto :falha_validacao
findstr /c:"const configuredDueDay = subscription?.dueDay ?? null;" "src\pages\admin\Plan.tsx" >nul 2>&1
if errorlevel 1 goto :falha_validacao
findstr /c:"subscription.daysOverdue" "src\pages\admin\Plan.tsx" >nul 2>&1
if not errorlevel 1 goto :falha_validacao

echo OK   subscription agora e tratada de forma segura.
echo.

echo [2/4] Executando TypeScript antes da publicacao...
call npm run typecheck
if errorlevel 1 goto :falha_typecheck
echo OK   TypeScript aprovado.
echo.

echo [3/4] Hotfix aplicado e validado.
if not exist "PUBLICAR_RC6_7.bat" goto :sem_publicador

echo [4/4] Iniciando PUBLICAR_RC6_7.bat...
call "PUBLICAR_RC6_7.bat"
exit /b %errorlevel%

:raiz_invalida
echo FALHA. Extraia este ZIP diretamente na raiz atual do FloriWeb,
echo na mesma pasta em que existem package.json, src e PUBLICAR_RC6_7.bat.
goto :fim_erro

:sem_publicador
echo FALHA. PUBLICAR_RC6_7.bat nao foi encontrado.
echo O hotfix JA FOI aplicado e o TypeScript passou.
echo Execute manualmente o publicador RC6.7 da sua pasta atual.
goto :fim_erro

:falha_validacao
echo FALHA. O arquivo foi copiado, mas a protecao contra subscription nula
echo nao foi encontrada como esperado.
goto :fim_erro

:falha_typecheck
echo FALHA. O hotfix foi aplicado, mas ainda existe erro no TypeScript.
echo Veja a mensagem imediatamente acima e NAO publique ate corrigir.
goto :fim_erro

:falha
echo FALHA ao copiar os arquivos do hotfix.
goto :fim_erro

:fim_erro
echo.
echo O .env existente nao foi alterado.
pause
exit /b 1
