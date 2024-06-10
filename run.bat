@echo off
if exist odin-ogl-cube.exe del odin-ogl-cube.exe
if exist odin-ogl-cube.pdb del odin-ogl-cube.pdb

set DEBUG_FLAG=
if "%1"=="-debug" set DEBUG_FLAG=-debug

odin run . -vet-semicolon %DEBUG_FLAG%