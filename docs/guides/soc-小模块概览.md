---
title: "实习生必练小模块"
description: "数字设计实习生必练的小模块汇总"
pubDate: 2025-01-01category: soc
order: 4
tags: [SOC, 小模块]
---

# 实习生必练小模块推荐

## 为什么从小模块开始

| 原因 | 说明 |
|---|---|
| **代码量可控** | 100-500 行，不会被淹没 |
| **功能独立** | 可以单独验证，看到完整结果 |
| **面试高频** | 几乎必问的基础模块 |
| **项目必备** | 实际项目中到处都在用 |
| **概念全覆盖** | 状态机、时序逻辑、跨时钟域、协议 |

---

## 模块难度分级

```
入门级 (1-2天)
├── Counter          计数器
├── Edge Detector    边沿检测
├── Debouncer        按键消抖
└── Synchronizer     跨时钟域同步

进阶级 (3-5天)
├── FIFO             先进先出队列
├── Arbitrer         仲裁器
├── UART TX/RX       串口收发
└── Timer            定时器

挑战级 (1周)
├── SPI Master       SPI 主机
├── I2C Master       I2C 主机
└── AXI4-Lite Slave  AXI 从机
```

---

## 1. 同步 FIFO（⭐⭐⭐⭐⭐ 最重要）

### 为什么必练

- 面试几乎必考
- 涉及指针设计、空满判断、跨时钟域
- 实际项目中大量使用（缓冲、速率匹配）

### 接口定义

```verilog
module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input  logic                  clk,
    input  logic                  rst_n,
    
    // 写端口
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,
    
    // 读端口
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty,
    
    // 可选：数据计数
    output logic [$clog2(DEPTH):0] data_count
);
```

### 关键设计点

```
核心思想：用二进制指针 + 格雷码判断空满

写指针 (wr_ptr): 0 → 1 → 2 → ... → DEPTH-1 → 0
读指针 (rd_ptr): 0 → 1 → 2 → ... → DEPTH-1 → 0

空判断: wr_ptr == rd_ptr
满判断: wr_ptr[MSB] != rd_ptr[MSB] && wr_ptr[LSB:0] == rd_ptr[LSB:0]
       (最高位不同，其余位相同)
```

### 代码框架

```verilog
// 存储器
logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

// 写指针
logic [$clog2(DEPTH):0] wr_ptr, wr_ptr_next;
// 读指针
logic [$clog2(DEPTH):0] rd_ptr, rd_ptr_next;

// 指针更新
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= '0;
        rd_ptr <= '0;
    end else begin
        if (wr_en && !full)  wr_ptr <= wr_ptr_next;
        if (rd_en && !empty) rd_ptr <= rd_ptr_next;
    end
end

// 写操作
always_ff @(posedge clk) begin
    if (wr_en && !full)
        mem[wr_ptr[$clog2(DEPTH)-1:0]] <= wr_data;
end

// 读操作
assign rd_data = mem[rd_ptr[$clog2(DEPTH)-1:0]];

// 空满判断
assign empty = (wr_ptr == rd_ptr);
assign full  = (wr_ptr != rd_ptr) && 
               (wr_ptr[$clog2(DEPTH)-1:0] == rd_ptr[$clog2(DEPTH)-1:0]);
```

### 进阶：异步 FIFO

```verilog
// 跨时钟域需要格雷码同步
function logic [$clog2(DEPTH):0] bin2gray(input logic [$clog2(DEPTH):0] bin);
    return bin ^ (bin >> 1);
endfunction

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
```

---

## 2. UART 收发器（⭐⭐⭐⭐⭐ 最实用）

### 为什么必练

- 调试必备，几乎所有项目都用
- 涉及波特率生成、状态机、串并转换
- 面试高频考点

### 接口定义

```verilog
module uart_tx (
    input  logic       clk,        // 系统时钟
    input  logic       rst_n,
    input  logic [7:0] tx_data,    // 发送数据
    input  logic       tx_valid,   // 数据有效
    output logic       tx_ready,   // 发送器就绪
    output logic       tx_pin      // UART TX 引脚
);

module uart_rx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx_pin,     // UART RX 引脚
    output logic [7:0] rx_data,    // 接收数据
    output logic       rx_valid    // 数据有效
);
```

