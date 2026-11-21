"""Transport APK signatures without making the private signing key available to CI."""
import base64
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile
import zlib


def sha(data):
    return hashlib.sha256(data).hexdigest()


def entries(path, data):
    out = {}
    with zipfile.ZipFile(path) as apk:
        for info in apk.infolist():
            ofs = info.header_offset
            assert data[ofs:ofs+4] == b"PK\x03\x04"
            name_length, extra_length = struct.unpack_from("<HH", data, ofs+26)
            out[info.filename] = (ofs+30+name_length+extra_length, info.compress_size)
    return out


def literal(data):
    return base64.b64encode(zlib.compress(data, 9)).decode("ascii")


def make(src, signed, out):
    a, b = src.read_bytes(), signed.read_bytes()
    ae, be = entries(src, a), entries(signed, b)
    ops, pos, copied = [], 0, 0
    for name, (start, length) in sorted(be.items(), key=lambda entry: entry[1][0]):
        if name not in ae or length < 128:
            continue
        offset, base_length = ae[name]
        if base_length != length or a[offset:offset+length] != b[start:start+length]:
            continue
        if start > pos:
            ops.append(literal(b[pos:start]))
        ops.append([offset, length])
        pos = start+length
        copied += length
    if pos < len(b):
        ops.append(literal(b[pos:]))
    assert copied > len(b) * .95, "Input must be the matching aligned, unsigned APK"
    manifest = dict(format=1, source=sha(a), signed=sha(b), size=len(b), ops=ops)
    payload = json.dumps(manifest, separators=(",", ":")).encode()
    out.write_text(literal(payload)+"\n", encoding="ascii")


def apply(src, delta, out):
    a = src.read_bytes()
    data = json.loads(zlib.decompress(base64.b64decode(delta.read_text(encoding="ascii"))))
    assert data["format"] == 1 and data["source"] == sha(a)
    assert 0 < data["size"] < 100_000_000
    b = bytearray()
    for op in data["ops"]:
        if isinstance(op, list):
            offset, length = op
            assert 0 <= offset < len(a) and 0 < length <= len(a)-offset
            b.extend(a[offset:offset+length])
        else:
            b.extend(zlib.decompress(base64.b64decode(op)))
        assert len(b) <= data["size"]
    assert len(b) == data["size"] and data["signed"] == sha(b)
    out.write_bytes(b)


if __name__ == "__main__":
    command, *paths = sys.argv[1:]
    {"make": make, "apply": apply}[command](*map(Path, paths))
