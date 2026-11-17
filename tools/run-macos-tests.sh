#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/tests
# Discovery includes portable parity, geometry and desktop-domain tests.
./tools/run-core-tests.sh
xcrun clang -Wall -Wextra -Werror -fobjc-arc -Imacos tests/native_cpu_reader.m macos/NWCPUReader.m -framework Foundation -o build/tests/cpu-reader
build/tests/cpu-reader
xcrun clang -Wall -Wextra -Werror -fobjc-arc -Imacos tests/native_settings.m macos/NWSettings.m -framework Foundation -o build/tests/settings
build/tests/settings
xcrun clang -Wall -Wextra -Werror -fobjc-arc -Imacos tests/native_wallpaper.m macos/NWWallpaperSnapshot.m -framework Cocoa -framework ImageIO -o build/tests/wallpaper
build/tests/wallpaper
xcrun clang -Wall -Wextra -Werror -fobjc-arc -Imacos tests/native_configuration.m macos/NWConfigurationController.m macos/NWSettings.m -framework Cocoa -framework ScreenSaver -o build/tests/configuration
# No output path: validate all native actions without requiring a screenshot.
build/tests/configuration
xcrun clang -std=c11 -Wall -Wextra -Werror -g -fsanitize=address,undefined -fno-omit-frame-pointer -Icore tools/desktop_stress.c core/nw_snake.c core/nw_desktop.c -lm -o build/tests/desktop-stress
build/tests/desktop-stress
xcrun clang -std=c11 -Wall -Wextra -Werror -g -fsanitize=address,undefined -Icore tools/nw4_stress.c core/nw4_snake.c core/nw4_session.c -o build/tests/nw4-stress
build/tests/nw4-stress
xcrun clang -std=c11 -Wall -Wextra -Werror -g -fsanitize=address,undefined -Icore tools/nw4_enhanced_stress.c core/nw4_snake.c -o build/tests/nw4-enhanced
build/tests/nw4-enhanced
xcrun clang -Wall -Wextra -Werror -fobjc-arc -Imacos -Icore tests/native_modern.m macos/NWModernSession.m macos/NWSettings.m core/nw4_snake.c core/nw4_session.c core/nw_desktop.c -framework Cocoa -framework IOKit -o build/tests/modern
build/tests/modern
# Build first: native_view links the exact production view/session objects.
./build-macos.sh
xcrun clang -Wall -Wextra -Werror -mmacosx-version-min=13.0 -fobjc-arc -Imacos -Icore tests/native_view.m \
    build/obj/NWModernSession.o build/obj/NetWareSnakeView.o build/obj/NWCPUReader.o build/obj/NWSettings.o \
    build/obj/NWConfigurationController.o build/obj/NWWallpaperSnapshot.o build/obj/NWUnifiedDesktopSession.o \
    build/obj/nw_snake.o build/obj/nw_desktop.o build/obj/nw_geometry.o \
    build/obj/nw4_snake.o build/obj/nw4_session.o \
    -framework Cocoa -framework ScreenSaver -framework QuartzCore -framework ImageIO -framework IOKit -lm -o build/tests/view
build/tests/view
codesign --verify --deep --strict build/NetWareSnake.saver
codesign --verify --deep --strict build/NetWareSnakePreview.app
printf '%s\n' 'macOS automated checks PASS: portable tests, native settings/wallpaper/configuration/view, sanitizer stress, bundles and signatures'
