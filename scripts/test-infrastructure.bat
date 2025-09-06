@echo off
setlocal enabledelayedexpansion

echo Starting ChronoSync Infrastructure Tests...

REM Check prerequisites
echo Checking prerequisites...

where docker >nul 2>nul
if errorlevel 1 (
    echo X Docker is not installed
    exit /b 1
)
echo + Docker is available

docker compose version >nul 2>nul
if errorlevel 1 (
    echo X Docker Compose is not installed
    exit /b 1
)
echo + Docker Compose is available

REM Check if .env exists
if not exist .env (
    echo Warning: .env file not found, copying from .env.example
    copy .env.example .env
    echo Please edit .env with your credentials and run the test again
    exit /b 1
)
echo + .env file exists

REM Start infrastructure
echo Starting infrastructure...
docker compose up -d --build

REM Wait for services to be ready
echo Waiting for services to be ready...
timeout /t 30 /nobreak >nul

REM Test HTTP endpoints
echo Testing HTTP endpoints...

curl -s -f http://localhost:8080 >nul 2>nul
if errorlevel 1 (
    echo X North nginx is not responding
) else (
    echo + North nginx is responding
)

REM Test application endpoints
for %%a in (app1 app2 app3) do (
    curl -s -f "http://localhost:8080/%%a/" >nul 2>nul
    if errorlevel 1 (
        echo X %%a endpoint is not responding
    ) else (
        echo + %%a endpoint is responding
    )
)

REM Test internal routing
curl -s -f http://localhost:8080/internal/health/ >nul 2>nul
if errorlevel 1 (
    echo X Internal routing is not working
) else (
    echo + Internal routing is working
)

REM Show service status
echo.
echo Infrastructure status:
docker compose ps

echo.
echo To clean up: docker compose down -v
echo To view logs: docker compose logs [service_name]
