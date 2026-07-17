---
title: "SystemVerilog 验证专用语法"
description: "SystemVerilog验证专用语法指南，涵盖class、SVA断言、coverage、UVM框架等高级验证主题"
pubDate: 2025-01-01
category: sv
order: 3
tags: [SV, 验证]
---

# SystemVerilog 验证专用语法

> 这些语法主要用于Testbench和验证环境，不可综合

---

## 层级总览

```
第七层  验证语法   repeat, $random, $display格式符, @(posedge), #N延时
        ↓            (Testbench专用, 验证工程师必会)
第八层  面向对象   class, extends, randomize, constraint
        ↓            (验证环境的基础)
第九层  断言       assert property, sequence, ##n
        ↓            (检查协议行为)
第十层  覆盖率     covergroup, coverpoint, cross
        ↓            (衡量验证进度)
第十一层 UVM框架   uvm_component, uvm_driver, uvm_monitor
                   (工业级验证方法学)
```

---

## 第七层：验证语法（Testbench专用）

### 7.1 repeat — 循环执行N次

```verilog
// 重复执行5次
repeat(5) begin
    @(posedge clk);
    wr_en = 1;
    wr_data = $random;//$开头是系统内建函数
end
```

**等价于：**
```verilog
for (int i = 0; i < 5; i++) begin
    @(posedge clk);
    wr_en = 1;
    wr_data = $random;
end
```

### 7.2 随机数生成

```verilog
$random              // 返回32位随机整数（有正有负）
$random % 256        // 0~255随机数
$urandom_range(0, 255) // 0~255随机数（推荐）
$urandom_range(16)   // 0~15随机数
```

**常用写法：**
```verilog
wr_data = $random % 256;           // 8位随机数据
address = $urandom_range(0, 1023); // 10位随机地址
```

### 7.3 格式化输出

```verilog
$display("写入: %0d", wr_data);    // 十进制，不补空格
$display("地址: %h", addr);        // 十六进制
$display("二进制: %b", data);      // 二进制
$display("时间: %0t", $time);      // 仿真时间
```

**格式符对比：**
| 格式符 | 含义 | 示例（值=255） |
|---|---|---|
| `%d` | 十进制，补空格 | ` 255` |
| `%0d` | 十进制，不补空格 | `255` |
| `%h` | 十六进制，补空格 | ` ff` |
| `%0h` | 十六进制，不补空格 | `ff` |
| `%b` | 二进制 | `11111111` |
| `%0t` | 仿真时间，不补空格 | `12345` |

### 7.4 等待边沿

```verilog
@(posedge clk);        // 等待时钟上升沿
@(negedge clk);        // 等待时钟下降沿
@(posedge clk or negedge rst_n);  // 等待任一边沿
```

**在Testbench中的用法：**
```verilog
// 在时钟上升沿驱动信号
@(posedge clk);
wr_en = 1;

// 等待多个时钟周期
repeat(10) @(posedge clk);
```

### 7.5 延时控制

```verilog
#10;           // 等待10个时间单位
#100;          // 等待100个时间单位
#(CLK_PERIOD); // 等待一个时钟周期
```

**时钟生成中的用法：**
```verilog
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;  // 每半个周期翻转
```

### 7.6 系统函数速查

| 函数 | 作用 | 示例 |
|---|---|---|
| `$random` | 32位随机整数 | `$random % 256` |
| `$urandom_range` | 范围随机数 | `$urandom_range(0, 15)` |
| `$display` | 打印信息 | `$display("data=%h", data)` |
| `$time` | 仿真时间 | `$display("t=%0t", $time)` |
| `$finish` | 结束仿真 | `$finish` |
| `$dumpfile` | 指定波形文件 | `$dumpfile("wave.vcd")` |
| `$dumpvars` | 指定dump信号 | `$dumpvars(0, tb)` |

### 7.7 验证模板

```verilog
`timescale 1ns / 1ps

module tb_example;
    // 参数
    parameter CLK_PERIOD = 10;
    
    // 信号
    logic clk;
    logic rst_n;
    
    // 时钟生成
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // 实例化
    example uut (
        .clk(clk),
        .rst_n(rst_n)
    );
    
    // 测试激励
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        
        repeat(10) begin
            @(posedge clk);
            // 驱动信号
        end
        
        $finish;
    end
    
    // 波形输出
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_example);
    end
endmodule
```

---

## 第八层：面向对象（class）

### 8.1 class 基础

#### 什么是class

class = 数据结构 + 操作方法的打包

```verilog
class transaction;
    // 属性（变量）= 数据结构
    logic [31:0] addr;
    logic [31:0] data;
    logic        wr;

    // 方法（函数/任务）= 操作
    function new(input logic [31:0] a = 0, input logic [31:0] d = 0);
        addr = a;
        data = d;
        wr   = 1;
    endfunction

    function void display();
        $display("addr=%h, data=%h, wr=%b", addr, data, wr);
    endfunction
