---
title: "UVM 知识详解"
description: "UVM验证方法学详解，基于实例讲解"
pubDate: 2026-07-20
category: uvm
order: 1
tags: [UVM, 验证]
---

# UVM 知识详解

> 基于 `design.sv` 和 `testbench.sv` 实例讲解

---

## 1. UVM 是什么

**UVM (Universal Verification Methodology)** = 通用验证方法学

```
UVM = 一套标准 + 一套工具库 + 一套最佳实践

目的：让不同公司的验证环境可以复用
```

### 为什么需要 UVM

```
没有 UVM：
├── 每家公司自己写验证环境
├── 代码不通用
└── 复用性差

有 UVM：
├── 统一标准
├── 代码可复用
└── 大量现成组件
```

---

## 2. 如何调用 UVM 库

### 核心三行代码

```verilog
package adpcm_pkg;           // 第1步：创建一个包

import uvm_pkg::*;           // 第2步：导入 UVM 库（所有类）
`include "uvm_macros.svh"    // 第3步：导入 UVM 宏（所有宏）

// ... 你的 UVM 代码 ...

endpackage
```

### 逐行解释

#### 第 1 行：创建 Package

```verilog
package adpcm_pkg;
```

**作用：** 创建一个"文件夹"，把所有 UVM 组件放进去

```
package = 文件夹
class   = 文件

package adpcm_pkg;
    class driver ...;
    class sequence ...;
    class test ...;
endpackage
```

**为什么需要 package？**
- UVM 的类很多，需要组织
- 避免命名冲突
- 方便导入导出

---

#### 第 2 行：导入 UVM 库

```verilog
import uvm_pkg::*;
```

**作用：** 把 UVM 库里的所有类、函数、任务导入进来

**`*` 是什么意思？**

| 写法 | 效果 |
|---|---|
| `import uvm_pkg::*` | 导入所有（推荐） |
| `import uvm_pkg::uvm_test` | 只导入一个类 |
| `import uvm_pkg::uvm_driver` | 只导入一个类 |

**`::` 双冒号是什么？**

```
:: = 作用域运算符（表示"里面的"）

uvm_pkg::uvm_test
    ↑       ↑
  包名    类名
 (文件夹) (文件)

就像文件路径： 文件夹/文件
```

| 符号 | 名称 | 例子 |
|---|---|---|
| `::` | 双冒号 | `uvm_pkg::uvm_test`（包里的类） |
| `.` | 点 | `obj.method`（对象的方法） |

**导入后能用什么？**

```verilog
import uvm_pkg::*;

// 现在可以直接用这些类：
class my_test extends uvm_test;       // ✅ 不用写全名
class my_driver extends uvm_driver;   // ✅ 不用写全名

// 如果不 import，需要这样写：
class my_test extends uvm_pkg::uvm_test;  // ❌ 麻烦
```

**导入的常用类：**

| 类名 | 作用 |
|---|---|
| `uvm_test` | 测试用例基类 |
| `uvm_driver` | 驱动器基类 |
| `uvm_sequence` | 序列基类 |
| `uvm_sequencer` | 序列器基类 |
| `uvm_component` | 组件基类 |
| `uvm_object` | 对象基类 |
| `uvm_phase` | Phase 管理 |

---

#### 第 3 行：包含宏文件

```verilog
`include "uvm_macros.svh"
```

**作用：** 包含 UVM 的宏定义文件

**`` ` `` 反引号是什么？**

```
反引号（backtick）= 编译指令前缀

`include    ← 编译指令（告诉编译器"复制文件内容"）
'b1010       ← 字面量（二进制数）

键位：键盘左上角，Esc 下面那个键
```

| 符号 | 名称 | 用途 | 例子 |
|---|---|---|---|
| `` ` `` | 反引号 | 编译指令 | `` `include ``, `` `define `` |
| `'` | 单引号 | 字面量 | `'b1010`, `'hFF`, `'d255` |

**不写反引号会怎样？**
```verilog
include "uvm_macros.svh"    // ❌ 报错：找不到 include
`include "uvm_macros.svh"   // ✅ 正确：这是编译指令
```

**什么时候用反引号？**

