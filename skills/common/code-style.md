# 统一代码规范（写代码强制约束）

## 概述

本文件是 cwork 所有写代码场景的**强制规范**。

**适用范围（强制）**：
- `cwork-implement` 阶段 4/6「执行计划」写代码前必须遵守本文件
- `cwork-bug` 阶段 4「修复代码」前必须遵守本文件
- 其余场景（cwork-test 自动修复、cwork-do 编排）通过联动 implement/bug 自动继承

## 一、基础规范

1. 遵循**阿里巴巴 Java 开发手册**
2. 方法命名驼峰、动词开头；类名大驼峰；常量全大写、下划线分隔
3. **禁止魔法数字**——业务数值提取为带业务含义的常量（如 `private static final int STATUS_PAID = 2;`）
4. 方法体不超过 **50 行**；条件嵌套不超过 **3 层**（用卫语句提前返回拉平）
5. 公共方法必须写业务注释（与 cwork 注释规范一致：业务视角、禁废话）
6. 代码用空行按逻辑块分隔，提高可读性

## 二、禁用项清单（写代码时直接避开）

| 禁用 | 替代方案 |
|---|---|
| `System.out.print` | `log.info / log.warn / log.error` |
| `e.printStackTrace()` | `log.error("业务描述", e)` |
| `Thread.sleep`（业务代码） | 定时任务 / 异步机制 / 重试框架 |
| `@Transactional` 用在非 public 方法 | 事务注解只放 public 方法（否则不生效） |
| `new SimpleDateFormat` | `DateTimeFormatter`（线程安全） |
| 空 catch 块 / catch 只写注释 | `log.error` 记录异常或重新抛出，禁止吞异常 |
| `Optional.get()` 未检查 | `orElse` / `orElseThrow` / `ofNullable` |
| `Arrays.asList(...)` 后 add/remove | `new ArrayList<>(Arrays.asList(...))` |
| `变量.equals("常量")` | `"常量".equals(变量)` 或 `Objects.equals`（防 NPE） |
| 方法参数超过 5 个 | 封装为请求对象（DTO） |
| 重写方法缺 `@Override` | 一律加 `@Override` |
| 资源对象（流/连接）手工 close | try-with-resources |

## 三、数据传递约束（重点）

- **跨方法/跨服务传参和返回值禁止 `Map<String,Object>`**：必须定义 DTO（字段 + 业务注释）。Map 只允许出现在**方法内部局部变量**
- REST / RPC / MQ 消息体出入参一律 DTO，字段名与接口契约一致
- 违规示例与修正：
  ```java
  // ❌ 禁止：跨方法用 Map 传参（无类型约束、字段含义靠猜、改动无法编译期发现）
  public void createOrder(Map<String, Object> params) { ... }

  // ✅ 正确：定义 DTO，字段有类型有注释
  public void createOrder(OrderCreateRequest request) { ... }
  ```

## 四、设计原则（写代码时自查）

- **单一职责**：一个类/方法只做一件事；类方法超过 20 个考虑拆分
- **DRY**：相同逻辑禁止复制粘贴，提公共方法
- **避免贫血模型**：状态判断/状态变更逻辑封装到实体或领域方法，不散落在 Service
- **异常必须处理**：不能吞，日志记录关键异常上下文（订单号/用户号等定位线索）
- **单次改动超过 300 行**：考虑拆分提交，一次 MR 只做一件事

## 五、前端规范

- 遵循 `cwork-implement/design-guide.md`（Token 系统 / 无障碍 / 响应式 / 动效 / 文案）
- 组件内禁止硬编码颜色/字号，一律使用设计 token
- 命名：组件大驼峰、变量/函数驼峰、CSS 类 kebab-case

## 规范自查（推演/验证阶段执行）

cwork-implement 推演收敛、cwork-bug 推演验证阶段，必须对本次改动 diff 做以下自查，命中即修：

1. diff 是否命中「禁用项清单」任一条
2. 跨方法/接口传参是否用了 `Map<String,Object>`（必须 DTO）
3. 是否引入魔法数字、方法超 50 行、嵌套超 3 层
4. 新增公共方法是否有业务注释
5. 重写方法是否加 `@Override`、资源是否 try-with-resources

## 反模式

- 写代码前不读本规范（implement/bug 已在流程中强制引用，漏读即违规）
- 规范自查走过场（命中禁用项不修）
- 为了过规范把代码改复杂（规范是底线不是目标，与「避免过度工程」平衡）
