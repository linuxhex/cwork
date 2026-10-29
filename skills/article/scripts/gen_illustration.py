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

def gen_cover(title: str, output: str, width=2560, height=1080):
    """生成简洁技术风封面"""
    img = Image.new('RGB', (width, height), hex_to_rgb(LIGHT))
    draw = ImageDraw.Draw(img)
    
    # 左侧科技蓝竖条
    draw.rectangle([0, 0, 80, height], fill=hex_to_rgb(PRIMARY))
    
    # 右侧几何装饰
    for i in range(5):
        x = width - 400 + i * 60
        y = 200 + i * 120
        draw.ellipse([x, y, x+100, y+100], fill=hex_to_rgb(PRIMARY), outline=None)
    
    # 标题文字（居中偏左）
    try:
        font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 80)
    except:
        font = ImageFont.load_default()
    
    # 简单居中
    bbox = draw.textbbox((0, 0), title, font=font)
    tw = bbox[2] - bbox[0]
    tx = (width - tw) // 2 - 200
    ty = height // 2 - 60
    draw.text((tx, ty), title, fill=hex_to_rgb(DARK), font=font)
    
    img.save(output, quality=95)
    print(f"封面已生成: {output}")

def gen_comparison(left_title: str, right_title: str, output: str, width=1600, height=900):
    """生成对比图"""
    img = Image.new('RGB', (width, height), hex_to_rgb(LIGHT))
    draw = ImageDraw.Draw(img)
    
    # 左半（红底）
    draw.rectangle([0, 0, width//2-20, height], fill="#FFF1F0")
    # 右半（绿底）
    draw.rectangle([width//2+20, 0, width, height], fill="#F6FFED")
    
    try:
        font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 60)
    except:
        font = ImageFont.load_default()
    
    # 左标题
    draw.text((100, 100), left_title, fill=hex_to_rgb(DARK), font=font)
    # 右标题
    draw.text((width//2 + 120, 100), right_title, fill=hex_to_rgb(DARK), font=font)
    
    img.save(output, quality=95)
    print(f"对比图已生成: {output}")

def gen_data_chart(data_json: str, chart_type: str, output: str):
    """生成数据图表"""
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
        ax.bar(labels, values, color=PRIMARY)
    elif chart_type == 'line':
        ax.plot(labels, values, marker='o', color=PRIMARY, linewidth=2)
    elif chart_type == 'pie':
        ax.pie(values, labels=labels, autopct='%1.1f%%', colors=[PRIMARY, '#FA8C16', '#52C41A', GRAY])
    
    ax.set_title('数据可视化', fontsize=16, fontweight='bold')
    plt.tight_layout()
    plt.savefig(output, dpi=150, bbox_inches='tight')
    print(f"图表已生成: {output}")

def fetch_unsplash(keyword: str, output: str):
    """从 Unsplash 下载图片"""
    import urllib.request
    import urllib.parse
    
    # Unsplash Source API（免费、可商用）
    url = f"https://source.unsplash.com/1600x900/?{urllib.parse.quote(keyword)}"
    try:
        urllib.request.urlretrieve(url, output)
        print(f"图片已下载: {output}")
    except Exception as e:
        print(f"下载失败: {e}", file=sys.stderr)
        sys.exit(1)

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
    
    # comparison
    p_comp = subparsers.add_parser('comparison', help='生成对比图')
    p_comp.add_argument('left', help='左侧标题')
    p_comp.add_argument('right', help='右侧标题')
    p_comp.add_argument('--output', '-o', required=True)
    
    # data
    p_data = subparsers.add_parser('data', help='生成数据图表')
    p_data.add_argument('--data', required=True, help='JSON 数据')
    p_data.add_argument('--type', choices=['bar', 'line', 'pie'], default='bar')
    p_data.add_argument('--output', '-o', required=True)
    
    # fetch
    p_fetch = subparsers.add_parser('fetch', help='从 Unsplash 下载')
    p_fetch.add_argument('keyword', help='关键词')
    p_fetch.add_argument('--output', '-o', required=True)
    
    # flow
    p_flow = subparsers.add_parser('flow', help='生成分层流程/架构图')
    p_flow.add_argument('layers', help='层列表 JSON，如 ["请求","网关","服务A|服务B","DB"]')
    p_flow.add_argument('--output', '-o', required=True)

    args = parser.parse_args()

    if args.command == 'cover':
        gen_cover(args.title, args.output, args.width, args.height)
    elif args.command == 'comparison':
        gen_comparison(args.left, args.right, args.output)
    elif args.command == 'data':
        gen_data_chart(args.data, args.type, args.output)
    elif args.command == 'flow':
        gen_flow_chart(args.layers, args.output)
    elif args.command == 'fetch':
        fetch_unsplash(args.keyword, args.output)
    else:
        parser.print_help()

if __name__ == '__main__':
    main()
