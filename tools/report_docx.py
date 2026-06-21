#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 Markdown 结课报告转换为符合《要求.doc》格式的 .docx（纯标准库）。

格式规范：
- 正文：中文宋体、英文数字 Times New Roman，小四(12pt)，1.5 倍行距，首行缩进 2 字符，段前段后 0。
- 章 1：三号(16pt)黑体加粗左对齐，段前段后 0.5 行。
- 节 1.1：四号(14pt)宋体加粗左对齐，段前段后 0.5 行。
- 条 1.1.1：小四宋体左对齐，段前段后 0.5 行。
- 表：三线表(线宽 0.5 磅)，表名在上方居中五号，表内五号、行距固定 18 磅。
- 图名、代码清单题：五号。
- 首页为封面（取自要求.doc 第二页）。
"""
import re
import sys
import os
import struct
import zipfile
from xml.sax.saxutils import escape

NS = ('xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"')

# 收集需要嵌入的图片：list of dict(rid, path, w_emu, h_emu, name)
IMAGES = []
MD_DIR = '.'  # 运行时由 build() 设为 Markdown 所在目录

# 字号（half-point）
SZ_XIAO2 = 36   # 小二 18pt
SZ_3 = 32       # 三号 16pt
SZ_4 = 28       # 四号 14pt
SZ_X4 = 24      # 小四 12pt
SZ_5 = 21       # 五号 10.5pt

SIMSUN = 'SimSun'
SIMHEI = 'SimHei'
TNR = 'Times New Roman'


def esc(t):
    return escape(t, {'"': "&quot;"})


def fonts(ascii_=TNR, ea=SIMSUN):
    return f'<w:rFonts w:ascii="{ascii_}" w:hAnsi="{ascii_}" w:eastAsia="{ea}" w:cs="{ascii_}"/>'


def inline_runs(text, base_sz=SZ_X4, ascii_=TNR, ea=SIMSUN, bold=False, italic=False):
    """把含 **加粗** 与 `行内代码` 的文本切成多个 run。"""
    tokens = re.split(r'(`[^`]+`|\*\*[^*]+\*\*)', text)
    out = []
    for tok in tokens:
        if not tok:
            continue
        b = bold
        mono = False
        content = tok
        if tok.startswith('`') and tok.endswith('`') and len(tok) >= 2:
            content = tok[1:-1]
            mono = True
        elif tok.startswith('**') and tok.endswith('**') and len(tok) >= 4:
            content = tok[2:-2]
            b = True
        rpr = '<w:rPr>'
        rpr += fonts('Consolas', 'SimSun') if mono else fonts(ascii_, ea)
        if b:
            rpr += '<w:b/>'
        if italic:
            rpr += '<w:i/>'
        rpr += f'<w:sz w:val="{base_sz}"/><w:szCs w:val="{base_sz}"/></w:rPr>'
        out.append(f'<w:r>{rpr}<w:t xml:space="preserve">{esc(content)}</w:t></w:r>')
    return ''.join(out) or '<w:r><w:t/></w:r>'


def p_body(text):
    """正文段落：小四，1.5 倍行距，首行缩进 2 字符，段前段后 0。"""
    ppr = ('<w:pPr><w:spacing w:before="0" w:after="0" w:line="360" w:lineRule="auto"/>'
           '<w:ind w:firstLineChars="200" w:firstLine="480"/></w:pPr>')
    return f'<w:p>{ppr}{inline_runs(text)}</w:p>'


def p_list(text, ordered_num=None):
    """列表项（款/项级）：缩进 2 字符，小四，固定行距 20 磅。"""
    prefix = f'{ordered_num}. ' if ordered_num else ''
    ppr = ('<w:pPr><w:spacing w:before="0" w:after="0" w:line="400" w:lineRule="exact"/>'
           '<w:ind w:leftChars="200" w:left="480" w:hangingChars="100" w:hanging="240"/></w:pPr>')
    return f'<w:p>{ppr}{inline_runs(prefix + text)}</w:p>'


def heading(text, level):
    if level == 1:       # 章：三号黑体加粗
        sz, ea, ascii_, bold = SZ_3, SIMHEI, TNR, True
    elif level == 2:     # 节：四号宋体加粗
        sz, ea, ascii_, bold = SZ_4, SIMSUN, TNR, True
    else:                # 条：小四宋体
        sz, ea, ascii_, bold = SZ_X4, SIMSUN, TNR, False
    ppr = (f'<w:pPr><w:pStyle w:val="Heading{level}"/>'
           f'<w:spacing w:beforeLines="50" w:afterLines="50" w:line="360" w:lineRule="auto"/>'
           f'<w:jc w:val="left"/><w:outlineLvl w:val="{level-1}"/></w:pPr>')
    return f'<w:p>{ppr}{inline_runs(text, base_sz=sz, ascii_=ascii_, ea=ea, bold=bold)}</w:p>'


def caption(text, center=True):
    """表名/图名/代码清单题：五号，可居中。"""
    jc = '<w:jc w:val="center"/>' if center else ''
    ppr = (f'<w:pPr><w:spacing w:before="60" w:after="60" w:line="360" w:lineRule="auto"/>{jc}</w:pPr>')
    return f'<w:p>{ppr}{inline_runs(text, base_sz=SZ_5)}</w:p>'


def code_block(lines):
    out = []
    for ln in lines:
        run = (f'<w:r><w:rPr>{fonts("Consolas", "SimSun")}'
               f'<w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
               f'<w:t xml:space="preserve">{esc(ln)}</w:t></w:r>')
        ppr = ('<w:pPr><w:spacing w:before="0" w:after="0" w:line="360" w:lineRule="auto"/>'
               '<w:ind w:left="360"/><w:shd w:val="clear" w:fill="F5F6FA"/></w:pPr>')
        out.append(f'<w:p>{ppr}{run}</w:p>')
    return ''.join(out)


def _png_size(path):
    """读取 PNG 宽高（像素）。"""
    with open(path, 'rb') as f:
        head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('not a PNG: ' + path)
    w, h = struct.unpack('>II', head[16:24])
    return w, h


def image_paragraph(path, max_width_cm=15.0):
    """生成居中的内嵌图片段落；按页面可用宽度等比缩放。"""
    abspath = path if os.path.isabs(path) else os.path.join(MD_DIR, path)
    px_w, px_h = _png_size(abspath)
    # 像素按 96 DPI 换算为厘米，再限制最大宽度
    cm_w = px_w / 96 * 2.54
    cm_h = px_h / 96 * 2.54
    if cm_w > max_width_cm:
        scale = max_width_cm / cm_w
        cm_w, cm_h = cm_w * scale, cm_h * scale
    EMU = 360000  # 每厘米
    w_emu = int(cm_w * EMU)
    h_emu = int(cm_h * EMU)
    rid = f'rIdImg{len(IMAGES) + 1}'
    name = os.path.basename(abspath)
    IMAGES.append({'rid': rid, 'path': abspath, 'name': name})
    pid = len(IMAGES)
    drawing = (
        '<w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
        f'<wp:extent cx="{w_emu}" cy="{h_emu}"/>'
        '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
        f'<wp:docPr id="{pid}" name="{esc(name)}"/>'
        '<wp:cNvGraphicFramePr>'
        '<a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>'
        '</wp:cNvGraphicFramePr>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr>'
        f'<pic:cNvPr id="{pid}" name="{esc(name)}"/>'
        '<pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill>'
        f'<a:blip r:embed="{rid}"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr>'
        f'<a:xfrm><a:off x="0" y="0"/><a:ext cx="{w_emu}" cy="{h_emu}"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '</pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>')
    ppr = '<w:pPr><w:spacing w:before="120" w:after="60"/><w:jc w:val="center"/></w:pPr>'
    return f'<w:p>{ppr}<w:r>{drawing}</w:r></w:p>'


PLACEHOLDER = '__X__'


def three_line_table(rows):
    """三线表：仅表格顶线、表头下线、表格底线；线宽 0.5 磅(sz=4)。
    表内五号宋体，行距固定 18 磅(line=360/exact)；表头加粗，文字左对齐。"""
    n = len(rows)
    # 表级仅设上下边框
    tbl = ('<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
           '<w:jc w:val="center"/>'
           '<w:tblBorders>'
           '<w:top w:val="single" w:sz="6" w:space="0" w:color="000000"/>'
           '<w:bottom w:val="single" w:sz="6" w:space="0" w:color="000000"/>'
           '<w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
           '<w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
           '<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
           '<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
           '</w:tblBorders>'
           '<w:tblCellMar>'
           '<w:top w:w="20" w:type="dxa"/><w:bottom w:w="20" w:type="dxa"/>'
           '<w:left w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/>'
           '</w:tblCellMar></w:tblPr>')
    for i, row in enumerate(rows):
        tbl += '<w:tr>'
        for cell in row:
            # 表头行单元格底部加线
            border = ''
            if i == 0:
                border = ('<w:tcBorders>'
                          '<w:bottom w:val="single" w:sz="6" w:space="0" w:color="000000"/>'
                          '</w:tcBorders>')
            tcpr = f'<w:tcPr>{border}<w:vAlign w:val="center"/></w:tcPr>'
            txt = cell.strip()
            runs = inline_runs(txt, base_sz=SZ_5, bold=(i == 0))
            ppr = ('<w:pPr><w:spacing w:before="0" w:after="0" w:line="360" w:lineRule="exact"/>'
                   '<w:jc w:val="left"/></w:pPr>')
            tbl += f'<w:tc>{tcpr}<w:p>{ppr}{runs}</w:p></w:tc>'
        tbl += '</w:tr>'
    tbl += '</w:tbl>'
    # 表后空一行（正文样式）
    tbl += '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr></w:p>'
    return tbl


def cover():
    """封面（取自《要求.doc》第二页）：标题、班级/学号/姓名、评分表、评阅人/日期、学院落款。"""
    parts = []
    # 顶部留白
    for _ in range(2):
        parts.append('<w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="360" w:lineRule="auto"/></w:pPr></w:p>')
    # 标题（小二号黑体加粗居中）
    parts.append(
        '<w:p><w:pPr><w:spacing w:before="240" w:after="600" w:line="480" w:lineRule="auto"/>'
        '<w:jc w:val="center"/></w:pPr>'
        f'<w:r><w:rPr>{fonts(TNR, SIMHEI)}<w:b/><w:sz w:val="{SZ_XIAO2}"/>'
        f'<w:szCs w:val="{SZ_XIAO2}"/></w:rPr><w:t>移动终端程序设计结课报告</w:t></w:r></w:p>')
    # 班级 / 学号 / 姓名
    parts.append('<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr></w:p>')
    info = '班    级：　　　　　　学    号：　　　　　　姓    名：　　　　　　'
    parts.append(
        '<w:p><w:pPr><w:spacing w:before="300" w:after="600" w:line="480" w:lineRule="auto"/>'
        '<w:jc w:val="center"/></w:pPr>'
        f'<w:r><w:rPr>{fonts(TNR, SIMSUN)}<w:sz w:val="{SZ_X4}"/>'
        f'<w:szCs w:val="{SZ_X4}"/></w:rPr><w:t xml:space="preserve">{esc(info)}</w:t></w:r></w:p>')
    # 评分表
    score_rows = [
        ['序号', '要求', '得分'],
        ['1', '界面要求：美观，友好，不能过于粗糙，具备一定设计美感（20分）', ''],
        ['2', '功能要求：基本功能实现，需要可以对功能进行扩充（20分）', ''],
        ['3', '对数据的持久化保存方式：可以使用文件，也可以使用数据库（20分）', ''],
        ['4', '代码要求：书写规范，结构合理，结合必要的注释（20分）', ''],
        ['5', '文档要求：内容详细，结构合理，格式正确（20分）', ''],
        ['合计', '', ''],
    ]
    parts.append(_cover_score_table(score_rows))
    # 评阅人 / 日期
    parts.append('<w:p><w:pPr><w:spacing w:before="360" w:after="0" w:line="480" w:lineRule="auto"/>'
                 '<w:jc w:val="right"/><w:ind w:right="600"/></w:pPr>'
                 f'<w:r><w:rPr>{fonts(TNR, SIMSUN)}<w:sz w:val="{SZ_X4}"/></w:rPr>'
                 '<w:t>评阅人：</w:t></w:r></w:p>')
    parts.append('<w:p><w:pPr><w:spacing w:before="0" w:after="600" w:line="480" w:lineRule="auto"/>'
                 '<w:jc w:val="right"/><w:ind w:right="600"/></w:pPr>'
                 f'<w:r><w:rPr>{fonts(TNR, SIMSUN)}<w:sz w:val="{SZ_X4}"/></w:rPr>'
                 '<w:t>日　期：</w:t></w:r></w:p>')
    # 学院落款（居中）
    parts.append('<w:p><w:pPr><w:spacing w:before="600" w:after="0" w:line="480" w:lineRule="auto"/>'
                 '<w:jc w:val="center"/></w:pPr>'
                 f'<w:r><w:rPr>{fonts(TNR, SIMSUN)}<w:b/><w:sz w:val="{SZ_4}"/></w:rPr>'
                 '<w:t>东北大学秦皇岛分校计算机与通信工程学院</w:t></w:r></w:p>')
    # 分页符
    parts.append('<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
    return ''.join(parts)


def _cover_score_table(rows):
    """封面评分表：完整边框表格（区别于正文三线表）。"""
    border = ('<w:tblBorders>' + ''.join(
        f'<w:{e} w:val="single" w:sz="4" w:space="0" w:color="000000"/>'
        for e in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV')) +
        '</w:tblBorders>')
    # 列宽：序号窄、要求宽、得分中
    grid = ('<w:tblGrid><w:gridCol w:w="900"/><w:gridCol w:w="6500"/>'
            '<w:gridCol w:w="1400"/></w:tblGrid>')
    tbl = ('<w:tbl><w:tblPr><w:tblW w:w="8800" w:type="dxa"/>'
           '<w:jc w:val="center"/>' + border + '</w:tblPr>' + grid)
    widths = [900, 6500, 1400]
    for i, row in enumerate(rows):
        tbl += '<w:tr>'
        for j, cell in enumerate(row):
            jc = 'center' if (i == 0 or j != 1) else 'left'
            runs = inline_runs(cell.strip(), base_sz=SZ_5, bold=(i == 0))
            tbl += (f'<w:tc><w:tcPr><w:tcW w:w="{widths[j]}" w:type="dxa"/>'
                    f'<w:vAlign w:val="center"/></w:tcPr>'
                    f'<w:p><w:pPr><w:spacing w:before="40" w:after="40" w:line="360" w:lineRule="auto"/>'
                    f'<w:jc w:val="{jc}"/></w:pPr>{runs}</w:p></w:tc>')
        tbl += '</w:tr>'
    tbl += '</w:tbl>'
    return tbl


def is_table_sep(line):
    return bool(re.match(r'^\s*\|?[\s:|-]+\|?\s*$', line)) and '-' in line


def split_row(line):
    s = line.strip()
    if s.startswith('|'):
        s = s[1:]
    if s.endswith('|'):
        s = s[:-1]
    return s.split('|')


CAP_RE = re.compile(r'^(表|图|代码清单|算法)\s')


def parse_body(md):
    """解析正文（封面之外），返回 OOXML 片段。"""
    lines = md.split('\n')
    body = []
    i, n = 0, len(lines)
    while i < n:
        line = lines[i]
        s = line.strip()

        if s.startswith('```'):
            i += 1
            buf = []
            while i < n and not lines[i].strip().startswith('```'):
                buf.append(lines[i])
                i += 1
            i += 1
            body.append(code_block(buf))
            continue

        if s == '':
            i += 1
            continue

        # 图片 ![alt](path)
        m = re.match(r'^!\[[^\]]*\]\(([^)]+)\)\s*$', s)
        if m:
            body.append(image_paragraph(m.group(1).strip()))
            i += 1
            continue

        m = re.match(r'^(#{1,6})\s+(.*)$', line)
        if m:
            level = len(m.group(1))
            text = re.sub(r'<!--.*?-->', '', m.group(2)).strip()
            if level == 1:
                if text == '移动终端程序设计结课报告':
                    i += 1
                    continue
                body.append(heading(text, 1))
            else:
                body.append(heading(text, level - 1))
            i += 1
            continue

        if CAP_RE.match(s):
            center = s.startswith('表') or s.startswith('图')
            body.append(caption(s, center=center))
            i += 1
            continue

        if '|' in line and i + 1 < n and is_table_sep(lines[i + 1]):
            rows = [split_row(line)]
            i += 2
            while i < n and '|' in lines[i] and lines[i].strip():
                rows.append(split_row(lines[i]))
                i += 1
            body.append(three_line_table(rows))
            continue

        m = re.match(r'^\s*(\d+)\.\s+(.*)$', line)
        if m:
            text = re.sub(r'<!--.*?-->', '', m.group(2)).strip()
            body.append(p_list(text, ordered_num=m.group(1)))
            i += 1
            continue

        m = re.match(r'^\s*[-*+]\s+(.*)$', line)
        if m:
            text = re.sub(r'<!--.*?-->', '', m.group(1)).strip()
            body.append(p_list(text))
            i += 1
            continue

        text = re.sub(r'<!--.*?-->', '', line).strip()
        if text:
            body.append(p_body(text))
        i += 1
    return ''.join(body)


CONTENT_TYPES = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Default Extension="png" ContentType="image/png"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>'''

RELS = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>'''

def doc_rels():
    rels = ['<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>']
    for img in IMAGES:
        rels.append(
            f'<Relationship Id="{img["rid"]}" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
            f'Target="media/{img["name"]}"/>')
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            + ''.join(rels) + '</Relationships>')

CORE = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:title>移动终端程序设计结课报告</dc:title><dc:creator>Reminder</dc:creator>
</cp:coreProperties>'''


def heading_style(idx):
    return (f'<w:style w:type="paragraph" w:styleId="Heading{idx}">'
            f'<w:name w:val="heading {idx}"/><w:basedOn w:val="Normal"/>'
            f'<w:next w:val="Normal"/><w:qFormat/>'
            f'<w:pPr><w:keepNext/><w:outlineLvl w:val="{idx-1}"/></w:pPr></w:style>')


STYLES = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          f'<w:styles {NS}>'
          '<w:docDefaults><w:rPrDefault><w:rPr>'
          f'{fonts(TNR, SIMSUN)}<w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr></w:rPrDefault>'
          '<w:pPrDefault><w:pPr><w:spacing w:after="0" w:line="360" w:lineRule="auto"/></w:pPr></w:pPrDefault>'
          '</w:docDefaults>'
          '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
          '<w:name w:val="Normal"/><w:qFormat/></w:style>'
          + ''.join(heading_style(k) for k in range(1, 7))
          + '</w:styles>')


def build(md_path, out_path):
    global MD_DIR
    MD_DIR = os.path.dirname(os.path.abspath(md_path))
    with open(md_path, encoding='utf-8') as f:
        md = f.read()
    body = parse_body(md)
    sect = ('<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
            '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" '
            'w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>')
    document = (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                f'<w:document {NS}><w:body>{cover()}{body}{sect}</w:body></w:document>')
    with zipfile.ZipFile(out_path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', CONTENT_TYPES)
        z.writestr('_rels/.rels', RELS)
        z.writestr('word/_rels/document.xml.rels', doc_rels())
        z.writestr('word/document.xml', document)
        z.writestr('word/styles.xml', STYLES)
        z.writestr('docProps/core.xml', CORE)
        for img in IMAGES:
            with open(img['path'], 'rb') as f:
                z.writestr(f'word/media/{img["name"]}', f.read())
    print(f'OK -> {out_path}  ({len(IMAGES)} image(s) embedded)')


if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2])

