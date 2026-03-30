# OA端与Service端架构规则文档（ANew调用机制）

本文件为 **OA 端与 Service 端对接与开发说明**（双端架构、ANew 映射、目录模板、禁止项与清单）。Cursor / Claude Code 及子代理（oa-agent、service-agent）以本文与 `.cursor/rules/project-rule.mdc` 为准互补：细节与示例以本文为主，门禁与委派策略以 project-rule / agents 为主。

## Project Overview

东审 OA (Office Automation) — 双系统架构：

1. **OA 端**（`D:\MYOA\webroot`）：旧版 PHP 5.2
    - GBK 编码
    - Layui + jQuery
    - MySQL 5.6
    - 职责：页面展示、交互、表单提交

2. **Service 端**（`D:\39.102.37.69\puyueheng`）：PHP 7.2 + ThinkPHP 6
    - UTF-8 编码
    - ThinkPHP 6 + Redis + MySQL 5.6
    - 职责：数据模型、业务逻辑、复杂计算、外部服务
    - 通过各模块 **`Export.php`** 对 OA 暴露能力（ANew 入口）

## Dual-System Architecture

```
+--------------------------- OA 端 (PHP 5.2) ---------------------------+
| 页面展示、用户交互、表单提交                                             |
| 技术：PHP、Layui、jQuery                                                |
| 关键：经 ANew() 调用 Service，不在 OA 内直接维护 Model/重业务            |
+----------------────────────────────────────────────────────────-------+
                              |
                         ANew('path')
                              v
+------------------------ Service 端 (PHP 7.2 + TP6) -------------------+
| 数据模型、业务逻辑、复杂计算                                             |
| 技术：ThinkPHP 6、Redis、GuzzleHttp 等                                 |
| 关键：每模块 Export.php 作为门面，供 ANew 调用                          |
+-----------------------------------------------------------------------+
```

## ANew() Usage Pattern

### Path Mapping Rule

```php
ANew('oa/businesstype/subscription_center')
// 映射到物理文件：
// D:\39.102.37.69\puyueheng\service\service-app\src\service\oa\businesstype\subscription_center\Export.php
```

**映射公式：**

```
ANew('a/b/c')  =>  service-app/src/service/a/b/c/Export.php
```

（即：`src/service/` + 路径片段 + `/Export.php`。）

### Export.php is Required

每个 Service 业务模块 **必须** 提供 `Export.php` 作为门面，作为 ANew() 的唯一约定入口。

## Service Directory Structure（service-app）

```
service/oa/module_name/feature_name/
├── Export.php          # 必选：门面，ANew() 入口
├── Error.php           # 必选：错误码
├── model/              # ThinkPHP 模型
│   └── XxxModel.php
├── logic/              # 业务实现
│   ├── XxxImpl.php
│   └── YyyService.php
└── validate/           # 校验器（增改必选）
    └── XxxValidate.php
```

## Development Rules

### OA 端（`D:\MYOA\webroot`）

**文件编码：** 业务源码使用 **GBK**。

**新建 PHP 文件头示例：**

```php
<?php
/**
 * 文件功能描述
 * @filesource 文件名.php
 * @author: puyueheng
 * @date: 当前时间
 * @copyright Copyright(c)2020-2021,dscpa.cn. All Rights Reserved
 */
```

**中文参数：** `helper/Charset.php`，例如：

```php
include_once 'helper/Charset.php';
$_GET = Charset::iconvArr($_GET);
```

**接口返回：** `helper/Api.php`

```php
include_once 'helper/Api.php';
Api::suc($data);        // 成功
Api::err('错误信息');    // 失败
```

**接口异常：** `helper/ExceptionHandler.php`

```php
include_once 'helper/ExceptionHandler.php';
$e = new ExceptionHandler();
$e->init();
// 由统一处理器捕获，接口文件不必大段 try-catch
```

**调用 Service：**

```php
include_once 'inc/auth.php';      // 鉴权
include_once 'helper/alias.php';  // ANew 加载

$service = ANew('oa/module/feature');
$result = $service->methodName($params);
```

### Service 端（`D:\39.102.37.69\puyueheng`）

**文件编码：** **UTF-8**。

**Export.php 模板：**

