@echo off

rem configure the path to GHDL here
set GHDL=C:\Tools\GHDL\0.33dev\bin\ghdl.exe

rem analyze VHDL files
%GHDL% -a ..\vhdl\JSON.pkg.vhdl
%GHDL% -a ..\Examples\Boards2.vhdl

rem run elaburation and simulation, redirect all outputs into a logfile
%GHDL% -r Boards2 > Boards2.log 2>&1

echo Reading logfile ...
echo --------------------------------------------------------------------------------
more Boards2.log
echo --------------------------------------------------------------------------------
