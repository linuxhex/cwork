# 统一代码规范（写代码强制约束）

## 概述

本文件是 cwork 所有写代码场景的**强制规范**。

**适用范围（强制）**：
- `cwork-implement` 阶段 4/6「执行计划」写代码前必须遵守本文件
- `cwork-bug` 阶段 4「修复代码」前必须遵守本文件
- 其余场景（cwork-test 自动修复、cwork-do 编排）通过联动 implement/bug 自动继承

## 一、命名规范（强制）

### 1.1 通用原则
- 命名贴近业务，知名见意，自解释
- 不使用不常用的简写缩写
- 不同场景使用对应后缀（VO/DTO/PO/DO）

### 1.2 工程目录命名
- 全小写，多单词不使用驼峰
- 不使用分隔符（-/_）
- 必须是包结构，不能是点号分隔的文件名

### 1.3 类命名
- 大驼峰命名法，首字母大写
- 通常不超过 20 个字符
- 以功能域后缀结尾（Controller/Service/DTO/VO/PO）
- 禁止带数字/特殊字符/old/new，尽量不用拼音

```java
// ✅ 正例
UserController、OrderService、StationDTO

// ❌ 反例
VehicleOrganization2Service、SaveAppUpgradeNewDTO、ShouqiController
```

### 1.4 方法命名
- 动词+名词组合，强调动作
- 通常不超过 30 个字符
- 以功能域后缀结尾

```java
// ✅ 正例
updateOrderStatus()、confirmBill()、getEndTime()

// ❌ 反例
dealOrder()、validOrder4Settle()、findOrgInfoByTypeNew()
```

### 1.5 变量命名
- 小驼峰命名
- 贴近业务含义
- 集合类型用复数形式

```java
// ✅ 正例
private List<String> stationIds;
private String operatorName;

// ❌ 反例
private String isNewUser;  // boolean 用 is 前缀
private String stationNameOld;  // 禁止 old/new
private Integer CarCompanyId;  // 首字母应小写
```

### 1.6 常量命名
- 全大写字母
- 单词间用下划线分隔

```java
// ✅ 正例
MAX_USER_COUNT = 100;
PLANT_TYPE = "plant_type";

// ❌ 反例
PAY-TYPE-PARENT = 1;  // 不能用连字符
park_order_parent = "8001";  // 不能小写
```

## 二、注释规范（强制）

### 2.1 核心原则
- 代码尽量自解释，注释是补充说明
- 注释不是代码的硬翻译
- 从业务层面说明，不是技术层面
- **修改代码必须同步修改注释**

### 2.2 类注释
只写类的功能和定位，不写 @author/@date 等无用信息

```java
// ✅ 正例
/**
 * 充电相关操作的 REST 接口入口
 */
@RestController
public class ChargeController { }

// ❌ 反例
/**
 * @author zhangsan
 * @date 2024-12-09
 */
@RestController
public class ChargeController { }
```

### 2.3 方法注释
- 从业务角度描述功能和使用注意事项
- 方法名足够说明则不需要注释
- 禁止列举入参等废话注释

```java
// ✅ 正例
/**
 * 有些申诉场景订单号可能已经在申诉中等状态，则不能重复申诉，不会查询到进行返回
 */
private List<String> queryNoAppealingOrderList(Integer appealType, List<String> tradeSeqList) { }

// ❌ 反例
/**
 * 设置登录后的电站价格展示
 *
 * @param target
 * @param stationPrice
 * @param vipPrice
 */
public static void setLoginPrice(...) { }
```

### 2.4 行内注释
- 说明业务逻辑，不是代码翻译
- 解释为什么这么做，不是做什么

```java
// ✅ 正例
// 新用户第一次登录时用户信息未初始化，设置默认等级为普通用户
if (userInfo == null) {
    userInfo = new UserInfo();
    userInfo.setLevel("NORMAL");
}

// ❌ 反例
// 判断是否为空
if (userInfo == null) {
    userInfo = new UserInfo();
}
```

