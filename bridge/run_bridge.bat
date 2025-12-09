@echo off
title GMod AI Assistant - Bridge Server
echo ================================================
echo   GMod AI Assistant - Bridge Server
echo ================================================
echo.
echo Connecting GMod to AI (local or cloud).
echo Players use !ai in GMod to chat.
echo.

cd /d "%~dp0"

python bridge_server.py

pause
