@ECHO off
ECHO Services:
ECHO 1=Move all files in son folder into parent folder.
ECHO 2=Replace file extension to all files in a folder.
ECHO 3=Delete all empty son folders.
SET /p serviceType=Input service type:

IF "%serviceType%"=="1" GOTO service1
IF "%serviceType%"=="2" GOTO service2
IF "%serviceType%"=="3" GOTO service3

:service1
SET /p parentFolder=Input parent folder path:
FOR /r "%parentFolder%" %%f IN (*.*) DO (
    move "%%f" "%parentFolder%"
)
ECHO Done!
SET /p deleteSonFolder=Delete all son folders(y/n)? 
IF "%deleteSonFolder%"=="y" (
    FOR /f "delims=" %%f IN ('DIR /s /ad /b "%parentFolder%"') DO (
        RMDIR "%%f"
    )
    ECHO Done!
)
PAUSE
EXIT

:service2
SET /p folder=Input folder path:
SET /p suffix=Input suffix ("." is not needed):
FOR /r "%folder%" %%f IN (*.*) DO (
    RENAME "%%f" "%%~nf.%suffix%"
)
ECHO Done!
PAUSE
EXIT

:service3
SET /p parentFolder=Input parent folder path(Empty=Temp folder):
IF "%parentFolder%"=="" (
    SET parentFolder=%TEMP%
)
DIR /s /ad /b "%parentFolder%" > dirTemp.txt
FOR /f "delims=" %%f IN ('sort dirTemp.txt /r') DO (
    RMDIR "%%f"
)
del /q "dirTemp.txt"
ECHO Done!
PAUSE
EXIT