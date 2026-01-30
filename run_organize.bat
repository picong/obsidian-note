@echo off
chcp 65001 > nul
cd /d "C:\Users\cong.pi\Documents\obsidian-note"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "organize_images_batch.ps1"
pause
