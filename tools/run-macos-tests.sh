#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/tests
./tools/run-core-tests.sh
xcrun clang -Wall -Wextra -Werror -fobjc-arc -Imacos tests/native_cpu_reader.m macos/NWCPUReader.m -framework Foundation -o build/tests/cpu-reader
build/tests/cpu-reader
xcrun clang -std=c11 -Wall -Wextra -Werror -g -fsanitize=address,undefined -Icore tools/nw4_stress.c core/nw4_snake.c core/nw4_session.c -o build/tests/nw4-stress
build/tests/nw4-stress
./build-macos.sh
codesign --verify --deep --strict build/NetWareSnake.saver
codesign --verify --deep --strict build/NetWareSnakePreview.app
