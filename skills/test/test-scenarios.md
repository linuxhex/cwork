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

## 小程序特有测试场景

| 场景 | 测试内容 | 实现方式 |
|------|---------|---------|
| **页面生命周期** | onLoad 参数接收、onShow 刷新、onHide 暂停、onUnload 清理 | `evaluate_script` 检查 data 状态 |
| **页面参数传递** | navigateTo 带 query 参数，目标页面 onLoad 接收 | `navigate_to({ path: "pages/xxx?param=val" })` |
| **分包加载** | 首次进入分包页面的加载耗时和正确性 | `navigate_to` + `wait_for({ timeout: 10000 })` |
| **TabBar 切换** | 5 个 Tab 页面间切换，页面状态保持 | `switch_tab` + `assert_text` |
| **页面栈管理** | 连续 navigateTo 不超 10 层，navigateBack 正确回退 | 循环 `navigate_to` + `navigate_back` |
| **下拉刷新** | 列表页下拉触发刷新，数据更新 | `evaluate_script` 触发 `onPullDownRefresh` |
| **登录态依赖** | 未登录时访问需登录页面，自动跳转登录页 | `relaunch` + `evaluate_script` 清除登录态 + `navigate_to` |
| **网络异常处理** | 接口超时/5xx 时页面展示错误提示 | 开发者工具 Network 面板模拟 + `assert_text` |
| **轮播图交互** | Swiper 自动播放 + 手动滑动 + 点击跳转 | `evaluate_script` 调用 `swiper.setCurrent()` |
| **长列表滚动** | ScrollView / 列表页上拉加载更多 | `evaluate_script` 设置 `scrollTop` + `wait_for` 新数据 |
| **web-view 页面** | 嵌套 H5 页面加载和交互 | `navigate_to` + `screenshot` 截图验证 |
