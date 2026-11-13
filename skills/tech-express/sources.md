# 科技速递 · 消息源清单与检索策略

全球并重：中文源与英文源各承担约一半入选条目。

---

## 一、领域 × 源矩阵

检索按 7 个领域展开，每个领域**中/英各至少 1 次查询**。

| 领域标签 | 中文首选 | 英文首选 |
|---------|---------|---------|
| `AI·芯片` | 量子位 qbitai.com、机器之心 jiqizhixin.com、快科技 mydrivers.com | TechCrunch techcrunch.com（AI）、SemiAnalysis semianalysis.com、Tom's Hardware tomshardware.com |
| `智能硬件` | IT之家 ithome.com、爱范儿 ifanr.com、雷科技 leikeji.com | The Verge theverge.com、9to5Mac 9to5mac.com、Ars Technica arstechnica.com |
| `互联网平台` | 36氪 36kr.com、虎嗅 huxiu.com、极客公园 geekpark.net | TechCrunch、The Information（付费墙，只用搜索快照）、Axios axios.com |
| `新能源·智造` | 智能车参考、第一电动 d1ev.com、高工锂电、财联社 汽车线 | Reuters Autos、Electrek electrek.co、Nikkei Asia asia.nikkei.com |
| `出海·跨境` | 36氪出海、界面新闻 jiemian.com、亿邦动力 ebrun.com | Reuters Technology、SCMP scmp.com、Nikkei Asia |
| `政策·监管` | 工信部 miit.gov.cn、商务部 mofcom.gov.cn、市场监管总局 samr.gov.cn、财联社电报 cls.cn | Reuters、Bloomberg bloomberg.com、欧盟委员会 digital-strategy.ec.europa.eu、美国 BIS bis.doc.gov |
| `资本·并购` | 投中网 chochina.com、IT桔子 itjuzi.com、第一财经 yicai.com | Bloomberg、CNBC cnbc.com（科技股）、Financial Times ft.com、Pitchbook（快照） |

**数据/出货量口径**（写数字时的引用源，别用自媒体二手数字）：IDC idc.com、Counterpoint counterpointresearch.com、Canalys canalys.com、TrendForce trendforce.com。

**快讯/滚动页**（值得直接 `WebFetch` 拉列表，命中率高于搜索）：
- 36氪快讯、虎嗅虎嗅早报、IT之家滚动新闻、财联社电报、爱范儿即时讯
- TechCrunch 首页、The Verge 新闻页、Ars Technica 首页、Reuters Technology 板块页

---

## 二、检索式模板

中文（把 `<D>` 换成绝对日期）：
```
"<媒体名或域名>" 科技 新闻 <D: YYYY年M月D日>
<D: YYYY年M月D日> <领域关键词> 发布/官宣/披露/上线
<公司或人物名> <D 或 D-1> <事件动词>
```

英文：
```
tech news <D: Month DD, YYYY> <topic> ("<chip export" OR "AI model" OR "acquisition">)
site:<media domain> <D: YYYY-MM-DD> <topic>
<D: Month D, YYYY> <company> announces/report/launches
```

**timeRange 用法（关键）**：
- `D == 真实当天` → 今日资讯查询用 `OneDay`，往日查询用 `OneWeek`。
- `D 是过去日期` → `OneDay/OneWeek` 是相对**真实当前时间**的过滤，会把 D 当天的消息全滤掉；此时一律 `NoLimit`，靠 query 里的绝对日期 + 打开原文核实发布日期来筛。

---

## 三、核实与降级规则

| 情况 | 处理 |
|------|------|
| `WebFetch` 打开原文成功，页上有发布日期 | 标「已核实」，可用原文数字与链接 |
| 原文需登录/付费墙（Bloomberg、FT、The Information、部分财联社深度） | 仅用搜索结果里的标题+摘要，正文写「据 <媒体> <日期> 报道」，标「快照」 |
| 站点直连失败/超时 | 换同源其它文章，或改抓聚合页；**不要**用记忆补全内容 |
| 只有社交媒体/转载无原始出处 | 不作为独立条目，最多作某条的补充说法，并注明出处层级 |
| 数字只有单一来源且存疑 | 正文加「据称/约」，或干脆不选该条 |

本机已验证的连通性事实（用于省掉无用尝试）：`mp.weixin.qq.com` 可直连并渲染登录页；`github.com` / `raw.githubusercontent.com` 在本环境 TCP 层不通，别把 GitHub 页面当消息源抓取，改用 WebSearch 摘要。

---

## 四、数量与配额

```
候选 25-40 条
├─ 今日资讯 5-8 条（海外 ≥2-3 条）
└─ 往日回顾 6-10 条（D-1 与 D-2 都要有，海外约占一半）
覆盖：7 个领域标签至少命中 5 个，单一领域不超过当日总条目的 40%
单一公司/单一人物不超过 3 条（避免速递变成某家公司日报）
```

配额只是底线，不是目标：**宁少不凑**。凑数的旧闻和标题党会直接拖垮评论部分的可信度。
