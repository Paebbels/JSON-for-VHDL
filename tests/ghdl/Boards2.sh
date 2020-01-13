#!/usr/bin/env sh

set -e

if [ "x$GHDL" = "x" ]; then
  GHDL=ghdl
fi

cd $(dirname $0)

echo analyze VHDL files
$GHDL -a --std=08 ../../src/Encodings.pkg.vhdl
$GHDL -a --std=08 ../../src/JSON.pkg.vhdl
$GHDL -a --std=08 ../../examples/Boards2.vhdl

echo run elaboration and simulation, redirect all outputs into a logfile
$GHDL --elab-run --std=08 Boards2 -gC_PROJECT_DIR=../.. > Boards2.log 2>&1

echo Reading logfile ...
echo --------------------------------------------------------------------------------
cat Boards2.log
#more Boards2.log
echo --------------------------------------------------------------------------------
