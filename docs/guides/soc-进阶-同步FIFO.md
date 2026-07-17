---
title: "同步FIFO"
description: "进阶级数字设计练习：同步FIFO"
pubDate: 2025-01-01category: soc
order: 9
tags: [SOC, 进阶, FIFO]
---

# 同步FIFO 完整练习

## 1. 模块功能说明

同步FIFO（First In First Out）是先进先出队列，用于数据缓冲和速率匹配。

```
应用场景:
- 数据缓冲（速度快→速度慢）
- 跨时钟域同步（异步FIFO）
- 协议接口缓冲
- 速率匹配
```

## 2. FIFO原理

```
FIFO结构:
写入 → [A] [B] [C] [D] → 读出
       ↑              ↑
     先进            先出

不能随机访问，只能按顺序读写
```

### 为什么需要FIFO？

```
场景1: 速度匹配
CPU (快) ──→ FIFO ──→ 外设 (慢)
100MHz          10MHz

场景2: 数据缓冲
发送方 ──→ FIFO ──→ 接收方
(突发数据)    (平滑输出)

场景3: 跨时钟域
CLK_A ──→ 异步FIFO ──→ CLK_B
```

## 3. 完整代码

### sync_fifo.sv

```verilog
//=============================================================================
// Module: sync_fifo
// Description: 同步FIFO
pubDate: 2025-01-01?n//              支持空满标志、数据计数
// Author: 学习笔记
// Date: 2026-07-13
//=============================================================================

module sync_fifo #(
    parameter DATA_WIDTH = 8,       // 数据位宽
    parameter DEPTH      = 16       // FIFO深度
)(
    input  logic clk,
    input  logic rst_n,
    
    // 写端口
    input  logic                  wr_en,     // 写使能
    input  logic [DATA_WIDTH-1:0] wr_data,   // 写数据
    output logic                  full,      // 满标志
    
    // 读端口
    input  logic                  rd_en,     // 读使能
    output logic [DATA_WIDTH-1:0] rd_data,   // 读数据
    output logic                  empty,     // 空标志
    
    // 可选：数据计数
    output logic [$clog2(DEPTH):0] data_count  // 当前数据量
);

    //=========================================================================
    // 参数计算
    //=========================================================================
    localparam PTR_WIDTH = $clog2(DEPTH);  // 指针位宽

    //=========================================================================
    // 信号声明
    //=========================================================================
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];  // 存储器
    logic [PTR_WIDTH:0] wr_ptr;              // 写指针（多1位用于判断满）
    logic [PTR_WIDTH:0] rd_ptr;              // 读指针

    //=========================================================================
    // 写指针更新
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (wr_en && !full)
            wr_ptr <= wr_ptr + 1;
    end

    //=========================================================================
    // 读指针更新
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (rd_en && !empty)
            rd_ptr <= rd_ptr + 1;
    end

    //=========================================================================
    // 写操作
    //=========================================================================
    always_ff @(posedge clk) begin
        if (wr_en && !full)
            mem[wr_ptr[PTR_WIDTH-1:0]] <= wr_data;
    end

    //=========================================================================
    // 读操作（组合逻辑读，同步写）
    //=========================================================================
    assign rd_data = mem[rd_ptr[PTR_WIDTH-1:0]];

    //=========================================================================
    // 空满判断
    //=========================================================================
    // 空：读写指针相同
    assign empty = (wr_ptr == rd_ptr);
    
    // 满：最高位不同，其余位相同
    assign full = (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]) &&
                  (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]);

    //=========================================================================
    // 数据计数
    //=========================================================================
    assign data_count = wr_ptr - rd_ptr;

endmodule
```

## 4. Testbench

### tb_sync_fifo.sv

```verilog
//=============================================================================
// Testbench: tb_sync_fifo
// Description: 同步FIFO测试平台
pubDate: 2025-01-01?n//=============================================================================

`timescale 1ns / 1ps

