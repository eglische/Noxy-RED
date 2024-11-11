@echo off
setlocal

:: Preserve the original directory path
set "orig_dir=%~dp0"

echo "+--------------------------------------+"
echo "^  <<<<==== Noxy-RED ====>>>>          ^"
echo "^                             by Yeti  ^"
echo "+--------------------------------------+"

:: Check if Docker stack is already running (ensure both Node-RED and MQTT are running)
echo Checking if Docker services (Node-RED and MQTT) are already running...
docker ps | findstr "nodered" >nul 2>&1
set "nodered_running=%errorlevel%"

docker ps | findstr "mqtt" >nul 2>&1
set "mqtt_running=%errorlevel%"

if %nodered_running% neq 0 if %mqtt_running% neq 0 (
    echo Neither Node-RED nor MQTT services are running. Starting Docker stack...
    if exist "%orig_dir%docker-stack\docker-compose.yml" (
        cd "%orig_dir%docker-stack"
        docker-compose up -d
    ) else (
        echo docker-compose.yml not found in %orig_dir%docker-stack directory.
        pause
    )
) else if %nodered_running% neq 0 (
    echo Only MQTT is running. Starting Node-RED...
    cd "%orig_dir%docker-stack"
    docker-compose up -d nodered
) else if %mqtt_running% neq 0 (
    echo Only Node-RED is running. Starting MQTT...
    cd "%orig_dir%docker-stack"
    docker-compose up -d mqtt
) else (
    echo Both Node-RED and MQTT are already running.
)

:: Step 1: Get the local machine IP (ignore localhost and loopback)
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4"') do (
    set "local_ip=%%a"
    goto :ip_found
)

:ip_found
set local_ip=%local_ip:~1%
echo Local Machine IP: %local_ip%

:: Start Noxy-RED Standalone
echo.
echo Starting Noxy-RED Standalone...
if exist "%orig_dir%bin\Noxy-RED Standalone\noxy_standalone.exe" (
    cd "%orig_dir%bin\Noxy-RED Standalone"
    call "noxy_standalone.exe"
    echo Noxy-RED Standalone started.
) else (
    echo Noxy-RED Standalone not found in %orig_dir%bin\Noxy-RED Standalone.
)

:: Display the local IP address and port information for Node-RED
echo.
echo Node-RED is accessible at: http://%local_ip%:1880
echo.
echo.
echo The script has completed its tasks, you can close this window.
pause
