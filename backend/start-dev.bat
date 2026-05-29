@echo off
echo ========================================
echo   Kartara Payment Gateway Backend
echo ========================================
echo.

REM Check if node_modules exists
if not exist "node_modules\" (
    echo [1/3] Installing dependencies...
    call npm install
    echo.
) else (
    echo [1/3] Dependencies already installed
    echo.
)

REM Check if .env exists
if not exist ".env" (
    echo [2/3] Creating .env file...
    copy .env.example .env
    echo.
    echo WARNING: Please update .env with your credentials!
    echo.
) else (
    echo [2/3] .env file exists
    echo.
)

echo [3/3] Starting backend server...
echo.
echo Backend will run on: http://localhost:3000
echo Health check: http://localhost:3000/health
echo.
echo IMPORTANT: 
echo 1. Make sure PocketBase is running on http://127.0.0.1:8090
echo 2. Run ngrok in another terminal: ngrok http 3000
echo 3. Update webhook URL in Midtrans Dashboard
echo.
echo Press Ctrl+C to stop the server
echo ========================================
echo.

npm run dev
