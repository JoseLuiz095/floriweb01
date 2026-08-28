@echo off
setlocal
cd /d "%~dp0"
title FloriWeb - Desenvolvimento

echo ============================================================
echo FloriWeb 2.0 - Ambiente de desenvolvimento
echo ============================================================
echo.

where node >nul 2>nul
if errorlevel 1 (
  echo ERRO: Node.js nao foi encontrado.
  echo Instale Node.js 20 ou superior e tente novamente.
  pause
  exit /b 1
)

if not exist node_modules (
  echo Dependencias nao encontradas. Executando npm install...
  call npm install
  if errorlevel 1 (
    echo.
    echo ERRO ao instalar dependencias.
    pause
    exit /b 1
  )
)

echo.
if exist .env (
  echo Modo: configuracao .env encontrada. O sistema tentara usar Supabase.
) else (
  echo Modo: DEMO LOCAL. Para Supabase, copie .env.example para .env e preencha as chaves.
)
echo.
echo Loja:  http://localhost:5173
echo Admin: http://localhost:5173/admin/login
echo.
echo No modo demo:
echo Usuario: admin@floriweb.demo
echo Senha:   Flori@2026
echo.
echo Pressione Ctrl+C para encerrar.
echo ============================================================
call npm run dev