## 三、基础编码规范

1. 遵循**阿里巴巴 Java 开发手册**
2. **禁止魔法数字**——业务数值提取为带业务含义的常量（如 `private static final int STATUS_PAID = 2;`）
3. 方法体不超过 **50 行**；条件嵌套不超过 **3 层**（用卫语句提前返回拉平）
4. 代码用空行按逻辑块分隔，提高可读性
5. 类长度不超过 **300 行**，超过考虑拆分
6. 每行代码不超过 **120 个字符**
7. 方法形参不超过 **5 个**，超过则封装为请求对象（DTO）

## 四、API 设计规范（强制）

### 4.1 路径规范
- RESTful 风格，动名词配合，动词在最后
- 全小写，中划线分隔（不用驼峰/下划线）
- 末尾不加 `/`
- RPC 接口路径带 `rpc` 标识

```
模板：POST /{版本}/[rpc]/{业务域}/{资源}/{动作}

// ✅ 正例
POST /v1/order/status/update
POST /v1/rpc/order/status/update
POST /base/user-station/list

// ❌ 反例
POST /order/status/Update  // 大写
POST /order/paymentWays    // 驼峰
POST /order/payment_ways   // 下划线
POST /base/selectAllBaseServerList2  // 带数字
POST /base/getTimeChargeNew  // 带 new
```

### 4.2 请求方式
- 尽量使用 POST（统一风格）
- 无入参的查询可用 GET
- 禁止使用 PUT/DELETE

### 4.3 出入参规范
- GET 方式：入参放 URL 路径（`@RequestParam`）
- POST 方式：入参放 body（`@RequestBody`）
- RPC 出参：使用 DTO 结尾（`XxxDTO`）
- REST 出参：使用 VO 结尾（`XxxVO`）

```java
// ✅ 正例
@GetMapping("/pile/list")
public ResponseEntity<PileVO> getPiles(@RequestParam String pileId) { }

@PostMapping("/pile/list")
public ResponseEntity<PileVO> getPiles(@RequestBody PileQueryRequest request) { }

// ❌ 反例
@GetMapping("/pile/list")
public ResponseEntity<PileVO> getPiles(@RequestBody String pileId) { }  // GET 不能用 @RequestBody
```

### 4.4 入参隔离原则
- 入参字段不出现联动组合
- A 字段的值不能决定 B 字段的含义
- 遇到联动场景，增加字段或拆分接口

```java
// ✅ 正例：拆分接口
@PostMapping("/password/login")
public ResponseEntity<UserDTO> loginByPassword(@RequestBody PasswordLoginRequest request) { }

@PostMapping("/phone/login")
public ResponseEntity<UserDTO> loginByPhone(@RequestBody PhoneLoginRequest request) { }

// ❌ 反例：联动字段
@PostMapping("/login")
public ResponseEntity<UserDTO> login(@RequestBody LoginRequest request) { }
// LoginRequest 中 loginType=1 时 account 是账号，loginType=2 时 account 是手机号
```

## 五、分包分层规范（强制）

