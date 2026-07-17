---
title: "SystemVerilog 设计专用语法"
description: "SystemVerilog设计专用语法指南，涵盖always变体、时序逻辑建模、复位策略、generate等硬件设计专属内容"
pubDate: 2025-01-01
category: sv
order: 2
tags: [SV, 设计]
---

# SystemVerilog 设计专用语法

> 这些语法主要用于RTL设计，描述实际硬件电路行为

---

## 层级总览

```
第三层  时序       always, always_ff, always_comb, always_latch
        ↓            (什么时候动)
第四层  生成       generate, genvar
        ↓            (编译期批量生成)
```

---

## 第三层：时序 — 什么时候动

### 3.1 always 四种变体

```verilog
// ① 时序 — 上升沿触发（最常用）
always @(posedge clk) begin
    if (!rst_n)  count <= 0;
    else         count <= count + 1;
end

// ② 时序 — 带异步复位
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)  result <= 0;
    else         result <= data;
end    // rst_n 下降沿直接复位, 不等 clk

// ③ 组合 — 老写法
always @(*) begin
    sum = a + b;     // *=任何输入变化都触发
end

// ④ SV 推荐写法
always_comb begin                    // 明确组合逻辑
    result_comb = mult_stage1 + c_stage1;
end

always_ff @(posedge clk) begin       // 明确时序逻辑
    q <= d;
end
```

| 写法 | 意图 | 推荐? |
|---|---|---|
| `always @(posedge clk)` | 时序 | ✅ 通用 |
| `always_ff @(posedge clk)` | 明确时序 | ✅ SV 推荐 |
| `always @(*)` | 组合 | ⚠️ 老写法 |
| `always_comb` | 明确组合 | ✅ SV 推荐 |

### 3.2 initial vs always 对比

| 特性 | `initial` | `always` |
|---|---|---|
| 执行次数 | 1 次 | 无限循环 |
| 可综合 | ❌ | ✅（有时钟的那种） |
| 用在 | TB 初始化 | 设计逻辑/时钟生成 |
| 多个块之间 | 并行 | 并行 |

### 3.3 clk — 芯片的心跳

`clk` = clock（时钟）的缩写。一根不停在 0 和 1 之间跳变的线。

```
clk:   ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
       │  │  │  │  │  │  │  │  │  │  │
────────┘  └──┘  └──┘  └──┘  └──┘  └──
       ← 一个周期 →      ← 频率 = 1/周期
```

| 概念 | 直白解释 |
|---|---|
| `clk` | 周期性 0/1 跳变的线 |
| 频率 | 每秒跳多少次（1 GHz = 每秒 10 亿次） |
| 周期 | 跳一次多久 |
| 为什么叫 clock | 芯片的"时钟"，所有寄存器踩同一个鼓点 |

设计中生成 clk：

```verilog
// 设计中通常由外部提供时钟
input logic clk;

// 或者用 PLL/MMCM 生成
// 时钟生成单元例化
```

### 3.4 信号命名约定 — rst / rst_n / _n 后缀

`rst` = reset（复位）。当 `rst` 有效时，所有寄存器回到初始状态。

两种常见命名：

| 信号名 | 有效电平 | 怎么判断在复位 |
|---|---|---|
| `rst` | 高有效 | `if (rst)` |
| `rst_n` | 低有效 | `if (!rst_n)` |

后缀约定：

| 后缀 | 全称 | 含义 | 常见度 |
|---|---|---|---|
| （无后缀） | — | 高电平有效，默认约定 | ⭐⭐⭐ |
| `_n` | negative | 低电平有效 | ⭐⭐⭐ |
| `_p` | positive | 高电平有效，显式标出 | ⭐ 极少用 |

绝大多数信号默认高有效，不加后缀就够了。`_n` 之所以普遍，正是因为它打破了默认——不加别人会误以为高有效。`_p` 则是"本来默认就是高有效还非要标"，几乎没有代码这样写。

```
rst    = 1  →  正在复位
rst_n  = 0  →  正在复位    （低有效，反直觉所以要后缀提醒）
```

`if (!rst_n)` 等价于 `if (rst_n == 0)` —— "复位被拉低了？"

真实芯片里复位通常低有效，因为上电瞬间电源不稳定，用低电平做复位更安全可靠。

---

## 时序逻辑建模

### 基本时序逻辑

```verilog
// D触发器
always_ff @(posedge clk) begin
    q <= d;
end

// 带使能的D触发器
always_ff @(posedge clk) begin
    if (en)
        q <= d;
end

// 带复位的D触发器
always_ff @(posedge clk) begin
    if (!rst_n)
        q <= 1'b0;
    else
        q <= d;
end
```

### 非阻塞赋值（<=）在设计中的应用

