@echo off
echo Building Open Store for Windows...
go build -ldflags="-H windowsgui -s -w" -o "Open Store.exe"
echo Build complete! You can find Open Store.exe in the current folder.
pause
