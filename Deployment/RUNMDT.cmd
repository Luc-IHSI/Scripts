@echo off
echo Looking for MDT deployment files...
echo.
for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
  if exist %%d:\Deploy\Scripts\AutoDetect.wsf (
    echo Found deployment files on drive %%d:
    cscript.exe %%d:\Deploy\Scripts\AutoDetect.wsf
    exit /b
  )
)
echo ERROR: Could not find deployment files!
echo Press any key to continue...
pause > nul