```
简单规则：看到 ` 开头的 → 都要加反引号
```

| 类型 | 例子 | 说明 |
|---|---|---|
| **编译指令** | `` `include ``, `` `define ``, `` `ifdef `` | 告诉编译器做事 |
| **UVM 宏** | `` `uvm_object_utils ``, `` `uvm_info `` | UVM 提供的宏 |
| **自定义宏** | `` `MAX ``（用 `define MAX` 定义的） | 你自己定义的宏 |

```verilog
// 编译指令
`include "uvm_macros.svh"     // ✅ 包含文件
`ifdef SIMULATION              // ✅ 条件编译
`define WIDTH 8                // ✅ 定义宏

// UVM 宏
`uvm_object_utils(my_class)   // ✅ 注册到工厂
`uvm_info("TAG", "msg", UVM_LOW)  // ✅ 打印信息

// 自定义宏
`define MAX 100
parameter a = `MAX;            // ✅ 使用时也要加
```

**怎么判断？**
```verilog
// 看名字：如果是以 uvm_ 或 define 的宏 → 加反引号
`uvm_xxx(...)    // UVM 宏
`MY_MACRO        // 自定义宏

// 看位置：如果是编译指令 → 加反引号
`include "..."
`define X Y
`ifdef XXX
```

**什么是宏？**

```
宏 = 代码替换工具

`uvm_info("TAG", "消息", UVM_LOW)
    ↓ 展开后变成
$display("[UVM INFO] %s: %s", "TAG", "消息");
```

**常用宏：**

| 宏 | 作用 | 展开后 |
|---|---|---|
| `` `uvm_object_utils(T) `` | 注册类到工厂 | 创建 `type_id` |
| `` `uvm_component_utils(T) `` | 注册组件到工厂 | 创建 `type_id` |
| `` `uvm_info(tag, msg, level) `` | 打印信息 | `$display(...)` |
| `` `uvm_error(tag, msg) `` | 打印错误 | `$error(...)` |
| `` `uvm_fatal(tag, msg) `` | 打印致命错误 | `$fatal(...)` |
| `` `uvm_record_field(name, val) `` | 记录字段 | 波形记录 |

**宏 vs 函数的区别：**

```
宏（`uvm_info）：
  - 编译前替换
  - 可以打印行号、文件名
  - 不能断点调试

函数（$display）：
  - 运行时执行
  - 可以断点调试
  - 不打印行号
```

---

### 完整调用流程

```
编译器看到：
┌─────────────────────────────────────────────────┐
│ package adpcm_pkg;                              │
│ import uvm_pkg::*;           ← 加载 UVM 库      │
│ `include "uvm_macros.svh"    ← 加载 UVM 宏      │
│                                                 │
│ class adpcm_test extends uvm_test;  ← 用 UVM 类 │
│ `uvm_component_utils(adpcm_test);  ← 用 UVM 宏  │
│ endclass                                        │
│ endpackage                                      │
└─────────────────────────────────────────────────┘

↓ 展开后

┌─────────────────────────────────────────────────┐
│ // UVM 库内容（自动展开）                         │
│ class uvm_test; ... endclass                    │
│ class uvm_driver; ... endclass                  │
│ // UVM 宏内容（自动展开）                         │
│ `define uvm_object_utils(T) ...                 │
│                                                 │
│ // 你的代码                                      │
│ class adpcm_test extends uvm_test;              │
│ // 宏展开：创建 type_id 等                       │
│ endclass                                        │
└─────────────────────────────────────────────────┘
```

---

### 常见问题

#### Q1: 不写 import 会怎样？

```verilog
package my_pkg;
    // 没有 import uvm_pkg::*;
    
    class my_test extends uvm_test;  // ❌ 报错：找不到 uvm_test
    endclass
endpackage
```

#### Q2: 不写 `include 会怎样？

```verilog
package my_pkg;
    import uvm_pkg::*;
    // 没有 `include "uvm_macros.svh"
    
    `uvm_object_utils(my_test)  // ❌ 报错：找不到宏
endpackage
```

#### Q3: 为什么用 `*` 全部导入？

```
效率考虑：
  - import 全部：编译器一次加载
  - import 单个：多次加载，效率低
  
安全考虑：
  - UVM 库的类名都是唯一的
  - 不会和其他库冲突
```

#### Q4: package 和 module 的区别？

| 特性 | package | module |
|---|---|---|
| **目的** | 组织类和函数 | 定义硬件电路 |
| **有端口** | ❌ | ✅ |
| **会被综合** | ❌ | ✅ |
| **使用 class** | ✅ | ❌ |

