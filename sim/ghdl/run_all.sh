#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
mkdir -p build

ghdl -a --std=93c --workdir=build $(cat sim/filelist.f)

if [ $# -eq 0 ]; then
    set -- $(cat sim/tb_list.txt)
fi

for tb in "$@"; do
    echo "=== Running $tb ==="
    ghdl -e --std=93c --workdir=build "$tb"
    ghdl -r --std=93c --workdir=build "$tb" --vcd="build/${tb}.vcd"
done