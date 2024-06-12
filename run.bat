@echo off
set DEBUG_FLAG=-debug
set ODIN_CMD=run

:process_args
if "%1"=="" goto end_args
if "%1"=="-nodbg" (
	set DEBUG_FLAG=
)
if "%1"=="-build" (
	set ODIN_CMD=build
)
shift
goto process_args
:end_args

@echo on
odin %ODIN_CMD% . -vet -o:none %DEBUG_FLAG%