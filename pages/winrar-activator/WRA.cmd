@echo off
setlocal EnableExtensions DisableDelayedExpansion
:: Ashesh Development custom launcher; GPL-3.0. See LICENSE and NOTICE.
:: PowerShell handles names and UTF-8 data without batch string substitution.
powershell.exe -NoProfile -File "%~dp0WRA.ps1" %*
exit /b %errorlevel%