```verilog
// 流水线寄存器
always_ff @(posedge clk) begin
    stage1 <= data_in;
    stage2 <= stage1;
    stage3 <= stage2;
end

// 移位寄存器
always_ff @(posedge clk) begin
    shift_reg <= {shift_reg[WIDTH-2:0], serial_in};
end

// 计数器
always_ff @(posedge clk) begin
    if (!rst_n)
        count <= 0;
    else if (count == MAX)
        count <= 0;
    else
        count <= count + 1;
end
```

---

## 复位策略

### 异步复位

```verilog
// 异步复位，同步释放
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 异步复位：rst_n下降沿立即生效
        state <= IDLE;
        data <= 0;
    end else begin
        // 正常工作：只在clk上升沿更新
        state <= next_state;
        data <= next_data;
    end
end
```

**敏感列表**：`@(posedge clk or negedge rst_n)`
- `negedge rst_n`在敏感列表中
- 复位信号变化时**立即响应**，不等时钟

### 同步复位

```verilog
// 同步复位：只在clk边沿检查复位
always_ff @(posedge clk) begin
    if (!rst_n) begin
        // 同步复位：只在clk上升沿时检查rst_n
        state <= IDLE;
        data <= 0;
    end else begin
        state <= next_state;
        data <= next_data;
    end
end
```

**敏感列表**：`@(posedge clk)`
- 复位检查**只在时钟边沿**发生

### 异步复位 vs 同步复位对比

| 特性 | 异步复位 | 同步复位 |
|---|---|---|
| 响应速度 | 立即响应 | 等待时钟边沿 |
| 敏感列表 | 含`negedge rst_n` | 只含`posedge clk` |
| 抗亚稳态 | 需要同步处理 | 天然同步 |
| 面积 | 稍大 | 稍小 |
| 推荐场景 | 大多数设计 | 高速设计 |

### 异步复位同步释放

```verilog
// 推荐做法：异步复位，同步释放
logic rst_n_sync;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rst_n_sync <= 1'b0;  // 异步复位
    end else begin
        rst_n_sync <= 1'b1;  // 同步释放
    end
end

// 使用同步后的复位
always_ff @(posedge clk or negedge rst_n_sync) begin
    if (!rst_n_sync)
        state <= IDLE;
    else
        state <= next_state;
end
```

---

## 第四层：生成 — 编译期批量生成

### 4.1 generate / genvar — 编译期批量生成

```verilog
genvar i;
generate
    for (i = 0; i < 16; i++) begin : gen_block
        assign out[i] = data[i] & mask[i];
    end
endgenerate
// 等价于手写 16 行 assign, 不用复制粘贴
```

### 4.2 generate if — 条件生成

```verilog
generate
    if (WIDTH == 8) begin : gen_8bit
        assign out = data[7:0];
    end else if (WIDTH == 16) begin : gen_16bit
        assign out = data[15:0];
    end else begin : gen_default
        assign out = data[WIDTH-1:0];
    end
endgenerate
```

### 4.3 generate for — 循环生成

```verilog
// 生成16个D触发器
genvar i;
generate
    for (i = 0; i < 16; i++) begin : gen_ff
        always_ff @(posedge clk) begin
            q[i] <= d[i];
        end
    end
endgenerate
```

### 4.4 generate case — 多路选择生成

```verilog
generate
    case (MODE)
        0: begin : gen_mode0
            assign out = a & b;
        end
        1: begin : gen_mode1
            assign out = a | b;
        end
        default: begin : gen_default
            assign out = 1'b0;
        end
    endcase
endgenerate
```

---

## 时钟生成

### 设计中的时钟

```verilog
// 设计中通常不自己生成时钟
// 时钟由外部PLL/MMCM提供

module my_design (
    input logic clk,        // 外部输入时钟
    input logic rst_n,
    // ...
);
    // 直接使用clk
    always_ff @(posedge clk) begin
        // ...
    end
endmodule
```

### 仿真中的时钟生成

```verilog
// TB中生成时钟（不可综合）
initial clk = 0;
always #5 clk = ~clk;           // 每 5ns 翻转 → 周期 10ns → 频率 100MHz

// 或者
always #(CLK_PERIOD/2) clk = ~clk;
```

---

## 附录：设计语法速查表

| 语法 | 用途 | 可综合 |
|---|---|---|
| `always_ff` | 时序逻辑 | ✅ |
| `always_comb` | 组合逻辑 | ✅ |
| `always_latch` | 锁存器 | ✅ |
| `generate` | 编译期生成 | ✅ |
| `genvar` | 生成变量 | ✅ |
| `initial` | 初始化（TB） | ❌ |
| `forever` | 无限循环（TB） | ❌ |

---

*最后更新: 2026-07-16*