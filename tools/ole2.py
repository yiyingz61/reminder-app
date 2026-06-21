#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""最小化 OLE2 (Compound File Binary) 解析器：提取指定流。
仅用于从二进制 .doc 中取出 WordDocument / 1Table / 0Table 等流。"""
import struct
import sys


class OLE2:
    def __init__(self, data):
        self.data = data
        hdr = data[:512]
        self.sector_shift = struct.unpack_from('<H', hdr, 30)[0]
        self.mini_shift = struct.unpack_from('<H', hdr, 32)[0]
        self.sector_size = 1 << self.sector_shift          # 通常 512
        self.mini_size = 1 << self.mini_shift              # 通常 64
        self.num_fat = struct.unpack_from('<I', hdr, 44)[0]
        self.dir_start = struct.unpack_from('<I', hdr, 48)[0]
        self.mini_cutoff = struct.unpack_from('<I', hdr, 56)[0]
        self.minifat_start = struct.unpack_from('<I', hdr, 60)[0]
        self.num_minifat = struct.unpack_from('<I', hdr, 64)[0]
        self.difat_start = struct.unpack_from('<I', hdr, 68)[0]
        self.num_difat = struct.unpack_from('<I', hdr, 72)[0]
        self._build_fat(hdr)
        self._build_dir()
        self._build_minifat()

    def _sector_off(self, sid):
        return 512 + sid * self.sector_size

    def _read_sector(self, sid):
        off = self._sector_off(sid)
        return self.data[off:off + self.sector_size]

    def _build_fat(self, hdr):
        # 收集 DIFAT（前 109 个在头里）
        difat = list(struct.unpack_from('<109I', hdr, 76))
        sid = self.difat_start
        for _ in range(self.num_difat):
            if sid in (0xFFFFFFFE, 0xFFFFFFFF):
                break
            sec = self._read_sector(sid)
            entries = struct.unpack(f'<{self.sector_size // 4}I', sec)
            difat.extend(entries[:-1])
            sid = entries[-1]
        # 读 FAT
        self.fat = []
        for fsid in difat:
            if fsid in (0xFFFFFFFE, 0xFFFFFFFF):
                continue
            sec = self._read_sector(fsid)
            self.fat.extend(struct.unpack(f'<{self.sector_size // 4}I', sec))

    def _chain(self, start):
        out = []
        sid = start
        seen = set()
        while sid not in (0xFFFFFFFE, 0xFFFFFFFF) and sid < len(self.fat):
            if sid in seen:
                break
            seen.add(sid)
            out.append(sid)
            sid = self.fat[sid]
        return out

    def _read_chain(self, start):
        return b''.join(self._read_sector(s) for s in self._chain(start))

    def _build_dir(self):
        raw = self._read_chain(self.dir_start)
        self.entries = []
        for i in range(0, len(raw), 128):
            e = raw[i:i + 128]
            if len(e) < 128:
                break
            namelen = struct.unpack_from('<H', e, 64)[0]
            if namelen == 0:
                continue
            name = e[:namelen - 2].decode('utf-16-le', 'ignore')
            etype = e[66]
            start = struct.unpack_from('<I', e, 116)[0]
            size = struct.unpack_from('<I', e, 120)[0]
            self.entries.append({'name': name, 'type': etype,
                                 'start': start, 'size': size})

    def _build_minifat(self):
        raw = self._read_chain(self.minifat_start) if self.num_minifat else b''
        self.minifat = list(struct.unpack(f'<{len(raw) // 4}I', raw)) if raw else []
        # mini stream 容器 = root entry 的数据
        root = next((e for e in self.entries if e['type'] == 5), None)
        self.mini_container = self._read_chain(root['start']) if root else b''

    def _read_mini_chain(self, start, size):
        out = []
        sid = start
        seen = set()
        while sid not in (0xFFFFFFFE, 0xFFFFFFFF) and sid < len(self.minifat):
            if sid in seen:
                break
            seen.add(sid)
            off = sid * self.mini_size
            out.append(self.mini_container[off:off + self.mini_size])
            sid = self.minifat[sid]
        return b''.join(out)[:size]

    def read_stream(self, name):
        e = next((x for x in self.entries if x['name'] == name), None)
        if not e:
            return None
        if e['size'] < self.mini_cutoff:
            return self._read_mini_chain(e['start'], e['size'])
        return self._read_chain(e['start'])[:e['size']]

    def list_streams(self):
        return [(e['name'], e['size'], e['type']) for e in self.entries]


if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()
    ole = OLE2(data)
    for n, s, t in ole.list_streams():
        print(f'{t} {s:8d}  {n!r}')
