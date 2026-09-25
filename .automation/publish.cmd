@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
cd /d "%ROOT%"
set "REPO=https://github.com/JoseLuiz095/floriweb01.git"
set "BRANCH=release/floriweb-v3.0.0-rc.6.20"
set "TAG=v3.0.0-rc.6.20"
set "TMP=%TEMP%\floriweb_rc620_release_%RANDOM%_%RANDOM%"

echo ============================================================
echo FloriWeb RC6.20 - Publicar RELEASE para teste
echo ============================================================
echo Repositorio: %REPO%
echo Branch:      %BRANCH%
echo Tag:         %TAG%
echo.
echo Este BAT NAO altera a main antes da promocao.
echo.
where git >nul 2>&1 || (echo ERRO: Git nao encontrado.& exit /b 1)
where node >nul 2>&1 || (echo ERRO: Node nao encontrado.& exit /b 1)
where npm >nul 2>&1 || (echo ERRO: npm nao encontrado.& exit /b 1)

set "HAS_BRANCH=0"
set "HAS_TAG=0"
git ls-remote --exit-code --heads "%REPO%" "refs/heads/%BRANCH%" >nul 2>&1 && set "HAS_BRANCH=1"
git ls-remote --exit-code --tags "%REPO%" "refs/tags/%TAG%" >nul 2>&1 && set "HAS_TAG=1"

if "!HAS_BRANCH!!HAS_TAG!"=="00" goto refs_ok
echo AVISO: branch/tag desta release ja existem.
set /p "RECREATE=Digite R para remover SOMENTE esta branch/tag e recriar, ou ENTER para cancelar: "
if /I not "!RECREATE!"=="R" exit /b 1
if "!HAS_BRANCH!"=="1" git push "%REPO%" --delete "%BRANCH%" || exit /b 1
if "!HAS_TAG!"=="1" git push "%REPO%" ":refs/tags/%TAG%" || exit /b 1

:refs_ok
echo [1/7] Clonando main atual...
git clone --no-recurse-submodules --branch main "%REPO%" "%TMP%" || goto fail
pushd "%TMP%"
for /f "delims=" %%V in ('node -p "require('./package.json').version"') do set "BASE=%%V"
if not "!BASE!"=="3.0.0-rc.6.14" if not "!BASE!"=="3.0.0-rc.6.15" if not "!BASE!"=="3.0.0-rc.6.16" if not "!BASE!"=="3.0.0-rc.6.17" if not "!BASE!"=="3.0.0-rc.6.18" if not "!BASE!"=="3.0.0-rc.6.19" if not "!BASE!"=="3.0.0-rc.6.20" (echo ERRO: main em !BASE!. Base nao suportada.& popd&goto fail_keep)
echo Base detectada: !BASE!

echo [2/7] Copiando o estado local atual para a copia limpa...
node "%ROOT%\.automation\prepare-release-snapshot.mjs" "%ROOT%" "%TMP%" || (popd&goto fail_keep)

echo [3/7] Instalando dependencias...
call "%ROOT%\.automation\install-root.cmd" "%TMP%" || (popd&goto fail_keep)

echo [4/7] Validando projeto...
call npm run validate || (echo ERRO: validacao falhou. Nada sera enviado.& popd&goto fail_keep)

echo [5/7] Preparando commit da release...
git checkout -b "%BRANCH%" || (popd&goto fail_keep)
git add -A
git diff --cached --quiet && (echo ERRO: o estado local e a main remota estao identicos; nenhuma alteracao preparada.& popd&goto fail_keep)
git status --short
echo.
set /p "CONF=Digite S para publicar FloriWeb RC6.20 QA Lite: "
if /I not "!CONF!"=="S" (popd&goto cleanup)
git config user.name >nul 2>&1 || git config user.name "Release Automation"
git config user.email >nul 2>&1 || git config user.email "release@local"
git commit -m "release: FloriWeb v3.0.0-rc.6.20 QA Lite" || (popd&goto fail_keep)
git tag -a "%TAG%" -m "FloriWeb v3.0.0-rc.6.20 QA Lite" || (popd&goto fail_keep)

echo [6/7] Enviando branch e tag de forma atomica...
git push --atomic origin "%BRANCH%" "%TAG%" || (popd&goto fail_keep)

echo [7/7] Conferindo refs remotas...
git ls-remote --exit-code --heads origin "refs/heads/%BRANCH%" >nul 2>&1 || (popd&goto fail_keep)
git ls-remote --exit-code --tags origin "refs/tags/%TAG%" >nul 2>&1 || (popd&goto fail_keep)
popd
echo SUCESSO - release RC6.20 publicada. MAIN nao alterada.
goto cleanup

:fail
echo ERRO ao preparar release.& exit /b 1
:fail_keep
echo FALHA. Pasta temporaria preservada: %TMP%& exit /b 1
:cleanup
if exist "%TMP%" rmdir /s /q "%TMP%" >nul 2>&1
exit /b 0