### 5.1 工程模块划分
```
order/                      # 工程名称
├── order-api/              # 对外提供的 API Module
│   └── com.ykc.order.domain.api/    # 对外 API 接口
│   └── com.ykc.order.domain.sdk/    # 对外 SDK
├── order-dto/              # 服务基础依赖 Module
│   └── com.ykc.order.domain.constant/  # 常量/枚举
│   └── com.ykc.order.domain.dto/       # 数据传输对象
└── order-app/              # 核心业务 Module
    ├── config/             # 服务配置
    ├── common/             # 公共设施
    │   ├── constant/       # 服务内常量
    │   ├── exception/      # 异常码/自定义异常
    │   └── utils/          # 工具类
    └── com.ykc.order.domain/
        ├── infrastructure/ # 基础设施接口
        │   ├── notify/     # 通知/消息（XxxMqSend）
        │   ├── repository/ # 存储接口
        │   │   ├── mysql/  # MySQL 实现（OrderDO）
        │   │   └── es/     # ES 实现（OrderMap）
        │   └── rpc/        # RPC 客户端（XxxClient）
        ├── entity/         # 领域对象、枚举（OrderPO）
        ├── service/        # 领域服务
        │   └── order/      # 订单域服务
        │       ├── model/      # 业务模型
        │       ├── repo/       # 防腐层（OrderDBRepo/OrderRedisRepo）
        │       └── ability/    # 原子逻辑（XxxAbility）
        ├── component/      # 前端渲染组装/领域聚合
        └── interface/      # 服务暴露的端点
            ├── rest/       # REST 入口（XxxController）
            │   ├── request/    # 请求参数（XxxQuery/XxxForm）
            │   └── response/   # 响应参数（XxxVO）
            ├── rpc/        # RPC 入口
            ├── mq/         # 消息入口
            └── job/        # 定时任务入口
```

### 5.2 分层职责
- **api 层**：只包含接口定义，不包含实现，最小化依赖
- **dto 层**：提供给外部的常量和数据传输对象
- **app 层**：核心业务逻辑，按领域分包
- **infrastructure**：基础设施接口定义（存储/通知/RPC）
- **service**：领域服务，编排业务能力
- **interface**：对外暴露的端点（REST/RPC/MQ/JOB）

## 六、稳定性规范（强制）

### 6.1 强弱依赖区分
- **强依赖**：直接阻断程序运行，必须处理异常
- **弱依赖**：局部降级，不阻断主流程

```java
// ✅ 正例：强依赖
public StartChargeResultDTO clientCharge(ClientChargeForm form) {
    return ResponseEntityUtils.getDataThrowExp(startStopChargeFeign.clientCharge(form));
}

// ✅ 正例：弱依赖（使用注解或 try-catch 降级）
@WeakMethod
public StopChargeResultDTO stop(StopChargeForm form) {
    return ResponseEntityUtils.getDataThrowExp(startStopChargeFeign.stop(form));
}

// 或显式 try-catch
public StopChargeResultDTO stop(StopChargeForm form) {
    try {
        return ResponseEntityUtils.getDataThrowExp(startStopChargeFeign.stop(form));
    } catch (Exception e) {
        log.warn("停充弱依赖降级", e);
        return null;
    }
}
```

### 6.2 NPE 零容忍
一切使用指针/引用/句柄等操作，都必须先判空或使用 Optional

```java
// ✅ 正例 1：判空
if (data.getMemberInfo() != null) {
    memberInfo.setExpireDate(data.getMemberInfo().getExpireTime());
}

// ✅ 正例 2：Optional（推荐）
memberInfo.setExpireDate(
    Optional.ofNullable(data.getMemberInfo())
        .map(MemberInfo::getExpireTime)
        .orElse(null)
);
```

### 6.3 越界判断
使用集合按下标取数据前，必须先判断集合长度

```java
List<AccountInfo> accountInfos = strategy.doLoginCheck(loginForm);

// ✅ 正例：先判断非空
BaseAssert.notEmpty(accountInfos, CommonResultStatus.SYSTEM_BUSY);
AccountInfo account = accountInfos.get(0);

// ❌ 反例：直接取
AccountInfo account = accountInfos.get(0);  // 可能 IndexOutOfBoundsException
```

### 6.4 Integer 比较
Integer 存在小值缓存（-128~127），比较必须用 `Objects.equals()`

```java
Integer a = 128;
Integer b = 128;

// ❌ 反例
if (a == b) { }  // false，超出缓存范围

// ✅ 正例
if (Objects.equals(a, b)) { }
```

