@echo off

set CONDITION=true

if %CONDITION%==true (
  odin run . -o:none -debug 
) else (
  odin run . -o:none -debug -vet
)