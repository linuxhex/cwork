# 主题组件库 —— 简洁技术风（tech-minimal）

> **定位**：对标美团技术团队 / 阿里技术等主流技术公众号——灰阶克制、左竖条层级、数据与边界优先、实战可落地。  
> **默认主题**：技术分享 / 开源项目 / 架构复盘 / 教程指南 **一律用本主题**，除非用户明确指定其它风格。  
> **红线**：生成前先读同目录 `platform-redlines.md`；HTML 一律从本库取，不要凭记忆手写花哨样式。

## 设计变量

```
主色（科技蓝）：   #1677FF
标题色（深炭）：   #1F1F1F
正文色：           #434343
辅助文字：         #8C8C8C
分割线：           #F0F0F0
浅底：             #F5F5F5
代码底：           #1E293B
强调橙（点睛）：   #FA8C16   ← 全篇 ≤ 3 处
正文字号：         15px
行高：             1.8
最大宽：           677px
字体：             -apple-system,BlinkMacSystemFont,'PingFang SC','Hiragino Sans GB','Microsoft YaHei',sans-serif
```

## 文章类型 → 组件配方

| 类型 | 核心组合 | 点缀 |
|------|----------|------|
| 技术分享 / 架构复盘 | 引言卡 + 本文看点 + 编号章节 + 正文下划线 + 引用金句 + 踩坑 NOTE + 深色代码块 | 数据对比 table |
| 开源项目介绍 | 引言卡 + 信息卡（GitHub） + 功能列表 STEP/SKILL + 快速开始代码块 + CTA | 对比 table |
| 教程指南 | 引言卡 + STEP 标签步骤 + 代码块 + 踩坑 NOTE | 子标题左竖条 |
| 产品推广 | 引言卡 + 看点三列 + 对比 table + CTA | 少用代码块 |
| 行业观察 | 引言卡 + 编号章节 + 金句竖条 + 数据强调 | 少用 STEP |

---

## 1 全局容器

```html
<section style="max-width:677px;margin:0 auto;background:#FFFFFF;font-family:-apple-system,BlinkMacSystemFont,'PingFang SC','Hiragino Sans GB','Microsoft YaHei',sans-serif;color:#434343;line-height:1.8;letter-spacing:0.3px;overflow-x:hidden;">
  <!-- 组件放这里 -->
</section>
```

## 2 开头引言卡（金句 + 下划线关键词）

> 外标题卖「为什么点开」，引言卡卖「核心判断」——**禁止复述外标题**。

```html
<section style="margin:10px 10px 32px;padding:28px 20px 22px;border-top:1px solid #F0F0F0;border-bottom:1px solid #F0F0F0;background:#FFFFFF;">
  <p style="font-size:11px;color:#8C8C8C;letter-spacing:2px;margin:0 0 14px;"><span leaf="">QUOTE</span></p>
  <p style="font-size:17px;font-weight:700;color:#1F1F1F;margin:0;line-height:1.7;">
    <span leaf="">{{金句前段}}</span>
    <span style="border-bottom:2px solid #1677FF;"><span leaf="">{{关键词}}</span></span>
    <span leaf="">{{金句收尾}}</span>
  </p>
</section>
```

## 3 本文看点（精选 3 个，不是全量目录）

```html
<section style="padding:0 10px 32px;">
  <p style="font-size:11px;color:#8C8C8C;margin:0 0 14px;letter-spacing:2px;"><span leaf="">本文看点</span></p>
  <table style="width:100%;border-collapse:collapse;">
    <tr>
      <td style="width:33%;vertical-align:top;background:#F5F5F5;border-top:2px solid #1677FF;padding:14px 10px;">
        <p style="font-size:11px;color:#8C8C8C;margin:0 0 6px;"><span leaf="">01</span></p>
        <p style="font-size:13px;font-weight:700;color:#1F1F1F;margin:0;line-height:1.5;"><span leaf="">{{看点一}}</span></p>
      </td>
      <td style="width:33%;vertical-align:top;background:#F5F5F5;border-top:2px solid #1677FF;padding:14px 10px;">
        <p style="font-size:11px;color:#8C8C8C;margin:0 0 6px;"><span leaf="">02</span></p>
        <p style="font-size:13px;font-weight:700;color:#1F1F1F;margin:0;line-height:1.5;"><span leaf="">{{看点二}}</span></p>
      </td>
      <td style="width:33%;vertical-align:top;background:#F5F5F5;border-top:2px solid #1677FF;padding:14px 10px;">
        <p style="font-size:11px;color:#8C8C8C;margin:0 0 6px;"><span leaf="">03</span></p>
        <p style="font-size:13px;font-weight:700;color:#1F1F1F;margin:0;line-height:1.5;"><span leaf="">{{看点三}}</span></p>
      </td>
    </tr>
  </table>
</section>
```