---

### 本例的实际调用

```verilog
// testbench.sv 第 9-12 行
package adpcm_pkg;              // 创建包
import uvm_pkg::*;              // 导入 UVM 库
`include "uvm_macros.svh"       // 导入 UVM 宏

// 之后就可以用了
class adpcm_seq_item extends uvm_sequence_item;  // 用 UVM 类
class adpcm_driver extends uvm_driver #(adpcm_seq_item);  // 用 UVM 类

`uvm_object_utils(adpcm_seq_item)  // 用 UVM 宏
`uvm_component_utils(adpcm_driver)  // 用 UVM 宏

endpackage
```

---

### 总结

| 代码 | 作用 | 必须？ |
|---|---|---|
| `package xxx;` | 创建代码包 | ✅ |
| `import uvm_pkg::*` | 导入 UVM 所有类 | ✅ |
| `` `include "uvm_macros.svh" `` | 导入 UVM 所有宏 | ✅ |

**一句话：** 没有这三行，UVM 的类和宏都用不了。

---

## 3. UVM 架构总览

```
┌──────────────────────────────────────────────────┐
│                  Test (测试用例)                  │
│  ┌────────────────────────────────────────────┐  │
│  │           Environment (环境)               │  │
│  │  ┌──────────────────────────────────────┐  │  │
│  │  │         Agent (代理)                 │  │  │
│  │  │                                      │  │  │
│  │  │  Sequence ──→ Sequencer ──→ Driver ──│──│──│──→ Interface ──→ DUT
│  │  │                                      │  │  │
│  │  │              Monitor ←───────────────│──│──│←── Interface ←── DUT
│  │  └──────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

### 本例的架构

```
┌─────────────────────────────────────┐
│           adpcm_test                │
│                                     │
│   adpcm_tx_seq                      │
│        │                            │
│        ▼                            │
│   adpcm_sequencer                   │
│        │                            │
│        ▼                            │
│   adpcm_driver ──→ adpcm_if ──→ DUT │
└─────────────────────────────────────┘
```

---

## 3.1 UVM Component 关系详解

### Component 是什么？

```
Component = 有生命周期的"活的"组件

特点：
├── 有 build_phase（创建阶段）
├── 有 run_phase（运行阶段）
├── 有 parent（父组件）
├── 可以创建子组件
└── 仿真结束才销毁
```

### Component vs Object

| 特性 | Component | Object |
|---|---|---|
| **生命周期** | 整个仿真 | 用完即毁 |
| **有 parent** | ✅ 有层次 | ❌ 独立 |
| **有 Phase** | ✅ 完整 | ❌ 无 |
| **基类** | `uvm_component` | `uvm_object` |
| **例子** | Driver, Monitor, Test | Sequence Item |

```
类比：
  Component = 员工（长期在职，有上级）
  Object = 快递包裹（用完就扔）
```

### Component 层次结构

```
uvm_component                    ← 根（所有 component 的祖先）
    │
    ├── uvm_test                ← 测试用例
    │       │
    │       └── uvm_env         ← 环境
    │               │
    │               └── uvm_agent    ← 代理
    │                       │
    │                       ├── uvm_driver     ← 驱动器
    │                       ├── uvm_monitor    ← 监控器
    │                       └── uvm_sequencer  ← 序列器
    │
    └── uvm_scoreboard         ← 记分板
```

### Parent-Child 关系

```verilog
// 创建组件时，指定 parent
class my_test extends uvm_test;
    my_env env;
    
    function void build_phase(uvm_phase phase);
        // this = my_test（自己是 parent）
        env = my_env::type_id::create("env", this);  // env 的 parent 是 test
    endfunction
endclass

class my_env extends uvm_env;
    my_agent agent;
    
    function void build_phase(uvm_phase phase);
        // this = my_env（自己是 parent）
        agent = my_agent::type_id::create("agent", this);  // agent 的 parent 是 env
    endfunction
endclass
```

### 层次结构图

```
my_test (parent = null)
    │
    └── my_env (parent = my_test)
            │
            └── my_agent (parent = my_env)
                    │
                    ├── my_driver (parent = my_agent)
                    ├── my_monitor (parent = my_agent)
                    └── my_sequencer (parent = my_agent)

层级路径：
  my_driver 的全名 = "uvm_test_top.env.agent.driver"
