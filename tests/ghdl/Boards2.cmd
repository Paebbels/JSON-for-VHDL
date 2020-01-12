@echo off

rem configure the path to GHDL here
set GHDL=C:\Tools\GHDL\0.34dev\bin\ghdl.exe

rem analyze VHDL files
%GHDL% -a --std=08 ..\..\examples\config.pkg.vhdl
%GHDL% -a --std=08 ..\..\src\Encodings.pkg.vhdl
%GHDL% -a --std=08 ..\..\src\JSON.pkg.vhdl
%GHDL% -a --std=08 ..\..\examples\Boards2.vhdl

rem run elaburation and simulation, redirect all outputs into a logfile
%GHDL% -r Boards2 > Boards2.log 2>&1

echo Reading logfile ...
echo --------------------------------------------------------------------------------
more Boards2.log
echo --------------------------------------------------------------------------------
