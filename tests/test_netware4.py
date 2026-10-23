"""4.2 host policy and scheduler, checked against the verified low-level engine."""
import ctypes as C
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

class NetWare4Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp=tempfile.TemporaryDirectory()
        path=Path(cls.tmp.name)/'nw4.dylib'
        subprocess.run(['cc','-std=c11','-Wall','-Wextra','-Werror','-shared','-fPIC',
                        str(ROOT/'core/nw4_snake.c'),str(ROOT/'core/nw4_session.c'),'-o',str(path)],check=True)
        cls.lib=C.CDLL(str(path)); l=cls.lib
        for name in ['nw4_create','nw4_session_create']:
            getattr(l,name).restype=C.c_void_p
        signatures={
          'nw4_destroy':([C.c_void_p],None),
          'nw4_session_destroy':([C.c_void_p],None),
          'nw4_processor_count':([C.c_uint,C.c_int],C.c_uint),
          'nw4_session_start':([C.c_void_p,C.c_uint,C.c_int],C.c_int),
          'nw4_activate':([C.c_void_p,C.c_uint],C.c_int),
          'nw4_tick':([C.c_void_p,C.c_uint,C.c_uint,C.c_void_p,C.c_void_p],C.c_int),
          'nw4_session_tick':([C.c_void_p,C.POINTER(C.c_uint),C.c_uint],C.c_int),
          'nw4_session_processors':([C.c_void_p],C.c_uint),
          'nw4_session_intervals':([C.c_void_p],C.c_uint64),
          'nw4_slot_lead':([C.c_uint],C.c_uint),
          'nw4_random_state':([C.c_void_p,C.POINTER(C.c_ubyte)],None),
        }
        for prefix in ['nw4','nw4_session']:
            for plane in ['characters','attributes']:
                signatures[f'{prefix}_{plane}']=([C.c_void_p],C.c_void_p)
        for name,(args,result) in signatures.items():
            fn=getattr(l,name);fn.argtypes=args;fn.restype=result
    @classmethod
    def tearDownClass(cls):cls.tmp.cleanup()
    def setUp(self):
        self.session=self.lib.nw4_session_create();self.world=self.lib.nw4_create()
        self.assertTrue(self.session);self.assertTrue(self.world)
    def tearDown(self):
        self.lib.nw4_session_destroy(self.session);self.lib.nw4_destroy(self.world)
    def frame(self,obj,prefix):
        return tuple(C.string_at(getattr(self.lib,f'{prefix}_{p}')(obj),2000)
                     for p in ['characters','attributes'])
    def test_processor_limits(self):
        for host in [0,1,2,16,30,31,32,64,128,1024]:
            for allow in [0,1]:
                expected=min(host or 1,32 if allow else 31)
                self.assertEqual(self.lib.nw4_processor_count(host,allow),expected)
                self.assertEqual(self.lib.nw4_session_start(self.session,host,allow),1)
                self.assertEqual(self.lib.nw4_session_processors(self.session),expected)
    def test_all_32_origins_stagger_and_palette(self):
        palette=[12,9,10,11,13,7,4,1,2,3,6,14,5,8,15]
        self.lib.nw4_session_start(self.session,32,1)
        self.assertEqual(self.frame(self.session,'nw4_session')[0],b' '*2000)
        for tick in range(125):
            self.lib.nw4_session_tick(self.session,None,0)
            if tick%4==0:
                p=tick//4;chars,attrs=self.frame(self.session,'nw4_session')
                self.assertEqual(chars[12*80+38:12*80+40],b'\xdb\xdb')
                self.assertEqual(attrs[12*80+38:12*80+40],bytes([palette[p%15]])*2)
        self.assertEqual(self.lib.nw4_session_intervals(self.session),125)
    def test_scheduler_per_cpu_loads_clamps_and_shared_writes(self):
        # Compare both frame planes after EVERY interval, including crossings,
        # band boundaries, missing per-CPU samples and CPU 31's delayed start.
        for host,allow in [(1,0),(8,0),(32,0),(32,1)]:
            count=self.lib.nw4_processor_count(host,allow)
            self.lib.nw4_session_start(self.session,host,allow)
            self.lib.nw4_activate(self.world,count)
            for tick in range(700):
                bands=[0,11,12,22,23,33,34,55,56,100,101,999]
                values=[bands[(p+tick//13)%len(bands)] for p in range(32)]
                n=0 if tick%31==0 else (3 if tick%19==0 else 32)
                loads=(C.c_uint*32)(*values)
                before=self.frame(self.session,'nw4_session')
                changed=self.lib.nw4_session_tick(self.session,loads,n)
                for p in range(count):
                    if tick>=4*p:
                        self.lib.nw4_tick(self.world,p,min(100,values[p]) if p<n else 0,None,None)
                actual=self.frame(self.session,'nw4_session')
                self.assertEqual(actual,self.frame(self.world,'nw4'))
                self.assertEqual(bool(changed),before!=actual)
    def test_activation_clears_world_preserves_rng_and_resets_palette(self):
        self.lib.nw4_activate(self.world,32)
        rng=(C.c_ubyte*118)();self.lib.nw4_random_state(self.world,rng);before=bytes(rng)
        self.lib.nw4_tick(self.world,31,100,None,None)
        self.lib.nw4_activate(self.world,1)
        chars,attrs=self.frame(self.world,'nw4')
        self.assertEqual(chars,b' '*2000);self.assertEqual(attrs,b'\0'*2000)
        self.lib.nw4_random_state(self.world,rng)
        fresh=self.lib.nw4_create()
        try:
            self.lib.nw4_activate(fresh,1)
            fresh_rng=(C.c_ubyte*118)();self.lib.nw4_random_state(fresh,fresh_rng)
            self.assertNotEqual(bytes(rng),bytes(fresh_rng))
            self.assertNotEqual(bytes(rng),before)
        finally:self.lib.nw4_destroy(fresh)
        self.assertEqual(self.lib.nw4_tick(self.world,31,100,None,None),0)
        self.lib.nw4_tick(self.world,0,0,None,None)
        self.assertEqual(self.frame(self.world,'nw4')[1][998],12)
    def test_load_band_boundaries(self):
        expected=[10]*12+[5]*11+[3]*11+[2]*22+[1]*45
        self.assertEqual([self.lib.nw4_slot_lead(u) for u in range(101)],expected)
    def test_invalid_calls(self):
        self.assertEqual(self.lib.nw4_activate(self.world,0),0)
        self.assertEqual(self.lib.nw4_activate(self.world,33),0)
        self.assertEqual(self.lib.nw4_session_tick(self.session,None,0),0)
        self.lib.nw4_activate(self.world,1)
        before=self.frame(self.world,'nw4')
        self.assertEqual(self.lib.nw4_tick(self.world,32,0,None,None),0)
        self.assertEqual(self.lib.nw4_tick(self.world,0,101,None,None),0)
        self.assertEqual(self.frame(self.world,'nw4'),before)

if __name__=='__main__':unittest.main()
