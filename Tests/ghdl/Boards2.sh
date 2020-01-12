#!/usr/bin/env sh

if [ "x$GHDL" = "x" ]; then
  GHDL=ghdl
fi

cd $(dirname $0)

echo analyze VHDL files
$GHDL -a --std=08 ../../Examples/config.pkg.vhdl
$GHDL -a --std=08 ../../Src/Encodings.pkg.vhdl
$GHDL -a --std=08 ../../Src/JSON.pkg.vhdl
$GHDL -a --std=08 ../../Examples/Boards2.vhdl

echo run elaboration and simulation, redirect all outputs into a logfile
$GHDL --elab-run --std=08 Boards2 > Boards2.log 2>&1

echo Reading logfile ...
echo --------------------------------------------------------------------------------
cat Boards2.log
#more Boards2.log
echo --------------------------------------------------------------------------------