module tb_sync_fifo;

    //=========================================================================
    // 参数
    //=========================================================================
    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;
    parameter CLK_PERIOD = 10;

    //=========================================================================
    // 信号
    //=========================================================================
    logic clk;
    logic rst_n;
    logic wr_en, rd_en;
    logic [DATA_WIDTH-1:0] wr_data, rd_data;
    logic full, empty;
    logic [$clog2(DEPTH):0] data_count;

    //=========================================================================
    // 时钟生成
    //=========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //=========================================================================
    // 实例化
    //=========================================================================
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .full(full),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .empty(empty),
        .data_count(data_count)
    );

    //=========================================================================
    // 测试激励
    //=========================================================================
    initial begin
        // 初始化
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;
        
        #100;
        rst_n = 1;
        #20;
        
        $display("=== 同步FIFO测试开始 ===");
        
        //=====================================================================
        // 测试1: 写入5个数据
        //=====================================================================
        $display("--- 测试1: 写入5个数据 ---");
        repeat(5) begin
            @(posedge clk);
            wr_en = 1;
            wr_data = $random % 256;
            $display("写入: %0d", wr_data);
            @(posedge clk);
            wr_en = 0;
        end
        $display("当前数据量: %0d", data_count);
        $display("");
        
        //=====================================================================
        // 测试2: 读出3个数据
        //=====================================================================
        $display("--- 测试2: 读出3个数据 ---");
        repeat(3) begin
            @(posedge clk);
            rd_en = 1;
            @(posedge clk);
            $display("读出: %0d", rd_data);
            rd_en = 0;
        end
        $display("当前数据量: %0d", data_count);
        $display("");
        
        //=====================================================================
        // 测试3: 读空
        //=====================================================================
        $display("--- 测试3: 读空 ---");
        while (!empty) begin
            @(posedge clk);
            rd_en = 1;
            @(posedge clk);
            $display("读出: %0d", rd_data);
            rd_en = 0;
        end
        $display("FIFO为空: %b", empty);
        $display("");
        
        //=====================================================================
        // 测试4: 写满
        //=====================================================================
        $display("--- 测试4: 写满 ---");
        while (!full) begin
            @(posedge clk);
            wr_en = 1;
            wr_data = $random % 256;
            @(posedge clk);
            wr_en = 0;
        end
        $display("FIFO为满: %b", full);
        $display("当前数据量: %0d", data_count);
        $display("");
        
        $display("=== 同步FIFO测试结束 ===");
        $finish;
    end

    //=========================================================================
    // 波形输出
    //=========================================================================
    initial begin
        $dumpfile("wave_fifo.vcd");
        $dumpvars(0, tb_sync_fifo);
    end

endmodule
```

## 5. 关键设计点

### 空满判断原理

```
指针设计:
写指针 (wr_ptr): 0 → 1 → 2 → ... → DEPTH-1 → 0
读指针 (rd_ptr): 0 → 1 → 2 → ... → DEPTH-1 → 0

空判断: wr_ptr == rd_ptr
满判断: wr_ptr[MSB] != rd_ptr[MSB] && wr_ptr[LSB:0] == rd_ptr[LSB:0]
       (最高位不同，其余位相同)
```

### 为什么指针要多1位？

```
4深度FIFO需要3位指针（2位地址 + 1位溢出位）

写入5次后:
wr_ptr = 3'b101 (二进制101)
rd_ptr = 3'b000 (二进制000)

满判断: wr_ptr[2] != rd_ptr[2]  → 1!=0 ✓
        wr_ptr[1:0] == rd_ptr[1:0] → 01==00 ✗

写入6次后:
wr_ptr = 3'b110
rd_ptr = 3'b000

满判断: wr_ptr[2] != rd_ptr[2]  → 1!=0 ✓
        wr_ptr[1:0] == rd_ptr[1:0] → 10==00 ✗

写入8次后:
wr_ptr = 3'b1000 (实际是4'b1000，但只取3位)
        → 溢出回0