### UART 帧格式

```
空闲态: ──────────────────────

起始位: ────────┐
               │  0
数据位:         └───D0─D1─D2─D3─D4─D5─D6─D7───
校验位:                          (可选) ──P──
停止位: ────────────────────────────────────┐
                                           │ 1
                                           └───

每帧: 1起始 + 8数据 + 0/1校验 + 1/2停止
```

### 波特率生成器

```verilog
module baud_gen #(
    parameter CLK_FREQ  = 50_000_000,  // 50MHz
    parameter BAUD_RATE = 115200
)(
    input  logic clk,
    input  logic rst_n,
    output logic baud_tick  // 波特率采样脉冲
);
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
    
    logic [$clog2(BAUD_DIV)-1:0] cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= '0;
            baud_tick <= 1'b0;
        end else if (cnt == BAUD_DIV - 1) begin
            cnt <= '0;
            baud_tick <= 1'b1;
        end else begin
            cnt <= cnt + 1;
            baud_tick <= 1'b0;
        end
    end
endmodule
```

### TX 状态机

```verilog
typedef enum logic [2:0] {
    TX_IDLE,
    TX_START,
    TX_DATA,
    TX_PARITY,
    TX_STOP
} tx_state_t;

tx_state_t state, next_state;

// 状态转移
always_comb begin
    next_state = state;
    case (state)
        TX_IDLE:  if (tx_valid) next_state = TX_START;
        TX_START: if (baud_tick) next_state = TX_DATA;
        TX_DATA:  if (baud_tick && bit_cnt == 7) 
                      next_state = TX_STOP;
        TX_STOP:  if (baud_tick) next_state = TX_IDLE;
    endcase
end
```

---

## 3. 边沿检测器（⭐⭐⭐⭐ 基础必备）

### 为什么必练

- 代码量小（20行），但概念重要
- 消抖、按键检测、协议解析都用到
- 理解寄存器延迟的核心概念

### 接口定义

```verilog
module edge_detector (
    input  logic clk,
    input  logic rst_n,
    input  logic signal_in,    // 原始信号
    output logic pos_edge,     // 上升沿脉冲
    output logic neg_edge,     // 下降沿脉冲
    output logic any_edge      // 任意沿脉冲
);
```

### 代码实现

```verilog
logic signal_d1, signal_d2;

// 两级寄存器（同步 + 边沿检测）
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        signal_d1 <= 1'b0;
        signal_d2 <= 1'b0;
    end else begin
        signal_d1 <= signal_in;
        signal_d2 <= signal_d1;
    end
end

// 边沿检测
assign pos_edge = signal_d1 & ~signal_d2;  // 0→1
assign neg_edge = ~signal_d1 & signal_d2;  // 1→0
assign any_edge = pos_edge | neg_edge;
```

### 时序图

```
clk         ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
             └──┘  └──┘  └──┘  └──┘  └──┘

signal_in   ──────────┐              ┌───────
                      └──────────────┘

signal_d1   ────────────┐              ┌─────
                        └──────────────┘

signal_d2   ──────────────┐              ┌───
                          └──────────────┘

pos_edge    ────────┐  ┌────────────────────
                    └──┘

neg_edge    ──────────────────────┐  ┌──────
                                 └──┘
```

---

## 4. 按键消抖器（⭐⭐⭐⭐ 实用）

### 为什么必练

- 实际工程必备
- 涉及计数器、状态机、边沿检测
- 理解机械抖动的物理现象

### 按键抖动原理

```
理想波形:
key_in    ────────┐              ┌────
                  └──────────────┘

实际波形（有抖动）:
key_in    ────┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌──
              └┘└┘└┘└┘└┘└┘└┘└┘└┘└┘

消抖后:
key_debounced ────────┐              ┌────
                      └──────────────┘
```

### 代码实现

