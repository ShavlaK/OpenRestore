Инструкция по сборке OpenRestore (Windows Edition)

Шаг 1: Компиляция основного приложения
1. Установите Python (если еще не установлен) с официального сайта python.org. При установке поставьте галочку "Add Python to PATH".
2. Откройте папку OpenRestore_Windows.
3. Дважды кликните по файлу `build.bat`.
4. Дождитесь завершения. В папке `dist/OpenRestore/` появится готовая программа. Вы уже можете запускать OpenRestore.exe оттуда.

Шаг 2: Создание красивого установщика (Setup.exe) с вшитым iTunes
1. Скачайте официальный iTunes для Windows (iTunes64Setup.exe) с сайта Apple:
   https://www.apple.com/itunes/download/win64
2. Положите скачанный файл `iTunes64Setup.exe` в папку `installer/`.
3. Скачайте и установите программу "Inno Setup" (https://jrsoftware.org/isdl.php).
4. Откройте файл `installer/OpenRestore.iss` через Inno Setup.
5. Нажмите сверху кнопку "Compile" (или Build).
6. В папке `installer/Output/` появится ваш готовый `OpenRestore_Setup.exe`!

Этот установщик сам проверит, есть ли на компьютере пользователя драйвера Apple. Если их нет, он тихо в фоновом режиме установит iTunes, а затем установит OpenRestore.
