"""Regression parity: portable C11 engine against original Python research reference.
Compiles the C source using the host's C compiler; no macOS dependencies.
"""
import ctypes as C
import os
import pathlib
import subprocess
import tempfile
import unittest
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from python_reference import Snake

class CoreParity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        lib = pathlib.Path(cls.temp.name) / ('libnwsnake.dylib' if sys.platform == 'darwin' else 'libnwsnake.so')
        subprocess.run([os.getenv('CC','cc'),'-O2','-std=c11','-fPIC','-shared',
                        '-I',str(ROOT/'core'),str(ROOT/'core'/'nw_snake.c'),'-o',str(lib)],check=True)
        cls.dll=C.CDLL(str(lib))
        defs = {
           'nw_snake_create':([C.c_int,C.c_int,C.c_uint32],C.c_void_p),
           'nw_snake_destroy':([C.c_void_p],None),
           'nw_snake_advance':([C.c_void_p,C.c_int],C.c_uint),
           'nw_snake_frame':([C.c_void_p,C.c_int],C.POINTER(C.c_ubyte)),
           'nw_snake_x':([C.c_void_p],C.c_int),
           'nw_snake_y':([C.c_void_p],C.c_int),
           'nw_snake_heading':([C.c_void_p],C.c_int),
           'nw_snake_phase':([C.c_void_p],C.c_int),
           'nw_snake_seed':([C.c_void_p],C.c_uint32),
           'nw_snake_moves':([C.c_void_p],C.c_uint64),
           'nw_snake_cursor':([C.c_void_p,C.c_int],C.c_int),
           'nw_snake_history_x':([C.c_void_p,C.c_int],C.c_int),
           'nw_snake_history_y':([C.c_void_p,C.c_int],C.c_int),
           'nw_snake_history_direction':([C.c_void_p,C.c_int],C.c_int),
           'nw_snake_load_band':([C.c_int],C.c_int),
           'nw_snake_columns':([C.c_void_p],C.c_int),
           'nw_snake_rows':([C.c_void_p],C.c_int),
        }
        for fn,(args,ret) in defs.items():
            f=getattr(cls.dll,fn);f.argtypes=args;f.restype=ret
    @classmethod
    def tearDownClass(cls): cls.temp.cleanup()

    def test_dimensions(self):
        for dims in [(80,25),(96,25),(176,25),(120,36)]:
            s=self.dll.nw_snake_create(*dims, 2)
            self.assertTrue(s)
            self.assertEqual(self.dll.nw_snake_columns(s), dims[0])
            self.assertEqual(self.dll.nw_snake_rows(s), dims[1])
            for i in range(2000):
                self.dll.nw_snake_advance(s,(i*13)%101)
                self.assertGreaterEqual(self.dll.nw_snake_x(s),0)
                self.assertLessEqual(self.dll.nw_snake_x(s),dims[0]-2)
                self.assertGreaterEqual(self.dll.nw_snake_y(s),0)
                self.assertLess(self.dll.nw_snake_y(s),dims[1])
            self.dll.nw_snake_destroy(s)

    def test_band_boundaries(self):
        for cpu,b in [(0,1),(11,1),(12,2),(22,2),(23,3),(33,3),(34,4),(55,4),(56,5),(100,5)]:
            self.assertEqual(self.dll.nw_snake_load_band(cpu), b)


    def test_protected_projection_matches_research_reference(self):
        from python_session_reference import SnakeSession
        for seed in (0,1,42,0x12345678):
            reference=SnakeSession(seed)
            s=self.dll.nw_snake_create(80,25,seed)
            try:
                for i in range(1200):
                    cpu=[0,17,28,44,75,44,28,17,5][(i//31+seed)%9]
                    reference.advance(cpu)
                    self.dll.nw_snake_advance(s,cpu)
                    self.assertEqual(list(self.dll.nw_snake_frame(s,1)[:2000]),reference.enhanced_screen,
                                     (seed,i,cpu))
            finally:self.dll.nw_snake_destroy(s)

    def test_full_parity_across_64_seeds_and_41600_steps(self):
        for seed in range(64):
            py=Snake(seed=seed)
            ptr=self.dll.nw_snake_create(80,25,seed)
            self.assertTrue(ptr)
            try:
                for t in range(650):
                    load = [0,5,11,12,17,22,23,28,33,34,44,55,56,75,100,75,44,28,17,5][(t//29+seed)%20]
                    py.update(load)
                    self.dll.nw_snake_advance(ptr,load)
                    context=(seed,t,load)
                    self.assertEqual(list(self.dll.nw_snake_frame(ptr,0)[:2000]),py.screen,context)
                    self.assertEqual((self.dll.nw_snake_x(ptr),self.dll.nw_snake_y(ptr)),(py.x,py.y),context)
                    self.assertEqual(self.dll.nw_snake_heading(ptr),py.heading,context)
                    self.assertEqual(self.dll.nw_snake_phase(ptr),py.phase,context)
                    self.assertEqual(self.dll.nw_snake_seed(ptr),py.seed,context)
                    self.assertEqual(self.dll.nw_snake_moves(ptr),py.moves,context)
                    self.assertEqual([self.dll.nw_snake_cursor(ptr,i) for i in range(5)],py.cursors,context)
                    self.assertEqual([self.dll.nw_snake_history_x(ptr,i) for i in range(51)],py.xs,context)
                    self.assertEqual([self.dll.nw_snake_history_y(ptr,i) for i in range(51)],py.ys,context)
                    self.assertEqual([self.dll.nw_snake_history_direction(ptr,i) for i in range(51)],py.directions,context)
            finally:self.dll.nw_snake_destroy(ptr)


class GeometryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        lib = pathlib.Path(cls.temp.name)/('libgeometry.dylib' if sys.platform=='darwin' else 'libgeometry.so')
        subprocess.run([os.getenv('CC','cc'),'-O2','-std=c11','-fPIC','-shared',
                        str(ROOT/'core'/'nw_geometry.c'),'-o',str(lib),'-lm'],check=True)
        cls.dll=C.CDLL(str(lib))
        cls.dll.nw_grid_for_view.argtypes=[C.c_double,C.c_double,C.c_int,C.c_int,C.c_int,C.POINTER(C.c_int),C.POINTER(C.c_int)]
        cls.dll.nw_grid_metrics.argtypes=[C.c_double,C.c_double,C.c_int,C.c_int,C.POINTER(C.c_double),C.POINTER(C.c_double),C.POINTER(C.c_double),C.POINTER(C.c_double)]
        cls.dll.nw_grid_metrics_for_mode.argtypes=[C.c_double,C.c_double,C.c_int,C.c_int,C.c_int,C.POINTER(C.c_double),C.POINTER(C.c_double),C.POINTER(C.c_double),C.POINTER(C.c_double)]
    @classmethod
    def tearDownClass(cls):cls.temp.cleanup()
    def geometry(self,w,h,faithful,wide,size):
        c=C.c_int();r=C.c_int()
        self.dll.nw_grid_for_view(w,h,faithful,wide,size,C.byref(c),C.byref(r))
        return c.value,r.value
    def test_faithful_fixed_across_aspect_ratios(self):
        for w,h in [(1920,1080),(3440,1440),(1024,768),(800,600),(100,100)]:
            self.assertEqual(self.geometry(w,h,1,1,0),(80,25))
    def test_widescreen_adds_columns(self):
        self.assertEqual(self.geometry(1920,1080,0,1,1),(88,25))
        self.assertEqual(self.geometry(3440,1440,0,1,1),(119,25))
        self.assertEqual(self.geometry(5120,1440,0,1,1),(177,25))
        self.assertEqual(self.geometry(1920,1080,0,0,1),(80,25))
    def metrics_for_mode(self,width,height,faithful):
        cw=C.c_double();ch=C.c_double();x=C.c_double();y=C.c_double()
        self.dll.nw_grid_metrics_for_mode(width,height,80,25,int(faithful),
                                         C.byref(cw),C.byref(ch),C.byref(x),C.byref(y))
        return cw.value,ch.value,x.value,y.value

    def test_faithful_vga_canvas_has_original_grid_and_4_3_bed(self):
        # The virtual canvas is 640x480, the 80x25 raster is 640x400,
        # centered with 40 blank scanlines on the top and bottom.
        for width,height in [(640,480),(1920,1080),(3440,1440),
                             (5120,1440),(1024,768),(900,1600),(320,180)]:
            cw,ch,x,y=self.metrics_for_mode(width,height,True)
            scale=min(width/640.0,height/480.0)
            self.assertAlmostEqual(cw,8*scale)
            self.assertAlmostEqual(ch,16*scale)
            self.assertAlmostEqual(x,(width-640*scale)/2)
            self.assertAlmostEqual(y,(height-480*scale)/2+40*scale)
            # 4:3 virtual viewport (including 40 scanline margins)
            self.assertAlmostEqual((80*cw)/(30*ch),4/3)
            self.assertAlmostEqual(x+80*cw/2,width/2)
            self.assertAlmostEqual(y+25*ch/2,height/2)
            self.assertLessEqual(x+80*cw,width+1e-6)
            self.assertLessEqual(y+25*ch,height+1e-6)

    def test_customizable_geometry_not_changed(self):
        w,h,x,y=self.metrics_for_mode(1920,1080,False)
        self.assertAlmostEqual(w,21.6)
        self.assertAlmostEqual(h,43.2)
        self.assertAlmostEqual(x,96)
        self.assertAlmostEqual(y,0)

    def test_cells_have_original_aspect(self):
        w=C.c_double();h=C.c_double();x=C.c_double();y=C.c_double()
        self.dll.nw_grid_metrics(1920,1080,80,25,C.byref(w),C.byref(h),C.byref(x),C.byref(y))
        self.assertAlmostEqual(2*w.value,h.value)
        self.assertGreaterEqual(x.value,0);self.assertGreaterEqual(y.value,0)
        self.assertLessEqual(x.value+80*w.value,1920.00001)
        self.assertLessEqual(y.value+25*h.value,1080.00001)

if __name__=='__main__': unittest.main()
