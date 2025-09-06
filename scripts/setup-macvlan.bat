@echo off
setlocal enabledelayedexpansion

echo MacVlan Network Setup for ChronoSync Infrastructure (Windows)
echo ===========================================================

REM Check if running with admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Warning: This script may require administrator privileges for some operations
)

echo.
echo Detecting network interfaces...

REM Get network adapter information
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /C:"Ethernet adapter"') do (
    set "adapter=%%i"
    set "adapter=!adapter:~1!"
    echo Found adapter: !adapter!
)

REM Try to get the active network adapter with an IP address
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /A "IPv4 Address"') do (
    set "current_ip=%%i"
    set "current_ip=!current_ip:~1!"
    echo Current IP: !current_ip!
)

echo.
echo IMPORTANT: MacVlan Support on Windows
echo ===================================
echo Windows Docker Desktop has limited MacVlan support:
echo - MacVlan networks are not fully supported on Windows Docker Desktop
echo - Consider using Docker on Linux VM or WSL2 for full MacVlan functionality
echo - Alternative: Use host networking or bridge networks
echo.

REM Check if .env exists
if not exist .env (
    echo Creating .env from .env.example...
    copy .env.example .env
)

echo.
echo MacVlan Configuration Notes for Windows:
echo =======================================
echo 1. Check your network adapter name with: ipconfig
echo 2. For WSL2: Use the WSL2 network interface
echo 3. For Hyper-V: Use the vEthernet adapter
echo 4. Update .env file manually with correct interface name
echo.

echo Example Windows network interface names:
echo - Ethernet
echo - Wi-Fi
echo - vEthernet (WSL)
echo - vEthernet (Default Switch)
echo.

echo To update .env file manually:
echo 1. Open .env in a text editor
echo 2. Set MACVLAN_PARENT_INTERFACE to your network adapter name
echo 3. Set MACVLAN_SUBNET to match your network (e.g., 192.168.1.0/24)
echo 4. Set MACVLAN_GATEWAY to your router IP (e.g., 192.168.1.1)
echo.

echo Next steps:
echo 1. Edit .env file with your network configuration
echo 2. Consider using Linux environment for full MacVlan support
echo 3. Test with: docker compose up -d dnsmasq
echo.

pause
