#!/usr/bin/env python3
"""
公众号文章插图生成工具
用法:
  python3 gen_illustration.py cover "文章主题" --output /tmp/cover.png
  python3 gen_illustration.py diagram "架构图" --type flowchart --output /tmp/diagram.png
  python3 gen_illustration.py comparison "改前" "改后" --output /tmp/compare.png
  python3 gen_illustration.py data --data '{"a":10,"b":20}' --type bar --output /tmp/data.png
  python3 gen_illustration.py fetch "关键词" --output /tmp/photo.png
"""
import argparse
import json
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("需要 Pillow: pip3 install Pillow", file=sys.stderr)
    sys.exit(1)

try:
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches
    from matplotlib.patches import FancyBboxPatch
    HAS_MPL = True
except ImportError:
    HAS_MPL = False

# 主题色（科技蓝）
PRIMARY = "#1677FF"
DARK = "#1F1F1F"
GRAY = "#8C8C8C"
LIGHT = "#F5F5F5"

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def rgb01(h):
    """hex 转 matplotlib 0-1 RGB 元组"""
    return tuple(v / 255 for v in hex_to_rgb(h))

def _load_font(size):
    """加载中文字体，多路径兜底"""
    for fp in ("/System/Library/Fonts/PingFang.ttc",
               "/System/Library/Fonts/Hiragino Sans GB.ttc",
               "/System/Library/Fonts/STHeiti Medium.ttc"):
        try:
            return ImageFont.truetype(fp, size)
        except Exception:
            continue
    return ImageFont.load_default()

def _wrap_text(draw, text, font, max_w):
    """按像素宽度折行"""
    lines, cur = [], ""
    for ch in text:
        if draw.textbbox((0, 0), cur + ch, font=font)[2] > max_w and cur:
            lines.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        lines.append(cur)
    return lines

