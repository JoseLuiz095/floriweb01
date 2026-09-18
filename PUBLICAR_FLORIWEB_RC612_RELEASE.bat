@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "REPO=https://github.com/JoseLuiz095/floriweb01.git"
set "BRANCH=release/floriweb-v3.0.0-rc.6.12"
set "TAG=v3.0.0-rc.6.12"

echo ============================================================
echo FloriWeb RC6.12 - Publicar release
echo ============================================================
if not exist package.json (echo ERRO: execute na raiz do FloriWeb.& pause & exit /b 1)
where git >nul 2>&1 || (echo ERRO: Git nao encontrado.& pause & exit /b 1)
where node >nul 2>&1 || (echo ERRO: Node nao encontrado.& pause & exit /b 1)

for /f "delims=" %%V in ('node -p "require('./package.json').version"') do set "VERSION=%%V"
if not "%VERSION%"=="3.0.0-rc.6.12" (
  echo ERRO: versao atual %VERSION%, esperado 3.0.0-rc.6.12.
  pause
  exit /b 1
)

if not exist .git git init || goto :fail
git remote get-url origin >nul 2>&1
if errorlevel 1 (git remote add origin "%REPO%") else (git remote set-url origin "%REPO%")
git fetch origin main --tags || goto :fail

git ls-remote --exit-code --heads origin "refs/heads/%BRANCH%" >nul 2>&1
if not errorlevel 1 (echo ERRO: branch remota ja existe.& pause & exit /b 1)
git ls-remote --exit-code --tags origin "refs/tags/%TAG%" >nul 2>&1
if not errorlevel 1 (echo ERRO: tag remota ja existe.& pause & exit /b 1)

git checkout -B "%BRANCH%" || goto :fail
git reset --mixed origin/main || goto :fail
git add -A || goto :fail

for %%F in (.env .env.local .env.production .env.development .env.preview) do git reset HEAD -- "%%F" >nul 2>&1
git reset HEAD -- ".wrangler" >nul 2>&1
git reset HEAD -- "node_modules" >nul 2>&1

echo.
echo Conferindo submodulos/gitlinks acidentais...
git ls-files --stage | findstr /b "160000 " >nul
if not errorlevel 1 (
  echo ERRO: encontrado mode 160000. Publicacao bloqueada:
  git ls-files --stage | findstr /b "160000 "
  pause
  exit /b 1
)

git status --short
echo.
set /p "CONF=Digite S para publicar RC6.12: "
if /I not "%CONF%"=="S" (echo Cancelado.& pause & exit /b 0)

git commit -m "release: FloriWeb v3.0.0-rc.6.12" || goto :fail
git tag -a "%TAG%" -m "FloriWeb v3.0.0-rc.6.12" || goto :fail
git push -u origin "%BRANCH%" || goto :fail
git push origin "%TAG%" || goto :fail

echo.
echo SUCESSO. A main ainda nao foi alterada.
pause
exit /b 0

:fail
echo.
echo FALHA. Nenhum force push foi utilizado.
pause
exit /b 1