```

### 为什么需要层次？

```
1. 仿真结束判断
   └── 所有 component 都结束 → 仿真结束

2. Phase 传播
   └── test.build_phase → env.build_phase → agent.build_phase → ...

3. 配置传递
   └── test 设置参数 → 子组件可以读取

4. 打印层次
   └── 便于调试，知道组件在哪个位置
```

### 本例的层次

```
top_tb                          ← 顶层模块（不是 component）
    │
    └── adpcm_test              ← component（parent = null）
            │
            ├── m_driver        ← component（parent = test）
            │
            └── m_sequencer     ← component（parent = test）

// testbench.sv 中的创建代码：
m_driver = adpcm_driver::type_id::create("m_driver", this);     // this = test
m_sequencer = adpcm_sequencer::type_id::create("m_sequencer", this);
```

### Component 的 Phase 顺序

```
uvm_test (顶层)
    │
    ├── build_phase          从 test 开始，向下传播
    │   └── test.build_phase
    │       └── env.build_phase
    │           └── agent.build_phase
    │               └── driver.build_phase
    │
    ├── connect_phase        从底层开始，向上传播
    │   └── driver.connect_phase
    │       └── agent.connect_phase
    │           └── env.connect_phase
    │               └── test.connect_phase
    │
    └── run_phase            所有 component 并行运行
        ├── driver.run_phase      ← 并行
        ├── monitor.run_phase     ← 并行
        └── sequencer.run_phase   ← 并行
```

### 常用 Component 类型

| 类型 | 作用 | 本例对应 |
|---|---|---|
| `uvm_test` | 测试用例，顶层控制 | `adpcm_test` |
| `uvm_env` | 环境，包含多个 agent | 本例没有 |
| `uvm_agent` | 代理，包含 driver/monitor/sequencer | 本例没有 |
| `uvm_driver` | 驱动器，产生时序 | `adpcm_driver` |
| `uvm_monitor` | 监控器，观察信号 | 本例没有 |
| `uvm_sequencer` | 序列器，调度 sequence | `adpcm_sequencer` |
| `uvm_scoreboard` | 记分板，比对数据 | 本例没有 |

### Component 注册

```verilog
// component 用这个宏注册
`uvm_component_utils(my_driver)

// object 用这个宏注册
`uvm_object_utils(my_sequence_item)

// 区别：
// component_utils → 创建时需要 parent
// object_utils → 创建时不需要 parent
```

### 总结

| 概念 | 说明 |
|---|---|
| **Component** | 有生命周期的活组件 |
| **Parent** | 创建时指定的父组件 |
| **层次** | component 形成树状结构 |
| **Phase** | 从 test 向下传播 |
| **并行** | run_phase 中所有 component 同时运行 |

---

## 4. 接口层 (Interface)

### design.sv 逐行解释

```verilog
interface adpcm_if;          // 第1步：定义接口（信号的"插座"）

logic clk;                   // 时钟信号
logic frame;                 // 帧同步信号（1=帧开始）
logic[3:0] data;             // 4位数据线
logic bozo;                  // 未使用的信号

clocking cb @(posedge clk);  // 第2步：时钟块（定义采样时刻）
    inout frame;             // frame 可读可写
    inout data;              // data 可读可写
endclocking

modport mon_mp (clocking cb); // 第3步：定义"监控端口"

endinterface
```

### 三个核心概念

| 概念 | 作用 | 本例 |
|---|---|---|
| **Interface** | 把信号打包成"插座" | `adpcm_if` |
| **Clocking** | 定义在哪个时钟沿操作信号 | `cb @(posedge clk)` |
| **Modport** | 定义不同角色的访问权限 | `mon_mp` |

### 时钟块的作用

```
没有 clocking（危险）：
  always @(posedge clk) data <= 1;  // 可能和其他模块竞争

有 clocking（安全）：
  clocking cb @(posedge clk);
      inout data;
  endclocking
  cb.data <= 1;  // 由 clocking 统一管理时序
```

---

## 4.1 Virtual Interface — 软件访问硬件的桥梁

### 为什么需要 Virtual Interface？

```
UVM 的两个世界：

软件世界（class）          硬件世界（interface）
├── Test                  ├── Design
├── Driver                ├── Signal
├── Monitor               ├── Clock
└── Sequence              └── Wire

