@echo off
echo Installing requirements...
pip install -r requirements.txt

echo Building OpenRestore for Windows...
pyinstaller --noconfirm --onedir --windowed --add-data "bin;bin" --name "OpenRestore" "src\main.py"

echo Build complete! You can find OpenRestore.exe in the 'dist\OpenRestore' folder.
pause