### 6.5 ThreadLocal 使用
- 使用 `InheritableThreadLocal` 支持子线程继承
- 使用 `ThreadLocal.withInitial()` 初始化
- **使用完必须 `remove()`**，防内存泄漏

```java
ThreadLocal<Integer> threadLocal = ThreadLocal.withInitial(() -> 0);
try {
    threadLocal.set(someValue);
    // 使用变量
} finally {
    threadLocal.remove();  // 必须清理
}
```

### 6.6 线程安全
- 尽量不使用全局变量
- 进程内使用 `java.util.concurrent.atomic` 原子类
- 跨进程使用 Redis 分布式锁
- 锁粒度尽量小
- 控制锁的竞争超时和可重入性

### 6.7 类型比较
不同类型不能直接用 `equals` 比较（地址不同永远 false）

```java
// code 是 String "1"，status 是 Integer 1
// ❌ 反例
if (ViewGunStatus.FAULT.getCode().equals(result.getStatus())) { }  // 永远 false

// ✅ 正例
if (Objects.equals(String.valueOf(ViewGunStatus.FAULT.getCode()), String.valueOf(result.getStatus()))) { }
```

## 七、性能规范（强制）

### 7.1 资源释放
及时释放不再使用的资源（流/连接），使用 try-with-resources

```java
// ✅ 正例
try (BufferedReader reader = new BufferedReader(new FileReader(filePath))) {
    // 使用 reader
} catch (IOException e) {
    log.error("读取文件失败", e);
}

// ❌ 反例
BufferedReader reader = null;
try {
    reader = new BufferedReader(new FileReader(filePath));
    // 使用 reader
} finally {
    if (reader != null) {
        reader.close();  // 手动关闭，可能遗漏
    }
}
```

### 7.2 代码嵌套深度
循环/递归中必须控制嵌套深度，防止栈溢出

```java
// ✅ 正例
public long factorial(int n) {
    if (n > 100) {  // 深度控制
        throw new IllegalArgumentException("n 过大");
    }
    if (n == 0) {  // 收敛控制
        return 1;
    }
    return n * factorial(n - 1);
}

// ❌ 反例
public long factorial(int n) {
    return n * factorial(n - 1);  // 无深度控制，可能 StackOverflow
}
```

### 7.3 循环体内禁止打印日志
批量日志汇总后一次性打印，减少 IO 操作

```java
// ✅ 正例
public void printList(List<String> list) {
    StringBuilder sb = new StringBuilder();
    for (String item : list) {
        sb.append(item).append("\n");
    }
    log.info("列表内容：\n{}", sb.toString());  // 一次性打印
}

// ❌ 反例
public void printList(List<String> list) {
    for (String item : list) {
        log.info(item);  // 循环体内打印，性能差
    }
}
```

### 7.4 多线程资源管理
- 基于 IO 密集/CPU 密集合理控制线程数
- 避免过度的锁竞争
- 使用并发容器代替互斥锁
- **禁止直接 new Thread()**，使用动态线程池

```java
// ✅ 正例：使用线程池
private final ExecutorService executorService = Executors.newCachedThreadPool();

public void processTasks(List<Runnable> tasks) {
    for (Runnable task : tasks) {
        executorService.submit(task);
    }
}

// ❌ 反例：直接创建线程
new Thread(() -> {
    // 任务逻辑
}).start();
```

### 7.5 避免复杂流处理
- 流的链式操作调试困难
- 复杂流操作可能不如传统循环高效
- 大数据量场景谨慎使用 Stream API

## 八、防御式编程（强制）

### 8.1 输入验证
函数入口处验证输入有效性

```java
public void processUserInput(String username, String password) {
    if (username == null || username.isEmpty()) {
        throw new IllegalArgumentException("用户名不能为空");
    }
    if (password == null || password.length() < 8) {
        throw new IllegalArgumentException("密码长度不能小于 8 位");
    }
    // 业务逻辑
}
```

### 8.2 异常处理
- 使用异常处理机制捕获和处理错误
- 异常必须记录日志或重新抛出
- 禁止空 catch 块