问题：class 里不能直接放 interface
原因：interface 是编译时确定的硬件对象，class 是运行时创建的软件对象

解决：用 virtual interface 作为桥梁
```

### Virtual Interface 是什么？

```
Virtual Interface = 指向实际 interface 的"遥控器"

实际 interface（硬件）    Virtual Interface（软件指针）
┌──────────────────┐     ┌─────────────────────┐
│ logic clk;       │     │ virtual axi_if vif; │
│ logic [31:0] addr│ ←── │                     │
│ logic write;     │     │ 通过 vif 访问        │
└──────────────────┘     └─────────────────────┘
```

### 代码示例

**1. 定义硬件接口（编译时确定）：**
```verilog
interface adpcm_if;
    logic clk;
    logic frame;
    logic [3:0] data;
    
    clocking cb @(posedge clk);
        inout frame;
        inout data;
    endclocking
    
    modport mon_mp (clocking cb);
endinterface
```

**2. Driver 中使用 virtual interface（运行时绑定）：**
```verilog
class adpcm_driver extends uvm_driver;
    virtual adpcm_if.mon_mp ADPCM;  // 虚拟接口句柄
    
    function void build_phase(uvm_phase phase);
        // 从 config_db 获取实际接口
        uvm_config_db #(virtual adpcm_if.mon_mp)::get(
            this, "", "ADPCM_vif", ADPCM
        );
    endfunction
    
    task run_phase(uvm_phase phase);
        @(ADPCM.cb);  // 通过 vif 访问硬件信号
        ADPCM.cb.frame <= 1;
        ADPCM.cb.data <= 4'hA;
    endtask
endclass
```

**3. Top 模块中传递 interface（连接硬件和软件）：**
```verilog
module testbench;
    adpcm_if adpcm_if_inst();  // 创建实际接口实例
    
    initial begin
        // 把实际 interface 放入 config_db
        uvm_config_db #(virtual adpcm_if.mon_mp)::set(
            null, "*", "ADPCM_vif", adpcm_if_inst.mon_mp
        );
        run_test();
    end
endmodule
```

### 为什么需要它？

| 直接用 interface | 用 virtual interface |
|------------------|---------------------|
| class 里不能放 interface | class 里放 vif 指针 ✅ |
| 编译时绑定，不灵活 | 运行时绑定，可切换 DUT |
| 无法在多个 test 中复用 | 同一 driver 可连不同 interface |

### 简单类比

```
实际 interface = 电视机（硬件实体）
Virtual Interface = 遥控器（操作电视的工具）

你不能把电视塞进 class 里
但你可以把遥控器放进 class 里
通过遥控器操作电视
```

### 关键点

- `virtual axi_if vif;` — 声明虚拟接口（指针）
- `uvm_config_db#(virtual axi_if)::get(...)` — 获取实际接口
- `uvm_config_db#(virtual axi_if)::set(...)` — 设置实际接口
- 通过 `vif.signal` 访问硬件信号

---

## 5. 事务层 (Sequence Item)

### testbench.sv 第 17-72 行

```verilog
class adpcm_seq_item extends uvm_sequence_item;

    rand logic[31:0] data;    // 32位数据（随机生成）
    rand int delay;           // 发送前延迟（随机生成）

    constraint c_delay { delay > 0; delay <= 20; }  // 约束：1-20

    // 以下都是 UVM 需要的固定写法
    `uvm_object_utils(adpcm_seq_item)   // 注册到工厂

    function new(string name = "adpcm_seq_item");
        super.new(name);                // 调用父类构造函数
    endfunction

    function void do_copy(uvm_object rhs);     // 拷贝功能
        adpcm_seq_item rhs_;
        if(!$cast(rhs_, rhs))                  // 类型转换
            uvm_report_error("do_copy", "cast failed");
        data = rhs_.data;
        delay = rhs_.delay;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);  // 比较功能
        adpcm_seq_item rhs_;
        do_compare = $cast(rhs_, rhs) &&
                     data == rhs_.data &&
                     delay == rhs_.delay;
    endfunction

    function string convert2string();           // 转字符串（打印用）
        return $sformatf(" data:\t%0h\n delay:\t%0d", data, delay);
    endfunction

endclass
```

### 类比理解

```
Sequence Item = 快递包裹

