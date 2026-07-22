---
title: "SystemVerilog 通用语法（设计验证都用）"
description: "SystemVerilog核心语法指南，涵盖数据类型、运算符、流程控制、模块定义等设计和验证都需要的基础知识"
pubDate: 2025-01-01
category: sv
order: 1
tags: [SV, 通用]
---

# SystemVerilog 通用语法（设计验证都用）

## 层级总览 — 按依赖关系排

下面的层看不懂，上面的就没法学。你的代码文件里每个知识点都落在这几层里的某一层。

```
第〇层  硬件直觉   0/1, 位, 时钟沿, 寄存器, 连线
        ↓            (脑子里有图就行)
第一层  声明       module, input/output, parameter, 数据类型, 数组
        ↓            (盒子长什么样)
第二层  赋值       assign, =, <=
        ↓            (值怎么传)
第三层  时序控制   initial, #N, @(posedge/negedge)
        ↓            (什么时候发生)
第四层  流程控制   if/else, case/casez, for, foreach
        ↓            (逻辑怎么组织)
第五层  封装       task, function, interface, 模块例化, typedef, enum, struct
        ↓            (大块怎么搭)
第六层  表达式     运算符(~ ! === ?: {} [M:N] [+: ] &|^归约 <<>>), 字面量('b 'h '0'), 系统函数($display...), 注释
                   (细节胶水, 可以随手查)
```

## 为什么 SV 里全是固定搭配

不是语法设计者故意限制你——是每句语法都对应一块真实的物理电路。SV 只是把物理规律翻译成了固定句式。

| 物理世界有什么 | SV 里就必须有对应的描述 |
|---|---|
| 一根线，持续导通 | `assign` |
| 时钟边沿触发的寄存器 | `always @(posedge clk) + <=` |
| 一个盒子，外面只有接口 | `module / input / output` |
| 一根线被多个源驱动 | `wire` |
| 一堆相同的寄存器 | unpacked array |
| 寄存器只在沿上更新 | `<=` 非阻塞 |
| 8 根并排的物理导线 | `logic [7:0] data` |

所以当你看到 `always @(posedge clk)`，你不用猜它在描述什么——它只能是寄存器。看到 `assign`，它只能是组合逻辑连线。这就是"固定搭配"的价值：看一句话就知道电路长什么样。

## 第〇层：硬件直觉

在看任何代码之前，先搞清这些概念。它们的细节在后面的层里展开，但脑子里的图应该先有。

- **位 (bit)** — 一根线，只能 0 或 1
- **向量 (vector)** — 一排线，`[7:0]` = 8 根并排
- **时钟 (clk)** — 一根不停 0→1→0→1 的线，芯片的心跳
- **时钟沿** — 0→1 的瞬间(上升沿) 或 1→0 的瞬间(下降沿)
- **寄存器** — 只在时钟沿上干活；平时不看输入，沿到了才采样
- **组合逻辑** — 没有时钟，输入一变输出立刻变，像一根导线

```
      1 ─────────┐          ┌──────────
                 │          │
                 │  上升沿   │  上升沿
      0 ────────┘          └──────────
```

寄存器行为:

```
  clk:    ──┐     ┌──┐     ┌──┐     ┌──
            └─────┘  └─────┘  └─────┘
             ↑       ↑       ↑       ↑
           每个上升沿, 把输入"咔嚓"采样进去
```

## 第一层：声明 — 盒子长什么样

### 1.1 module — 所有代码的骨架

```verilog
module adder (
    input  logic [7:0] a, b,
    output logic [7:0] sum,
    output logic       carry
);
    // 逻辑实现
    assign {carry, sum} = a + b;

endmodule                         // 盒子关
```

### 1.2 input / output — 端口方向

```verilog
input  logic        clk;       // 信号从外部进来
output logic [7:0]  result;    // 信号从这里出去
```

