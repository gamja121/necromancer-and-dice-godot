@echo off
set "task_godot=D:\Workspace\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%task_godot%" (
  echo Godot executable was not found. Open project.godot in Godot and press F6.
  pause
  exit /b 1
)
start "Necromancer and Dice" "%task_godot%" --path "%~dp0"
