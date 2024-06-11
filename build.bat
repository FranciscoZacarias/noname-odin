@echo off
if exist odin-ogl-cube.exe del odin-ogl-cube.exe
if exist odin-ogl-cube.pdb del odin-ogl-cube.pdb
@echo on
odin build . -vet-semicolon -debug