| 方向 | 谁驱动 | 模块内部能读吗 | 模块内部能写吗 |
|---|---|---|---|
| `input` | 外部模块 | ✅ | ❌ |
| `output` | 本模块 | ✅ | ✅ |

### 1.3 parameter — 可配置的常量

```verilog
parameter D_WIDTH = 16;     // 默认 16, 例化时可以改
parameter DEPTH = 32;
```

命名约定：

| 前缀 | 全称 | 含义 | 示例 |
|---|---|---|---|
| `D_` | Data | 数据相关 | `D_WIDTH` = 数据位宽（每个存储单元多少位） |
| `A_` | Address | 地址相关 | `A_WIDTH` = 地址位宽（地址总线多少根线） |

```
DEPTH = 存储深度（总共多少个单元）
DEPTH = 2^(A_WIDTH)       →   A_WIDTH=5  →  DEPTH=32
最大地址 = DEPTH - 1      →   最大地址=31
```

地址位宽决定了能寻址多少个单元，数据位宽决定了每个单元存多少位。

这种 `D_` / `A_` 前缀是 RAM、FIFO 等存储模块的通用命名习惯，看到前缀就知道这个参数管的是数据还是地址。

## 第二层：赋值 — 值怎么传

### 2.1 assign — 一根物理连线

```verilog
assign sum = a + b;
```

电路原理图:

```
  a ──┬──
      │   \
  b ──┼─── + ──── sum
      │   /
```

没有时钟。`a` 或 `b` 任意时刻变化，`sum` 立刻更新。`assign` 使用连续赋值语法 `=`；它不是过程块中的“阻塞赋值”，阻塞/非阻塞的概念只适用于过程赋值。

常见用法：

```verilog
assign sum = a + b;
assign {carry, out} = a + b + cin;     // 位拼接输出
assign max = (a > b) ? a : b;          // 三目选择
assign bus = (oe) ? internal : 8'bz;   // 总线使能
```

### 2.2 always — 事件驱动的过程块

```verilog
always @(posedge clk) begin
    q <= d;       // q=输出, d=输入, D触发器的传统命名 (q←output, d←data)
end
```

电路原理图:

```
  clk ──┤> 触发器
               │
  d ──────────┐│
              D Q ──── q
              ↑
  只有 clk 上升沿这一刻, d 被采样进寄存器
```

### 2.3 `=` vs `<=` — 阻塞 vs 非阻塞

| 特性 | `=` 阻塞 | `<=` 非阻塞 |
|---|---|---|
| 执行顺序 | 立刻执行，一行完了才下一行 | 同时执行，时刻结束时统一更新 |
| 用在 | `assign` / `always_comb` | `always @(posedge clk)` |
| 电路 | 组合逻辑 | 时序逻辑（寄存器） |

```verilog
// <= 非阻塞 — 并行交换 a 和 b ✅
always @(posedge clk) begin
    a <= b;
    b <= a;
end

// = 阻塞 — 两个都变成 b, 交换失败 ❌
always @(posedge clk) begin
    a = b;
    b = a;
end
```

规则：时序逻辑一律 `<=`，组合逻辑（`assign`/`always_comb`）用 `=`。

### 2.4 initial — 仿真启动时执行一次（通常用于 TB）

```verilog
initial begin
    clk = 0;
    rst_n = 0;
    #10 rst_n = 1;          // 10ns 后释放复位
    #100 $finish;            // 再过 100ns 结束仿真
end
```

在 ASIC 流程中通常不可综合，因此主要用于测试平台；部分 FPGA 工具支持特定寄存器或存储器的 `initial` 初始化，具体以工具和器件能力为准。

### 2.5 begin / end — 多行打包

```verilog
// 一行可省 begin/end
if (we)  memory[addr] <= data;

// 多行必须 begin/end
if (we) begin
    memory[addr] <= data;
    $display("wrote %h to %h", data, addr);
end
```

### 2.6 #N — 等 N 个时间单位

