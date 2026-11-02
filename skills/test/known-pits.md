> **按需优先加载**：写 plan / 点操作失败排障时先 Read 本文件（≤1 屏），再决定要不要翻完整 `web-test.md`。
> 本表是**硬结论**——命中即采用，禁止用浏览器连试「重新发现」。

# Web 测试已知坑速查（强制采用）

## 点击通道（OMP / YKC）

| 场景 | 强制 action | 禁止 | 根因 |
|------|-------------|------|------|
| OMP 列表页「筛选 / 查询 / 搜索」按钮（筛选区展开后） | **`dispatchClick`**（可加 `matchText`） | 先 `click` / `clickCdp` 试一轮 | top-tip 横幅盖住按钮行，CDP/ego 点在横幅上，请求不发（OMJF-19967 46min 盲试） |
| YKC 登录页协议勾选框 | **`clickCdp`** | JS/`click` 合成 | 自定义 Vue checkbox，合成 click 不改状态 |
| el-date-picker 打开面板 | **`openDatePicker`** | click/clickCdp | focus 不落地，面板打不开 |
| 被遮挡但仍是标准 `@click` 按钮 | `dispatchClick` | 连环换坐标 | 同横幅坑 |

## 断言 / 等待

| 场景 | 强制写法 | 禁止 |
|------|----------|------|
| 登录成功 | `waitForUrl` / `assertUrl` | aiAssert / 按钮灰 / idle 凑数 |
| 筛选/提交后验接口 | 操作后直接 `assertApi`（水位线+短轮询已内置） | 再堆多个 `waitForNetworkIdle` |
| 菜单删除 / 下线路由 / 文案回链消失 | `assertText expectNotContains` | 只靠 aiAssert 截图 |
| 表单 input 填值校验 | `assertText`（读 `.value`） | 指望 `textContent` |
| 单场景 idle | ≤2 个 `waitForNetworkIdle` | ≥3（validatePlan 拒绝） |
| navigate 后断言 | 中间加 `waitForUrl`/`waitForElement` | navigate 紧跟 assert* |

## 探索止损（Agent 强制，防 46 分钟盲试）

1. **写 plan 前**：本表命中场景直接采用对应 action，**不要**先用错误通道跑一遍再改。
2. **操作不生效第 1 次**：只允许一次 `--snapshot`（或截图+目标 outerHTML）；对照本表换通道；**禁止**无观察连试。
3. **同一 selector / 同一按钮第 2 次仍无效**：必须查本地组件源码（若有）或标该步骤思路；仍禁止再开完整多场景重跑当探针。
4. **第 3 次无效**：步骤/场景标 **BLOCKED**，写卡点（截图+已试通道），**继续后续场景**；全局禁止为同一目标再开浏览器探针。
5. **探针 heredoc**：仅 `--snapshot` 表达不了的单点观察；单 heredoc、只读、timeout≤60s；禁止用「完整 plan + 3～8 分钟 timeout」当探索手段。
6. **怀疑执行器 bug**：先用最小复现（1 场景、≤5 步）；确认后再改源仓库——禁止在业务排障中途连环改执行器+全量重跑。
