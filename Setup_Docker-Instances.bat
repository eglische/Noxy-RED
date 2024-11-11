@echo off
setlocal

:: Set the directory where the batch file is located (relative path)
set script_dir=%~dp0

echo "+--------------------------------------+"
echo "^  <<<<==== Noxy-RED ====>>>>          ^"
echo "+--------------------------------------+"

:: Navigate to the directory where docker-compose.yml is located
cd /d "%script_dir%docker-stack"

:: Check if Docker is installed
docker --version >nul 2>&1
if %errorLevel% neq 0 (
    echo Docker is not installed. Please install Docker Desktop first.
    pause
    exit /b
)

:: Check if Docker Desktop executable is present
set dockerDesktopPath="%PROGRAMFILES%\Docker\Docker\Docker Desktop.exe"

if exist %dockerDesktopPath% (
    echo Docker Desktop found. Starting Docker Desktop...
    start "" %dockerDesktopPath%
    echo Waiting for Docker Desktop to start...
) else (
    echo Docker Desktop executable not found at %dockerDesktopPath%.
    echo Please start Docker Desktop manually to proceed.
    pause
)

:: Wait for Docker Desktop to start
:wait_for_docker
timeout /t 5 >nul
docker info >nul 2>&1
if %errorLevel% neq 0 (
    echo Still waiting for Docker to start...
    goto wait_for_docker
)

echo Docker Desktop is running.

:: Start the Docker stack
echo Starting the Docker stack...
docker-compose up -d

:: Check for Docker stack status
if %errorLevel% neq 0 (
    echo.
    echo Failed to start the Docker stack. 
    echo Please make sure Docker Desktop is running and you accepted the terms of service.
    pause
    exit /b
)

:: Now that Docker is running and the stack is up, ask for a single shortcut

echo.
echo.
echo Do you want to create a shortcut for Noxy-RED Standalone on the Desktop and Start Menu?
call :ask_shortcut
if "%result%"=="y" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$WshShell = New-Object -ComObject WScript.Shell; $DesktopPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath('Desktop'), 'Noxy-RED.lnk'); $Shortcut = $WshShell.CreateShortcut($DesktopPath); $Shortcut.TargetPath = '%script_dir%start_Noxy-RED.bat'; $Shortcut.IconLocation = '%script_dir%icon\\noxyred.ico'; $Shortcut.Save()"
    echo Desktop shortcut for Noxy-RED created.

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$WshShell = New-Object -ComObject WScript.Shell; $StartMenuPath = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\\Windows\\Start Menu\\Programs\\Noxy-RED.lnk'); $Shortcut = $WshShell.CreateShortcut($StartMenuPath); $Shortcut.TargetPath = '%script_dir%start_Noxy-RED.bat'; $Shortcut.IconLocation = '%script_dir%icon\\noxyred.ico'; $Shortcut.Save()"
    echo Start Menu shortcut for Noxy-RED created.
)

exit /b

:: Function to ask user for shortcut creation
:ask_shortcut
set /p result="%~1 (y/n): "
if /i "%result%"=="y" (
    set result=y
    goto :eof
) else if /i "%result%"=="n" (
    set result=n
    goto :eof
) else (
    echo Invalid input. Please enter y or n.
    goto ask_shortcut
)

:: Display the local IP address and port information for Node-RED
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4"') do (
    set "local_ip=%%a"
    goto :ip_found
)

:ip_found
set local_ip=%local_ip:~1%
echo.
echo Node-RED is accessible at: http://%local_ip%:1880
echo.
echo The script has completed its tasks. You can now close this window.
pause
