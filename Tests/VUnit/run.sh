#!/bin/sh

cd $(dirname $0)

$(command -v winpty) docker run --rm -it \
  -v /$(cd $(pwd)/.. && pwd)://work \
  -w //work \
  ghdl/ext:vunit-master bash -c "cd ./VUnit && VUNIT_SIMULATOR=ghdl python3 run.py -v"