┌─────────────────┐
│   data = 32'hAA │  ← 包裹里的东西
│   delay = 5     │  ← 发送前等待的时间
└─────────────────┘

rand     = 随机生成（每次仿真值不同）
constraint = 约束（delay 必须在 1-20 之间）
```

### 关键方法

| 方法 | 作用 | 什么时候调用 |
|---|---|---|
| `new()` | 构造函数 | 创建对象时 |
| `do_copy()` | 复制数据 | 需要拷贝事务时 |
| `do_compare()` | 比较数据 | scoreboard 比对时 |
| `convert2string()` | 打印信息 | `$display` 时 |

---

## 6. 驱动层 (Driver)

### testbench.sv 第 76-119 行

```verilog
class adpcm_driver extends uvm_driver #(adpcm_seq_item);

    `uvm_component_utils(adpcm_driver)

    adpcm_seq_item req;                    // 事务句柄
    virtual adpcm_if.mon_mp ADPCM;         // 接口句柄

    task run_phase(uvm_phase phase);
        ADPCM.cb.frame <= 0;              // 初始值
        ADPCM.cb.data <= 0;
        fork
            // 这个 forever 循环：发送数据
            forever begin
                seq_item_port.get_next_item(req);  // 1. 从 Sequencer 拿数据
                
                repeat(req.delay) @(ADPCM.cb);     // 2. 等待 delay 个周期
                
                ADPCM.cb.frame <= 1;               // 3. 帧开始
                for(int i = 0; i < 8; i++) begin   // 4. 发送 8 个 4-bit
                    @(ADPCM.cb);
                    ADPCM.cb.data <= req.data[3:0]; // 发低 4 位
                    req.data = req.data >> 4;        // 右移 4 位
                end
                ADPCM.cb.frame <= 0;               // 5. 帧结束
                
                seq_item_port.item_done();          // 6. 告诉 Sequencer：用完了
            end
        join_none
    endtask

endclass
```

### Driver 的作用

```
Driver = 翻译官

Sequence 说：  "发数据 0xAA，等 5 个周期"
Driver 做：     把这句话翻译成具体的信号时序

┌───────────────────────────────────────────────────┐
│  等 5 周期    │ frame=1 │ 8个data       │ frame=0  │
│              │          │ D0 D1 ... D7 │          │
└───────────────────────────────────────────────────┘
```

### 数据发送过程

```
req.data = 32'hA5B6C7D8

第 1 个周期：发送 data = 8 (32'hD8 的低 4 位)
第 2 个周期：发送 data = D
第 3 个周期：发送 data = 7
第 4 个周期：发送 data = C
第 5 个周期：发送 data = 6
第 6 个周期：发送 data = B
第 7 个周期：发送 data = 5
第 8 个周期：发送 data = A

总共 8 个 4-bit = 32 位
```

### Driver 的关键 API

| API | 作用 |
|---|---|
| `get_next_item(req)` | 从 Sequencer 获取下一个事务 |
| `item_done()` | 告诉 Sequencer 事务已处理完 |
| `@(ADPCM.cb)` | 等待时钟沿 |

---

## 7. 序列层 (Sequence)

### testbench.sv 第 136-165 行

```verilog
class adpcm_tx_seq extends uvm_sequence #(adpcm_seq_item);

    `uvm_object_utils(adpcm_tx_seq)

    adpcm_seq_item req;

    rand int no_reqs = 10;    // 发送 10 个事务

    task body;
        req = adpcm_seq_item::type_id::create("req");  // 创建事务对象

        for(int i = 0; i < no_reqs; i++) begin
            start_item(req);                              // 1. 开始
            
            req.delay = $urandom_range(1, 20);           // 2. 随机延迟
            req.data = $urandom();                        // 3. 随机数据
            
            finish_item(req);                             // 4. 发送
            $display("发送第 %0d 帧", i);
        end
    endtask

endclass
```

### Sequence 的作用

```
Sequence = 测试计划

"我要发 10 个随机包"
"每个包的数据随机"
"每个包的延迟随机"

它不关心"怎么发"，只关心"发什么"
```

### Sequence 的 API

| API | 作用 |
|---|---|
| `type_id::create()` | 创建对象（工厂模式） |
| `start_item(req)` | 通知 Sequencer 准备发送 |
| `finish_item(req)` | 等待 Driver 处理完 |
| `$urandom_range(1,20)` | 生成随机数 |

---

## 8. 验证环境 (Environment)

### testbench.sv 第 121-129 行

```verilog
class adpcm_sequencer extends uvm_sequencer #(adpcm_seq_item);
    `uvm_component_utils(adpcm_sequencer)
    // 空的，只需要继承
endclass
```