```verilog
module debouncer #(
    parameter CLK_FREQ  = 50_000_000,
    parameter DEBOUNCE_MS = 20  // 20ms 消抖
)(
    input  logic clk,
    input  logic rst_n,
    input  logic key_in,        // 原始按键
    output logic key_debounced, // 消抖后
    output logic key_pos_edge   // 上升沿
);

    localparam CNT_MAX = CLK_FREQ / 1000 * DEBOUNCE_MS;
    
    logic [$clog2(CNT_MAX)-1:0] cnt;
    logic key_sync1, key_sync2;
    logic key_stable;
    
    // 同步器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_sync1 <= 1'b1;  // 按键默认高
            key_sync2 <= 1'b1;
        end else begin
            key_sync1 <= key_in;
            key_sync2 <= key_sync1;
        end
    end
    
    // 计数器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= '0;
            key_stable <= 1'b1;
        end else if (key_sync2 != key_stable) begin
            if (cnt == CNT_MAX - 1)
                key_stable <= key_sync2;
            else
                cnt <= cnt + 1;
        end else begin
            cnt <= '0;
        end
    end
    
    assign key_debounced = key_stable;
    
    // 边沿检测
    logic key_stable_d;
    always_ff @(posedge clk) key_stable_d <= key_stable;
    assign key_pos_edge = key_stable & ~key_stable_d;
    
endmodule
```

---

## 5. 跨时钟域同步器（⭐⭐⭐⭐⭐ 必须掌握）

### 为什么必练

- 数字设计核心问题
- 不同步会导致亚稳态
- 面试必考知识点

### 亚稳态问题

```
跨时钟域传输:

CLK_A  ──┐  ┌──┐  ┌──┐  ┌──
         └──┘  └──┘  └──┘

DATA_A  ──────X─────────────  ← 在 CLK_B 上升沿变化

CLK_B  ──┐  ┌──┐  ┌──┐  ┌──
         └──┘  └──┘  └──┘
              ↑
              │  采样到不稳定值 → 亚稳态！
              ▼
DATA_B  ────?-──────────────
```

### 2 级同步器

```verilog
module sync_2ff #(
    parameter WIDTH = 1
)(
    input  logic             clk_dst,    // 目标时钟
    input  logic             rst_n,
    input  logic [WIDTH-1:0] data_src,   // 源数据
    output logic [WIDTH-1:0] data_dst    // 同步后数据
);

    logic [WIDTH-1:0] sync_reg1;
    
    always_ff @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            sync_reg1 <= '0;
            data_dst  <= '0;
        end else begin
            sync_reg1 <= data_src;  // 第一级（可能亚稳态）
            data_dst  <= sync_reg1; // 第二级（稳定）
        end
    end
    
endmodule
```

### 握手同步

```verilog
// 源端
logic req_src, ack_sync;
logic req_toggle;

always_ff @(posedge clk_src or negedge rst_n) begin
    if (!rst_n) req_toggle <= 1'b0;
    else if (req_src) req_toggle <= ~req_toggle;
end

// 目标端同步
logic req_toggle_sync1, req_toggle_sync2;
always_ff @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) begin
        req_toggle_sync1 <= 1'b0;
        req_toggle_sync2 <= 1'b0;
    end else begin
        req_toggle_sync1 <= req_toggle;
        req_toggle_sync2 <= req_toggle_sync1;
    end
end
```

---

## 6. 仲裁器（⭐⭐⭐⭐ 总线必备）

### 为什么必练

- 总线、DMA、多端口内存都需要
- 理解优先级、公平性
- 状态机练习

### 接口定义

```verilog
module arbiter #(
    parameter NUM_MASTER = 4
)(
    input  logic clk,
    input  logic rst_n,
    
    // 请求
    input  logic [NUM_MASTER-1:0] req,      // 请求信号
    output logic [NUM_MASTER-1:0] grant,    // 授权信号
    
    // 输出
    output logic [$clog2(NUM_MASTER)-1:0] sel  // 选中的主设备
);
```

### 仲裁算法

```verilog
// 1. 固定优先级仲裁
always_comb begin
    grant = '0;
    sel   = '0;
    for (int i = NUM_MASTER-1; i >= 0; i--) begin
        if (req[i]) begin
            grant[i] = 1'b1;
            sel      = i[$clog2(NUM_MASTER)-1:0];
        end
    end
end

// 2. 轮询仲裁 (Round Robin)
logic [$clog2(NUM_MASTER)-1:0] last_grant;

always_comb begin
    grant = '0;
    sel   = '0;
    for (int i = 0; i < NUM_MASTER; i++) begin
        automatic int idx = (last_grant + 1 + i) % NUM_MASTER;
        if (req[idx]) begin
            grant[idx] = 1'b1;
            sel        = idx[$clog2(NUM_MASTER)-1:0];
        end
    end
end
```

