@echo off
set DEBUG_FLAG=
set CLEAR_FLAG=

:process_args
if "%1"=="" goto end_args
if "%1"=="-debug" (
	set DEBUG_FLAG=-debug
) else if "%1"=="-clear" (
	set CLEAR_FLAG=1
)
shift
goto process_args

:end_args
if defined CLEAR_FLAG (
	if exist odin-ogl-cube.exe del odin-ogl-cube.exe
	if exist odin-ogl-cube.pdb del odin-ogl-cube.pdb
)

@echo on
odin run . -vet-semicolon %DEBUG_FLAG%