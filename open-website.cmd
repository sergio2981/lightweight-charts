@echo off
setlocal

rem Opens the Lightweight Charts website (docs + demos) in the default browser.
rem
rem The site is a Docusaurus build, so the first run compiles it (a few
rem minutes); later runs only serve website/build. If the server is already up
rem on the port, the browser is pointed at it and no second server is started.
rem
rem Note: `if errorlevel 1` rather than `if %ERRORLEVEL% neq 0`, because a
rem percent-expanded ERRORLEVEL inside a parenthesised block is the value from
rem before the block ran, not from the command inside it.

set "PORT=3010"
set "URL=http://localhost:%PORT%/lightweight-charts/"

cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
	"$deadline=(Get-Date).AddSeconds(1); while((Get-Date) -lt $deadline){ $c=New-Object Net.Sockets.TcpClient; try{ if($c.ConnectAsync('127.0.0.1',%PORT%).Wait(200)){ $c.Close(); exit 0 } }catch{}; $c.Close(); Start-Sleep -Milliseconds 150 }; exit 1"
if errorlevel 1 goto :start

:open
echo Opening %URL%
start "" "%URL%"
endlocal

:start
if not exist "website\build\index.html" (
	echo Building the website. This takes a few minutes on the first run...
	call pnpm --filter lightweight-charts-website build
	if errorlevel 1 goto :build-failed
	goto :serve
)

:serve
echo Starting the server on port %PORT%...
start "Lightweight Charts website" /min cmd /k pnpm serve-website

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
	"$deadline=(Get-Date).AddSeconds(60); while((Get-Date) -lt $deadline){ $c=New-Object Net.Sockets.TcpClient; try{ if($c.ConnectAsync('127.0.0.1',%PORT%).Wait(200)){ $c.Close(); exit 0 } }catch{}; $c.Close(); Start-Sleep -Milliseconds 250 }; exit 1"
if errorlevel 1 goto :serve-failed

goto :open

:build-failed
echo.
echo The website build failed. Review the output above.
pause
exit /b 1

:serve-failed
echo The server did not start. Check the "Lightweight Charts website" window for errors.
pause
exit /b 1