endclass

// 使用
transaction txn;
initial begin
    txn = new(32'h100, 32'hABCD);  // 创建对象
    txn.display();                  // 调用方法
end
```

#### 关键点

| 关键字 | 作用 |
|--------|------|
| `class ... endclass` | 定义类 |
| `new()` | 构造函数，创建对象时自动调用 |
| `function void display()` | 方法，操作数据 |

#### 什么是方法

**方法 = 类能做的事情（操作数据的函数）**

```verilog
class calculator;
    int result;         // 数据

    // 方法1：加法
    function void add(input int a, input int b);
        result = a + b;
    endfunction

    // 方法2：显示
    function void display();
        $display("result = %0d", result);
    endfunction
endclass

// 使用
calculator calc;
initial begin
    calc = new();
    calc.add(1, 2);     // 调用方法：做加法
    calc.display();     // 调用方法：打印结果
end
```

| 数据 | 方法 | 作用 |
|------|------|------|
| `result` | `add()` | 计算 |
| `result` | `display()` | 打印 |

方法就是**操作数据的函数**，告诉你这个类能做什么。

#### 内存模型

```
句柄 txn          对象（堆内存）
┌────────┐       ┌─────────────────┐
│ 0x1000 │──────>│ addr = 0x100    │
└────────┘       │ data = 0xABCD   │
                 │ wr   = 1        │
                 └─────────────────┘
```

#### new() 构造函数详解

```verilog
// 写法1：带默认值
function new(input logic [31:0] a = 0, input logic [31:0] d = 0);
    addr = a;
    data = d;
endfunction

// 写法2：无参数
function new();
    addr = 0;
    data = 0;
endfunction

