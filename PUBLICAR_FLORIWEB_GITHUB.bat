@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "REMOTE_URL=https://github.com/JoseLuiz095/floriweb01.git"
set "BRANCH=release/floriweb-v3.0.0-rc.6.11"
set "TAG=v3.0.0-rc.6.11"
set "COMMIT_MSG=release: FloriWeb v3.0.0-rc.6.11"

echo ============================================================
echo FloriWeb - publicar versao no GitHub
echo Branch: %BRANCH%
echo Tag:    %TAG%
echo ============================================================
echo.

where git >nul 2>&1
if errorlevel 1 (
  echo ERRO: Git nao encontrado no PATH.
  pause
  exit /b 1
)

if not exist package.json (
  echo ERRO: package.json nao encontrado.
  echo Copie este BAT para a raiz do projeto FloriWeb antes de executar.
  pause
  exit /b 1
)

findstr /C:"\"name\": \"floriweb\"" package.json >nul 2>&1
if errorlevel 1 (
  echo ERRO: esta pasta nao parece ser o FloriWeb.
  pause
  exit /b 1
)

findstr /C:"\"version\": \"3.0.0-rc.6.11\"" package.json >nul 2>&1
if errorlevel 1 (
  echo ERRO: package.json ainda nao esta em 3.0.0-rc.6.11.
  echo Execute primeiro o hotfix/validacao RC6.11.
  pause
  exit /b 1
)

if not exist .git (
  echo [1/8] Inicializando repositorio Git local...
  git init
  if errorlevel 1 goto :falha
) else (
  echo [1/8] Repositorio Git local encontrado.
)

echo [2/8] Configurando remote origin...
git remote get-url origin >nul 2>&1
if errorlevel 1 (
  git remote add origin "%REMOTE_URL%"
) else (
  git remote set-url origin "%REMOTE_URL%"
)
if errorlevel 1 goto :falha

echo [3/8] Buscando referencias remotas...
git fetch origin --tags
if errorlevel 1 goto :falha

echo [4/8] Criando/atualizando branch de release local...
git checkout -B "%BRANCH%"
if errorlevel 1 goto :falha

echo [5/8] Preparando arquivos...
if exist .env git check-ignore .env >nul 2>&1
if exist .env.local git check-ignore .env.local >nul 2>&1
git add -A
if exist .env git reset -- .env >nul 2>&1
if exist .env.local git reset -- .env.local >nul 2>&1
if exist .env.production git reset -- .env.production >nul 2>&1
if exist .env.development git reset -- .env.development >nul 2>&1

echo.
git status --short
echo.
choice /C SN /N /M "Continuar com o commit e push? [S/N]: "
if errorlevel 2 exit /b 0

git diff --cached --quiet
if not errorlevel 1 (
  echo Nenhuma alteracao nova para commit. Tentando publicar a branch atual.
) else (
  git commit -m "%COMMIT_MSG%"
  if errorlevel 1 goto :falha
)

echo [6/8] Enviando branch de release...
git push -u origin "%BRANCH%"
if errorlevel 1 goto :falha

echo [7/8] Criando tag se ainda nao existir...
git rev-parse "%TAG%" >nul 2>&1
if errorlevel 1 (
  git tag -a "%TAG%" -m "FloriWeb %TAG%"
  if errorlevel 1 goto :falha
) else (
  echo Tag local %TAG% ja existe. Mantendo a existente.
)

echo [8/8] Enviando tag...
git push origin "%TAG%"
if errorlevel 1 (
  echo AVISO: a tag pode ja existir no remoto. Confira no GitHub.
)

echo.
echo ============================================================
echo SUCESSO - release publicada.
echo Nao altera a branch main automaticamente.
echo Para promover, use PROMOVER_FLORIWEB_PARA_MAIN.bat.
echo ============================================================
pause
exit /b 0

:falha
echo.
echo ============================================================
echo FALHA - publicacao interrompida.
echo Nenhum force push foi executado.
echo ============================================================
pause
exit /b 1
