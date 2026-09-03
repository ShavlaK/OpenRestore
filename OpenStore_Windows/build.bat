@echo off
echo Installing requirements...
pip install -r requirements.txt

echo Building OpenStore for Windows...
pyinstaller --noconfirm --onedir --windowed --add-data "bin;bin" --name "OpenStore" "src\main.py"

echo Build complete! You can find OpenStore.exe in the 'dist\OpenStore' folder.
pause