### Sequencer 的作用

```
Sequencer = 中转站 / 调度员

Sequence 说：  "我要发数据"
                  ↓
Sequencer：    "好的，排队等 Driver 有空"
                  ↓
Driver 说：    "我有空了"
                  ↓
Sequencer：    "给你数据"
```

---

## 9. 测试用例 (Test)

### testbench.sv 第 171-204 行

```verilog
class adpcm_test extends uvm_test;

    `uvm_component_utils(adpcm_test)

    adpcm_tx_seq test_seq;
    adpcm_driver m_driver;
    adpcm_sequencer m_sequencer;

    // Phase 1: 创建组件
    function void build_phase(uvm_phase phase);
        m_driver = adpcm_driver::type_id::create("m_driver", this);
        m_sequencer = adpcm_sequencer::type_id::create("m_sequencer", this);
    endfunction

    // Phase 2: 连接组件
    function void connect_phase(uvm_phase phase);
        m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        uvm_config_db #(virtual adpcm_if.mon_mp)::get(this, "", "ADPCM_vif", m_driver.ADPCM);
    endfunction

    // Phase 3: 运行测试
    task run_phase(uvm_phase phase);
        test_seq = adpcm_tx_seq::type_id::create("test_seq");
        phase.raise_objection(this);       // 告诉 UVM：开始测试
        test_seq.start(m_sequencer);       // 运行序列
        phase.drop_objection(this);        // 告诉 UVM：测试结束
    endtask

endclass
```

### Test 的三个阶段

```
build_phase:   创建所有组件（"准备工具"）
    ↓
connect_phase: 连接组件（"接好线"）
    ↓
run_phase:     运行测试（"开始干活"）
```

### 为什么用 factory 创建对象？

```verilog
// 不推荐
m_driver = new("m_driver", this);

// 推荐（UVM factory）
m_driver = adpcm_driver::type_id::create("m_driver", this);
```

**原因：** factory 允许在不修改代码的情况下替换组件（override）

---

## 10. 工厂机制

### 什么是工厂？

```
工厂 = 对象创建中心

传统方式：  需要什么对象 → 直接 new()
UVM 方式：  需要什么对象 → 告诉工厂 → 工厂给你创建
```

### 为什么要用工厂？

```verilog
// 测试 A 用普通 Driver
factory.set_type_override_by_type(
    adpcm_driver::get_type(), 
    adpcm_driver_special::get_type()  // 用特殊版 Driver
);

// 不改任何代码，只是告诉工厂："换一个版本"
```

### 工厂注册

```verilog
class adpcm_driver extends uvm_driver;
    `uvm_component_utils(adpcm_driver)  // ← 注册到工厂
endclass

// 之后就可以用
adpcm_driver::type_id::create("name", parent);
```

---

## 11. Phase 机制

### UVM 的执行顺序

```
build_phase          创建组件
    ↓
connect_phase        连接组件
    ↓
end_of_elaboration   环境搭建完成
    ↓
start_of_simulation  仿真开始
    ↓
run_phase            运行测试 ← 主要工作在这里
    ↓
extract_phase        提取数据
    ↓
check_phase          检查结果
    ↓
report_phase         报告
    ↓
final                清理
```

### 为什么需要 Phase？

```
没有 Phase：
  组件 A 还没创建
  组件 B 就想连接 A
  → 错误！

有 Phase：
  Phase 1: 全部创建
  Phase 2: 全部连接
  → 顺序保证
```

### objection 机制

```verilog
task run_phase(uvm_phase phase);
    phase.raise_objection(this);  // "我还在运行"
    test_seq.start(m_sequencer);
    phase.drop_objection(this);   // "我运行完了"
endtask
```

**作用：** 防止仿真过早结束

### Phase 与 Task/Function 的关系

```
Phase 本质 = UVM 规定的执行阶段

function phase → 不能耗时（瞬间完成） → build_phase、connect_phase
task phase    → 能耗时（等时钟沿）   → run_phase、main_phase
```

