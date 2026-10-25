@echo off
rem NEXA AutoTest - automated final check of the Windows version.
rem Double-click; results: reports\FINAL_AUTOTEST_REPORT.md
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\autotest\NEXA_AutoTest.ps1" %*
