"""Release metadata, quiet logging, and desktop-picture privacy boundaries."""
from pathlib import Path
import plistlib
import unittest
ROOT=Path(__file__).resolve().parents[1]
SOURCE=(ROOT/'macos/NetWareSnakeView.m').read_text()

class ProductionPolicyTests(unittest.TestCase):
    def test_logging_is_not_per_frame(self):
        self.assertIn('NWLogDiagnostic(_diagnostics,',SOURCE)
        self.assertNotIn('NSLog(',SOURCE)
        self.assertIn('os_log_info(',SOURCE)
        self.assertIn('os_log_error(',SOURCE)
        for marker in ('ANIMATE build=','DRAW_ENTRY build=','CPU_SAMPLE'):
            self.assertNotIn(marker,SOURCE)

    def test_desktop_background_uses_no_screen_or_window_capture(self):
        wallpaper=(ROOT/'macos/NWWallpaperSnapshot.m').read_text()
        self.assertIn('desktopImageURLForScreen:',wallpaper)
        self.assertIn('CGImageSourceCreateThumbnailAtIndex',wallpaper)
        for api in ('CGWindowListCreateImage','CGDisplayCreateImage','SCShareableContent','CGRequestScreenCaptureAccess'):
            self.assertNotIn(api,wallpaper)

    def test_footer_uses_owning_bundle(self):
        sheet=(ROOT/'macos/NWConfigurationController.m').read_text()
        self.assertIn('NSBundle bundleForClass:[NWConfigurationController class]',sheet)
        self.assertIn('CFBundleShortVersionString',sheet)
        self.assertIn('CFBundleVersion',sheet)
        self.assertNotIn('[[NSBundle mainBundle] bundleIdentifier]',sheet)

    def test_release_metadata_and_installer_match(self):
        for name in ('Info.plist','Info.preview.plist'):
            with (ROOT/'macos'/name).open('rb') as file:
                info=plistlib.load(file)
            self.assertEqual(info['CFBundleShortVersionString'],'0.7.0')
            self.assertEqual(info['CFBundleVersion'],'16')
        self.assertIn('0.7.0',(ROOT/'build-macos.sh').read_text())
        self.assertIn('0.7.0',(ROOT/'install-macos.sh').read_text())

if __name__=='__main__':unittest.main()
