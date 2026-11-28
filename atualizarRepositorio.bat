@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo ========================================================
echo Instalacao + Criacao + Envio: MauricioReis123/mobilidadeUrbana03_motorista
echo ========================================================
echo.

set "USUARIO=MauricioReis123"
set "REPO=mobilidadeUrbana03_motorista"
set "URL_REPO=https://github.com/%USUARIO%/%REPO%.git"

:: 1. Localiza ou baixa/instala o Git
where git >nul 2>nul
if %errorlevel% neq 0 (
    if exist "C:\Program Files\Git\cmd\git.exe" (
        set "PATH=%PATH%;C:\Program Files\Git\cmd"
    ) else (
        echo [INFO] Baixando e instalando Git silenciosamente...
        powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $url = (Invoke-RestMethod 'https://api.github.com/repos/git-for-windows/git/releases/latest').assets | Where-Object { $_.name -match '64-bit\.exe$' } | Select-Object -First 1 -ExpandProperty browser_download_url; Invoke-WebRequest -Uri $url -OutFile \"$env:TEMP\git_installer.exe\"; Start-Process -FilePath \"$env:TEMP\git_installer.exe\" -ArgumentList '/VERYSILENT /NORESTART' -Wait"
        set "PATH=%PATH%;C:\Program Files\Git\cmd"
    )
)

:: 2. Localiza ou baixa o GitHub CLI (gh) portatil automaticamente
set "GH_DIR=%LOCALAPPDATA%\gh_cli_portatil"
set "GH_EXE=%GH_DIR%\bin\gh.exe"

if not exist "%GH_EXE%" (
    for /f "delims=" %%i in ('where gh 2^>nul') do set "GH_EXE=%%i"
)

if not exist "%GH_EXE%" (
    echo [1/5] Baixando GitHub CLI oficial diretamente...
    if not exist "%GH_DIR%" mkdir "%GH_DIR%"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/cli/cli/releases/latest'; $asset = $release.assets | Where-Object { $_.name -match 'windows_amd64\.zip$' } | Select-Object -First 1; Write-Host ('Baixando ' + $asset.name + '...'); Invoke-WebRequest -Uri $asset.browser_download_url -OutFile '%GH_DIR%\gh.zip'; Expand-Archive -Path '%GH_DIR%\gh.zip' -DestinationPath '%GH_DIR%' -Force; Remove-Item '%GH_DIR%\gh.zip' -Force"
)

:: Confirma se o gh.exe foi extraido corretamente (inclusive se veio dentro de subpasta)
if not exist "%GH_EXE%" (
    for /f "delims=" %%f in ('dir /b /s "%GH_DIR%\gh.exe" 2^>nul') do set "GH_EXE=%%f"
)

if not exist "%GH_EXE%" (
    echo [ERRO] Nao foi possivel baixar ou localizar o gh.exe. Verifique sua internet ou antivirus.
    pause
    exit /b 1
)

:: 3. Verifica autenticacao e vincula ao Git
echo.
echo [2/5] Verificando conta logada no GitHub...
"%GH_EXE%" auth status
if %errorlevel% neq 0 (
    echo.
    echo Iniciando login no navegador...
    "%GH_EXE%" auth login -p https -w
)

"%GH_EXE%" auth setup-git

:: 4. Cria o repositorio na API do GitHub
echo.
echo [3/5] Criando repositorio "%USUARIO%/%REPO%"...
"%GH_EXE%" repo view %USUARIO%/%REPO% >nul 2>nul
if %errorlevel% neq 0 (
    "%GH_EXE%" repo create %REPO% --public
) else (
    echo Repositorio ja existe. Prosseguindo para envio...
)

timeout /t 2 >nul
"%GH_EXE%" repo view %USUARIO%/%REPO% >nul 2>nul
if %errorlevel% neq 0 (
    echo.
    echo [ERRO] O repositorio "%REPO%" nao foi criado. Veja o motivo exato na mensagem acima.
    pause
    exit /b 1
)

:: 5. Prepara commit e faz push
echo.
echo [4/5] Preparando arquivos locais...
git config user.name >nul 2>nul || git config --global user.name "%USUARIO%"
git config user.email >nul 2>nul || git config --global user.email "%USUARIO%@users.noreply.github.com"

set "TEM_ARQUIVO=0"
for %%F in (*) do (
    if /i not "%%~nxF"=="%~nx0" set "TEM_ARQUIVO=1"
)
if "%TEM_ARQUIVO%"=="0" (
    echo # mobilidadeUrbana03_motorista > README.md
)

if not exist ".git" git init
git branch -M main
git remote remove origin >nul 2>nul
git remote add origin %URL_REPO%

git add -A
git commit -m "Atualizacao do repositorio mobilidadeUrbana03_motorista" >nul 2>nul

echo.
echo [5/5] Enviando arquivos para %URL_REPO%...
git push -u origin main --force

if %errorlevel% equ 0 (
    echo.
    echo ========================================================
    echo [SUCESSO] Repositorio criado e atualizado!
    echo Acesse: https://github.com/%USUARIO%/%REPO%
    echo ========================================================
) else (
    echo.
    echo [ERRO] Falha no git push. Veja o detalhe acima.
)

echo.
pause
endlocal