### 仲裁时序

```
固定优先级仲裁:

req[0]   ────┐     ┌───────────────
             └─────┘

req[1]   ──────────┐     ┌─────────
                   └─────┘

req[2]   ──────────────────────────

grant[0] ────┐     ┌───┐
             └─────┘   └────────────

grant[1] ──────────────┐     ┌─────
                       └─────┘

sel      ────0─────0───1─────1─────
```

---

## 7. Timer 定时器（⭐⭐⭐ 基础外设）

### 为什么必练

- 嵌入式系统基础
- PWM、看门狗、实时时钟的基础
- 寄存器配置练习

### 接口定义

```verilog
module timer #(
    parameter CLK_FREQ = 50_000_000
)(
    input  logic        clk,
    input  logic        rst_n,
    
    // APB 配置接口
    input  logic [3:0]  addr,
    input  logic        wr_en,
    input  logic [31:0] wr_data,
    output logic [31:0] rd_data,
    
    // 中断输出
    output logic        irq
);
```

### 寄存器映射

| 偏移 | 名称 | 读写 | 说明 |
|---|---|---|---|
| 0x00 | CTRL | R/W | 控制寄存器 |
| 0x04 | STATUS | R/W | 状态寄存器 |
| 0x08 | CNT | R | 计数器当前值 |
| 0x0C | THRESHOLD | R/W | 阈值 |
| 0x10 | PRESCALE | R/W | 分频器 |

### 代码实现

```verilog
// 寄存器定义
logic [31:0] ctrl, threshold, prescale;
logic [31:0] cnt;
logic        irq_pending;

// 控制寄存器位定义
localparam CTRL_ENABLE  = 0;
localparam CTRL_IRQ_EN  = 1;
localparam CTRL_AUTO_RELOAD = 2;

// 计数逻辑
logic [31:0] prescale_cnt;
logic        prescale_tick;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        prescale_cnt <= '0;
        prescale_tick <= 1'b0;
    end else if (ctrl[CTRL_ENABLE]) begin
        if (prescale_cnt == prescale) begin
            prescale_cnt <= '0;
            prescale_tick <= 1'b1;
        end else begin
            prescale_cnt <= prescale_cnt + 1;
            prescale_tick <= 1'b0;
        end
    end
end

// 主计数器
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt <= '0;
        irq_pending <= 1'b0;
    end else if (ctrl[CTRL_ENABLE] && prescale_tick) begin
        if (cnt >= threshold) begin
            cnt <= '0;
            irq_pending <= 1'b1;
            if (!ctrl[CTRL_AUTO_RELOAD])
                ctrl[CTRL_ENABLE] <= 1'b0;  // 停止
        end else begin
            cnt <= cnt + 1;
        end
    end
end

assign irq = irq_pending & ctrl[CTRL_IRQ_EN];
```

---

## 8. SPI Master（⭐⭐⭐ 常用接口）

### 为什么必练

- Flash、传感器、屏幕通信都用
- 时钟极性/相位（CPOL/CPHA）
- 移位寄存器核心

### 接口定义

```verilog
module spi_master (
    input  logic        clk,
    input  logic        rst_n,
    
    // 控制接口
    input  logic [7:0]  tx_data,
    input  logic        tx_valid,
    output logic        tx_ready,
    output logic [7:0]  rx_data,
    output logic        rx_valid,
    
    // SPI 接口
    output logic        sclk,       // 时钟
    output logic        mosi,       // 主出从入
    input  logic        miso,       // 主入从出
    output logic        cs_n        // 片选（低有效）
);
```

### SPI 模式