```php
<?php
namespace app\service\oa\module\feature;

use app\service\oa\module\feature\logic\XxxImpl;

class Export
{
    public function methodName($param): returnType
    {
        return XxxImpl::methodName($param);
    }
}
```

**Model 模板：** 见仓库既有约定；须设置 `$name`、`$connection`（如 `td_oa`）等。

**Logic：** 增改数据须经 **Validate**；业务异常使用 `lib\exception\Exception` 与模块 `Error` 码。

**Exception：**

```php
use lib\exception\Exception;

throw Exception::user(Error::ERROR_CODE, 'message');  // 用户/业务可理解错误
throw Exception::system('message');                   // 系统错误
throw Exception::args();                              // 参数错误
```

## Prohibited Practices

### OA 端

1. **禁止在 OA 直接操作 Model** — 通过 `ANew(...)` 调 Service。
2. **禁止在 OA 新建 Model 类** — Model 只在 Service 维护。
3. **禁止在 OA 堆复杂业务** — 下沉到 Service。
4. **禁止滥用原生 SQL** — OA 侧用项目规定的 `helper/db.php` 等封装；复杂查询在 Service ORM/Service 层封装。
5. **禁止业务里直接 `include_once` Model** — 使用 Service/ANew 约定路径。

### Service 端

- 禁止在业务层散落不可维护的裸 SQL；对外保持 Export 门面一致。
- 增改数据必须经过 Validate（与项目 checklist 一致）。

## Code Style（双端共性摘要）

- 命名：变量 camelCase，类 PascalCase。
- Service 端增改须验证器；OA 端须校验外部输入。
- 架构：与现有仓库一致（含「高耦合、低内聚」等团队表述时，以 codebase 为准）；公共逻辑独立模块。
- 避免循环内操作数据库（除非必要）；DRY；关键注释；控制无意义空行。
- 前后端分离：**一页逻辑对应一个接口**；避免多前端随意共用一个接口。
- 错误信息友好，不暴露敏感细节。
- **Service 统一抛异常；OA 接口层用 ExceptionHandler 呈现友好错误。**

## Constants

Service 端常量：`D:\39.102.37.69\puyueheng\framework\com-lib\src\constant`

## Queue Operations（示例）

- Job 示例：`service\service-api\app\job\qc\UpdateStepSponsorQueue.php`
- 投递示例：`service\service-app\src\service\oa\qc\logic\QcwordImpl.php` 的 `updateStepSponsor` 等（经 Export、ANew、队列消费端一致实现）

## Development Checklist

### Service 端

- [ ] `Export.php` 命名空间与路径正确
- [ ] `Error.php` 错误码
- [ ] `model/` 且 `$connection` 等于项目约定
- [ ] `logic/` 实现
- [ ] `validate/` 且 create/update 场景齐全
- [ ] 公共方法参数/返回值类型清晰
- [ ] 业务错误 `Exception::user(...)`；必要时 `Log::notice()` 等

### OA 端

- [ ] `inc/auth.php` 鉴权（按页面需要）
- [ ] `helper/auth_login.php` 登录鉴权（`helper/auth_login.php`和`inc/auth.php`二选一引用）
- [ ] `general/ds/script/base.php` 脚本文件（必引）
- [ ] `helper/alias.php` 以使用 ANew
- [ ] 接口类初始化 `ExceptionHandler`
- [ ] 通过 ANew 获取 Service，不写直连 Model/重逻辑
- [ ] 入参校验（空、类型、范围）
- [ ] JSON 使用 `Api::suc` / `Api::err`
- [ ] 不直接使用数据库与 Model

## Architecture Principles

1. **职责分离：** OA = 展示与交互；Service = 业务与数据访问。
2. **统一入口：** 模块能力经 `Export.php` 暴露；Export 委托 logic。
3. **路径一致：** `ANew('a/b/c')` 严格对应 `src/service/a/b/c/Export.php`。
4. **Model 只在 Service：** OA 不直接使用 Model。
5. **异常：** Service 抛统一异常；OA 用 ExceptionHandler 接住并返回友好提示。
6. **传参与返回：** OA 多传 int/string/array；Service 返回结构化 array 等。

## When Uncertain

**先提问，不要假设。**

仅当用户明确要求「只输出代码」时，回复可只含代码。