```verilog
timeunit 1ns;
timeprecision 1ps;

#10;                    // 空等 10 个 timeunit；此处为 10ns
#10 clk = ~clk;         // 10ns 后翻转时钟
#20 data = 8'hFF;       // 20ns 后赋值
```

未声明 `timeunit` 时，`#10` 的实际时间由编译单元的 ``timescale`` 决定，不能一概理解为 10ns。

### 2.7 @(posedge) / @(negedge) — 等到边沿

`posedge` 和 `negedge` 是固定关键字，后面的信号名可以换成任何信号。

```verilog
@(posedge 任意信号)    // "等到它从 0 变 1 的那一刻"
@(negedge 任意信号)    // "等到它从 1 变 0 的那一刻"

@(posedge clk)              // clk 的上升沿
@(posedge clk_write)        // clk_write 的上升沿
@(posedge ready)            // ready 的上升沿
@(negedge rst_n)            // rst_n 的下降沿
@(posedge clk or negedge rst_n)   // 任意一个来就触发
```

`@(posedge ready)` 只等待 `ready` 从低到高的事件；它不等价于 ready/valid 握手。若 `ready` 已经为高，等待该事件不会立即返回；握手协议应在时钟沿检查 `valid && ready`。

## 第四层：流程控制 — 逻辑怎么组织

### 4.1 if / else — 条件分支

```verilog
// 单分支
if (write_enable)
    memory[addr] <= data;

// 双分支
if (!rst_n)
    count <= 0;
else
    count <= count + 1;

// 简化的同步 slave：只在 valid && ready 的握手周期接受请求
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bus.ready <= 0;
        bus.rdata <= '0;
    end else begin
        bus.ready <= 1;                // 本例始终可以接受请求
        if (bus.valid && bus.write)
            memory[bus.addr] <= bus.wdata;
        else if (bus.valid && bus.read)
            bus.rdata <= memory[bus.addr];
    end
end

// 简化的 master：发起请求后保持 valid，直到 valid && ready 握手完成
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bus.valid <= 0;
        bus.write <= 0;
        bus.read  <= 0;
    end else if (!bus.valid && master_write) begin
        bus.write <= 1;
        bus.read  <= 0;
        bus.addr  <= master_addr;
        bus.wdata <= master_wdata;
        bus.valid <= 1;
    end else if (!bus.valid && master_read) begin
        bus.write <= 0;
        bus.read  <= 1;
        bus.addr  <= master_addr;
        bus.valid <= 1;
    end else if (bus.valid && bus.ready) begin
        if (bus.read)
            master_rdata <= bus.rdata;
        bus.valid <= 0;
        bus.write <= 0;
        bus.read  <= 0;
    end
end
```

`bus` = 总线（bus），一组共享信号线（`write`/`read`/`wdata`/`rdata`/`ready`/`addr`/`valid`），CPU 和所有外设都挂在这组线上通信。

**Slave vs Master 对比**：

| 特征 | Slave（从设备） | Master（主设备） |
|---|---|---|
| 角色 | 响应请求 | 发起请求 |
| 产生信号 | `ready` | `valid` |
| 主动行为 | 等待并响应 | 发送地址和数据 |

**Slave 响应逻辑**：

| 总线动作 | 存储器行为 | 回应 |
|---|---|---|
| 发起写 (`write=1`) | 把 `wdata` 存进 `memory[addr]` | `ready=1`（写好了） |
| 发起读 (`read=1`) | 从 `memory[addr]` 取数据放到 `rdata` | `ready=1`（数据放好了） |
| 无请求 | 空闲 | `ready=0`（没在干活） |

### 4.2 case / casez — 多路分支