```
CPOL=0, CPHA=0 (Mode 0):
SCLK  ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
        └──┘  └──┘  └──┘  └──┘
         ↑ 采样  ↑ 变化  ↑ 采样
MOSI  ──D7─────D6─────D5─────D4───
MISO  ──Q7─────Q6─────Q5─────Q4───

CPOL=1, CPHA=1 (Mode 3):
SCLK  ────┐  ┌──┐  ┌──┐  ┌──┐  ┌─
          └──┘  └──┘  └──┘  └──┘
           ↑ 变化  ↑ 采样  ↑ 变化
```

### 代码框架

```verilog
typedef enum logic [1:0] {
    SPI_IDLE,
    SPI_TRANSFER,
    SPI_DONE
} spi_state_t;

spi_state_t state;
logic [2:0] bit_cnt;
logic [7:0] shift_reg;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= SPI_IDLE;
        sclk <= 1'b0;
        cs_n <= 1'b1;
    end else begin
        case (state)
            SPI_IDLE: begin
                cs_n <= 1'b0;
                if (tx_valid) begin
                    state <= SPI_TRANSFER;
                    shift_reg <= tx_data;
                    bit_cnt <= '0;
                end
            end
            SPI_TRANSFER: begin
                if (sclk_tick) begin
                    sclk <= ~sclk;
                    if (sclk == 1'b0) begin  // 上升沿采样
                        shift_reg <= {shift_reg[6:0], miso};
                    end else begin           // 下降沿移出
                        mosi <= shift_reg[7];
                        bit_cnt <= bit_cnt + 1;
                        if (bit_cnt == 7)
                            state <= SPI_DONE;
                    end
                end
            end
            SPI_DONE: begin
                cs_n <= 1'b1;
                state <= SPI_IDLE;
            end
        endcase
    end
end
```

---

## 9. I2C Master（⭐⭐⭐ 常用接口）

### 为什么必练

- EEPROM、传感器、实时时钟通信
- 开漏输出、上拉电阻
- 起始/停止条件、ACK/NACK

### I2C 时序

```
起始条件: SDA 在 SCL 高时下降
                ┌───┐   ┌───┐   ┌───┐
SCL        ─────┘   └───┘   └───┘   └────
               ┌───────┐
SDA        ────┘       └──────────────
                   ↑ START

数据传输: SDA 在 SCL 低时变化
                ┌───┐   ┌───┐   ┌───┐
SCL        ─────┘   └───┘   └───┘   └────
            ┌───┐   ┌───┐   ┌───┐
SDA        ─┘   └───┘   └───┘   └────────
               D7       D6       D5

停止条件: SDA 在 SCL 高时上升
                ┌───┐   ┌───┐
SCL        ─────┘   └───┘   └────────────
                        ┌───────────────
SDA        ─────────────┘
                       ↑ STOP
```

---

## 10. AXI4-Lite Slave（⭐⭐⭐⭐⭐ 总线基础）

### 为什么必练

- 理解总线协议核心
- 寄存器映射、地址解码
- 实际 IP 开发必备

### 接口定义

```verilog
module axi4_lite_slave #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  logic aclk,
    input  logic aresetn,
    
    // AXI4-Lite 接口
    input  logic [ADDR_WIDTH-1:0]  awaddr,
    input  logic                   awvalid,
    output logic                   awready,
    
    input  logic [DATA_WIDTH-1:0]  wdata,
    input  logic [DATA_WIDTH/8-1:0] wstrb,
    input  logic                   wvalid,
    output logic                   wready,
    
    output logic [1:0]             bresp,
    output logic                   bvalid,
    input  logic                   bready,
    
    input  logic [ADDR_WIDTH-1:0]  araddr,
    input  logic                   arvalid,
    output logic                   arready,
    
    output logic [DATA_WIDTH-1:0]  rdata,
    output logic [1:0]             rresp,
    output logic                   rvalid,
    input  logic                   rready
);
```

### 写通道状态机

