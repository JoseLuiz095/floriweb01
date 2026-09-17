@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "BACKUP=_backup_preview_rc6_11"

echo ============================================================
echo FloriWeb - Restaurar arquivos anteriores a RC6.11 PREVIA
echo ============================================================
if not exist "%BACKUP%\src" (
  echo ERRO: backup %BACKUP% nao encontrado.
  pause
  exit /b 1
)

xcopy "%BACKUP%\src\*" "src\" /E /Y /I >nul
if errorlevel 1 (
  echo FALHA ao restaurar backup.
  pause
  exit /b 1
)

echo Backup restaurado localmente.
echo O Worker de producao nunca foi alterado por PUBLICAR_PREVIA_RC6_11.bat.
pause