```verilog
// 基础 case — 状态机最常用
case (state)
    IDLE     : next_state = WORK;
    WORK     : next_state = DONE;
    DONE     : next_state = IDLE;
    default  : next_state = IDLE;    // 没匹配到时走这里
endcase

// casez — case 表达式中的 Z，以及 case item 中的 Z/? 视为 don't-care
// irq = interrupt request（中断请求），外设需要CPU处理时拉高irq信号
casez (irq)
    4'b???1 : $display("irq[0] is 1");  // 只关心 bit[0], 其他位不管
    4'b??1? : $display("irq[1] is 1");
    4'b?1?? : $display("irq[2] is 1");
endcase
```

| 类型 | 比较规则 | 常用场景 |
|---|---|---|
| `case` | 完全相等 | 状态机、译码器 |
| `casez` | Z 和 `?` 位可不关心；按分支顺序优先匹配 | 掩码译码、中断优先级 |
| `casex` | z 和 x 都不关心 | 极少用，别用 |

### 4.3 for / foreach — 循环

```verilog
// for — 和 C 一样
for (int i = 0; i < 16; i++)
    memory[i] = 0;

// foreach — 自动推断范围 (SV 推荐)
foreach (memory[i])
    memory[i] = 0;

// 多维 foreach
foreach (matrix[row, col])
    $display("matrix[%0d][%0d] = %0d", row, col, matrix[row][col]);
```

`foreach` = 对数组的每个元素都执行一遍。SV 推荐用它替代 `for`——不用写起点、终点、步长，自动根据数组维度推断。

```
foreach (数组名[索引变量])

foreach (memory[i])         // 一维：自动遍历 memory[0] 到 memory[最后一个]
foreach (matrix[r, c])      // 二维：自动遍历所有行和列
```

| 特性 | `for` | `foreach` |
|---|---|---|
| 范围 | 手动写 `i=0; i<16; i++` | 自动推断 |
| 写错边界 | 可能越界 | 不会 |
| 多维 | 手写嵌套 | `foreach(arr[i, j])` 一行遍历数组维度 |
| 推荐 | 计数循环、非数组循环 | 遍历数组元素时更简洁 |

## 第五层：封装 — 大块怎么搭

### 5.1 task — 有延时的子程序

```verilog
// 1. 复位任务
task reset_dut;
    begin
        reset = 1;
        #20;
        reset = 0;
        #10;
    end
endtask

// 调用
reset_dut;

// 2. 写寄存器任务
task write_reg(input [7:0] addr, data);
    begin
        @(negedge clk);      // 在 DUT 采样沿前驱动
        wr_en = 1;
        wr_addr = addr;
        wr_data = data;
        @(negedge clk);
        wr_en = 0;
    end
endtask

// 调用
write_reg(8'h00, 8'hFF);
write_reg(8'h10, 8'h55);

// 3. 等待就绪任务
task wait_ready(input int timeout = 100);
    begin
        int cnt = 0;
        while (!ready && cnt < timeout) begin
            @(posedge clk);
            cnt++;
        end
        if (!ready) $error("Timeout!");
    end
endtask

// 调用
wait_ready(50);

// 4. 时钟生成（注意：时钟生成直接用 always，不用 task）
always #10 clk = ~clk;  // 最常用写法
```

### 5.2 function — 零时间执行的子程序

```verilog
function int adder(int a, int b);
    return a + b;
endfunction

int result;
result = adder(3, 5);    // result = 8
```

### 5.3 task vs function

| 特性 | `task` | `function` |
|---|---|---|
| 返回值 | 可通过 `output/inout` 返回多个值 | 可有返回值；也可写成 `function void` |
| `#` / `@(posedge)` | ✅ 能 | ❌ 不能 |
| 消耗仿真时间 | ✅ | ❌（立刻算完） |
| 用在 | 接口操作、时序流程 | 数学计算、数据转换 |
| 调用 | `task_name(args);` | `result = func(args);` 或单独调用 `void'(...)` |

### 5.4 模块例化 — 盒子插盒子

**模块例化**就是把一个模块当作"盒子"插到另一个模块里使用。模块定义是模板，例化是创建实际使用的实例。