def gen_cover(title: str, output: str, width=2560, height=1080, style="bar", subtitle=""):
    """生成简洁技术风封面
    style: bar=左竖条居中 | block=底部色块 | grid=几何网格
    """
    img = Image.new('RGB', (width, height), hex_to_rgb(LIGHT))
    draw = ImageDraw.Draw(img)
    p = hex_to_rgb(PRIMARY)
    d = hex_to_rgb(DARK)

    title_font = _load_font(120)
    sub_font = _load_font(48)

    if style == "block":
        # 底部大色块 + 白字标题
        draw.rectangle([0, height - 380, width, height], fill=p)
        lines = _wrap_text(draw, title, title_font, width - 200)
        y = height - 380 + (380 - len(lines) * 150) // 2
        for ln in lines:
            bbox = draw.textbbox((0, 0), ln, font=title_font)
            draw.text(((width - (bbox[2]-bbox[0])) // 2, y), ln, fill="#FFFFFF", font=title_font)
            y += 150
    elif style == "grid":
        # 右侧点阵网格装饰
        for i in range(8):
            for j in range(5):
                x, y = width - 700 + i * 70, 150 + j * 160
                draw.ellipse([x, y, x + 28, y + 28], fill=p)
        lines = _wrap_text(draw, title, title_font, width - 900)
        y = (height - len(lines) * 150) // 2
        for ln in lines:
            draw.text((140, y), ln, fill=d, font=title_font)
            y += 150
    else:  # bar（默认）
        # 左侧竖条 + 居中标题 + 右下角圆
        draw.rectangle([0, 0, 80, height], fill=p)
        draw.ellipse([width - 420, height - 420, width - 180, height - 180], fill=p)
        lines = _wrap_text(draw, title, title_font, width - 800)
        y = (height - len(lines) * 150) // 2 - 40
        for ln in lines:
            bbox = draw.textbbox((0, 0), ln, font=title_font)
            draw.text(((width - (bbox[2]-bbox[0])) // 2, y), ln, fill=d, font=title_font)
            y += 150

    if subtitle:
        lines = _wrap_text(draw, subtitle, sub_font, width - 400)
        sy = height - 160 if style == "block" else height - 200
        for ln in lines[:2]:
            bbox = draw.textbbox((0, 0), ln, font=sub_font)
            draw.text(((width - (bbox[2]-bbox[0])) // 2, sy), ln, fill=hex_to_rgb(GRAY), font=sub_font)
            sy += 66

    img.save(output, quality=95)
    print(f"封面已生成: {output} (style={style})")

def gen_comparison(left_title: str, right_title: str, output: str, width=1600, height=900,
                   left_items="", right_items=""):
    """生成对比图（左右两栏 + 各自条目列表）
    items: 分号分隔，如 "手动喂上下文;契约靠人盯"
    """
    img = Image.new('RGB', (width, height), "#FFFFFF")
    draw = ImageDraw.Draw(img)

    half = width // 2
    draw.rectangle([0, 0, half - 16, height], fill="#FFF1F0")
    draw.rectangle([half + 16, 0, width, height], fill="#F6FFED")

    title_font = _load_font(64)
    item_font = _load_font(44)

    def draw_col(x_start, title, items, mark):
        draw.text((x_start + 60, 90), title, fill=hex_to_rgb(DARK), font=title_font)
        y = 240
        for it in [i.strip() for i in items.split(';') if i.strip()]:
            draw.text((x_start + 60, y), mark, fill=hex_to_rgb(GRAY), font=item_font)
            for ln in _wrap_text(draw, it, item_font, half - 220)[:2]:
                draw.text((x_start + 140, y), ln, fill="#434343", font=item_font)
                y += 78
            y += 30

    draw_col(0, left_title, left_items, "×")
    draw_col(half, right_title, right_items, "√")

    img.save(output, quality=95)
    print(f"对比图已生成: {output}")

def gen_data_chart(data_json: str, chart_type: str, output: str, title=""):
    """生成数据图表（bar/line 带数值标注）"""
    if not HAS_MPL:
        print("需要 matplotlib: pip3 install matplotlib", file=sys.stderr)
        sys.exit(1)

    data = json.loads(data_json)
    labels = list(data.keys())
    values = list(data.values())

    plt.rcParams['font.sans-serif'] = ['PingFang SC', 'Arial Unicode MS']
    plt.rcParams['axes.unicode_minus'] = False

    fig, ax = plt.subplots(figsize=(12, 6))

    if chart_type == 'bar':
        bars = ax.bar(labels, values, color=PRIMARY, width=0.55)
        for b, v in zip(bars, values):
            ax.text(b.get_x() + b.get_width() / 2, b.get_height(), f'{v}',
                    ha='center', va='bottom', fontsize=13, fontweight='bold', color=DARK)
        ax.spines[['top', 'right']].set_visible(False)
    elif chart_type == 'line':
        ax.plot(labels, values, marker='o', color=PRIMARY, linewidth=2)
        for x, v in zip(labels, values):
            ax.annotate(f'{v}', (x, v), textcoords='offset points', xytext=(0, 10),
                        ha='center', fontsize=12, color=DARK)
        ax.spines[['top', 'right']].set_visible(False)
    elif chart_type == 'pie':
        ax.pie(values, labels=labels, autopct='%1.1f%%', colors=[PRIMARY, '#FA8C16', '#52C41A', GRAY])

    ax.set_title(title or '数据对比', fontsize=18, fontweight='bold', color=DARK, pad=16)
    plt.tight_layout()
    plt.savefig(output, dpi=150, bbox_inches='tight', facecolor='white')
    print(f"图表已生成: {output}")

def fetch_photo(keyword: str, output: str, width=1600, height=900):
    """下载氛围照片（picsum，随机高质量摄影图；不按关键词匹配）
    下载失败时兜底：生成抽象技术风几何图，绝不中断流程
    """
    import urllib.request

    for attempt_url in (f"https://picsum.photos/{width}/{height}",
                        f"https://picsum.photos/seed/{abs(hash(keyword)) % 9999}/{width}/{height}"):
        try:
            urllib.request.urlretrieve(attempt_url, output)
            print(f"照片已下载: {output}")
            return
        except Exception as e:
            print(f"  下载失败({attempt_url}): {e}", file=sys.stderr)

    # 兜底：生成抽象技术风图
    img = Image.new('RGB', (width, height), hex_to_rgb(LIGHT))
    draw = ImageDraw.Draw(img)
    p = hex_to_rgb(PRIMARY)
    for i in range(12):
        x = (i * 197) % (width - 300)
        y = (i * 331) % (height - 300)
        size = 60 + (i * 53) % 180
        if i % 2 == 0:
            draw.ellipse([x, y, x + size, y + size], outline=p, width=6)
        else:
            draw.rectangle([x, y, x + size, y + size], outline=p, width=6)
    draw.rectangle([0, height - 60, width, height], fill=p)
    img.save(output, quality=95)
    print(f"网络不可用，已生成抽象图兜底: {output}")

def gen_flow_chart(layers_json: str, output: str):
    """生成分层流程/架构图
    layers_json 示例: '["用户请求","网关","服务A|服务B","DB|缓存"]'
    每个元素是一层（从上到下），层内用 | 分隔并列节点
    """
    if not HAS_MPL:
        print("需要 matplotlib: pip3 install matplotlib", file=sys.stderr)
        sys.exit(1)

    layers = json.loads(layers_json)
    max_nodes = max(len(l.split('|')) for l in layers)

    node_w, node_h = 1.6, 0.7
    gap_x, gap_y = 0.6, 1.2
    fig_w = max_nodes * (node_w + gap_x) + 1
    fig_h = len(layers) * (node_h + gap_y) + 1

    plt.rcParams['font.sans-serif'] = ['PingFang SC', 'Arial Unicode MS', 'Heiti TC']
    plt.rcParams['axes.unicode_minus'] = False

    fig, ax = plt.subplots(figsize=(fig_w, fig_h))
    ax.set_xlim(0, fig_w)
    ax.set_ylim(0, fig_h)
    ax.axis('off')

    p = rgb01(PRIMARY)
    d = hex_to_rgb(DARK)
    node_pos = {}  # (layer_idx, node_idx) -> (cx, cy)

    for li, layer in enumerate(layers):
        nodes = [n.strip() for n in layer.split('|')]
        cy = fig_h - 0.5 - li * (node_h + gap_y) - node_h / 2
        total_w = len(nodes) * node_w + (len(nodes) - 1) * gap_x
        start_x = (fig_w - total_w) / 2
        for ni, name in enumerate(nodes):
            cx = start_x + ni * (node_w + gap_x) + node_w / 2
            node_pos[(li, ni)] = (cx, cy)
            box = FancyBboxPatch((cx - node_w/2, cy - node_h/2), node_w, node_h,
                                 boxstyle="round,pad=0.05,rounding_size=0.12",
                                 facecolor='#F5F5F5', edgecolor=p, linewidth=2)
            ax.add_patch(box)
            ax.text(cx, cy, name, ha='center', va='center',
                    fontsize=13, fontweight='bold', color='#%02x%02x%02x' % d)

    # 画层间连线：下一层每节点连到上一层中心（简化为层对层）
    for li in range(len(layers) - 1):
        n_upper = len(layers[li].split('|'))
        n_lower = len(layers[li + 1].split('|'))
        if n_upper == n_lower:
            for ni in range(n_upper):
                x1, y1 = node_pos[(li, ni)]
                x2, y2 = node_pos[(li + 1, ni)]
                ax.annotate('', xy=(x2, y2 + node_h/2), xytext=(x1, y1 - node_h/2),
                            arrowprops=dict(arrowstyle='->', color=p, lw=1.8))
        else:
            # 多对一/一对多：连到下层整体中心
            ucx = sum(node_pos[(li, i)][0] for i in range(n_upper)) / n_upper
            ucy = node_pos[(li, 0)][1]
            lcx = sum(node_pos[(li + 1, i)][0] for i in range(n_lower)) / n_lower
            lcy = node_pos[(li + 1, 0)][1]
            ax.annotate('', xy=(lcx, lcy + node_h/2), xytext=(ucx, ucy - node_h/2),
                        arrowprops=dict(arrowstyle='->', color=p, lw=1.8))

    plt.tight_layout()
    plt.savefig(output, dpi=150, bbox_inches='tight', facecolor='white')
    print(f"流程图已生成: {output}")


def main():
    parser = argparse.ArgumentParser(description='公众号插图生成')
    subparsers = parser.add_subparsers(dest='command')
    
    # cover
    p_cover = subparsers.add_parser('cover', help='生成封面')
    p_cover.add_argument('title', help='标题')
    p_cover.add_argument('--output', '-o', required=True)
    p_cover.add_argument('--width', type=int, default=2560)
    p_cover.add_argument('--height', type=int, default=1080)
    p_cover.add_argument('--style', choices=['bar', 'block', 'grid'], default='bar', help='风格变体')
    p_cover.add_argument('--subtitle', default='', help='副标题（可选）')

    # comparison
    p_comp = subparsers.add_parser('comparison', help='生成对比图')
    p_comp.add_argument('left', help='左侧标题')
    p_comp.add_argument('right', help='右侧标题')
    p_comp.add_argument('--output', '-o', required=True)
    p_comp.add_argument('--left-items', default='', help='左侧条目，分号分隔')
    p_comp.add_argument('--right-items', default='', help='右侧条目，分号分隔')

    # data
    p_data = subparsers.add_parser('data', help='生成数据图表')
    p_data.add_argument('--data', required=True, help='JSON 数据')
    p_data.add_argument('--type', choices=['bar', 'line', 'pie'], default='bar')
    p_data.add_argument('--title', default='', help='图表标题')
    p_data.add_argument('--output', '-o', required=True)

    # fetch
    p_fetch = subparsers.add_parser('fetch', help='下载氛围照片（picsum 随机图；失败自动兜底生成抽象图）')
    p_fetch.add_argument('keyword', help='仅作随机种子，不做关键词匹配')
    p_fetch.add_argument('--output', '-o', required=True)
    p_fetch.add_argument('--width', type=int, default=1600)
    p_fetch.add_argument('--height', type=int, default=900)

    # flow
    p_flow = subparsers.add_parser('flow', help='生成分层流程/架构图')
    p_flow.add_argument('layers', help='层列表 JSON，如 ["请求","网关","服务A|服务B","DB"]')
    p_flow.add_argument('--output', '-o', required=True)

    args = parser.parse_args()

    if args.command == 'cover':
        gen_cover(args.title, args.output, args.width, args.height, args.style, args.subtitle)
    elif args.command == 'comparison':
        gen_comparison(args.left, args.right, args.output,
                       left_items=args.left_items, right_items=args.right_items)
    elif args.command == 'data':
        gen_data_chart(args.data, args.type, args.output, args.title)
    elif args.command == 'flow':
        gen_flow_chart(args.layers, args.output)
    elif args.command == 'fetch':
        fetch_photo(args.keyword, args.output, args.width, args.height)
    else:
        parser.print_help()

if __name__ == '__main__':
    main()
