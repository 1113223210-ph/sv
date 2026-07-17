---
title: "跨时钟域同步器"
description: "入门级数字设计练习：跨时钟域同步器"
pubDate: 2025-01-01category: soc
order: 6
tags: [SOC, 入门, 跨时钟域]
---

# 跨时钟域同步器 完整练习

## 1. 模块功能说明

跨时钟域同步器解决**不同时钟域之间信号传递**的问题，防止亚稳态传播。

```
应用场景:
- 双时钟 FIFO（异步FIFO）
- CPU 与外设之间的握手
- 多时钟域 SoC 设计
- 任意异步信号同步
```

## 2. 亚稳态问题详解

### 什么是亚稳态？

```
正常采样:
                ┌───┐
CLK        ─────┘   └─────────────
                 ↑
DATA       ──────X─────────────────  ← 数据稳定
                 │
                 ▼
Q          ──────X─────────────────  ← 正确采样

亚稳态（数据在时钟沿附近变化）:
                ┌───┐
CLK        ─────┘   └─────────────
                 ↑
DATA       ────X─X─X───────────────  ← 数据在时钟沿变化！
                 │ │ │
                 ▼ ▼ ▼
Q          ─────?─?─?───────────────  ← 输出不确定！

亚稳态的危害:
1. 输出值不确定（可能是 0 或 1）
2. 输出可能振荡
3. 可能传播到下游逻辑，导致系统故障
```

### 为什么需要两级同步器？

```
一级同步器（不推荐）:
               ┌──────────────────────────┐
异步信号 ────→ │ DFF1 (可能亚稳态)        │ ────→ 下游逻辑
               └──────────────────────────┘
                        ↑
                   如果 DFF1 进入亚稳态，
                   输出不确定，直接传给下游

两级同步器（推荐）:
               ┌─────────┐    ┌─────────┐
异步信号 ────→ │ DFF1    │───→│ DFF2    │ ────→ 下游逻辑
               │(可能亚稳)│    │(稳定)   │
               └─────────┘    └─────────┘
                        ↑           ↑
                   第一级可能    第二级有完整时钟周期
                   进入亚稳态    来稳定输出

原理:
- DFF1 进入亚稳态的概率很高
- DFF1 的亚稳态需要时间稳定（通常 < 1 个时钟周期）
- DFF2 在下一个时钟沿采样时，DFF1 大概率已经稳定
- 两级同时亚稳态的概率极低（MTBF = 数年）
```

### MTBF 计算

```
MTBF = T_w / (f_CLK × f_DATA × P_META)

T_w:    稳定时间窗口（通常 = 时钟周期）
f_CLK:  目标时钟频率
f_DATA: 源数据变化频率
P_META: 单级亚稳态概率（由工艺决定）

两级同步器:
MTBF_2 = MTBF_1 × (T_w / τ)

τ: DFF 的亚稳态时间常数（~数十皮秒）

例: f_CLK=100MHz, f_DATA=10MHz, T_w=10ns, τ=20ps
    MTBF_1 ≈ 5000 秒（约1.4小时）
    MTBF_2 ≈ 2.5 × 10^9 秒（约80年）✓
```

## 3. 完整代码

### sync_2ff.sv

```verilog
//=============================================================================
// Module: sync_2ff
// Description: 两级同步器 - 用于单比特信号跨时钟域
pubDate: 2025-01-01?n//              解决亚稳态问题
// Author: 学习笔记
// Date: 2026-07-13
//=============================================================================

module sync_2ff #(
    parameter INIT_VAL = 1'b0    // 初始值
)(
    input  logic clk_dst,        // 目标时钟域时钟
    input  logic rst_n,          // 异步复位（低有效）
    input  logic data_src,       // 源时钟域信号
    output logic data_dst        // 同步到目标时钟域的信号
);

    //=========================================================================
    // 两级寄存器
    //=========================================================================
    logic sync_reg1;     // 第一级（可能亚稳态）
    logic sync_reg2;     // 第二级（稳定输出）

    always_ff @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            sync_reg1 <= INIT_VAL;
            sync_reg2 <= INIT_VAL;
        end else begin
            sync_reg1 <= data_src;  // 第一级：采样异步信号
            sync_reg2 <= sync_reg1; // 第二级：输出稳定值
        end
    end

    assign data_dst = sync_reg2;

endmodule
```

### sync_2ff_multi.sv