```verilog
// 模块名 #(参数) 实例名 (.端口(信号), ...);
// 实例名可以是任意合法标识符，Testbench中常用uut（Unit Under Test）

ram #(8, 5, 32) RAM (
    .clk_write(clk_write),       // .端口名(连接的信号)
    .data_write(data_write),
    .write_enable(write_enable),
    .clk_read(clk_read),
    .address_read(address_read),
    .data_read(data_read)        // 最后一个端口不加逗号
);
```

| 连接方式 | 语法 | 说明 |
|---|---|---|
| 按名连接 | `.端口(信号)` | 推荐，顺序随便 |
| 按位连接 | `ram RAM(s1, s2, ...)` | 顺序必须和声明一致 |
| 通配连接 | `dut(.*)` | 同名信号自动连 |

参数覆盖：

- `=赋值`是设置默认值（模块定义时用）
- `#传递`是在例化时从外部覆盖默认值（模块例化时用）

```verilog
// 模块定义：= 给默认值
module debounce #(parameter DELAY = 10) (...);
//                                  ↑ 默认10

// 模块例化：# 传新值覆盖
debounce #(.DELAY(20)) u_debounce (...);
//            ↑ 外部传20，覆盖默认的10
```

### 5.5 interface — 信号组封装

```verilog
interface bus_if(input logic clk);
    logic [31:0] addr, wdata, rdata;
    logic        write, read, valid, ready;

    task do_write(input logic [31:0] a, d);
        @(negedge clk);       // 在采样沿前驱动，避免 race
        addr  <= a;
        wdata <= d;
        write <= 1;
        read  <= 0;
        valid <= 1;
        do @(posedge clk); while (!ready);
        @(negedge clk);
        valid <= 0;
        write <= 0;
    endtask

    modport master (input clk, ready, rdata,
                    output addr, wdata, write, read, valid);
    modport slave  (input clk, addr, wdata, write, read, valid,
                    output ready, rdata);
endinterface

module master(bus_if.master bus);    // 一个 bus 替代多根信号，并限制方向
module slave(bus_if.slave bus);

module top;
    logic clk;
    bus_if bus(clk);
    master m(bus);
    slave  s(bus);
endmodule
```

好处：增删信号只改 `interface` 一处，不用每个模块改一遍。

### 5.6 typedef /enum/ struct

- **typedef** — 给类型起别名，简化声明
- **enum** — 为有限集合的取值命名；显式类型转换仍可构造其他位模式
- **struct** — 把多个变量打包成一个整体

```verilog
// typedef — 自定义类型别名
typedef logic [7:0] data_t;

// enum — 给值起名字；为避免同一作用域重名，使用前缀
typedef enum {S_IDLE, S_READ, S_WRITE, S_DONE} simple_state_t;

// struct — 打包相关信号
typedef struct packed {
    bit [7:0]  opcode;
    bit [15:0] addr;
    bit [7:0]  data;
} instruction_t;    // 总计 32 位
```

**没有 typedef/enum/struct 时（代码混乱）：**

```verilog
module bad_example(
    input  logic [7:0]  state,      // 这8位是什么？
    input  logic [31:0] addr,       // 地址？数据？
    input  logic [31:0] data,
    input  logic        type,       // 0还是1代表什么？
    input  logic [3:0]  burst_len   // 这4位啥意思？
);
```

看到代码完全不知道每个信号的含义和取值范围。

**有 typedef/enum/struct 后（代码清晰）：**

