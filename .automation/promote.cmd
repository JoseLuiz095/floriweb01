@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
cd /d "%ROOT%"
set "REPO=https://github.com/JoseLuiz095/floriweb01.git"
set "BRANCH=release/floriweb-v3.0.0-rc.6.20"
set "TMP=%TEMP%\floriweb_rc620_promote_%RANDOM%_%RANDOM%"

echo ============================================================
echo FloriWeb RC6.20 - Promover para MAIN
echo ============================================================
echo Apos sucesso: limpa artefatos legados no clone temporario e apaga branches remotas exceto main.
echo Tags sao preservadas. Sua pasta local nao sera resetada.
where git >nul 2>&1 || (echo ERRO: Git nao encontrado.& exit /b 1)
where node >nul 2>&1 || (echo ERRO: Node nao encontrado.& exit /b 1)

git ls-remote --exit-code --heads "%REPO%" "refs/heads/%BRANCH%" >nul 2>&1 || (echo ERRO: release nao existe.& exit /b 1)
git clone --no-recurse-submodules --branch main "%REPO%" "%TMP%" || goto fail
pushd "%TMP%"
git fetch origin "%BRANCH%" --tags || (popd&goto fail_keep)
git merge-base --is-ancestor origin/main "origin/%BRANCH%" || (echo ERRO: main mudou apos a release. Recrie a release.& popd&goto fail_keep)

set "VF=%TEMP%\flori620_%RANDOM%.json"
git show "origin/%BRANCH%:package.json" > "!VF!" || (popd&goto fail_keep)
node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.exit(p.version==='3.0.0-rc.6.20'?0:1)" "!VF!"
set "VC=!ERRORLEVEL!"
del /q "!VF!" >nul 2>&1
if not "!VC!"=="0" (echo ERRO: release nao contem RC6.20.& popd&goto fail_keep)

echo Confirme Preview, QA Lite e checklist manual antes de promover.
set /p "CONF=Digite PRODUCAO para promover: "
if /I not "!CONF!"=="PRODUCAO" (popd&goto cleanup)

git checkout -B main origin/main || (popd&goto fail_keep)
git merge --ff-only "origin/%BRANCH%" || (popd&goto fail_keep)
node "%ROOT%\.automation\clean-main.mjs" || (popd&goto fail_keep)
git add -A
git diff --cached --quiet
if errorlevel 1 (
 git config user.name >nul 2>&1 || git config user.name "FloriWeb Release"
 git config user.email >nul 2>&1 || git config user.email "floriweb-release@local"
 git commit -m "chore: limpar artefatos legados do FloriWeb" || (popd&goto fail_keep)
)
git push origin main || (popd&goto fail_keep)
for /f "tokens=2" %%R in ('git ls-remote --heads origin') do (
 set "REF=%%R"
 set "B=!REF:refs/heads/=!"
 if /I not "!B!"=="main" git push origin --delete "!B!"
)
popd
echo SUCESSO - MAIN em RC6.20 e branches remotas antigas removidas.
goto cleanup

:fail
echo ERRO ao preparar promocao.& exit /b 1
:fail_keep
echo FALHA. Pasta preservada: %TMP%& exit /b 1
:cleanup
if exist "%TMP%" rmdir /s /q "%TMP%" >nul 2>&1
exit /b 0
