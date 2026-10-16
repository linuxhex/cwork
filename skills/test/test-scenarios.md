# 充电小程序（YKC）常见测试场景模板

> agent 按需选用，按优先级分级。

## P0 核心流程

| 场景 | 页面路径 | 关键步骤 | 断言 |
|------|---------|---------|------|
| **手机号登录** | pages/login/login | 输入手机号 → 获取验证码 → 输入验证码 → 点击登录 | 跳转到首页 + 用户信息展示 |
| **微信一键登录** | pages/login/login | 点击微信登录按钮 → 授权 | 跳转到首页 + 用户信息展示 |
| **扫码充电** | pages/testExp/index | 点击扫码 → 扫码结果页 → 选择充电桩 → 确认下单 | 订单创建成功 + 跳转充电页 |
| **充电中状态** | pages/charge/charge | 进入充电中页面 | 充电功率/时长/费用实时更新 |
| **结束充电** | pages/charge/charge | 点击结束充电 → 确认 | 订单完成 + 费用展示 + 跳转订单详情 |
| **支付订单** | pages/order/pay | 选择支付方式 → 确认支付 | 支付成功 + 订单状态更新 |

## P1 重要功能

| 场景 | 页面路径 | 关键步骤 | 断言 |
|------|---------|---------|------|
| **首页展示** | pages/home/index/index | 打开首页 | 轮播图展示 + 推荐站点列表 + TabBar 可见 |
| **站点列表** | pages/home/citys/citys | 打开城市/站点列表 | 站点卡片展示 + 距离排序 + 下拉刷新 |
| **订单列表** | pages/order/index/index | 打开订单列表 | 订单卡片展示 + 状态筛选 + 上拉加载更多 |
| **订单详情** | pages/order/detail/detail | 进入订单详情 | 订单信息完整 + 充电明细 + 支付信息 |
| **个人中心** | pages/user/index/index | 打开个人中心 | 用户头像/昵称 + 余额 + 菜单列表 |
| **钱包/余额** | pages/user/wallet/index | 打开钱包 | 余额展示 + 充值入口 + 消费记录入口 |
| **充值流程** | pages/user/recharge/index | 选择金额 → 确认充值 → 支付 | 余额更新 + 充值记录生成 |

## P2 辅助功能

| 场景 | 页面路径 | 关键步骤 | 断言 |
|------|---------|---------|------|
| **设置页** | pages/user/settings/index | 打开设置 | 各设置项展示 + 退出登录按钮可见 |
| **消息列表** | pages/message/index | 打开消息 | 消息列表展示 + 未读标记 |
| **优惠券** | pages/user/coupon/index | 打开优惠券 | 优惠券列表 + 状态筛选 |
| **充电记录** | pages/user/card/consume-records/index | 打开消费记录 | 记录列表 + 时间筛选 |

## 小程序特有测试场景（plan 动作映射）

> 「plan 写法」列使用 mini-run.cjs 的 plan.json 动作词汇（navigate/back/click/input/callMethod/setData/evaluate/wait/expectPage/expectData/expectText/expectElement），选择器必须来自 `--snapshot` 实测。

| 场景 | 测试内容 | plan 写法 |
|------|---------|----------|
| **页面生命周期** | onLoad 参数接收、onShow 刷新、onHide 暂停、onUnload 清理 | `evaluate`（返回页面 data 状态）+ `expectData` 断言 |
| **页面参数传递** | navigateTo 带 query 参数，目标页面 onLoad 接收 | `navigate`（url 带 `?param=val`）+ `expectData` 断言接收值 |
| **分包加载** | 首次进入分包页面的加载耗时和正确性 | `navigate` + `wait 5000` + `expectPage` |
| **TabBar 切换** | 5 个 Tab 页面间切换，页面状态保持 | `navigate` `type:"switchTab"` + `expectPage`（TabBar 页必须 switchTab） |
| **页面栈管理** | 连续 navigateTo 不超 10 层，navigateBack 正确回退 | 循环 `navigate` + `back` + `expectPage` 验证回退目标 |
| **下拉刷新** | 列表页下拉触发刷新，数据更新 | `callMethod`（`{"method":"onPullDownRefresh"}`）+ `expectData` 断言刷新后数据 |
| **登录态依赖** | 未登录时访问需登录页面，自动跳转登录页 | `evaluate` 清 storage（`wx.clearStorageSync()`）+ `navigate` `type:"reLaunch"` + `expectPage` 登录页 |
| **轮播图交互** | Swiper 自动播放 + 手动滑动 + 点击跳转 | `wait` 等自动播放 + `expectData`（current 变化）+ `click` 圆点/图 + `expectPage` |
| **长列表滚动** | ScrollView / 列表页上拉加载更多 | `callMethod` 或 `evaluate` 触发加载（如 `onReachBottom`）+ `expectData` 断言列表长度增加 |
| **web-view 页面** | 嵌套 H5 页面加载 | 仅 `navigate` + `expectPage` 断言跳转；**web-view 内部 H5 元素 automator 不可达，交互场景标人工** |

> **网络异常场景（接口超时/5xx）不在 plan 里模拟**：mini-run.cjs 直连引擎的设计原则是「不 mock 任何 wx API」（mock 会污染业务请求，MCP 时代根因）。需弱网/断网场景时人工用开发者工具 Network 面板模拟，或在报告中标注未覆盖。

> ⚠️ **执行链路唯一**：测试执行一律 `mini-run.cjs --plan`（直连 automator，导航内部即 evaluate 调 `wx.*`，每操作 15s 超时 + 全局看门狗，无 MCP 挂起风险）。MCP 工具（`navigate_to`/`evaluate_script` 等）仅作探索降级备选，详见 mini-test.md；禁止用 MCP 跑测试——其导航类工具底层裸调 automator 回包丢失会永久挂起（实测：小程序一直加载中、点击无反应，只能重启开发者工具恢复）。