```java
public String readFile(String filePath) {
    try {
        if (filePath == null || filePath.isEmpty()) {
            throw new FileNotFoundException("文件路径无效");
        }
        return Files.readString(Path.of(filePath));
    } catch (IOException e) {
        log.error("读取文件失败：{}", filePath, e);
        throw new BusinessException("文件读取失败", e);
    }
}
```

### 8.3 边界检查
数组/集合操作前检查边界

```java
public int getElement(int[] array, int index) {
    if (array == null) {
        throw new IllegalArgumentException("数组不能为空");
    }
    if (index < 0 || index >= array.length) {
        throw new IndexOutOfBoundsException("索引越界：" + index);
    }
    return array[index];
}
```

### 8.4 空值检查
使用对象前先检查是否为空

```java
public void processData(String data) {
    if (data == null) {
        throw new NullPointerException("数据不能为空");
    }
    log.info("处理数据：{}", data);
}
```

### 8.5 除零检查
除法运算前检查除数

```java
public double divide(double dividend, double divisor) {
    if (divisor == 0) {
        throw new ArithmeticException("除数不能为零");
    }
    return dividend / divisor;
}
```

### 8.6 关键日志记录
错误异常场景必须有日志

```java
public void performTask() {
    try {
        // 业务逻辑
    } catch (Exception e) {
        log.error("执行任务失败", e);  // 必须记录异常
        throw e;
    }
}
```

## 九、日志规范（强制）

### 9.1 日志框架
使用 Log4j2 或 SLF4J + Logback，禁止使用 `System.out`

### 9.2 日志级别
- `log.error()`：异常等重要错误
- `log.warn()`：一般错误信息
- `log.info()`：普通业务日志
- `log.debug()`：特殊情况观察

### 9.3 占位符输出
使用占位符，不使用字符串拼接

```java
// ✅ 正例
log.info("处理订单，userId: {}, orderId: {}", userId, orderId);

try {
    // 业务逻辑
} catch (Exception e) {
    log.error("处理订单异常，userId: {}", userId, e);  // 异常不加占位符
}

// ❌ 反例
log.info("处理订单，userId: " + userId);  // 字符串拼接
log.info("处理订单，userId: %s", userId);  // 格式化符号
```

### 9.4 业务含义
日志必须包含唯一业务标识（userId/orderId/tradeSeq 等）

```java
// ✅ 正例
log.info("渲染充值页面，userId: {}", userId);

// ❌ 反例
log.info("渲染充值页面运行到这了");  // 无业务标识
```

### 9.5 禁止提前序列化
不要在日志记录前将对象转为字符串

```java
// ✅ 正例
log.debug("当前时间：{}", now);  // 使用占位符，debug 级别不打印时不序列化

// ❌ 反例
String message = "当前时间：" + now.toString();  // 提前序列化
log.debug(message);
```

### 9.6 自定义对象 toString
自定义对象手动复写 `toString()`，打印关键字段

```java
public class RechargeRenderVO {
    private BigDecimal amount;
    private List<String> introduces;

    @Override
    public String toString() {
        return "RechargeRenderVO{" +
                "amount=" + amount +
                ", introduces=" + introduces +
                '}';
    }
}

// ✅ 正例
log.info("充值渲染，vo: {}", vo);  // 自动调用 toString

// ❌ 反例
log.info("充值渲染，vo: {}", JSONUtil.toJsonStr(vo));  // JSON 序列化，性能差
```

### 9.7 禁止直接用异常打印
```java
// ✅ 正例
try {
    // 业务逻辑
} catch (Exception e) {
    log.error("处理异常，userId: {}", userId, e);  // 完整异常信息
}

// ❌ 反例
try {
    // 业务逻辑
} catch (Exception e) {
    e.printStackTrace();  // 禁止
}

try {
    // 业务逻辑
} catch (Exception e) {
    log.error(e.getMessage());  // 只打印异常信息，缺少上下文
}
```