## 4 章节标题（编号 + 左竖条）

```html
<section style="margin:36px 10px 20px;padding-bottom:12px;border-bottom:1px solid #F0F0F0;">
  <p style="font-size:11px;color:#8C8C8C;letter-spacing:2px;margin:0 0 6px;"><span leaf="">0{{N}} · {{EN_TAG}}</span></p>
  <h2 style="font-size:18px;font-weight:800;color:#1F1F1F;margin:0;padding-left:12px;border-left:4px solid #1677FF;line-height:1.4;">
    <span leaf="">{{中文章节标题}}</span>
  </h2>
</section>
```

子标题（`###`）：

```html
<p style="font-size:15px;font-weight:800;color:#1F1F1F;margin:24px 10px 12px;padding-left:10px;border-left:3px solid #1677FF;line-height:1.4;">
  <span leaf="">{{子标题}}</span>
</p>
```

## 5 正文段落（每段 1–3 个关键词下划线）

```html
<p style="margin:0 10px 18px;font-size:15px;line-height:1.8;text-align:justify;color:#434343;">
  <span leaf="">{{前半句}}</span>
  <span style="border-bottom:2px solid #1677FF;font-weight:600;color:#1F1F1F;"><span leaf="">{{关键短语 4-15 字}}</span></span>
  <span leaf="">{{后半句}}</span>
</p>
```

## 6 引用 / 金句 / 踩坑

金句竖条：

```html
<section style="border-left:3px solid #1677FF;padding:14px 0 14px 18px;margin:0 10px 24px;">
  <p style="font-size:15px;font-weight:700;color:#1F1F1F;margin:0;line-height:1.7;">
    <span leaf="">「{{核心观点}}」</span>
  </p>
</section>
```

踩坑 NOTE：

```html
<section style="background:#F5F5F5;border-top:2px solid #1F1F1F;padding:16px 18px;margin:0 10px 24px;">
  <p style="font-size:11px;color:#8C8C8C;margin:0 0 8px;letter-spacing:2px;"><span leaf="">NOTE</span></p>
  <p style="font-size:14px;color:#434343;margin:0;line-height:1.8;"><span leaf="">{{边界 / 坑 / 不适用场景}}</span></p>
</section>
```

橙点睛提示（全篇 ≤3）：

```html
<section style="border-left:3px solid #FA8C16;padding:12px 0 12px 18px;margin:0 10px 20px;">
  <p style="font-size:14px;font-weight:700;color:#1F1F1F;margin:0;line-height:1.8;"><span leaf="">{{最需注意的一句}}</span></p>
</section>
```

## 7 深色代码块（每行一个 p，不用 white-space:pre）

```html
<section style="margin:0 10px 20px;border-radius:8px;overflow:hidden;background:#1E293B;">
  <section style="padding:8px 14px;background:#0F172A;">
    <span style="font-size:12px;color:#64748B;font-family:Consolas,Monaco,monospace;"><span leaf="">bash</span></span>
  </section>
  <section style="padding:12px 14px;">
    <p style="margin:0;font-family:'SF Mono',Consolas,Monaco,monospace;font-size:13px;line-height:1.6;color:#E2E8F0;"><span leaf="">node cwork.js --tool auto</span></p>
  </section>
</section>
```

行内代码：

```html
<span style="background:#F5F5F5;color:#1677FF;padding:1px 6px;border-radius:4px;font-family:'SF Mono',Consolas,Monaco,monospace;font-size:13px;"><span leaf="">SKILL.md</span></span>
```

## 8 信息卡 / GitHub 卡（纯色，不用渐变）

