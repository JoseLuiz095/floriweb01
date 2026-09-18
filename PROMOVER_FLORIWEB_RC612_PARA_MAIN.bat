@echo off
setlocal
cd /d "%~dp0"
set "REPO=https://github.com/JoseLuiz095/floriweb01.git"
set "BRANCH=release/floriweb-v3.0.0-rc.6.12"

git remote set-url origin "%REPO%" >nul 2>&1
git fetch origin main "%BRANCH%" || goto :fail
git merge-base --is-ancestor origin/main "origin/%BRANCH%" || (echo ERRO: main mudou; promocao cancelada.& pause & exit /b 1)

git ls-tree -r "origin/%BRANCH%" | findstr /b "160000 " >nul
if not errorlevel 1 (
  echo ERRO: release contem submodulo/gitlink:
  git ls-tree -r "origin/%BRANCH%" | findstr /b "160000 "
  pause
  exit /b 1
)

set /p "CONF=Digite S para promover RC6.12 para MAIN: "
if /I not "%CONF%"=="S" exit /b 0
git push origin "origin/%BRANCH%:refs/heads/main" || goto :fail
echo SUCESSO. Main atualizada.
pause
exit /b 0

:fail
echo FALHA. Nao foi usado force push.
pause
exit /b 1
