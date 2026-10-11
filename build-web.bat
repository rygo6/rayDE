:: Builds rayDE for the web with emscripten.
:: Output goes to docs/ (index.html, index.js, index.wasm, index.data)
:: which GitHub Pages serves from master /docs. Commit docs/ after building.
::
:: Requires emsdk. If emcc is not on PATH, EMSDK_DIR is used to find emsdk_env.bat.
:: RAYLIB_PATH defaults to ../raylib and can be overridden.

@echo off
setlocal

if not defined RAYLIB_PATH SET RAYLIB_PATH=../raylib
if not defined EMSDK_DIR SET EMSDK_DIR=C:\UnitySrc\emsdk

SET OUT_DIR=docs
SET OBJ_DIR=obj\web
SET RAYLIB_WEB_LIB=%OBJ_DIR%\libraylib.web.a

where emcc >nul 2>nul
if errorlevel 1 call "%EMSDK_DIR%\emsdk_env.bat" >nul
where emcc >nul 2>nul
if errorlevel 1 (
	echo emcc not found. Install emsdk or set EMSDK_DIR.
	exit /b 1
)

if not exist %OUT_DIR% mkdir %OUT_DIR%
if not exist %OBJ_DIR% mkdir %OBJ_DIR%

:: Build raylib for web once. Delete obj\web to force a rebuild (do this after changing RAYLIB_PATH).
if exist %RAYLIB_WEB_LIB% goto BuildRayDE

echo Building raylib for web from %RAYLIB_PATH%...
:: utils.c only exists in older raylib, newer raylib folded it into rcore.c.
for %%f in (rcore rshapes rtextures rtext rmodels utils raudio) do (
	if exist "%RAYLIB_PATH%/src/%%f.c" (
		call emcc -c "%RAYLIB_PATH%/src/%%f.c" -o "%OBJ_DIR%/%%f.o" -Os -std=gnu99 -DPLATFORM_WEB -DGRAPHICS_API_OPENGL_ES2 -I"%RAYLIB_PATH%/src" -I"%RAYLIB_PATH%/src/external/glfw/include"
		if errorlevel 1 exit /b 1
	)
)
SET RAYLIB_OBJS=
for %%o in (%OBJ_DIR%\*.o) do call SET RAYLIB_OBJS=%%RAYLIB_OBJS%% %%o
call emar rcs %RAYLIB_WEB_LIB% %RAYLIB_OBJS%
if errorlevel 1 exit /b 1

:BuildRayDE
echo Building rayDE for web...

:: ASYNCIFY lets the goto main loop yield to the browser in WindowShouldClose().
:: src/main.c is preloaded as the file being edited, same as desktop.
call emcc -o %OUT_DIR%/index.html src/main.c %RAYLIB_WEB_LIB% ^
	-std=gnu11 -O2 -DPLATFORM_WEB ^
	-I"%RAYLIB_PATH%/src" ^
	-Wall -Wextra -Wshadow -Wformat=2 -Wno-unused-variable -Wno-unused-function -Wno-unused-label -Wno-unused-but-set-variable ^
	-sUSE_GLFW=3 -sASYNCIFY -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=1mb ^
	-sEXPORTED_RUNTIME_METHODS=FS ^
	--preload-file src/main.c@src/main.c ^
	--preload-file resources/JetBrainsMono-Regular.ttf@resources/JetBrainsMono-Regular.ttf ^
	--shell-file web/shell.html
if errorlevel 1 exit /b 1

@echo Success! Output in %OUT_DIR%
@echo Test locally with: emrun %OUT_DIR%/index.html