```verilog
// typedef：给类型起别名
typedef logic [7:0]  byte_t;
typedef logic [31:0] word_t;
typedef logic [3:0]  burst_len_t;

// enum：有限集合的取值 + 自动命名
typedef enum logic [7:0] {
    STATE_IDLE    = 8'h00,
    STATE_RUNNING = 8'h01,
    STATE_STOP    = 8'h02,
    STATE_ERROR   = 8'hFF
} state_t;

typedef enum logic {
    RW_READ  = 1'b0,
    RW_WRITE = 1'b1
} rw_t;

typedef enum logic [1:0] {
    BURST_1   = 2'b00,
    BURST_4   = 2'b01,
    BURST_8   = 2'b10,
    BURST_16  = 2'b11
} burst_t;

// struct：多个信号打包成一个整体
typedef struct packed {
    word_t       addr;
    word_t       data;
    rw_t         rw;
    burst_t      burst;
    burst_len_t  len;
} transaction_t;

// 使用
module good_example(
    input  state_t        state,      // 清楚：状态机状态
    input  transaction_t  txn         // 清楚：一次传输事务
);

    // 用 enum 名字，不用魔法数字
    if (state == STATE_IDLE) begin
        // ...
    end

    if (txn.rw == RW_WRITE) begin
        // 比 if (type == 1'b1) 清晰多了
    end

endmodule
```

| 写法 | 含义 |
|------|------|
| `if (type == 1'b1)` | 不知道1代表什么 |
| `if (txn.rw == RW_WRITE)` | 一眼看出是写操作 |
| `if (state == 8'hFF)` | 魔法数字，容易写错 |
| `if (state == STATE_ERROR)` | 清晰明了 |

封装层次从低到高：`typedef` → `enum` → `struct` → `class` → `interface`，都是封装，只是"重量"不同。

枚举标签位于声明它的作用域中；若多个 enum 放在同一 module/package/class，标签名称不能重复。工程中常用前缀、package 或 class 作用域避免冲突。

## 第六层：表达式 — 细节胶水

这一层的内容随手查就行，不需要背。

### 6.1 字面量

```
<位宽>'<进制符><数值>

  8    '    b     1010_0101
  ↑         ↑     ↑
位宽       进制   值(_是分隔符, 无意义)
```

| 符号 | 进制 | 合法字符 |
|---|---|---|
| `'b` | 二进制 | `0` `1` `x` `z` `_` |
| `'h` | 十六进制 | `0-9` `A-F` `a-f` `x` `z` `_` |
| `'d` | 十进制 | `0-9` `x` `z` `_` |
| `'o` | 八进制 | `0-7` `x` `z` `_` |

```verilog
8'b1000_0000       // 无符号 → 128
8'sb1000_0000      // 有符号 → -128 (s = signed)
8'sh80             // 有符号十六进制 → -128
'hF                 // 未写位宽的十六进制常量至少为 32 位；表达式上下文仍可能影响最终位宽

'0    // 全 0, 宽度由上下文推断
'1    // 全 1
'x    // 全 x
'z    // 全 z
```

### 6.2 运算符

**取反**

```verilog
~   // 按位取反 — 每一位 0→1, 1→0   (~8'b1010 = 8'b0101)
!   // 逻辑取反 — 只看整体真假     (!8'b1010 = 1'b0)
```

| 运算符 | `~` 按位取反 | `!` 逻辑取反 |
|---|---|---|
| 操作 | 每一位单独翻 | 整个值判真假 |
| 结果位宽 | 和原值一样 | 永远是 1 位 |
| 用在 | `clk = ~clk`、数据取反 | `if (!rst_n)` |

翻转时钟原理：

```verilog
initial clk = 0;
always #5 clk = ~clk;

 0ns: clk=0  →  5ns: ~0=1  →  10ns: ~1=0  →  15ns: ~0=1  →  ...
```

```
  1  ┌──┐     ┌──┐     ┌──
     │  │     │  │     │
  0  ┘  └─────┘  └─────┘
     ←5ns→ ←── 周期10ns ──→
```

**比较**

```verilog
===    // 全等 — 能比较 x 和 z (1'bx === 1'bx = 1)
==     // 逻辑相等 — 比到 x 返回 x (1'bx == 1'bx = x)
```

**位拼接**

