@echo off
title RightMenuAddToPATH Installer By TheUknownCreator
:: If not run as Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File %~dp0RightMenuAddToPATH_Installer.ps1' -Verb RunAs
    exit b
)
powershell -NoProfile -ExecutionPolicy Bypass -File %~dp0RightMenuAddToPATH_Installer.ps1