@echo off
setlocal
set "PROJECT_DIR=%~dp0"
for %%G in (godot.exe godot4.exe Godot_v4.7.2-stable_win64.exe) do (
    where %%G >nul 2>nul
    if not errorlevel 1 (
        start "Neon Pursuit" "%%G" --path "%PROJECT_DIR%"
        exit /b 0
    )
)
echo Install Godot 4.7.2 or export the Windows Desktop preset, then run the exported NeonPursuit.exe.
pause
