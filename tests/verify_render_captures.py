"""Reject missing, truncated, duplicate or flat gameplay captures; stdlib only."""
import hashlib
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
NAMES = ('coast-day', 'harbor-day', 'canyon-day', 'airfield-day', 'coast-night', 'world-map')
hashes = set()
for name in NAMES:
    path = ROOT / 'docs/screenshots/gameplay' / (name + '.png')
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', f'{name}: invalid PNG'
    assert struct.unpack('>II', data[16:24]) == (1920, 1080), f'{name}: wrong dimensions'
    offset, compressed, ended = 8, bytearray(), False
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset+4])[0]
        kind = data[offset+4:offset+8]
        payload = data[offset+8:offset+8+length]
        crc = struct.unpack('>I', data[offset+8+length:offset+12+length])[0]
        assert zlib.crc32(kind + payload) == crc, f'{name}: damaged PNG chunk'
        if kind == b'IDAT':
            compressed.extend(payload)
        if kind == b'IEND':
            ended = True
        offset += length + 12
    assert ended, f'{name}: truncated PNG'
    pixels = zlib.decompress(compressed)
    assert len(set(pixels)) > 32, f'{name}: blank or flat image'
    digest = hashlib.sha256(pixels).digest()
    assert digest not in hashes, f'{name}: duplicate screenshot'
    hashes.add(digest)
    print(f'PASS {name}: 1920x1080, intact, distinct PNG')
assert len(hashes) == 6
