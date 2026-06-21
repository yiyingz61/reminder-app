#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""渲染"系统分层架构图"为 PNG（使用 PIL + 中文字体）。"""
from PIL import Image, ImageDraw, ImageFont

# 高分辨率绘制再缩放，获得抗锯齿效果
SCALE = 2
W, H = 1100, 820
img = Image.new('RGB', (W * SCALE, H * SCALE), '#FFFFFF')
d = ImageDraw.Draw(img)

HEI = '/mnt/c/Windows/Fonts/simhei.ttf'
SUN = '/mnt/c/Windows/Fonts/simfang.ttf'


def font(path, size):
    return ImageFont.truetype(path, size * SCALE)


f_title = font(HEI, 30)
f_layer = font(HEI, 28)
f_item = font(SUN, 22)
f_sub = font(SUN, 19)
f_arrow = font(HEI, 20)


def cx(x):
    return x * SCALE


def center_text(draw, box, text, fnt, fill):
    x0, y0, x1, y1 = box
    tb = draw.textbbox((0, 0), text, font=fnt)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    draw.text((((x0 + x1) - tw) / 2 - tb[0], ((y0 + y1) - th) / 2 - tb[1]),
              text, font=fnt, fill=fill)


def rounded(box, radius, fill, outline, width=2):
    d.rounded_rectangle([cx(box[0]), cx(box[1]), cx(box[2]), cx(box[3])],
                        radius=radius * SCALE, fill=fill, outline=outline,
                        width=width * SCALE)


# 标题
center_text(d, (cx(0), cx(20), cx(W), cx(70)), '日程提醒 App 分层架构',
            f_title, '#1F3864')

layers = [
    {  # 表现层
        'name': '表现层（UI / Screens）',
        'y0': 110, 'y1': 270,
        'fill': '#E8F0FE', 'line': '#5B8DEF', 'name_color': '#1A4Fb0',
        'cards': [
            ('HomeScreen', '我的一天 / 日期切换'),
            ('TodoScreen', '待办列表'),
            ('ScheduleEditScreen', '新建 / 编辑日程'),
            ('RootShell', '底部导航 + 圆形按钮'),
        ],
    },
    {  # 模型层
        'name': '数据模型层（Models）',
        'y0': 350, 'y1': 510,
        'fill': '#E9F7F1', 'line': '#34C2A8', 'name_color': '#1E8270',
        'cards': [
            ('Schedule', '日程实体 / 序列化'),
            ('Todo', '待办实体 / 序列化'),
        ],
    },
    {  # 持久化层
        'name': '数据持久化层（Data / SQLite）',
        'y0': 590, 'y1': 750,
        'fill': '#FDF1E3', 'line': '#F5A623', 'name_color': '#B5740A',
        'cards': [
            ('AppDatabase', 'SQLite 连接 / 建表 / 增删改查'),
        ],
    },
]

MARGIN = 70
for ly in layers:
    rounded((MARGIN, ly['y0'], W - MARGIN, ly['y1']), 16,
            ly['fill'], ly['line'], 2)
    # 层名（左上角）
    d.text((cx(MARGIN + 22), cx(ly['y0'] + 14)), ly['name'],
           font=f_layer, fill=ly['name_color'])
    # 卡片
    n = len(ly['cards'])
    area_x0, area_x1 = MARGIN + 24, W - MARGIN - 24
    gap = 18
    card_y0, card_y1 = ly['y0'] + 64, ly['y1'] - 20
    cw = (area_x1 - area_x0 - gap * (n - 1)) / n
    for i, (title, sub) in enumerate(ly['cards']):
        bx0 = area_x0 + i * (cw + gap)
        bx1 = bx0 + cw
        rounded((bx0, card_y0, bx1, card_y1), 10, '#FFFFFF', ly['line'], 2)
        mx = (bx0 + bx1) / 2
        # 标题居中偏上，副标题居中偏下，两行明确分开
        d.text((cx(mx), cx(card_y0 + 26)), title, font=f_item,
               fill='#222222', anchor='mm')
        d.text((cx(mx), cx(card_y1 - 24)), sub, font=f_sub,
               fill='#777777', anchor='mm')

# 层间双向箭头 + 文字
def arrow(x, y0, y1, label):
    d.line([cx(x), cx(y0), cx(x), cx(y1)], fill='#888888', width=2 * SCALE)
    # 下箭头
    d.polygon([(cx(x), cx(y1)), (cx(x - 8), cx(y1 - 14)), (cx(x + 8), cx(y1 - 14))],
              fill='#888888')
    # 上箭头
    d.polygon([(cx(x), cx(y0)), (cx(x - 8), cx(y0 + 14)), (cx(x + 8), cx(y0 + 14))],
              fill='#888888')
    d.text((cx(x + 16), cx((y0 + y1) / 2)), label, font=f_arrow,
           fill='#555555', anchor='lm')


arrow(W / 2, 270, 350, '读 / 写（FutureBuilder）')
arrow(W / 2, 510, 590, '映射 / 持久化')

img = img.resize((W, H), Image.LANCZOS)
out = '/home/yiyingz/code/reminder_app/assets/architecture.png'
import os
os.makedirs(os.path.dirname(out), exist_ok=True)
img.save(out, 'PNG')
print('saved', out, img.size)