```verilog
//=============================================================================
// Module: sync_2ff_multi
// Description: 多比特两级同步器
pubDate: 2025-01-01?n//              注意：多比特信号不建议直接同步，应使用握手或异步FIFO
//=============================================================================

module sync_2ff_multi #(
    parameter WIDTH    = 8,
    parameter INIT_VAL = 0
)(
    input  logic              clk_dst,
    input  logic              rst_n,
    input  logic [WIDTH-1:0]  data_src,
    output logic [WIDTH-1:0]  data_dst
);

    logic [WIDTH-1:0] sync_reg1;
    logic [WIDTH-1:0] sync_reg2;

    always_ff @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            sync_reg1 <= INIT_VAL;
            sync_reg2 <= INIT_VAL;
        end else begin
            sync_reg1 <= data_src;
            sync_reg2 <= sync_reg1;
        end
    end

    assign data_dst = sync_reg2;

endmodule
```

### sync_handshake.sv

```verilog
//=============================================================================
// Module: sync_handshake
// Description: 握手同步器 - 用于多比特信号跨时钟域
pubDate: 2025-01-01?n//              使用 req/ack 握手协议
//=============================================================================

module sync_handshake #(
    parameter WIDTH = 32
)(
    // 源时钟域
    input  logic             clk_src,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] data_in,
    input  logic             valid,      // 源端数据有效
    output logic             ready,      // 源端就绪
    
    // 目标时钟域
    input  logic             clk_dst,
    output logic [WIDTH-1:0] data_out,
    output logic             valid_out,  // 目标端数据有效
    input  logic             ready_out   // 目标端就绪
);

    //=========================================================================
    // 源时钟域：锁存数据，产生 req
    //=========================================================================
    logic [WIDTH-1:0] data_reg;
    logic req_toggle;       // req 翻转信号
    logic ack_sync1, ack_sync2;  // ack 同步后
    
    always_ff @(posedge clk_src or negedge rst_n) begin
        if (!rst_n) begin
            data_reg   <= '0;
            req_toggle <= 1'b0;
        end else if (valid && ready) begin
            data_reg   <= data_in;
            req_toggle <= ~req_toggle;  // 翻转表示新数据
        end
    end
    
    // 同步 ack 信号到源时钟域
    always_ff @(posedge clk_src or negedge rst_n) begin
        if (!rst_n) begin
            ack_sync1 <= 1'b0;
            ack_sync2 <= 1'b0;
        end else begin
            ack_sync1 <= req_toggle;    // ack 与 req 相同表示已接收
            ack_sync2 <= ack_sync1;
        end
    end
    
    assign ready = (ack_sync2 == req_toggle);  // ack 与 req 相同表示空闲

    //=========================================================================
    // 目标时钟域：检测 req，输出数据，产生 ack
    //=========================================================================
    logic req_sync1, req_sync2;
    logic ack_toggle;
    logic data_valid;
    
    // 同步 req 信号到目标时钟域
    always_ff @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            req_sync1 <= 1'b0;
            req_sync2 <= 1'b0;
        end else begin
            req_sync1 <= req_toggle;
            req_sync2 <= req_sync1;
        end
    end
    
    // 检测 req 变化，锁存数据
    always_ff @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            data_out   <= '0;
            ack_toggle <= 1'b0;
            data_valid <= 1'b0;
        end else if (req_sync2 != ack_toggle) begin
            // req 与 ack 不同，表示有新数据
            data_out   <= data_reg;
            ack_toggle <= ~ack_toggle;  // 发送 ack
            data_valid <= 1'b1;
        end else begin
            data_valid <= 1'b0;
        end
    end
    
    assign valid_out = data_valid;

endmodule
```

## 4. Testbench

### tb_sync_2ff.sv

```verilog
//=============================================================================
// Testbench: tb_sync_2ff
// Description: 两级同步器测试平台
pubDate: 2025-01-01?n//=============================================================================

`timescale 1ns / 1ps

