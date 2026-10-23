#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
MON42U=${1:?Usage: tools/check-netware4-original.sh /absolute/path/MON42U.NLM}
PYTHON=${PYTHON:-python3}
mkdir -p build/tests
case "$(uname -s)" in
 Darwin) LIB="$PWD/build/tests/libnw4.dylib"; FLAGS='-dynamiclib' ;;
 *) LIB="$PWD/build/tests/libnw4.so"; FLAGS='-shared -fPIC' ;;
esac
cc -std=c11 -Wall -Wextra -Werror -O2 $FLAGS core/nw4_snake.c -o "$LIB"
"$PYTHON" tests/netware4_reference/compare.py "$MON42U" "$LIB" build/tests/netware42-comparison-results.json
"$PYTHON" tests/netware4_reference/worker_test.py "$MON42U" "$LIB"