// 使用
txn = new();           // 用默认值
txn = new(32'h100);    // 只传addr
txn = new(32'h100, 32'hABCD);  // 都传
```

#### 句柄 vs 对象

**句柄（handle）= 对象的地址（类似指针）**

```
句柄 txn          对象（内存中）
┌────────┐       ┌─────────────┐
│ 0x1000 │──────>│ addr = 0x100│
└────────┘       │ data = 0xFF │
                 └─────────────┘
```

```verilog
transaction txn;       // 声明句柄（还没指向对象）
transaction txn2;

txn = new();           // 创建对象，句柄指向它
txn2 = txn;            // 两个句柄指向同一个对象

txn2.addr = 32'hFF;   // 修改txn.addr也会变（同一个对象）
```

**重要区别：**

| 操作 | 含义 |
|------|------|
| `transaction txn;` | 声明句柄（空的） |
| `txn = new();` | 创建对象，句柄指向它 |
| `txn2 = txn;` | 两个句柄指向同一个对象 |

**简单比喻：句柄是"遥控器"，对象是"电视"**

```
遥控器A ──┐
          │
遥控器B ──┼──> 同一台电视
          │
遥控器C ──┘
```

一个对象可以有多个句柄，修改任意一个句柄都会影响对象。

### 8.2 继承（extends）

#### 完整示例：总线事务继承

```verilog
// ============================================
// 父类：所有总线事务的共性
// ============================================
class base_transaction;
    logic [31:0] addr;          // 地址
    logic [31:0] data;          // 数据
    logic        wr;            // 读写：1=写，0=读
    logic [7:0]  id;            // 事务ID
    int          delay;         // 延迟（时钟周期）

    // 构造函数：初始化5个共性属性
    function new(input logic [31:0] a = 0, 
                 input logic [31:0] d = 0, 
                 input logic        w = 0,
                 input logic [7:0]  i = 0,
                 input int          del = 0);
        addr  = a;
        data  = d;
        wr    = w;
        id    = i;
        delay = del;
    endfunction

    // 显示方法：显示共性信息
    function void display();
        $display("id=%0d, wr=%b, addr=%h, data=%h, delay=%0d", 
                 id, wr, addr, data, delay);
    endfunction
endclass

// ============================================
// 子类1：AXI事务（继承父类，扩展AXI特有属性）
// ============================================
class axi_transaction extends base_transaction;
    logic [7:0]  burst_len;     // 突发长度（AXI特有）
    logic [2:0]  burst_size;    // 突发大小（AXI特有）
    logic [1:0]  resp;          // 响应状态（AXI特有）

    // 构造函数：调用父类 + 初始化子类属性
    function new(input logic [31:0] a = 0, 
                 input logic [31:0] d = 0, 
                 input logic        w = 0,
                 input logic [7:0]  i = 0,
                 input int          del = 0,
                 input logic [7:0]  blen = 0,
                 input logic [2:0]  bsize = 0);
        super.new(a, d, w, i, del);     // 初始化父类5个属性
        burst_len  = blen;              // 初始化子类属性
        burst_size = bsize;
    endfunction

    // 重写display：显示AXI特有信息
    function void display();
        $display("AXI: id=%0d, wr=%b, addr=%h, data=%h, len=%0d", 
                 id, wr, addr, data, burst_len);
    endfunction
endclass

// ============================================
// 子类2：APB事务（继承父类，扩展APB特有属性）
// ============================================
class apb_transaction extends base_transaction;
    logic        sel;           // 片选（APB特有）
    logic        enable;        // 使能（APB特有）

    function new(input logic [31:0] a = 0, 
                 input logic [31:0] d = 0, 
                 input logic        w = 0,
                 input logic [7:0]  i = 0,
                 input int          del = 0,
                 input logic        s = 0,
                 input logic        en = 0);
        super.new(a, d, w, i, del);     // 初始化父类5个属性
        sel    = s;                     // 初始化子类属性
        enable = en;
    endfunction

    function void display();
        $display("APB: id=%0d, wr=%b, addr=%h, data=%h", 
                 id, wr, addr, data);
    endfunction
endclass
```

#### 使用示例

```verilog
axi_transaction axi_txn;
apb_transaction apb_txn;

initial begin
    // 创建AXI事务：只需传AXI特有参数
    axi_txn = new(.a(32'h1000), .d(32'hDEAD_BEEF), .w(1), .blen(4));
    axi_txn.display();

    // 创建APB事务：只需传APB特有参数
    apb_txn = new(.a(32'h2000), .d(32'hCAFE_BABE), .w(0), .s(1));
    apb_txn.display();
end
```

#### 继承优势总结

```
父类 base_transaction (5个属性 + 1个方法)
┌─────────────────────────────────┐
│ addr, data, wr, id, delay       │
│ display()                       │
└─────────────────────────────────┘
            │
            ├──> axi_transaction (继承5个，新增3个)
            │     burst_len, burst_size, resp
            │
            └──> apb_transaction (继承5个，新增2个)
                  sel, enable
```

| 优势 | 说明 |
|------|------|
| **代码复用** | 父类5个属性不用重复写 |
| **易于维护** | 修改父类，所有子类自动生效 |
| **扩展方便** | 子类只需关注特有属性 |
| **统一接口** | 所有transaction可以用同一个句柄 |

#### 关键点

| 关键字 | 作用 |
|--------|------|
| `extends` | 继承父类 |
| `super.new()` | 调用父类构造函数（必须第一行） |
| `virtual` | 允许子类重写方法 |

#### virtual 关键字

```verilog
// 父类方法不加virtual
class base;
    function void display();
        $display("base");
    endfunction
endclass

class child extends base;
    function void display();  // 这是隐藏，不是重写
        $display("child");
    endfunction
endclass

// 父类方法加virtual
class base;
    virtual function void display();  // 允许重写
        $display("base");
    endfunction
endclass

class child extends base;
    function void display();  // 这是重写
        $display("child");
    endfunction
endclass
```

| 情况 | 行为 |
|------|------|
| 不加`virtual` | 隐藏（hiding） |
| 加`virtual` | 重写（override） |

**建议：父类方法都加`virtual`**，方便子类重写。

#### 继承关系

```
base_transaction          extended_transaction
┌──────────────┐          ┌──────────────────┐
│ addr         │          │ addr (继承)      │
└──────────────┘          │ data (新增)      │
                          │ wr   (新增)      │
                          └──────────────────┘
```

#### super.new() 的重要性

```verilog
// 正确：super.new()必须第一行
function new(input logic [31:0] a = 0, input logic [31:0] d = 0);
    super.new(a);  // ✅ 第一行调用
    data = d;
endfunction

// 错误：super.new()不是第一行
function new(input logic [31:0] a = 0, input logic [31:0] d = 0);
    data = d;      // ❌ 报错
    super.new(a);
endfunction
```

#### 使用示例

```verilog
extended_transaction ext_txn;

initial begin
    ext_txn = new(32'h100, 32'hABCD);
    
    // 可以访问父类和子类的属性
    $display("addr = %h", ext_txn.addr);   // 父类
    $display("data = %h", ext_txn.data);   // 子类
    $display("wr   = %b", ext_txn.wr);     // 子类
end
```

#### 方法重写（override）

```verilog
class base_transaction;
    virtual function void display();  // virtual允许重写
        $display("base: addr=%h", addr);
    endfunction
endclass

class extended_transaction extends base_transaction;
    function void display();  // 重写父类方法
        $display("extended: addr=%h, data=%h", addr, data);
    endfunction
endclass
```

### 8.3 随机化（randomize）

#### 基本语法

```verilog
// 定义可随机化的transaction类
class random_transaction;
    rand logic [31:0] addr;   // rand: 可随机化（每次随机可能重复）
    rand logic [31:0] data;   // rand: 可随机化
    randc bit [7:0]   id;     // randc: 随机循环（不重复，遍历所有值后重来）

    // 约束：限制随机范围
    constraint c_addr {
        addr inside {[32'h0000:32'h00FF]};  // 地址范围：0x0000~0x00FF
    }

    constraint c_data {
        data != 0;  // 数据不能为0
    }
endclass

// 使用：生成随机激励
random_transaction txn;           // 声明句柄
initial begin
    txn = new();                  // 创建对象
    repeat(10) begin              // 重复10次
        assert(txn.randomize())   // 随机化成功返回1，失败返回0
            $display("addr=%h, data=%h", txn.addr, txn.data);  // 打印随机值
        else
            $error("随机化失败");  // 约束冲突时报错
    end
end
```

#### rand vs randc

| 关键字 | 行为 | 用途 |
|--------|------|------|
| `rand` | 每次随机，可能重复 | 地址、数据 |
| `randc` | 循环不重复，遍历所有值后重来 | ID、事务类型 |

```verilog
rand  logic [7:0] data;   // 可能：0x01, 0x01, 0x02, 0x03...
randc logic [7:0] id;     // 保证：0x01, 0x02, 0x03...0xFF, 然后重来
```

#### randomize() 返回值

```verilog
// 返回1：随机化成功
// 返回0：随机化失败（约束冲突）
assert(txn.randomize())
    $display("成功");
else
    $error("失败");
```

#### 内联约束（inline constraint）

```verilog
// 只随机化某些字段
assert(txn.randomize() with {
    addr == 32'h100;      // 强制addr=0x100
    data inside {[0:100]}; // data在0~100
})
```

### 8.4 约束详解

```verilog
class constrained_transaction;
    rand logic [7:0]  cmd;
    rand logic [31:0] addr;
    rand logic [31:0] data;
    rand bit [2:0]    burst_len;

    constraint c_cmd {
        cmd inside {8'h01, 8'h02, 8'h03};  // 枚举值
    }

    constraint c_addr {
        addr[1:0] == 2'b00;  // 地址对齐
        addr < 32'h1000;     // 地址范围
    }

    constraint c_burst {
        burst_len inside {[1:8]};  // 突发长度1~8
        soft data == 0;            // soft: 软约束（可被覆盖）
    }

    // 条件约束
    constraint c_cond {
        if (cmd == 8'h01)
            addr inside {[32'h000:32'h0FF]};
        else
            addr inside {[32'h100:32'h1FF]};
    }
endclass
```

#### 约束操作符速查

| 操作符 | 含义 | 示例 |
|--------|------|------|
| `inside` | 在集合内 | `addr inside {[0:255]}` |
| `==` | 等于 | `data == 0` |
| `!=` | 不等于 | `data != 0` |
| `<` `>` `<=` `>=` | 比较 | `addr < 32'h1000` |
| `{a, b}` | 拼接 | `addr[1:0] == 2'b00` |

#### soft约束

```verilog
constraint c_data {
    soft data == 0;  // 软约束，可以被覆盖
}

// 覆盖soft约束
assert(txn.randomize() with {
    data == 32'hFF;  // 覆盖soft data == 0
})
```

#### 条件约束

```verilog
constraint c_cond {
    if (cmd == 8'h01)
        addr inside {[32'h000:32'h0FF]};
    else
        addr inside {[32'h100:32'h1FF]};
}
```

#### 约束块命名

```verilog
constraint c1 { ... }  // 命名约束块
constraint c2 { ... }  // 可以单独禁用/启用
```

#### 地址对齐详解

**什么是地址对齐？**

地址对齐 = 地址必须是某个边界的整数倍

```verilog
// 4字节对齐：地址必须是4的倍数
addr[1:0] == 2'b00;  // 低2位必须为00

// 8字节对齐：地址必须是8的倍数
addr[2:0] == 3'b000;  // 低3位必须为000
```

**为什么需要对齐？**

CPU访问存储器时，通常按字（word）读取：
- 32位CPU一次读4字节
- 地址必须是4的倍数，才能对齐读取

**不对齐会怎样？**

| 情况 | 后果 |
|------|------|
| 对齐 | 一次读取完成，效率高 |
| 不对齐 | 需要读两次再拼接，效率低，甚至报错 |

```
地址0x0000（对齐）：
  一次读取：[0x0000-0x0003] → 完成

地址0x0001（不对齐）：
  读取1：[0x0000-0x0003]
  读取2：[0x0004-0x0007]
  拆分拼接 → 效率低
```

**CPU位宽与对齐关系**

| CPU位宽 | 对齐要求 | 检查位 | 一次读取 |
|---------|----------|--------|----------|
| 8位 | 1字节对齐 | 无要求 | 1字节 |
| 16位 | 2字节对齐 | `addr[0]==0` | 2字节 |
| 32位 | 4字节对齐 | `addr[1:0]==00` | 4字节 |
| 64位 | 8字节对齐 | `addr[2:0]==000` | 8字节 |

**不是非要是4的倍数，取决于CPU位宽**

```verilog
// 16位CPU：2字节对齐
constraint c_align_16 {
    addr[0] == 1'b0;  // 低1位为0
}

// 32位CPU：4字节对齐
constraint c_align_32 {
    addr[1:0] == 2'b00;  // 低2位为0
}

// 64位CPU：8字节对齐
constraint c_align_64 {
    addr[2:0] == 3'b000;  // 低3位为0
}
```

**二进制规律：低N位为0，就是2^N的倍数**

```
十进制    二进制     低2位    低3位
0        0000      00 ✅    000 ✅  是4和8的倍数
4        0100      00 ✅    100 ❌  是4的倍数，不是8的
8        1000      00 ✅    000 ✅  是4和8的倍数
1        0001      01 ❌    001 ❌  都不是
2        0010      10 ❌    010 ❌  都不是
3        0011      11 ❌    011 ❌  都不是
```

**常见对齐方式**

| 对齐 | 检查位 | 合法地址 |
|------|--------|----------|
| 1字节 | 无要求 | 0x00,0x01,0x02... |
| 2字节 | `addr[0]==0` | 0x00,0x02,0x04... |
| 4字节 | `addr[1:0]==00` | 0x00,0x04,0x08... |
| 8字节 | `addr[2:0]==000` | 0x00,0x08,0x10... |

**约束写法**

```verilog
// 4字节对齐
constraint c_align {
    addr[1:0] == 2'b00;      // 低2位为0
}

// 地址对齐 + 范围约束
constraint c_addr {
    addr[1:0] == 2'b00;      // 4字节对齐
    addr inside {[32'h000:32'h1FF]};  // 地址范围
}

// 用取模运算符写对齐约束（效果相同）
constraint c_align_mod {
    addr % 4 == 0;           // 等价于 addr[1:0] == 0
}
```

**位操作 vs 取模，两种写法对比**

```verilog
// 写法1：位操作（推荐，综合效率高）
constraint c1 { addr[1:0] == 2'b00; }

// 写法2：取模运算（更直观）
constraint c2 { addr % 4 == 0; }

// 两种写法效果完全一样：
// 0x00 % 4 == 0 ✅    0x04 % 4 == 0 ✅    0x08 % 4 == 0 ✅
// 0x01 % 4 == 1 ❌    0x02 % 4 == 2 ❌    0x03 % 4 == 3 ❌
```

#### 核心概念总结

| 概念 | 本质 | 目的 |
|------|------|------|
| 约束 | 加条件限制随机值范围 | 让随机值有意义，符合协议规范 |
| 随机 | 自动生成测试向量 | 提高测试效率和覆盖率 |
| 对齐 | 让CPU一次读完数据 | 提高访问效率，减少读取次数 |

### 8.5 Class 实用示例

#### 示例1：基础transaction

```verilog
class transaction;
    logic [31:0] addr;
    logic [31:0] data;
    logic        wr;

    function new(input logic [31:0] a = 0, 
                 input logic [31:0] d = 0, 
                 input logic        w = 1);
        addr = a;
        data = d;
        wr   = w;
    endfunction

    function void display();
        $display("wr=%b, addr=%h, data=%h", wr, addr, data);
    endfunction
endclass

// 使用
transaction txn;
initial begin
    txn = new(32'h100, 32'hABCD, 1);
    txn.display();
end
```

#### 示例2：继承 - 基础与扩展

```verilog
class base_transaction;
    logic [31:0] addr;

    function new(input logic [31:0] a = 0);
        addr = a;
    endfunction
endclass

class ext_transaction extends base_transaction;
    logic [31:0] data;

    function new(input logic [31:0] a = 0, input logic [31:0] d = 0);
        super.new(a);
        data = d;
    endfunction
endclass
```

#### 示例3：driver - 驱动DUT

```verilog
// driver类：负责向DUT（被测设备）发送激励
class driver;
    virtual axi_if vif;          // 虚接口：连接DUT的信号线

    // 构造函数：传入接口
    function new(virtual axi_if vif);
        this.vif = vif;          // this.访问成员变量，保存接口
    endfunction

    // 写任务：向DUT写入数据
    task write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge vif.clk);      // 等待时钟上升沿
        vif.awvalid <= 1;        // 写地址有效
        vif.awaddr  <= addr;     // 驱动写地址
        @(posedge vif.clk);      // 等待下一个时钟沿
        vif.wvalid  <= 1;        // 写数据有效
        vif.wdata   <= data;     // 驱动写数据
    endtask
endclass
```

**关键点说明**

| 关键字 | 作用 |
|--------|------|
| `virtual` | 虚接口，连接DUT的实际信号 |
| `this.vif` | 成员变量赋值 |
| `@(posedge vif.clk)` | 等待时钟上升沿 |
| `task` | 有时延的操作（含`@(posedge)`） |

**driver的工作流程**

```
1. 等待时钟沿
2. 驱动写地址（awvalid=1, awaddr=地址）
3. 等待下一个时钟沿
4. 驱动写数据（wvalid=1, wdata=数据）
```

#### 示例4：scoreboard - 比较结果

```verilog
// scoreboard类：比较预期结果和实际结果
class scoreboard;
    int pass_count = 0;          // 通过计数
    int fail_count = 0;          // 失败计数

    // 检查函数：比较expected和actual
    function void check(input logic [31:0] expected,   // 预期值
                        input logic [31:0] actual);     // 实际值
        if (expected === actual) begin                  // 全等比较
            $display("PASS: %h == %h", expected, actual);  // 打印通过
            pass_count++;                               // 通过计数+1
        end else begin
            $display("FAIL: %h != %h", expected, actual);  // 打印失败
            fail_count++;                               // 失败计数+1
        end
    endfunction
endclass
```

**关键点说明**

| 关键字 | 作用 |
|--------|------|
| `===` | 全等比较（能比较x和z） |
| `expected` | 预期值（应该的结果） |
| `actual` | 实际值（DUT输出） |

**scoreboard的作用**

```
DUT输出 → actual
              ↓
        比较器 ← expected（参考模型）
              ↓
        PASS/FAIL
```

**使用示例**

```verilog
scoreboard sb;
initial begin
    sb = new();
    sb.check(32'hDEAD_BEEF, actual_data);  // 比较
end

// 最后统计
$display("Pass: %0d, Fail: %0d", sb.pass_count, sb.fail_count);
```

#### 示例5：parameterized class - 参数化类

```verilog
class fifo #(parameter WIDTH = 8, DEPTH = 16);
    logic [WIDTH-1:0] queue[$];

    function void push(input logic [WIDTH-1:0] data);
        if (queue.size() < DEPTH)
            queue.push_back(data);
    endfunction

    function logic [WIDTH-1:0] pop();
        return queue.pop_front();
    endfunction
endclass

// 使用
fifo #(8, 16)   fifo8;    // 8位宽，深度16
fifo #(32, 64)  fifo32;   // 32位宽，深度64
```

#### 深度、地址位数、数据位宽、字节数详解

**四个核心概念**

| 概念 | 定义 | 示例 |
|------|------|------|
| **深度** | 能存多少个数据 | 16个 |
| **地址位数** | 寻址深度需要几位 | 4位（2^4=16） |
| **数据位宽** | 每个数据多少位 | 8位（1字节） |
| **字节数** | 总容量 | 16×1=16字节 |

**关系公式**

```
地址位数 = $clog2(深度)
字节数 = 深度 × 数据位宽 / 8
```

**示例计算**

```verilog
fifo #(8, 16)   fifo8;
// 深度：16
// 地址位数：4位（2^4=16）
// 数据位宽：8位（1字节）
// 字节数：16 × 1 = 16字节

fifo #(32, 64)  fifo32;
// 深度：64
// 地址位数：6位（2^6=64）
// 数据位宽：32位（4字节）
// 字节数：64 × 4 = 256字节
```

**常见配置表**

| 深度 | 地址位数 | 数据位宽 | 字节数 |
|------|----------|----------|--------|
| 4 | 2位 | 8位 | 4字节 |
| 8 | 3位 | 8位 | 8字节 |
| 16 | 4位 | 8位 | 16字节 |
| 64 | 6位 | 32位 | 256字节 |
| 1024 | 10位 | 32位 | 4096字节 |

---

## 第九层：断言（SVA）

### 9.1 基础断言

```verilog
// 简单断言
assert property (@(posedge clk)
    req |-> ##3 ack
) else $error("req到ack超过3周期");

// 含义：req有效后，3个周期内必须有ack
```

### 9.2 序列（sequence）

```verilog
// 定义序列
sequence s_wr;
    @(posedge clk) awvalid && awready;
endsequence

sequence s_data;
    @(posedge clk) wvalid && wready;
endsequence

// 使用序列
property p_wr_data;
    @(posedge clk)
    s_wr |-> s_data ##0 wlast;
endproperty

assert property (p_wr_data);
```

### 9.3 常用断言操作符

#### 蕴含符号（Implication）

```verilog
// |-> 重叠蕴含：前提成立的同一周期检查结论
assert property (@(posedge clk)
    req |-> ack
);
// 含义：如果 req 为真，那么同一周期 ack 必须为真

// |=> 非重叠蕴含：前提成立的下一周期开始检查结论
assert property (@(posedge clk)
    req |=> ack
);
// 含义：如果 req 为真，那么下一周期 ack 必须为真

// 对比时序图：
// clk:    ↑   ↑   ↑
// req:    1   0   0
// ack(|->): 1   0   0  ← 同一周期检查
// ack(|=>): 0   1   0  ← 下一周期检查
```

#### 延迟操作符（##）

```verilog
// ##n 延迟n个周期
assert property (@(posedge clk)
    req |-> ##3 ack
);
// 含义：req 为真后，3个周期内必须有 ack

// ##[min:max] 延迟范围
assert property (@(posedge clk)
    req |-> ##[1:5] ack
);
// 含义：req 为真后，1~5个周期内必须有 ack

// ##0 同一周期（与 |-> 类似）
assert property (@(posedge clk)
    req |-> ##0 ack
);
// 含义：req 为真时，同一周期 ack 必须为真

// ##$ 无限延迟（可配合其他操作符）
assert property (@(posedge clk)
    req |-> ##[1:$] ack
);
// 含义：req 为真后，最终必须有 ack（不限周期数）
```

#### 组合使用

```verilog
// 多步延迟
assert property (@(posedge clk)
    req |-> ##1 req_ack |-> ##2 data_valid
);
// 含义：req → 1周期后 req_ack → 2周期后 data_valid

// 范围延迟 + 蕴含
assert property (@(posedge clk)
    $rose(valid) |-> ##[1:3] ready && (data == expected)
);
// 含义：valid 上升沿后，1~3周期内 ready 为真且数据正确
```

#### 系统函数

**高频（必须掌握）：**
```verilog
// $past(signal) - 前1个周期的值
assert property (@(posedge clk)
    wr_data == $past(wr_data) + 1
);
// 含义：数据每周期递增1

// $past(signal, n) - 前n个周期的值
assert property (@(posedge clk)
    $past(valid, 2) |-> ack
);
// 含义：2个周期前的 valid 为真时，当前 ack 必须为真

// $rose(signal) - 信号上升沿（从0变1）
assert property (@(posedge clk)
    $rose(valid) |-> ##[1:3] ready
);
// 含义：valid 上升沿后，1~3周期内 ready 必须为真

// $fell(signal) - 信号下降沿（从1变0）
assert property (@(posedge clk)
    $fell(valid) |-> !ready
);
// 含义：valid 下降沿时，ready 必须为假

// $stable(signal) - 信号稳定（没有变化）
assert property (@(posedge clk)
    $stable(data) |-> ack
);
// 含义：data 没变时，ack 必须为真

// $changed(signal) - 信号变化（有改变）
assert property (@(posedge clk)
    $changed(data) |-> ##1 valid
);
// 含义：data 变化后，下一周期 valid 必须为真
```

**中频（偶尔使用）：**
```verilog
// $countones(signal) - 统计1的个数
assert property (@(posedge clk)
    $countones(flags) == 4 |-> done
);
// 含义：flags 中有4个1时，done 必须为真

// $onehot(signal) - 只有1位为1
assert property (@(posedge clk)
    $onehot(sel) |-> valid
);
// 含义：sel 只有1位为1时，valid 必须为真
```

**低频（很少使用）：**
```verilog
// $onehot0(signal) - 最多1位为1（可以全0）
assert property (@(posedge clk)
    $onehot0(sel) |-> valid
);

// $isunknown(signal) - 是否有未知态X/Z
assert property (@(posedge clk)
    !$isunknown(data) |-> valid
);
// 含义：data 没有X/Z时，valid 必须为真

// $sampled(signal) - 采样信号值（用于覆盖率）
assert property (@(posedge clk)
    $sampled(cmd) == 8'h01 |-> rd_en
);
```

#### 其他操作符

```verilog
// within 包含
assert property (@(posedge clk)
    $rose(valid) |-> within ($rose(valid) ##1 $rose(ready))
);

// throughout 持续期间
assert property (@(posedge clk)
    reset throughout (valid [*0:$])
);
```

### 9.4 覆盖断言

```verilog
// cover属性：统计场景出现次数
property p_cover_wr;
    @(posedge clk)
    wr_en && !full |=> wr_en && (wr_data == $past(wr_data) + 1);
endproperty

cover property (p_cover_wr);

// assume属性：假设条件（用于形式验证）
assume property (@(posedge clk)
    reset |=> !wr_en
);
```

---

## 第十层：覆盖率（covergroup）

### 10.1 基础covergroup

```verilog
class transaction_coverage;
    rand logic [7:0]  cmd;
    rand logic [31:0] addr;
    rand logic [31:0] data;

    covergroup cg;
        // 命令覆盖点
        cp_cmd: coverpoint cmd {
            bins read  = {8'h01};
            bins write = {8'h02};
            bins reset = {8'h03};
        }

        // 地址覆盖点
        cp_addr: coverpoint addr {
            bins low  = {[0:32'hFF]};
            bins mid  = {[32'h100:32'h1FF]};
            bins high = {[32'h200:32'hFF]};
        }

        // 交叉覆盖
        cx_cmd_addr: cross cp_cmd, cp_addr;
    endgroup

    // 实例化
    covergroup_inst = new();

    // 采样
    function void sample();
        covergroup_inst.sample();
    endfunction
endclass
```

### 10.2 覆盖点详解

```verilog
covergroup cg;
    // 基本覆盖点
    cp_data: coverpoint data {
        bins zero   = {0};
        bins small  = {[1:127]};
        bins large  = {[128:255]};
        bins others = default;  // 其他值
    }

    // 带权重
    cp_cmd: coverpoint cmd {
        bins low_weight  = {1} weight 1;
        bins high_weight = {2} weight 10;
    }

    // 自动分箱
    cp_auto: coverpoint addr {
        bins auto[] = {[0:255]};  // 自动分成N个bin
    }

    // 序列覆盖
    cp_seq: coverpoint data {
        bins seq1 = (0, 1, 2);
        bins seq2 = (3[*3]);  // 3连续出现3次
    }
endgroup
```

### 10.3 覆盖率目标

```verilog
// 设置覆盖率目标
covergroup cg;
    cp_cmd: coverpoint cmd {
        bins read  = {8'h01};
        bins write = {8'h02};
    }

    // 全局目标
    option.goal = 100;  // 100%覆盖率

    // 单个覆盖点目标
    cp_cmd.option.goal = 90;
endgroup

// 检查覆盖率
initial begin
    // 运行测试...
    #10000;

    if (cg.get_coverage() >= 100)
        $display("覆盖率达标: %0f%%", cg.get_coverage());
    else
        $warning("覆盖率不足: %0f%%", cg.get_coverage());
end
```

---

## 第十一层：UVM框架

### 11.1 UVM组件层次

```
uvm_test
    └── uvm_env
            ├── uvm_agent
            │       ├── uvm_driver
            │       ├── uvm_monitor
            │       └── uvm_sequencer
            ├── uvm_scoreboard
            └── uvm_coverage
```

### 11.2 基础UVM组件

```verilog
// Driver
class my_driver extends uvm_driver #(transaction);
    `uvm_component_utils(my_driver)

    function new(string name = "my_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        transaction txn;
        forever begin
            seq_item_port.get_next_item(txn);
            // 驱动信号
            vif.wr   <= txn.wr;
            vif.addr <= txn.addr;
            vif.data <= txn.data;
            @(posedge vif.clk);
            seq_item_port.item_done();
        end
    endtask
endclass

// Monitor
class my_monitor extends uvm_monitor;
    `uvm_component_utils(my_monitor)

    uvm_analysis_port #(transaction) ap;

    function new(string name = "my_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        transaction txn;
        forever begin
            @(posedge vif.clk);
            if (vif.valid && vif.ready) begin
                txn = transaction::type_id::create("txn");
                txn.addr = vif.addr;
                txn.data = vif.data;
                ap.write(txn);
            end
        end
    endtask
endclass

// Scoreboard
class my_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_scoreboard)

    uvm_analysis_imp #(transaction, my_scoreboard) imp;

    function new(string name = "my_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        imp = new("imp", this);
    endfunction

    function void write(transaction txn);
        // 比较实际输出与预期
        if (txn.actual != txn.expected)
            `uvm_error("SCOREBOARD", $sformatf("不匹配: %h vs %h", txn.actual, txn.expected))
    endfunction
endclass
```

### 11.3 UVM Test

```verilog
class my_test extends uvm_test;
    `uvm_component_utils(my_test)

    my_env env;

    function new(string name = "my_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = my_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        my_sequence seq;
        phase.raise_objection(this);
        seq = my_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
        #1000;
        phase.drop_objection(this);
    endtask
endclass
```

### 11.4 UVM序列

```verilog
class my_sequence extends uvm_sequence #(transaction);
    `uvm_object_utils(my_sequence)

    task body();
        transaction txn;
        repeat(10) begin
            txn = transaction::type_id::create("txn");
            start_item(txn);
            assert(txn.randomize());
            finish_item(txn);
        end
    endtask
endclass
```

---

## 验证流程

```
1. 编写Transaction（定义数据结构）
2. 编写Driver（驱动DUT）
3. 编写Monitor（采集信号）
4. 编写Scoreboard（比较结果）
5. 编写Coverage（统计覆盖率）
6. 编写Sequence（生成激励）
7. 编写Test（组织验证环境）
8. 运行仿真，分析覆盖率
```

---

## 附录：面试高频问题

| 模块 | 常见问题 |
|---|---|
| **class** | 静态属性vs动态属性？继承和多态？ |
| **randomize** | 约束如何编写？如何覆盖约束？ |
| **SVA** | \|->和\|=>的区别？sequence如何定义？ |
| **coverage** | coverpoint和cross的区别？如何提高覆盖率？ |
| **UVM** | 组件层次结构？phase机制？factory机制？ |

---

*最后更新: 2026-07-16*