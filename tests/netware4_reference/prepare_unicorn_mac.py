"""Optional local workaround for a restricted Apple Silicon host.

Unicorn 2.1.4's cache-size sysctl can be denied in a sandbox. Its fallback
CTR_EL0 read then traps. Substitute a conservative 64-byte cache-maintenance
stride in a COPY of this exact wheel library. No guest x86 instruction or
operating-system setting is changed. This is unnecessary on normal hosts.
"""
from pathlib import Path
import hashlib,subprocess,sys
src=Path(sys.argv[1]);out=Path(sys.argv[2]);b=bytearray(src.read_bytes())
expected='7207c8e3d7a63118fb0bca73e01816797fd51b1d8a39a4cbc7abfd562ee59c85'
if hashlib.sha256(b).hexdigest()!=expected:raise SystemExit('Different library build; refusing offset patch')
o=0x10c78
assert b[o:o+4]==bytes.fromhex('28003bd5')  # mrs x8, CTR_EL0
b[o:o+4]=bytes.fromhex('880080d2')           # mov x8,#4; existing code computes 4<<4
out.mkdir(parents=True,exist_ok=True);dest=out/'libunicorn.2.dylib';dest.write_bytes(b)
subprocess.run(['codesign','--force','--sign','-',str(dest)],check=True)
print('Use LIBUNICORN_PATH='+str(out.resolve()))
