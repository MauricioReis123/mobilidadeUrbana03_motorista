@echo off
setlocal enabledelayedexpansion
title Analisador Profundo Flutter - Codemagic Prep

echo ========================================================
echo       INICIANDO ANALISE PRE-COMPILACAO (CODEMAGIC)
echo ========================================================
echo.

:: Define o arquivo de log de saída
set "LOG_FILE=relatorio_analise.txt"

echo [%DATE% %TIME%] Iniciando analise do projeto > "%LOG_FILE%"
echo ================================================ >> "%LOG_FILE%"

echo [1/4] Limpando arquivos temporarios e cache antigo...
echo [1/4] Limpando arquivos temporarios e cache antigo... >> "%LOG_FILE%"
call flutter clean >nul 2>&1
call flutter pub get >> "%LOG_FILE%" 2>&1
if %errorlevel% neq 0 (
    echo [FALHA] Erro ao obter dependencias (pub get). Verifique o pubspec.yaml!
    echo [FALHA] Erro ao obter dependencias (pub get). >> "%LOG_FILE%"
    goto FIM
)
echo [SUCESSO] Dependencias atualizadas com sucesso.
echo [SUCESSO] Dependencias atualizadas com sucesso. >> "%LOG_FILE%"
echo.

echo [2/4] Executando analise estatica do codigo (flutter analyze)...
echo [2/4] Executando analise estatica do codigo... >> "%LOG_FILE%"
call flutter analyze >> "%LOG_FILE%" 2>&1
if %errorlevel% neq 0 (
    echo [ATENCAO] O 'flutter analyze' encontrou erros ou avisos no seu codigo!
    echo [ATENCAO] O 'flutter analyze' encontrou erros ou avisos. >> "%LOG_FILE%"
    echo Verifique o arquivo relatorio_analise.txt para detalhes.
) else (
    echo [SUCESSO] Nenhum erro estrutural ou sintatico encontrado pelo Flutter!
    echo [SUCESSO] Nenhum erro encontrado pelo Flutter. >> "%LOG_FILE%"
)
echo.

echo [3/4] Validando estrutura e configuracoes do Android (Gradle)...
echo [3/4] Validando estrutura do Android... >> "%LOG_FILE%"
if exist "android" (
    cd android
    call gradlew.bat check >> "../%LOG_FILE%" 2>&1
    cd ..
    if %errorlevel% neq 0 (
        echo [FALHA] Erro encontrado na validacao do Gradle do Android!
        echo [FALHA] Erro encontrado na validacao do Gradle. >> "%LOG_FILE%"
    ) else (
        echo [SUCESSO] Validacao do Android passou sem erros de build!
        echo [SUCESSO] Validacao do Android passou sem erros. >> "%LOG_FILE%"
    )
) else (
    echo [AVISO] Pasta Android nao encontrada neste nivel.
    echo [AVISO] Pasta Android nao encontrada. >> "%LOG_FILE%"
)
echo.

echo ========================================================
echo               ANALISE CONCLUIDA!
echo ========================================================
echo O relatorio completo foi salvo em: %LOG_FILE%
echo Abra esse arquivo se quiser ver os detalhes de cada etapa.
echo.
goto SAIR

:FIM
echo.
echo ========================================================
echo       PROCESSO INTERROMPIDO POR ERROS CRITICOS
echo ========================================================
echo Verifique o arquivo %LOG_FILE% para corrigir antes do Codemagic.

:SAIR
echo.
pause
