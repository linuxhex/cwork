# 公众号平台红线（强制）

借鉴自开源排版 skill（gzh-design / doocs/md）的实测踩坑，结合本仓库「微信安全 inline」约束。写进编辑器前必须过一遍。

## 禁止

| 写法 | 后果 |
|------|------|
| `<style>` / `<script>` / 外部 CSS | 被剥掉 |
| `class` / `id` 属性 | 被剥掉，样式全丢 |
| `<div>`（优先用 `<section>`） | 部分场景样式丢失 |
| `position:fixed/absolute/sticky` | 布局错乱 |
| `float` / `display:grid` / CSS 变量 `var(--x)` | 不渲染或异常 |
| `@media` / `@keyframes` | 不生效 |
| `linear-gradient` 作文字/卡片背景 | 可渲染但易触发暗色模式结构检测；**默认用纯色** |
| `white-space:pre` 代码块 | 源码缩进被原样渲染成大空白 |
| `width:100%` 强制铺满小图 | 小图被拉伸发糊 |
| 四周 `border:dashed` 虚线框包标题 | 笨重抢戏 |
| 正文半角标点 `, . ! ? : " '` | 观感廉价；代码块内除外 |
| 正文里 `【配图 x】` / `[此处插入图片]` 占位文字 | 等于没图 |
| 文档外壳 `<!DOCTYPE>/<html>/<head>/<body>` | 粘贴进编辑器会干扰 |

## 必须

- **全部 inline `style="..."`**，不依赖 class。
- **文字节点用 `<span leaf="">...</span>` 包裹**（公众号粘贴后否则易丢样式；本仓库写入编辑器时同样遵守）。
- 装饰性空元素（细分割线、短线）内部放 `<span leaf=""><br></span>`，否则被剥样式。
- 图片：`max-width:100%;height:auto;display:block;margin:0 auto`（**不用** `width:100%` 除非是布局元素）。
- 代码块：每行一个 `<p style="margin:0">`，缩进用全角空格 `　`，不用 `white-space:pre`。
- 产物格式：纯 `<section>…</section>` 正文片段，直接写进编辑器；**不生成本地半成品 `.html` 入库**。
- 双栏对比优先用 `<table>` 嵌套（比 flex 更稳）；导读三列等轻量布局可用有限 `display:flex`。

## 有限可用

- `display:flex`（导读卡、步骤标签行；**双栏对比仍优先 table**）
- `border-radius` / 轻量 `box-shadow`（阴影别依赖，可能不渲染）
- `<section> / <p> / <span> / <strong> / <img> / <h2> / <h3> / <pre> 的替代写法见主题库`

## 视觉层级（全篇通用，防「到处加粗=没有重点」）

| 层级 | 作用 | 频率 |
|------|------|------|
| 锚点层 | 产品名 / 核心结论 / CTA | 全文 ≤ 5 处 |
| 标记层 | 正文关键词下划线 | 每段 1–3 个短语 |
| 容器层 | 引用块、提示条、代码块、STEP 标签 | 按需 |

## 写入前自检（checklist）

- [ ] 无 class / style 块 / 渐变文字底
- [ ] 关键文字已 `<span leaf="">` 包裹
- [ ] 无配图占位文字；图片已在编辑器内上传或即将上传
- [ ] 正文全角标点；代码块内保持半角
- [ ] 锚点强调 ≤ 5 处
- [ ] 草稿箱已查过，有同主题则改旧稿不重复新建
