@echo off
title pfUI Octo: install / update the client DLLs
echo Installs or updates ClassicAPI, SuperWoW, nampower, UnitXP_SP3 and WeirdUtils (without its performance module)
echo from their authors' release pages: the versions tested with pfUI Octo, each checked by its SHA-256.
echo It lists them and asks before changing anything. pfUI Octo works without them - they make it better.
echo AuctionQueryThrottle (no wait between auction house searches) is only installed if you ask:
echo   powershell -ExecutionPolicy Bypass -File tools\install_dlls.ps1 -AuctionQueryThrottle
echo Close the game first if it is running.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\install_dlls.ps1"
echo.
pause
