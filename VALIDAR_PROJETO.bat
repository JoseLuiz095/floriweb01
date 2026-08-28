@echo off
setlocal
cd /d "%~dp0"
title FloriWeb - Validacao

echo ============================================================
echo FloriWeb 2.0 - Validacao tecnica
echo ============================================================
echo.

where node >nul 2>nul
if errorlevel 1 (
  echo ERRO: Node.js nao encontrado. Instale Node.js 20 ou superior.
  pause
  exit /b 1
)

if not exist node_modules (
  echo Dependencias nao encontradas. Executando npm install...
  call npm install
  if errorlevel 1 goto :falha
)

echo.
echo [1/2] TypeScript + build Vite
call npm run build
if errorlevel 1 goto :falha

echo.
echo [2/2] Estrutura gerada
if not exist dist goto :falha

echo.
echo ============================================================
echo VALIDACAO CONCLUIDA
ECHO Build disponivel em: %CD%\dist
echo Para testar o build: npm run preview
echo ============================================================
pause
exit /b 0

:falha
echo.
echo ============================================================
echo FALHA NA VALIDACAO
ECHO Revise a mensagem de erro acima.
echo ============================================================
pause
exit /b 1