```html
<section style="background:#1677FF;color:#fff;padding:18px 20px;border-radius:8px;margin:0 10px 24px;">
  <p style="margin:0 0 8px;font-size:16px;font-weight:700;"><span leaf="">📦 {{项目名}}</span></p>
  <p style="margin:0 0 6px;opacity:0.95;"><span leaf="">{{一句话定位}}</span></p>
  <p style="margin:0;font-size:13px;"><span leaf="">🔗 {{GitHub 地址}}</span></p>
</section>
```

## 9 对比（table 嵌套，禁用 flex 双栏）

```html
<table style="width:100%;border-collapse:collapse;margin:0 0 24px;">
  <tr>
    <td style="width:50%;padding:16px;background:#FFF1F0;vertical-align:top;">
      <p style="margin:0 0 8px;font-weight:700;color:#1F1F1F;"><span leaf="">😅 改前 / 裸用</span></p>
      <p style="margin:0;color:#434343;line-height:1.7;"><span leaf="">要点一</span><br><span leaf="">要点二</span></p>
    </td>
    <td style="width:50%;padding:16px;background:#F6FFED;vertical-align:top;">
      <p style="margin:0 0 8px;font-weight:700;color:#1F1F1F;"><span leaf="">😎 改后 / 方案</span></p>
      <p style="margin:0;color:#434343;line-height:1.7;"><span leaf="">要点一</span><br><span leaf="">要点二</span></p>
    </td>
  </tr>
</table>
```

## 10 STEP 实战步骤

```html
<section style="margin:0 10px 20px;">
  <p style="margin:0 0 8px;">
    <span style="display:inline-block;background:#1F1F1F;color:#fff;font-size:11px;font-weight:700;padding:2px 8px;border-radius:3px;"><span leaf="">STEP 01</span></span>
    <span style="font-size:15px;font-weight:800;color:#1F1F1F;margin-left:8px;"><span leaf="">{{步骤标题}}</span></span>
  </p>
  <p style="font-size:15px;color:#434343;margin:0;line-height:1.8;"><span leaf="">{{步骤说明，可跟代码块}}</span></p>
</section>
```

## 11 分割线 / 结尾 CTA

```html
<section style="padding:8px 10px 24px;">
  <section style="height:1px;background:#F0F0F0;"><span leaf=""><br></span></section>
</section>
```

```html
<section style="margin:0 10px 28px;padding:18px 20px;background:#F5F5F5;border-radius:6px;">
  <p style="margin:0 0 8px;font-weight:700;color:#1F1F1F;"><span leaf="">一句话总结</span></p>
  <p style="margin:0 0 12px;color:#434343;line-height:1.8;"><span leaf="">{{总结}}</span></p>
  <p style="margin:0;font-size:13px;color:#8C8C8C;"><span leaf="">觉得有用？欢迎点赞、在看、转发。评论区聊聊你的实践。</span></p>
</section>
```

## 12 图片

```html
<section style="margin:0 10px 8px;">
  <span leaf=""><img src="图片URL" style="max-width:100%;height:auto;display:block;margin:0 auto;"></span>
</section>
<p style="font-size:12px;color:#8C8C8C;text-align:center;margin:0 0 24px;"><span leaf="">— {{图注，无则删整行}}</span></p>
```

> 写入编辑器时：本地图**不能**用本地 path 塞进 src；用编辑器「插入图片」上传后，微信生成的 `mmbiz.qpic.cn` URL 才可进正文。

---

## 装配顺序（默认骨架）

1. 全局容器  
2. 引言卡  
3. 本文看点（≥3 章时）  
4. 信息卡（开源/产品时）  
5. 章节 × N（标题 → 正文下划线 → 代码/对比/STEP/NOTE）  
6. 一句话总结 CTA  
7. 分割线

## 实战导向硬约束（内容层，配合 tech-writer）

- 每个技术方案必须有：**场景 → 做法 → 数据/结果 → 边界/坑**。
- 禁止只讲「我们用了 XX」不讲「为什么不用 YY」。
- 数字必须具体（耗时、QPS、错误率、人天）；禁止「大幅提升」。
- 教程类必须可跟着敲：命令可复制、步骤有 STEP 编号。
