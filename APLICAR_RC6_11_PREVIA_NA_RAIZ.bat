@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "BACKUP=_backup_preview_rc6_11"

echo ============================================================
echo FloriWeb V3 RC6.11 - Aplicar PREVIA na raiz - V4
echo ============================================================
echo.

if not exist package.json (
  echo ERRO: package.json nao encontrado.
  echo Extraia este ZIP diretamente na raiz do projeto FloriWeb.
  pause
  exit /b 1
)

if not exist payload\src\styles.css (
  echo ERRO: pasta payload incompleta.
  pause
  exit /b 1
)

if exist "%BACKUP%\src" (
  echo [1/3] Backup anterior encontrado e PRESERVADO: %BACKUP%
) else (
  echo [1/3] Criando backup dos arquivos alterados...
  mkdir "%BACKUP%" >nul 2>&1
  if exist "src\types\index.ts" xcopy "src\types\index.ts" "%BACKUP%\src\types\" /Y /I >nul
  if exist "src\utils\storeHours.ts" xcopy "src\utils\storeHours.ts" "%BACKUP%\src\utils\" /Y /I >nul
  if exist "src\components\StoreHeader.tsx" xcopy "src\components\StoreHeader.tsx" "%BACKUP%\src\components\" /Y /I >nul
  if exist "src\pages\admin\Settings.tsx" xcopy "src\pages\admin\Settings.tsx" "%BACKUP%\src\pages\admin\" /Y /I >nul
  if exist "src\pages\admin\Finance.tsx" xcopy "src\pages\admin\Finance.tsx" "%BACKUP%\src\pages\admin\" /Y /I >nul
  if exist "src\pages\admin\Orders.tsx" xcopy "src\pages\admin\Orders.tsx" "%BACKUP%\src\pages\admin\" /Y /I >nul
  if exist "src\pages\store\OrderSuccess.tsx" xcopy "src\pages\store\OrderSuccess.tsx" "%BACKUP%\src\pages\store\" /Y /I >nul
  if exist "src\layouts\MasterLayout.tsx" xcopy "src\layouts\MasterLayout.tsx" "%BACKUP%\src\layouts\" /Y /I >nul
  if exist "src\styles.css" xcopy "src\styles.css" "%BACKUP%\src\" /Y /I >nul
)

echo [2/3] Aplicando arquivos da previa...
xcopy "payload\src\*" "src" /E /Y /I >nul
if errorlevel 1 goto :copyfail

echo [3/3] Validando marcadores da RC6.11...
if not exist "src\pages\admin\Orders.tsx" goto :missing_orders
if not exist "src\utils\storeHours.ts" goto :missing_hours
if not exist "src\styles.css" goto :missing_css

findstr /C:"/admin/pedidos?highlight=" "src\pages\admin\Finance.tsx" >nul || goto :missing_finance
findstr /C:"breakStart" "src\pages\admin\Settings.tsx" >nul || goto :missing_lunch
findstr /C:"orders-toolbar--filters" "src\pages\admin\Orders.tsx" >nul || goto :missing_order_filter
findstr /C:"hoursOpen" "src\components\StoreHeader.tsx" >nul || goto :missing_hours_ui
findstr /C:"RC6.11 refinement" "src\styles.css" >nul || goto :missing_styles
findstr /C:"breakStart?: string" "src\types\index.ts" >nul || goto :missing_lunch_type
findstr /C:"paymentStatus?: 'pending' | 'paid'" "src\types\index.ts" >nul || goto :missing_payment_type
findstr /C:"searchOpen?:boolean" "src\components\StoreHeader.tsx" >nul || goto :missing_search_props

echo.
echo ============================================================
echo SUCESSO - RC6.11 PREVIA aplicada localmente.
echo Backup original preservado em: %BACKUP%
echo Proximo passo: PUBLICAR_PREVIA_RC6_11.bat
echo ============================================================
pause
exit /b 0

:copyfail
echo ERRO: falha ao copiar o payload para src.
goto :fail
:missing_orders
echo ERRO: src\pages\admin\Orders.tsx nao encontrado.
goto :fail
:missing_hours
echo ERRO: src\utils\storeHours.ts nao encontrado.
goto :fail
:missing_css
echo ERRO: src\styles.css nao encontrado.
goto :fail
:missing_finance
echo ERRO: link do pedido relacionado nao foi localizado no Financeiro.
goto :fail
:missing_lunch
echo ERRO: configuracao de pausa de almoco nao foi localizada em Settings.tsx.
goto :fail
:missing_order_filter
echo ERRO: filtros de pedidos nao foram localizados.
goto :fail
:missing_hours_ui
echo ERRO: popover controlado dos horarios nao foi localizado.
goto :fail
:missing_styles
echo ERRO: bloco visual RC6.11 nao foi localizado em styles.css.
goto :fail
:missing_lunch_type
echo ERRO: tipo breakStart/breakEnd nao foi localizado em src\types\index.ts.
goto :fail
:missing_payment_type
echo ERRO: tipos de recebimento do pedido nao foram localizados em src\types\index.ts.
goto :fail
:missing_search_props
echo ERRO: compatibilidade de pesquisa da vitrine nao foi localizada no StoreHeader.
goto :fail

:fail
echo.
echo ============================================================
echo FALHA - confira a mensagem ERRO imediatamente acima.
echo O .env e as configuracoes existentes nao foram alterados.
echo O backup anterior NAO foi sobrescrito.
echo Backup: %BACKUP%
echo ============================================================
pause
exit /b 1
