@echo off

setlocal EnableDelayedExpansion

set QT_MAJOR_VER=6

:: %PYTHON% -c "import PyQt!QT_MAJOR_VER!.Qsci"
python -c "import PyQt%QT_MAJOR_VER%.Qsci"

