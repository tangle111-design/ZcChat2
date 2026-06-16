@echo off
chcp 65001 >nul
title ZcChat2 Full Service

echo Starting VITS TTS Backend...
start "" /D "C:\vits-simple-api-windows-cpu-v0.6.16" "C:\vits-simple-api-windows-cpu-v0.6.16\start.bat"

echo Starting ZcChat2...
start "" /D "C:\Users\tangle\Desktop\ZcChat2\build" ZcChat2.exe

echo Done. Both services started.