```

## 6. 进阶：异步FIFO

### 跨时钟域问题

```
写时钟域 ──→ 异步FIFO ──→ 读时钟域
CLK_WR              CLK_RD

问题: 读写指针在不同时钟域，直接比较会产生亚稳态
解决: 使用格雷码同步
```

### 格雷码转换

```verilog
// 格雷码特点: 相邻数值只变1位
// 二进制: 000, 001, 010, 011, 100, 101, 110, 111
// 格雷码: 000, 001, 011, 010, 110, 111, 101, 100

function logic [$clog2(DEPTH):0] bin2gray(input logic [$clog2(DEPTH):0] bin);
    return bin ^ (bin >> 1);
endfunction
```

### 异步FIFO代码框架

```verilog
// 写指针格雷码同步到读时钟域
logic [$clog2(DEPTH):0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;
always_ff @(posedge rd_clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr_gray_sync1 <= '0;
        wr_ptr_gray_sync2 <= '0;
    end else begin
        wr_ptr_gray_sync1 <= bin2gray(wr_ptr);
        wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
    end
end

// 空判断（在读时钟域）
assign empty = (wr_ptr_gray_sync2 == bin2gray(rd_ptr));

// 满判断（在写时钟域）
assign full = (rd_ptr_gray_sync2 != bin2gray(wr_ptr)) &&
              (rd_ptr_gray_sync2[PTR_WIDTH-1:0] == bin2gray(wr_ptr)[PTR_WIDTH-1:0]);
```

## 7. 练习任务

### 任务1：基础验证（必做）

```bash
# 编译
iverilog -o tb_sync_fifo tb_sync_fifo.sv sync_fifo.sv

# 运行仿真
vvp tb_sync_fifo

# 查看波形
gtkwave wave_fifo.vcd
```

**观察并记录：**
- [ ] 空满标志是否正确？
- [ ] 数据计数是否准确？
- [ ] 写满后是否拒绝写入？
- [ ] 读空后是否拒绝读出？

### 任务2：参数调整（必做）

修改参数，观察不同深度的效果：

```verilog
parameter DEPTH = 8;    // 深度8
parameter DEPTH = 32;   // 深度32
parameter DEPTH = 64;   // 深度64
```

### 任务3：功能扩展（选做）

添加以下功能：

```verilog
// 1. 可编程almost_full/almost_empty
output logic almost_full,    // 快满（剩余1个空位）
output logic almost_empty,   // 快空（剩余1个数据）

// 2. 同步复位选项
parameter SYNC_RST = 0,     // 0=异步复位, 1=同步复位

// 3. 可配置读写独立使能
input  logic wr_req,        // 写请求
input  logic rd_req,        // 读请求
```

## 8. 常见错误

| 错误 | 原因 | 解决方法 |
|---|---|---|
| 空满同时为1 | 指针位宽不够 | 确保指针比地址多1位 |
| 数据丢失 | 满时继续写入 | 检查full标志后再写 |
| 读出错误数据 | 空时继续读出 | 检查empty标志后再读 |
| 格雷码同步出错 | 位宽不匹配 | 确保同步器位宽一致 |

## 9. 知识点总结

### FIFO类型对比

| 类型 | 时钟 | 用途 |
|---|---|---|
| 同步FIFO | 单一时钟 | 模块内缓冲 |
| 异步FIFO | 双时钟 | 跨时钟域同步 |
| 伪同步FIFO | 单时钟 | 简化版异步FIFO |

### 空满判断方法

| 方法 | 优点 | 缺点 |
|---|---|---|
| 指针比较 | 简单直接 | 需要多1位指针 |
| 计数器 | 直观 | 面积稍大 |
| 格雷码 | 跨时钟域安全 | 需要转换电路 |

---

*完成本练习后，你应该掌握：*
- [x] FIFO工作原理
- [x] 空满判断逻辑
- [x] 指针设计方法
- [x] 格雷码跨时钟域同步

*最后更新: 2026-07-14*