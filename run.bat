@echo off
set DEBUG_FLAG=

:process_args
if "%1"=="" goto end_args
if "%1"=="-debug" (
	set DEBUG_FLAG=-debug
)
shift
goto process_args
:end_args

@echo on
odin run . -vet -o:none %DEBUG_FLAG%