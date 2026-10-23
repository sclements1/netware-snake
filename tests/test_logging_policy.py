"""Static checks for quiet logging, release metadata and product scope."""
from pathlib import Path
import plistlib
import unittest
ROOT=Path(__file__).resolve().parents[1]
SOURCE=(ROOT/'macos/NetWareSnakeView.m').read_text()

class ProductionPolicyTests(unittest.TestCase):
    def test_diagnostics_opt_in_and_not_per_frame(self):
        self.assertIn('@"diagnostics":@NO',SOURCE)
        self.assertIn('NWLogDiagnostic(_diagnostics,',SOURCE)
        self.assertNotIn('NSLog(',SOURCE)
        self.assertIn('os_log_info(',SOURCE)
        self.assertIn('os_log_error(',SOURCE)
        self.assertNotIn('ANIMATE build=',SOURCE)
        self.assertNotIn('DRAW_ENTRY build=',SOURCE)

    def test_troubleshooting_is_independent_of_mode(self):
        self.assertIn('BOOL diagnostics=[_defaults boolForKey:@"diagnostics"];',SOURCE)
        self.assertIn('[_defaults setBool:_diagnosticsBox.state==NSControlStateValueOn forKey:@"diagnostics"]',SOURCE)
        self.assertNotIn('[_diagnosticsBox setEnabled:editable]',SOURCE)

    def test_wallpaper_feature_entirely_removed(self):
        self.assertNotIn('wallpaper',SOURCE.lower())
        self.assertNotIn('nw_eat',SOURCE)
        self.assertNotIn('desktopimage',SOURCE.lower())
        self.assertFalse((ROOT/'core/nw_eat.c').exists())
        self.assertFalse((ROOT/'core/nw_eat.h').exists())
        build=(ROOT/'build-macos.sh').read_text()
        self.assertNotIn('nw_eat',build)
        self.assertNotIn('ImageIO',build)

    def test_faithful_is_fixed_and_vga_proportioned(self):
        self.assertIn('mode!=1,widescreen,size,&columns,&rows',SOURCE)
        self.assertIn('nw_grid_metrics_for_mode(',SOURCE)
        self.assertIn('_mode!=1,&cw,&ch,&ox,&oy',SOURCE)
        self.assertIn('double speed=mode==1?',SOURCE)
        self.assertIn('BOOL widescreen=mode==1',SOURCE)
        self.assertIn('BOOL demo=mode==1',SOURCE)
        self.assertIn('BOOL overlap=mode==1',SOURCE)
        self.assertIn('if (customizable) {',SOURCE)
        self.assertIn('if (!editable) [_wideBox setState:NSControlStateValueOff]',SOURCE)

    def test_version_footer_loaded_from_bundle_not_host(self):
        self.assertIn('NSBundle bundleForClass:[NetWareSnakeView class]',SOURCE)
        self.assertIn('CFBundleShortVersionString',SOURCE)
        self.assertIn('CFBundleVersion',SOURCE)
        self.assertIn('NetWare Snake v%@ · build %@',SOURCE)
        self.assertNotIn('[[NSBundle mainBundle] bundleIdentifier]',SOURCE)

    def test_build_and_install_version(self):
        for name in ('Info.plist','Info.preview.plist'):
            with (ROOT/'macos'/name).open('rb') as file:
                info=plistlib.load(file)
            self.assertEqual(info['CFBundleShortVersionString'],'0.4.0')
            self.assertEqual(info['CFBundleVersion'],'13')
        self.assertIn('0.4.0',(ROOT/'build-macos.sh').read_text())
        self.assertIn('0.4.0',(ROOT/'install-macos.sh').read_text())

if __name__=='__main__': unittest.main()
