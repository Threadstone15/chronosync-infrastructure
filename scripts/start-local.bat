@echo off
REM Helper script to start the infrastructure on Windows
REM For Windows PowerShell environments

echo Starting ChronoSync Infrastructure...

REM Check if .env exists
if not exist .env (
    echo Creating .env from .env.example...
    copy .env.example .env
    echo Please edit .env with your MySQL credentials before continuing
    exit /b 1
)

REM Start the infrastructure
docker compose up --build
