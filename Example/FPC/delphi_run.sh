#!/bin/sh
rm *.o
rm *.obj
rm *.ppu
rm *.exe
dcc64 -B -$O+ triangle.pas
dcc64 -B -$O+ -NSSystem gears.pas