```verilog
{a, b} = {8'd3, 8'd5};        // 打包赋值
{carry, sum} = a + b;          // 拆包
```

**切片**

```verilog
data[7:0]           // 固定切片 — M 和 N 必须是常数
data[base +: 8]     // 可变切片 — base 可变量, 往上取 8 位
data[15 -: 8]       // 往下取 8 位 (= data[15:8])
```

**归约**

```verilog
&data    // 归约与: 全 1 得 1
|data    // 归约或: 有 1 就得 1
^data    // 归约异或: 奇数个 1 得 1
```

**移位**

```verilog
data << 2     // 逻辑左移 — 低位补 0
data >> 2     // 逻辑右移 — 高位补 0
data >>> 2    // 算术右移 — 高位补符号位 (保持正负性)

// byte b = -128 (8'b1000_0000)
// b >>> 1 = 8'b1100_0000 = -64  ← 保持负数
// b >>  1 = 8'b0100_0000 = 64   ← 变正数了!
```

**三元**

```verilog
out = (sel) ? a : b;    // 等价于 if(sel) out=a else out=b
```

### 6.3 常用系统函数

| 函数 | 作用 |
|---|---|
| `$display("fmt", args)` | 打印到控制台 |
| `$sformatf("fmt", args)` | 格式化到字符串 |
| `$time` | 当前仿真时间 |
| `$finish` | 结束仿真 |
| `$dumpfile("dump.vcd")` | 指定波形文件名 |
| `$dumpvars(N, module)` | 指定要 dump 的信号 |

`$display` 格式符 — 和 C 语言 printf 一样：

```verilog
$display("wrote %h to %h", data, addr);
         ↑               ↑         ↑
       格式串          第一个%h   第二个%h
                       代入data   代入addr
```

| 格式符 | 含义 | 示例（值=255） |
|---|---|---|
| `%h` | 十六进制，使用默认显示宽度 | `ff` |
| `%d` | 十进制，使用默认显示宽度 | `255` |
| `%b` | 二进制 binary | `11111111` |
| `%0h` | 十六进制，不使用默认宽度填充 | `ff` |
| `%0d` | 十进制，不使用默认宽度填充 | `255` |

不加 `0` 时使用默认字段宽度；`%0h`/`%0d` 使用最小必要宽度。十六进制的前导零、十进制的空格填充会随数据类型和字段宽度而变化，因此不应简单理解为“是否补空格”。

### 6.4 注释

```verilog
// 单行注释

/*
   多行注释
   和 C/C++/Java 一样
*/
```

## 附录A：你代码里的实物对照

```verilog
// adder.v — assign = 组合逻辑
assign sum = a + b;                    // 没有时钟, 永远在线

// RAM.sv — always(posedge) = 时序逻辑
always @(posedge clk_write) begin
    if (write_enable)
        memory[addr] <= data_write;    // <= 非阻塞
end

// sv_basics.sv — always_ff + always_comb 配合
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)  result <= 0;          // <= 非阻塞 + 异步复位
    else         result <= result_comb;
end

always_comb begin
    result_comb = mult_stage1 + c_stage1; // = 阻塞 + 组合逻辑
end
```

