@echo off
chcp 65001 > nul
echo ========================================================
echo   Загрузка проекта «Сомния» в GitHub (ветка main)
echo ========================================================
echo.
cd /d D:\ANTI\somnia
C:\git\cmd\git.exe push -u origin main
echo.
if %ERRORLEVEL% equ 0 (
    echo [УСПЕХ] Проект успешно отправлен в GitHub!
    echo Теперь перейдите на страницу репозитория во вкладку Actions.
) else (
    echo [ОШИБКА] Произошла ошибка при отправке. Проверьте подключение и авторизацию.
)
echo.
pause
