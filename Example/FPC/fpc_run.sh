#!/bin/sh
rm *.o
rm *.obj
rm *.ppu
rm *.exe
fpc -B -O3 -vhn -CX -XX triangle.pas
fpc -B -O3 -vhn -CX -XX gears.pas
#fpc -B -O3 -vhn -CX -XX mwindows.pas
fpc -B -O3 -vhn -CX -XX heightmap.pas