## 十、复用性规范（强制）

### 10.1 工具类复用
- 字符串处理：去除空格、大小写转换、时间格式化
- 数据类型处理：BigDecimal 比较、0 值判断、防空加减
- 日期时间处理：格式转换、天数间隔计算
- 上下文工具类：用户信息、设备信息、链路上下文

### 10.2 业务识别抽象
- 通用上下文：用户类型、账户类型、订单类型
- 业务标识：C 端用户/企业账户、个人钱包/企业钱包

### 10.3 设计模式应用
- **模板方法 + 策略模式**：通用代码放模板方法，变化部分用策略控制
- **工厂模式**：对象创建逻辑封装
- **单例模式**：全局唯一实例（注意线程安全）

## 十一、可读性与可维护性（强制）

### 11.1 统一命名风格
- 返回集合用复数形式：`getOrders()` 不是 `getOrderList()`
- boolean 类型用 `is` 前缀：`isCharged()` 不是 `checkCharged()`

### 11.2 结构布局
- 1 个 tab = 4 个空格
- 类和方法之间有 1 个 tab 缩进
- 每个逻辑块用空行分隔
- 多行语句操作符垂直对齐
- 方法参数垂直对齐

```java
// ✅ 正例
public class Example {
    
    public void process() {
        int a = 1;
        int b = 2;
        
        int sum = a + b +
                  c + 4 +
                  5 + 6;  // 操作符对齐
        
        someMethod(
            "param1",
            "param2",
            "param3"  // 参数对齐
        );
    }
    
    private void doSomething() {
        // 逻辑代码
    }
}
```

### 11.3 代码模块化
- 功能模块逻辑尽量收敛聚焦
- 业务需求变动时及时局部重构
- 保持代码满足 SOLID 原则，至少满足开闭原则

## 十二、禁用项清单（写代码时直接避开）

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
| `new Thread()` 直接创建线程 | 使用线程池（`ExecutorService`） |
| 全局可变变量 | 局部变量 / ThreadLocal / 原子类 |
| 复杂 Stream 链式操作（>5 步） | 拆分为多个简单操作或传统循环 |
| 循环体内打印日志 | 汇总后一次性打印 |
| 提前序列化对象打日志 | 使用占位符，让日志框架按需序列化 |

## 十三、数据传递约束（重点）

- **跨方法/跨服务传参和返回值禁止 `Map<String,Object>`**：必须定义 DTO（字段 + 业务注释）。Map 只允许出现在**方法内部局部变量**
- REST / RPC / MQ 消息体出入参一律 DTO，字段名与接口契约一致
- 违规示例与修正：
  ```java
  // ❌ 禁止：跨方法用 Map 传参（无类型约束、字段含义靠猜、改动无法编译期发现）
  public void createOrder(Map<String, Object> params) { ... }

  // ✅ 正确：定义 DTO，字段有类型有注释
  public void createOrder(OrderCreateRequest request) { ... }
  ```

## 十四、设计原则（写代码时自查）

- **单一职责**：一个类/方法只做一件事；类方法超过 20 个考虑拆分
- **DRY**：相同逻辑禁止复制粘贴，提公共方法
- **避免贫血模型**：状态判断/状态变更逻辑封装到实体或领域方法，不散落在 Service
- **异常必须处理**：不能吞，日志记录关键异常上下文（订单号/用户号等定位线索）
- **单次改动超过 300 行**：考虑拆分提交，一次 MR 只做一件事

## 十五、前端规范

- 遵循 `cwork-implement/design-guide.md`（Token 系统 / 无障碍 / 响应式 / 动效 / 文案）
- 组件内禁止硬编码颜色/字号，一律使用设计 token
- 命名：组件大驼峰、变量/函数驼峰、CSS 类 kebab-case

## 规范自查（推演/验证阶段执行）