```verilog
typedef enum logic [1:0] {
    WR_IDLE,
    WR_ADDR,
    WR_DATA,
    WR_RESP
} wr_state_t;

wr_state_t wr_state;

always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        wr_state <= WR_IDLE;
        awready <= 1'b0;
        wready <= 1'b0;
        bvalid <= 1'b0;
    end else begin
        case (wr_state)
            WR_IDLE: begin
                awready <= 1'b1;
                if (awvalid && awready) begin
                    wr_state <= WR_ADDR;
                    awready <= 1'b0;
                end
            end
            WR_ADDR: begin
                wready <= 1'b1;
                if (wvalid && wready) begin
                    wr_state <= WR_DATA;
                    wready <= 1'b0;
                    // 写寄存器
                    if (wstrb[0]) reg_file[awaddr][7:0]   <= wdata[7:0];
                    if (wstrb[1]) reg_file[awaddr][15:8]  <= wdata[15:8];
                    if (wstrb[2]) reg_file[awaddr][23:16] <= wdata[23:16];
                    if (wstrb[3]) reg_file[awaddr][31:24] <= wdata[31:24];
                end
            end
            WR_DATA: begin
                bvalid <= 1'b1;
                bresp <= 2'b00;  // OKAY
                if (bready && bvalid) begin
                    bvalid <= 1'b0;
                    wr_state <= WR_IDLE;
                end
            end
        endcase
    end
end
```

---

## Testbench 编写模板

### 基本 TB 结构

```verilog
module tb_fifo;

    // 参数
    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;
    parameter CLK_PERIOD = 10;  // 10ns = 100MHz

    // 信号
    logic clk;
    logic rst_n;
    logic wr_en, rd_en;
    logic [DATA_WIDTH-1:0] wr_data, rd_data;
    logic full, empty;

    // 时钟生成
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // 实例化
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
        .empty(empty)
    );

    // 测试序列
    initial begin
        // 初始化
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;
        #100;
        rst_n = 1;
        #20;

        // 写入 5 个数据
        repeat(5) begin
            @(posedge clk);
            wr_en = 1;
            wr_data = $random;
            @(posedge clk);
            wr_en = 0;
        end

        // 读出 5 个数据
        repeat(5) begin
            @(posedge clk);
            rd_en = 1;
            @(posedge clk);
            rd_en = 0;
        end

        #100;
        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("fifo.vcd");
        $dumpvars(0, tb_fifo);
    end

    // 监控
    always @(posedge clk) begin
        if (wr_en && !full)
            $display("WR: %0h at time %0t", wr_data, $time);
        if (rd_en && !empty)
            $display("RD: %0h at time %0t", rd_data, $time);
    end

endmodule
```

---

## 学习路线建议

```
第 1 周: 基础模块
├── Day 1-2: 边沿检测器 + 消抖器
├── Day 3-4: 2级同步器 + 握手同步
└── Day 5:   复习 + 写 Testbench

第 2 周: 核心模块
├── Day 1-3: 同步 FIFO（重点！）
├── Day 4-5: 仲裁器
└── Day 6-7: 复习 + 对比异步 FIFO

第 3 周: 接口模块
├── Day 1-3: UART TX/RX
├── Day 4-5: Timer
└── Day 6-7: 复习 + 集成测试

第 4 周: 总线接口
├── Day 1-3: AXI4-Lite Slave
├── Day 4-5: SPI Master
└── Day 6-7: 项目实战
```

---

## 面试高频问题

| 模块 | 常见问题 |
|---|---|
| **FIFO** | 空满判断原理？异步 FIFO 如何跨时钟域？ |
| **UART** | 波特率如何生成？帧格式是什么？ |
| **同步器** | 为什么需要两级？亚稳态是什么？ |
| **边沿检测** | 为什么需要两级寄存器？ |
| **仲裁器** | 固定优先级 vs 轮询的优缺点？ |
| **状态机** | 三段式 vs 两段式？Moore vs Mealy？ |

---

## 详细练习文档

进阶级模块的完整练习文档（含代码、Testbench、练习任务）：

| 模块 | 文档链接 | 内容概要 |
|---|---|---|
| **同步FIFO** | [同步FIFO.md](进阶级练习/同步FIFO.md) | 空满判断、指针设计、格雷码同步 |
| **仲裁器** | [仲裁器.md](进阶级练习/仲裁器.md) | 固定优先级、轮询仲裁、状态机 |
| **UART收发器** | [UART收发器.md](进阶级练习/UART收发器.md) | 帧格式、波特率生成、16x过采样 |
| **定时器** | [定时器.md](进阶级练习/定时器.md) | 寄存器映射、分频器、PWM输出 |

---

*最后更新: 2026-07-14*