@echo off
set DEBUG_FLAG=-debug

:process_args
if "%1"=="" goto end_args
if "%1"=="-nodbg" (
	set DEBUG_FLAG=
)
shift
goto process_args
:end_args

odin run . -vet -o:none %DEBUG_FLAG%