| 语法 | 你在哪见过 |
|---|---|
| `module ... endmodule` | 所有文件 |
| `parameter` | `RAM.sv`, `sv_basics.sv` |
| `input` / `output` | `RAM.sv`, `adder.v`, `sv_basics.sv`, `sv_interface.sv` |
| `assign` | `adder.v` |
| `always @(posedge ...)` | `RAM.sv`, `sv_interface.sv` |
| `always #N clk = ~clk` | `adder.v`, `sv_basics.sv`, `sv_interface.sv` |
| `always_ff` | `sv_basics.sv` |
| `always_comb` | `sv_basics.sv` |
| `initial` | `testbench.sv`, `adder.v`, `data_type.sv`, `arrays.sv`, `sv_basics.sv` |
| `begin` / `end` | 所有文件 |
| `if` / `else` | `RAM.sv`, `data_type.sv`, `sv_interface.sv` |
| `case` | (暂无, 但第一册已收录) |
| `for` / `foreach` | `arrays.sv` |
| `task` | `testbench.sv`, `sv_interface.sv` |
| `function` | (暂无, 但第一册已收录) |
| `#N;` | `testbench.sv`, `adder.v`, 所有 TB |
| `@(posedge ...)` | `sv_basics.sv`, `sv_interface.sv` |
| `{a,b}` 拼接 | `adder.v` |
| `===` | `data_type.sv` |
| `^` 归约异或 | `data_type.sv` |
| `!` / `~` | `sv_basics.sv`, `adder.v` |
| `$display` | 所有 TB 文件 |
| `$dumpfile` / `$dumpvars` | `testbench.sv`, `adder.v`, `sv_basics.sv` |
| `$finish` / `$time` | `adder.v`, `sv_basics.sv` |
| `#(参数)` + `.端口(信号)` | `testbench.sv`, `sv_basics.sv` |
| `.*` 通配连接 | `sv_basics.sv` |
| `interface` | `sv_interface.sv` |
| `'0` 填充 | `sv_basics.sv` |

## 附录B：通用语法完整地图

按层级排，全部 ✅ 就代表通用语法毕业。

### 第〇层 硬件直觉

- ✅ 0/1/位/向量
- ✅ 时钟(clk)/上升沿/下降沿
- ✅ 寄存器 vs 组合逻辑

### 第一层 声明

- ✅ `module`/`endmodule` `input`/`output` `parameter`
- ✅ 数据类型 (`logic`/`bit`/`int`/`byte`/`enum`/`struct`)
- ✅ 数组 (packed/unpacked/dynamic/queue/assoc)

### 第二层 赋值

- ✅ `assign` `always` `=` vs `<=`

### 第三层 时序控制

- ✅ `initial` `#N` `@(posedge)` / `@(negedge)`

### 第四层 流程控制

- ✅ `if`/`else` `case`/`casez` `for`/`foreach`

### 第五层 封装

- ✅ `task` `function` 模块例化 (`.端口`, `#参数`, `.*`)
- ✅ `interface` `typedef` `enum`/`struct`

### 第六层 表达式

- ✅ `~` / `!` / `===` `? :` `{a,b}` 拼接
- ✅ `[M:N]` / `[+: ]` 归约 `&` `|` `^` `<<` `>>` `<<<` `>>>`
- ✅ `'b`/`'h`/`'d`/`'o` `'sb`/`'sh` `'0`/`'1`/`'x`/`'z`
- ✅ `$display`/`$dumpfile`/`$finish`/`$time`
- ✅ `//` 和 `/* */` 注释

## 附录C：常见坑

| 坑 | 说明 |
|---|---|
| 时序逻辑里用 `=` | `always @(posedge clk)` 里用 `=` 会导致意外顺序, 用 `<=` |
| 组合逻辑里用 `<=` | 通常仍能编译，但调度语义不符合组合逻辑预期；应使用 `=`，lint 常会报警 |
| 忘记复位 | 仿真一开始寄存器是 x, 不复位永远是 x |
| 位宽不够 | 若只写 `assign sum = a + b;`，8 位 `sum` 会丢弃进位；应使用 9 位结果或 `{carry, sum}` |
| `always_comb` 不完整 | `if` 没写 else 可能综合出锁存器 (latch) |
| `byte` 是有符号的 | `8'hFF` 赋给 `byte` = -1, 不是 255 |
| `bit` 吞 x | 含 x 的 DUT 信号接给 `bit` 变量 → x 变 0 → bug 藏掉 |
| 不写位宽 | `'hF` 至少为 32 位，参与表达式时易出现符号扩展或截断误判 |

---

*最后更新: 2026-07-22*