module tb_sync_2ff;

    //=========================================================================
    // 参数
    //=========================================================================
    parameter CLK_SRC_PERIOD = 8;    // 源时钟 125MHz
    parameter CLK_DST_PERIOD = 10;   // 目标时钟 100MHz

    //=========================================================================
    // 信号
    //=========================================================================
    logic clk_src, clk_dst;
    logic rst_n;
    logic data_src;
    logic data_dst;

    //=========================================================================
    // 时钟生成（异步时钟）
    //=========================================================================
    initial clk_src = 0;
    initial clk_dst = 0;
    always #(CLK_SRC_PERIOD/2) clk_src = ~clk_src;
    always #(CLK_DST_PERIOD/2) clk_dst = ~clk_dst;

    //=========================================================================
    // 实例化被测模块
    //=========================================================================
    sync_2ff uut (
        .clk_dst   (clk_dst),
        .rst_n     (rst_n),
        .data_src  (data_src),
        .data_dst  (data_dst)
    );

    //=========================================================================
    // 测试激励
    //=========================================================================
    initial begin
        // 初始化
        rst_n = 0;
        data_src = 0;
        
        #25;
        rst_n = 1;
        #10;
        
        $display("=== 两级同步器测试开始 ===");
        $display("源时钟: %0d MHz", 1000/CLK_SRC_PERIOD);
        $display("目标时钟: %0d MHz", 1000/CLK_DST_PERIOD);
        $display("");
        
        //=====================================================================
        // 测试 1: 正常数据传输
        //=====================================================================
        $display("--- 测试 1: 正常数据传输 ---");
        data_src = 1;
        #100;
        data_src = 0;
        #100;
        data_src = 1;
        #200;
        $display("");
        
        //=====================================================================
        // 测试 2: 快速变化（最坏情况）
        //=====================================================================
        $display("--- 测试 2: 快速变化（亚稳态风险）---");
        repeat(20) begin
            #((CLK_SRC_PERIOD + CLK_DST_PERIOD) / 4);
            data_src = ~data_src;
        end
        #100;
        $display("");
        
        //=====================================================================
        // 测试 3: 数据在时钟沿附近变化（高风险）
        //=====================================================================
        $display("--- 测试 3: 数据在时钟沿附近变化 ---");
        // 精确控制数据变化时刻，使其接近目标时钟沿
        repeat(10) begin
            @(posedge clk_dst);
            #1;  // 目标时钟沿后 1ns 变化
            data_src = ~data_src;
            #2;
            data_src = ~data_src;
        end
        #200;
        $display("");
        
        //=====================================================================
        // 测试 4: 长时间运行（检测 MTBF）
        //=====================================================================
        $display("--- 测试 4: 长时间运行测试 ---");
        repeat(1000) begin
            @(posedge clk_src);
            data_src = $random;
        end
        $display("  完成 1000 次随机变化");
        
        $display("");
        $display("=== 两级同步器测试结束 ===");
        $finish;
    end

    //=========================================================================
    // 波形输出
    //=========================================================================
    initial begin
        $dumpfile("wave_sync_2ff.vcd");
        $dumpvars(0, tb_sync_2ff);
    end

    //=========================================================================
    // 监控亚稳态（简化版）
    //=========================================================================
    // 实际仿真中难以直接检测亚稳态，这里监控数据变化
    logic data_src_d;
    always_ff @(posedge clk_dst) data_src_d <= data_src;
    
    always @(posedge clk_dst) begin
        if (data_src !== data_src_d && data_src !== data_dst)
            $display("时间=%0t: 注意! 数据变化中 data_src=%b, data_dst=%b", 
                     $time, data_src, data_dst);
    end

endmodule
```

### tb_sync_handshake.sv

```verilog
//=============================================================================
// Testbench: tb_sync_handshake
// Description: 握手同步器测试平台
pubDate: 2025-01-01?n//=============================================================================

`timescale 1ns / 1ps

module tb_sync_handshake;

    parameter WIDTH = 8;
    parameter CLK_SRC_PERIOD = 10;
    parameter CLK_DST_PERIOD = 13;  // 不同频率

    logic clk_src, clk_dst;
    logic rst_n;
    logic [WIDTH-1:0] data_in;
    logic valid, ready;
    logic [WIDTH-1:0] data_out;
    logic valid_out, ready_out;

    initial clk_src = 0;
    initial clk_dst = 0;
    always #(CLK_SRC_PERIOD/2) clk_src = ~clk_src;
    always #(CLK_DST_PERIOD/2) clk_dst = ~clk_dst;

    sync_handshake #(.WIDTH(WIDTH)) uut (
        .clk_src   (clk_src),
        .rst_n     (rst_n),
        .data_in   (data_in),
        .valid     (valid),
        .ready     (ready),
        .clk_dst   (clk_dst),
        .data_out  (data_out),
        .valid_out (valid_out),
        .ready_out (ready_out)
    );

    initial begin
        rst_n = 0;
        data_in = 0;
        valid = 0;
        ready_out = 1;
        
        #25;
        rst_n = 1;
        #10;
        
        $display("=== 握手同步器测试开始 ===");
        
        // 发送 5 个数据
        repeat(5) begin
            @(posedge clk_src);
            data_in = $random;
            valid = 1;
            wait(ready);
            @(posedge clk_src);
            valid = 0;
            #50;
        end
        
        #200;
        $display("=== 握手同步器测试结束 ===");
        $finish;
    end

    initial begin
        $dumpfile("wave_sync_handshake.vcd");
        $dumpvars(0, tb_sync_handshake);
    end

    always @(posedge clk_dst) begin
        if (valid_out)
            $display("时间=%0t: 目标端收到数据 %0d", $time, data_out);
    end

endmodule
```

