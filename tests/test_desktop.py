"""Portable desktop-union geometry, traversal and persistent eaten-cell tests."""
import ctypes as C
import math
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class Rect(C.Structure):
    _fields_ = [('x',C.c_double),('y',C.c_double),('width',C.c_double),('height',C.c_double)]


class Layout(C.Structure):
    _fields_ = [('bounds',Rect),('origin_x',C.c_double),('origin_y',C.c_double),
                ('cell_width',C.c_double),('cell_height',C.c_double),
                ('columns',C.c_int),('rows',C.c_int),('domain',C.POINTER(C.c_uint8))]


class DesktopTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        path = pathlib.Path(cls.temp.name)/('desktop.dylib' if sys.platform=='darwin' else 'desktop.so')
        subprocess.run([os.getenv('CC','cc'),'-std=c11','-Wall','-Wextra','-Werror','-O2','-fPIC','-shared',
                        str(ROOT/'core/nw_snake.c'),str(ROOT/'core/nw_desktop.c'),'-lm','-o',str(path)],check=True)
        cls.lib = C.CDLL(str(path))
        definitions = {
            'nw_desktop_build':([C.POINTER(Rect),C.c_size_t,C.c_double,C.c_int,C.POINTER(Layout)],C.c_int),
            'nw_desktop_dispose':([C.POINTER(Layout)],None),
            'nw_snake_create':([C.c_int,C.c_int,C.c_uint32],C.c_void_p),
            'nw_snake_destroy':([C.c_void_p],None),
            'nw_snake_reset':([C.c_void_p,C.c_uint32],None),
            'nw_snake_recenter':([C.c_void_p],C.c_int),
            'nw_snake_set_domain':([C.c_void_p,C.POINTER(C.c_uint8),C.c_size_t],C.c_int),
            'nw_snake_visited':([C.c_void_p],C.POINTER(C.c_uint8)),
            'nw_snake_frame':([C.c_void_p,C.c_int],C.POINTER(C.c_uint8)),
            'nw_snake_advance':([C.c_void_p,C.c_int],C.c_uint),
            'nw_snake_x':([C.c_void_p],C.c_int),'nw_snake_y':([C.c_void_p],C.c_int),
            'nw_snake_moves':([C.c_void_p],C.c_uint64),'nw_snake_passes':([C.c_void_p],C.c_uint64),
            'nw_snake_seed':([C.c_void_p],C.c_uint32),
        }
        for name,(arguments,result) in definitions.items():
            f=getattr(cls.lib,name);f.argtypes=arguments;f.restype=result

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def layout(self,rectangles,reference=500,size=1):
        rects=(Rect*len(rectangles))(*(Rect(*r) for r in rectangles))
        result=Layout()
        self.assertEqual(self.lib.nw_desktop_build(rects,len(rects),reference,size,C.byref(result)),1)
        self.addCleanup(self.lib.nw_desktop_dispose,C.byref(result))
        return result

    def snake(self,columns=80,rows=25,seed=42):
        result=self.lib.nw_snake_create(columns,rows,seed)
        self.assertTrue(result)
        self.addCleanup(self.lib.nw_snake_destroy,result)
        return result

    def position(self,s):
        return self.lib.nw_snake_x(s),self.lib.nw_snake_y(s)

    def test_sizes_aspect_and_reference_height(self):
        for size,rows in ((0,34),(1,25),(2,18)):
            with self.subTest(size=size):
                grid=self.layout([(0,0,1000,500)],size=size)
                self.assertEqual((grid.columns,grid.rows),(rows*4,rows))
                self.assertAlmostEqual(grid.cell_height,500/rows)
                self.assertAlmostEqual(grid.cell_width*2,grid.cell_height)
                self.assertAlmostEqual(grid.origin_x,0)
                self.assertAlmostEqual(grid.origin_y,0)
                self.assertTrue(all(grid.domain[:grid.columns*grid.rows]))

    def test_negative_staggered_union_has_holes_and_one_cell_scale(self):
        rects=[(-1000,-500,1000,500),(0,-250,1000,500)]
        grid=self.layout(rects)
        self.assertEqual((grid.bounds.x,grid.bounds.y,grid.bounds.width,grid.bounds.height),(-1000,-500,2000,750))
        self.assertEqual((grid.columns,grid.rows),(200,37))
        self.assertEqual((grid.cell_width,grid.cell_height),(10,20))
        self.assertEqual((grid.origin_x,grid.origin_y),(-1000,-495))
        for y in range(grid.rows):
            for x in range(grid.columns):
                px=grid.origin_x+(x+.5)*grid.cell_width
                py=grid.origin_y+(y+.5)*grid.cell_height
                expected=any(a<=px<a+w and b<=py<b+h for a,b,w,h in rects)
                self.assertEqual(bool(grid.domain[y*grid.columns+x]),expected)
        self.assertEqual(grid.domain[100],0)  # upper-right hole
        self.assertEqual(grid.domain[(grid.rows-1)*grid.columns],0)  # lower-left hole
        self.assertEqual(grid.domain[20*grid.columns+99],1)
        self.assertEqual(grid.domain[20*grid.columns+100],1)

    def test_crosses_horizontal_and_vertical_display_seams(self):
        for rectangles,axis in (([(0,0,1000,500),(1000,0,1000,500)],0),
                                ([(0,0,1000,500),(0,500,1000,500)],1)):
            grid=self.layout(rectangles)
            s=self.snake(grid.columns,grid.rows)
            self.assertEqual(self.lib.nw_snake_set_domain(s,grid.domain,grid.columns*grid.rows),1)
            visited_axes=set()
            for _ in range(1600):
                self.lib.nw_snake_advance(s,100)
                x,y=self.position(s)
                self.assertTrue(grid.domain[y*grid.columns+x] and grid.domain[y*grid.columns+x+1])
                point=(grid.origin_x+(x+1)*grid.cell_width,grid.origin_y+(y+.5)*grid.cell_height)
                seam=1000 if axis==0 else 500
                visited_axes.add(point[axis]>=seam)
            self.assertEqual(visited_axes,{False,True})

    def test_mask_is_copied_and_neither_head_nor_frame_enters_holes(self):
        grid=self.layout([(-1000,-500,1000,500),(0,-250,1000,500)])
        n=grid.columns*grid.rows
        original=bytes(grid.domain[:n])
        s=self.snake(grid.columns,grid.rows)
        self.assertEqual(self.lib.nw_snake_set_domain(s,grid.domain,n),1)
        for i in range(n):grid.domain[i]=0
        for _ in range(1800):
            self.lib.nw_snake_advance(s,100)
            x,y=self.position(s)
            self.assertTrue(original[y*grid.columns+x] and original[y*grid.columns+x+1])
        self.assertGreater(self.lib.nw_snake_moves(s),100)
        for protected in (0,1):
            frame=self.lib.nw_snake_frame(s,protected)
            self.assertTrue(all(frame[i]==32 for i in range(n) if not original[i]))
        visited=self.lib.nw_snake_visited(s)
        self.assertTrue(all(not visited[i] for i in range(n) if not original[i]))

    def test_visited_persists_after_tail_and_protected_projection(self):
        s=self.snake()
        self.assertEqual(self.position(s),(38,12))  # historical default unchanged
        self.assertFalse(any(self.lib.nw_snake_visited(s)[:2000]))
        first=self.lib.nw_snake_advance(s,100)
        self.assertTrue(first & 8)
        visited=bytes(self.lib.nw_snake_visited(s)[:2000])
        self.assertEqual(sum(visited),2)
        self.assertEqual(visited[12*80+38:12*80+40],b'\x01\x01')
        for _ in range(450):
            self.lib.nw_snake_advance(s,100)
            current=bytes(self.lib.nw_snake_visited(s)[:2000])
            self.assertTrue(all(not a or b for a,b in zip(visited,current)))
            visited=current
            self.lib.nw_snake_frame(s,1)
            self.lib.nw_snake_frame(s,0)
            self.assertEqual(bytes(self.lib.nw_snake_visited(s)[:2000]),visited)
        frame=bytes(self.lib.nw_snake_frame(s,0)[:2000])
        self.assertTrue(any(v and g==32 for v,g in zip(visited,frame)))
        self.lib.nw_snake_reset(s,19)
        self.assertEqual(self.position(s),(38,12))
        self.assertFalse(any(self.lib.nw_snake_visited(s)[:2000]))
        self.assertEqual(self.lib.nw_snake_passes(s),0)

    def test_domain_center_reset_and_invalid_changes_preserve_state(self):
        s=self.snake(120,40)
        self.assertEqual(self.lib.nw_snake_recenter(s),1)
        self.assertEqual(self.position(s),(59,19))
        n=120*40
        mask=(C.c_uint8*n)()
        # Center is in a hole; the nearest valid pair must be selected.
        mask[19*120+80]=mask[19*120+81]=1
        self.assertEqual(self.lib.nw_snake_set_domain(s,mask,n),1)
        self.assertEqual(self.position(s),(80,19))
        self.lib.nw_snake_advance(s,100)
        state=(self.position(s),self.lib.nw_snake_seed(s),self.lib.nw_snake_passes(s),
               bytes(self.lib.nw_snake_visited(s)[:n]),bytes(self.lib.nw_snake_frame(s,0)[:n]))
        empty=(C.c_uint8*n)()
        for bad,length in ((mask,n-1),(empty,n),(None,1)):
            self.assertEqual(self.lib.nw_snake_set_domain(s,bad,length),0)
            self.assertEqual((self.position(s),self.lib.nw_snake_seed(s),self.lib.nw_snake_passes(s),
                              bytes(self.lib.nw_snake_visited(s)[:n]),bytes(self.lib.nw_snake_frame(s,0)[:n])),state)
        self.lib.nw_snake_reset(s,5)
        self.assertEqual(self.position(s),(80,19))
        self.assertFalse(any(self.lib.nw_snake_visited(s)[:n]))
        self.assertEqual(self.lib.nw_snake_set_domain(s,None,0),1)
        self.assertEqual(self.position(s),(59,19))

    def test_isolated_pair_does_not_spin_move_or_escape(self):
        s=self.snake()
        mask=(C.c_uint8*2000)()
        mask[5*80+10]=mask[5*80+11]=1
        self.assertEqual(self.lib.nw_snake_set_domain(s,mask,2000),1)
        for _ in range(1000):
            self.lib.nw_snake_advance(s,100)
            self.assertEqual(self.position(s),(10,5))
        self.assertEqual(self.lib.nw_snake_moves(s),0)
        self.assertEqual(sum(self.lib.nw_snake_visited(s)[:2000]),2)
        self.assertEqual(self.lib.nw_snake_frame(s,0)[5*80+10],219)

    def test_layout_rejects_invalid_without_mutation_and_caps_large_grid(self):
        result=Layout();result.columns=123
        for rect in ((0,0,0,50),(0,0,50,-1),(math.nan,0,50,50),
                     (0,0,math.inf,50),(0,0,1e9,1)):
            a=(Rect*1)(Rect(*rect))
            self.assertEqual(self.lib.nw_desktop_build(a,1,500,1,C.byref(result)),0)
            self.assertEqual(result.columns,123)
        a=(Rect*1)(Rect(0,0,1000,500))
        self.assertEqual(self.lib.nw_desktop_build(a,1,0,1,C.byref(result)),0)
        self.assertEqual(self.lib.nw_desktop_build(a,1,500,3,C.byref(result)),0)
        grid=self.layout([(0,0,1000000,10000)],reference=10000)
        self.assertEqual(grid.columns,4096)
        self.assertGreaterEqual(grid.rows,14)
        self.assertLessEqual(grid.rows,2048)
        self.assertAlmostEqual(grid.cell_width*2,grid.cell_height)
        wide=self.snake(4096,14)
        self.assertEqual(self.lib.nw_snake_recenter(wide),1)
        self.assertEqual(self.position(wide),(2047,6))


if __name__=='__main__':
    unittest.main()