cwork-implement 推演收敛、cwork-bug 推演验证阶段，必须对本次改动 diff 做以下自查，命中即修：

### 命名与注释
1. 类名/方法名/变量名是否符合命名规范（大驼峰/动词+名词/小驼峰）
2. 是否使用了 old/new/数字/拼音等禁用命名
3. 新增公共方法是否有业务注释（非废话注释）
4. 修改代码是否同步修改了注释

### 编码规范
5. diff 是否命中「禁用项清单」任一条
6. 是否引入魔法数字
7. 方法是否超过 50 行
8. 条件嵌套是否超过 3 层
9. 类长度是否超过 300 行
10. 方法参数是否超过 5 个

### 稳定性
11. 是否有 NPE 风险（未判空/未用 Optional）
12. 集合下标访问前是否判断长度
13. Integer 比较是否使用 `Objects.equals()`
14. ThreadLocal 使用后是否 `remove()`
15. 强弱依赖是否区分处理

### 性能
16. 资源（流/连接）是否使用 try-with-resources
17. 是否在循环体内打印日志
18. 是否直接 `new Thread()` 而非线程池
19. 日志是否使用占位符而非字符串拼接
20. 日志是否包含业务标识（userId/orderId 等）

### 数据传递
21. 跨方法/接口传参是否用了 `Map<String,Object>`（必须 DTO）
22. API 路径是否符合 RESTful 规范（小写/中划线/动名词）
23. 入参是否存在联动字段（应拆分接口）

### 设计原则
24. 是否满足单一职责原则
25. 是否存在重复代码（应提取公共方法）
26. 新增公共方法是否有业务注释
27. 重写方法是否加 `@Override`
28. 资源是否 try-with-resources

## 反模式

### 命名与注释
- 命名不贴近业务（`dealOrder()` 而非 `updateOrderStatus()`）
- 使用不常用缩写（`sec` 而非 `chargedTime`）
- 类名/方法名带 old/new/数字
- 注释是代码的硬翻译（`// 判断是否为空`）
- 修改代码不同步修改注释

### 编码规范
- 写代码前不读本规范（implement/bug 已在流程中强制引用，漏读即违规）
- 规范自查走过场（命中禁用项不修）
- 为了过规范把代码改复杂（规范是底线不是目标，与「避免过度工程」平衡）
- 魔法数字硬编码（`if (status == 2)` 而非 `if (status == STATUS_PAID)`）
- 方法体过长（>50 行）不拆分
- 条件嵌套过深（>3 层）不用卫语句

### 稳定性
- 不区分强弱依赖（所有 RPC 调用都当强依赖处理）
- NPE 零容忍意识不足（未判空直接使用）
- 集合下标访问前不判断长度
- Integer 用 `==` 比较而非 `Objects.equals()`
- ThreadLocal 使用后不 `remove()`
- 不同类型直接用 `equals` 比较

### 性能
- 资源不释放（流/连接未关闭）
- 循环体内打印日志
- 直接 `new Thread()` 而非线程池
- 日志字符串拼接而非占位符
- 提前序列化对象打日志
- 复杂 Stream 链式操作（调试困难）

### API 设计
- 路径不符合 RESTful 规范（大写/驼峰/下划线）
- 入参存在联动字段（A 的值决定 B 的含义）
- GET 请求用 `@RequestBody`
- POST 请求参数放 URL

### 分包分层
- 不按领域分包，按技术分层（所有 Controller 放一个包）
- API 模块包含实现逻辑
- DTO 模块依赖业务模块

### 防御式编程
- 不验证输入直接使用
- 空 catch 块吞异常
- 不记录异常日志
- 不检查边界条件

### 设计原则
- 一个类/方法做 multiple 事情（违反单一职责）
- 复制粘贴代码（违反 DRY）
- 贫血模型（状态判断散落在 Service）
- 单次改动超过 300 行不拆分