## 5. 仿真波形分析

```
两级同步器时序:

CLK_SRC   ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
            └──┘  └──┘  └──┘  └──┘  └──┘

DATA_SRC  ──────┐        ┌───────────────
                └────────┘
                      ↑ 异步变化

CLK_DST   ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
            └──┘  └──┘  └──┘  └──┘  └──┘

SYNC_REG1 ────────┐        ┌─────────────
             (可能亚稳) └────────┘

SYNC_REG2 ──────────┐        ┌───────────
               (稳定) └────────┘

DATA_DST  ──────────┐        ┌───────────
                     └────────┘
                     ↑ 延迟约 2 个目标时钟周期
```

## 6. 练习任务

### 任务 1：基础验证（必做）

```bash
# 编译
iverilog -o tb_sync_2ff tb_sync_2ff.sv sync_2ff.sv

# 运行仿真
vvp tb_sync_2ff

# 查看波形
gtkwave wave_sync_2ff.vcd
```

**观察并记录：**
- [ ] 输出信号延迟了多少个时钟周期？
- [ ] 快速变化时输出是否稳定？
- [ ] 是否观察到亚稳态现象？

### 任务 2：频率影响（必做）

测试不同时钟频率组合：

```verilog
// 测试用例
parameter CLK_SRC_PERIOD = 5;    // 200MHz
parameter CLK_DST_PERIOD = 10;   // 100MHz

// 反向
parameter CLK_SRC_PERIOD = 10;   // 100MHz
parameter CLK_DST_PERIOD = 5;    // 200MHz
```

**记录：**
- 不同频率组合下的同步延迟
- 亚稳态出现的频率

### 任务 3：多比特同步（选做）

实现并测试多比特同步器：

```verilog
// 要求：
// 1. 实现 8 比特同步器
// 2. 测试数据完整性
// 3. 对比直接同步 vs 握手同步
```

### 任务 4：握手同步器验证（选做）

编写完整的 Testbench，验证握手同步器：

1. 发送端连续发送 10 个数据
2. 接收端随机延迟接收
3. 验证数据完整性

## 7. 常见错误

| 错误 | 原因 | 解决方法 |
|---|---|---|
| 多比特数据错误 | 直接同步多比特信号 | 使用握手或异步FIFO |
| 同步延迟太大 | 不必要的额外级数 | 通常两级足够 |
| 复位释放时机 | 复位释放导致亚稳态 | 使用异步复位同步释放 |

## 8. 跨时钟域方案对比

| 方案 | 适用场景 | 延迟 | 复杂度 | 可靠性 |
|---|---|---|---|---|
| **两级同步** | 单比特信号 | 2周期 | 低 | 高 |
| **握手同步** | 多比特低频 | 变化 | 中 | 高 |
| **异步FIFO** | 多比特高频 | 确定 | 高 | 极高 |
| **脉冲同步** | 脉冲信号 | 2周期 | 低 | 高 |

### 选择指南

```
信号类型?
├── 单比特 ──────────→ 两级同步器
│
└── 多比特
    ├── 低频 (<1MHz) → 握手同步器
    └── 高频 (>1MHz) → 异步 FIFO

数据量?
├── 偶发 ────────────→ 握手同步器
└── 连续流 ──────────→ 异步 FIFO
```

## 9. 知识点总结

### 两级同步器原理

```
MTBF (Mean Time Between Failures):
- 单级: MTBF₁ = T_w / (f_CLK × f_DATA × P_META)
- 两级: MTBF₂ = MTBF₁ × (T_w / τ)
- τ 是 DFF 的亚稳态时间常数（~20ps）

实际 MTBF:
- 100MHz 时钟, 10MHz 数据
- 单级 MTBF ≈ 1.4 小时（不可靠）
- 两级 MTBF ≈ 80 年（足够可靠）
```

### 关键要点

| 要点 | 说明 |
|---|---|
| **两级足够** | 大多数场景两级同步器足够 |
| **异步复位** | 复位信号也需要同步 |
| **多比特问题** | 不能直接用两级同步 |
| **延迟代价** | 同步会引入 2 个时钟周期延迟 |

## 10. 扩展阅读

- **异步 FIFO 设计** - 完整的多比特同步方案
- **Clock Domain Crossing (CDC)** - 跨时钟域设计方法学
- **Metastability in Digital Design** - 亚稳态的深入分析

---

*完成本练习后，你应该掌握：*
- [x] 亚稳态原理
- [x] 两级同步器设计
- [x] MTBF 计算
- [x] 跨时钟域方案选择