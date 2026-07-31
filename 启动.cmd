@echo off
REM Launch the .ahk that sits next to this .cmd using the portable AutoHotkey v2.
REM We DON'T hardcode the (Chinese) script name here: the console OEM codepage is 437,
REM which can't represent Chinese, so a literal Chinese path in this file becomes garbage.
REM %~dp0 (this file's folder) and the for-loop filename come from the Unicode filesystem
REM at runtime, so they stay correct regardless of codepage. No admin needed.
for %%F in ("%~dp0*.ahk") do start "" "C:\no_install\AutoHotkey\AutoHotkey64.exe" "%%~fF"