| Phase | 类型 | 本质 | 能耗时间？ | 用途 |
|-------|------|------|-----------|------|
| `build_phase` | function | 就是 function | ❌ | 创建组件 |
| `connect_phase` | function | 就是 function | ❌ | 连线 |
| `end_of_elaboration` | function | 就是 function | ❌ | 检查环境 |
| `start_of_simulation` | function | 就是 function | ❌ | 初始化 |
| `run_phase` | task | 就是 task | ✅ | 发激励、等时钟 |
| `main_phase` | task | 就是 task | ✅ | 跑 sequence |
| `extract_phase` | function | 就是 function | ❌ | 提取数据 |
| `check_phase` | function | 就是 function | ❌ | 检查结果 |
| `report_phase` | function | 就是 function | ❌ | 打印报告 |

**为什么这样设计？**

```
build_phase（function）：
  └── 只创建对象，不碰信号，不需要等时钟，瞬间完成

connect_phase（function）：
  └── 只连线，不碰信号，不需要等时钟，瞬间完成

run_phase（task）：
  └── 要产生时序、等时钟沿，必须能耗时，所以是 task

main_phase（task）：
  └── 要跑 sequence、发激励，必须能耗时，所以是 task
```

**简单记忆：**
- **function phase** = 准备工作（创建、连接），不能耗时
- **task phase** = 实际干活（发激励、等结果），必须能耗时

---

## 12. 完整数据流

```
时间线：

T0:  adpcm_test.build_phase
     └── 创建 Driver、Sequencer

T1:  adpcm_test.connect_phase
     └── 连接 Driver ←→ Sequencer

T2:  adpcm_test.run_phase
     └── 启动 adpcm_tx_seq

T3:  adpcm_tx_seq.body
     └── 创建 req，随机化 data/delay

T4:  start_item(req)
     └── 通知 Sequencer 准备

T5:  finish_item(req)
     └── Sequencer 把 req 传给 Driver

T6:  adpcm_driver.run_phase
     ├── get_next_item(req)     拿到 req
     ├── repeat(delay)          等待
     ├── frame <= 1             帧开始
     ├── 发送 8 个 nibble       数据传输
     ├── frame <= 0             帧结束
     └── item_done()            完成

T7-T12: 重复 T3-T6 共 10 次
```

### 信号级流程

```
Driver 执行时，接口信号变化：

clk    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
         └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

frame  ──────────────────┐  ┌────────────────────────────────┐
                         └──┘                                └──
                         ↑ 帧开始                          帧结束

data   ──────────────────X──X──X──X──X──X──X──X─────────────
                         D0 D1 D2 D3 D4 D5 D6 D7
```

---

## 13. 总结对照表

| UVM 概念 | 本例对应 | 作用 |
|---|---|---|
| **Interface** | `adpcm_if` | 信号打包 |
| **Virtual Interface** | `virtual adpcm_if.mon_mp` | 软件访问硬件的桥梁 |
| **Sequence Item** | `adpcm_seq_item` | 数据包定义 |
| **Driver** | `adpcm_driver` | 信号时序驱动 |
| **Sequencer** | `adpcm_sequencer` | 中转调度 |
| **Sequence** | `adpcm_tx_seq` | 测试激励 |
| **Test** | `adpcm_test` | 测试用例 |
| **Factory** | `type_id::create()` | 对象创建 |
| **Phase** | `build/connect/run` | 执行顺序 |
| **objection** | `raise/drop` | 防止仿真提前结束 |

### UVM 验证流程口诀

```
1. 定义接口 (Interface)
2. 定义虚拟接口 (Virtual Interface)
3. 定义数据包 (Sequence Item)
4. 写驱动器 (Driver)
5. 写序列器 (Sequencer)
6. 写测试序列 (Sequence)
7. 组装测试 (Test)
8. 跑仿真看结果
```

---

## 附录：本例代码行号对照

| 文件 | 行号 | 内容 |
|---|---|---|
| design.sv | 1-16 | 接口定义 |
| testbench.sv | 9-12 | 导入 UVM 库 |
| testbench.sv | 17-72 | Sequence Item |
| testbench.sv | 76-119 | Driver |
| testbench.sv | 121-129 | Sequencer |
| testbench.sv | 136-165 | Sequence |
| testbench.sv | 171-204 | Test |
| testbench.sv | 209-235 | 顶层模块 |

---

*最后更新: 2026-07-18*
