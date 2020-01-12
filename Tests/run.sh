#!/usr/bin/env sh

cd $(dirname $0)

if [ "$#" -le 1 ]; then
  echo "Two argument are required, at least!"
  exit 1
fi

cdir="$1"
shift

docker run --rm -t \
  -v /$(pwd)/../://work \
  -w //work/Tests/"$cdir" \
  -e VUNIT_SIMULATOR=ghdl \
  ghdl/vunit:llvm-master "$@"
