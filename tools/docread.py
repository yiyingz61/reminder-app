#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从二进制 .doc 中按 piece table 抽取正文文本（含中文）。"""
import struct
import sys
from ole2 import OLE2


def extract_text(path):
    data = open(path, 'rb').read()
    ole = OLE2(data)
    wd = ole.read_stream('WordDocument')

    # FIB 关键字段
    flags = struct.unpack_from('<H', wd, 10)[0]
    table_name = '1Table' if (flags & 0x0200) else '0Table'
    table = ole.read_stream(table_name)

    # fcClx / lcbClx 在 FibRgFcLcb97 中（偏移自 fcMin 起算）
    # FIB: base(32) + csw(2)+rgW(28) + cslw(2)+rgLw(88) + cbRgFcLcb(2) 后是 FibRgFcLcb97
    # fcClx 是该结构第 33 个 pair => 偏移 = 0x01A2
    fcClx = struct.unpack_from('<I', wd, 0x01A2)[0]
    lcbClx = struct.unpack_from('<I', wd, 0x01A6)[0]
    clx = table[fcClx:fcClx + lcbClx]

    # 解析 Clx：跳过可能的 Prc，定位 Pcdt (0x02)
    i = 0
    pcdt = None
    while i < len(clx):
        if clx[i] == 0x02:
            lcb = struct.unpack_from('<I', clx, i + 1)[0]
            pcdt = clx[i + 5:i + 5 + lcb]
            break
        elif clx[i] == 0x01:
            cb = struct.unpack_from('<H', clx, i + 1)[0]
            i += 3 + cb
        else:
            i += 1
    if pcdt is None:
        return _fallback(wd)

    # PlcPcd: (n+1) 个 CP（每个 4 字节），随后 n 个 PCD（每个 8 字节）
    n = (len(pcdt) - 4) // (4 + 8)
    cps = list(struct.unpack_from(f'<{n + 1}I', pcdt, 0))
    pcd_off = (n + 1) * 4
    out = []
    for k in range(n):
        cp_start, cp_end = cps[k], cps[k + 1]
        fc_field = struct.unpack_from('<I', pcdt, pcd_off + k * 8 + 2)[0]
        compressed = (fc_field & 0x40000000) != 0
        fc = fc_field & 0x3FFFFFFF
        length = cp_end - cp_start
        if compressed:
            fc = fc // 2
            raw = wd[fc:fc + length]
            out.append(raw.decode('cp1252', 'replace'))
        else:
            raw = wd[fc:fc + length * 2]
            out.append(raw.decode('utf-16-le', 'replace'))
    text = ''.join(out)
    return _clean(text)


def _clean(text):
    # Word 控制字符转换
    rep = {'\r': '\n', '\x07': '\t', '\x0b': '\n', '\x0c': '\n',
           '\x08': '', '\x01': '', '\x02': '', '\x05': '', '\x13': '',
           '\x14': '', '\x15': '', '\x1e': '-', '\x1f': '', '\xa0': ' '}
    for a, b in rep.items():
        text = text.replace(a, b)
    return text


def _fallback(wd):
    # 退化方案：直接按 UTF-16 扫描
    try:
        return wd.decode('utf-16-le', 'ignore')
    except Exception:
        return ''


if __name__ == '__main__':
    print(extract_text(sys.argv[1]))
