---
title: "UART收发器"
description: "进阶级数字设计练习：UART收发器"
pubDate: 2025-01-01category: soc
order: 11
tags: [SOC, 进阶, UART]
---

# UART收发器 完整练习

## 1. 模块功能说明

UART（Universal Asynchronous Receiver/Transmitter）是通用异步收发器，用于串口通信。

```
应用场景:
- 调试串口（最常用）
- GPS模块通信
- 蓝牙模块通信
- 传感器数据读取
```

## 2. UART原理

### 串口通信特点

```
异步通信：没有共享时钟
双方约定：波特率、数据位、校验位、停止位

发送方 ──TX──→ 接收方
       ←─RX──
```

### 帧格式

```
空闲态: ────────────────────── (高电平)

起始位: ────────┐
               │  0 (低电平)
数据位:         └───D0─D1─D2─D3─D4─D5─D6─D7───
校验位:                          (可选) ──P──
停止位: ────────────────────────────────────┐
                                           │ 1 (高电平)
                                           └───

每帧: 1起始 + 8数据 + 0/1校验 + 1/2停止
```

### 波特率

```
波特率 = 每秒传输的位数

9600 baud  → 每位 ≈ 104.17μs
115200 baud → 每位 ≈ 8.68μs

系统时钟50MHz，波特率115200:
分频系数 = 50,000,000 / 115200 ≈ 434
```

## 3. 完整代码

### uart_tx.sv

```verilog
//=============================================================================
// Module: uart_tx
// Description: UART发送器
pubDate: 2025-01-01?n//              支持可配置波特率和帧格式
// Author: 学习笔记
// Date: 2026-07-13
//=============================================================================

module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,  // 系统时钟
    parameter BAUD_RATE = 115200       // 波特率
)(
    input  logic       clk,
    input  logic       rst_n,
    
    // 用户接口
    input  logic [7:0] tx_data,    // 发送数据
    input  logic       tx_valid,   // 数据有效
    output logic       tx_ready,   // 发送器就绪
    
    // UART接口
    output logic       tx_pin      // UART TX引脚
);

    //=========================================================================
    // 波特率生成器
    //=========================================================================
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
    localparam BAUD_CNT_WIDTH = $clog2(BAUD_DIV);
    
    logic [BAUD_CNT_WIDTH-1:0] baud_cnt;
    logic baud_tick;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= '0;
            baud_tick <= 1'b0;
        end else if (baud_cnt == BAUD_DIV - 1) begin
            baud_cnt <= '0;
            baud_tick <= 1'b1;
        end else begin
            baud_cnt <= baud_cnt + 1;
            baud_tick <= 1'b0;
        end
    end

    //=========================================================================
    // 发送状态机
    //=========================================================================
    typedef enum logic [2:0] {
        TX_IDLE,
        TX_START,
        TX_DATA,
        TX_STOP
    } tx_state_t;
    
    tx_state_t state;
    logic [2:0] bit_cnt;        // 数据位计数
    logic [7:0] shift_reg;      // 移位寄存器

    //=========================================================================
    // 状态转移
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= TX_IDLE;
            tx_pin <= 1'b1;      // 空闲态高电平
            shift_reg <= '0;
            bit_cnt <= '0;
        end else begin
            case (state)
                TX_IDLE: begin
                    tx_pin <= 1'b1;
                    if (tx_valid && tx_ready) begin
                        state <= TX_START;
                        shift_reg <= tx_data;
                        bit_cnt <= '0;
                    end
                end
                
                TX_START: begin
                    tx_pin <= 1'b0;  // 起始位
                    if (baud_tick) begin
                        state <= TX_DATA;
                    end
                end
                
                TX_DATA: begin
                    tx_pin <= shift_reg[0];  // LSB先发
                    if (baud_tick) begin
                        shift_reg <= {1'b0, shift_reg[7:1]};
                        bit_cnt <= bit_cnt + 1;
                        if (bit_cnt == 3'd7) begin
                            state <= TX_STOP;
                        end
                    end
                end
                
                TX_STOP: begin
                    tx_pin <= 1'b1;  // 停止位
                    if (baud_tick) begin
                        state <= TX_IDLE;
                    end
                end
                
                default: state <= TX_IDLE;
            endcase
        end
    end

    //=========================================================================
    // 发送器就绪
    //=========================================================================
    assign tx_ready = (state == TX_IDLE);

endmodule
```

### uart_rx.sv

```verilog
//=============================================================================
// Module: uart_rx
// Description: UART接收器
pubDate: 2025-01-01?n//              支持可配置波特率和帧格式
// Author: 学习笔记
// Date: 2026-07-13
//=============================================================================

module uart_rx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic       clk,
    input  logic       rst_n,
    
    // UART接口
    input  logic       rx_pin,     // UART RX引脚
    
    // 用户接口
    output logic [7:0] rx_data,    // 接收数据
    output logic       rx_valid    // 数据有效（单周期脉冲）
);

    //=========================================================================
    // 波特率生成器（16x过采样）
    //=========================================================================
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE / 16;  // 16倍过采样
    localparam BAUD_CNT_WIDTH = $clog2(BAUD_DIV);
    
    logic [BAUD_CNT_WIDTH-1:0] baud_cnt;
    logic baud_tick;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= '0;
            baud_tick <= 1'b0;
        end else if (baud_cnt == BAUD_DIV - 1) begin
            baud_cnt <= '0;
            baud_tick <= 1'b1;
        end else begin
            baud_cnt <= baud_cnt + 1;
            baud_tick <= 1'b0;
        end
    end

    //=========================================================================
    // 接收状态机
    //=========================================================================
    typedef enum logic [2:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } rx_state_t;
    
    rx_state_t state;
    logic [2:0] bit_cnt;
    logic [7:0] shift_reg;
    logic [3:0] sample_cnt;     // 16x采样计数

    //=========================================================================
    // 输入同步（消除亚稳态）
    //=========================================================================
    logic rx_pin_sync1, rx_pin_sync2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_pin_sync1 <= 1'b1;
            rx_pin_sync2 <= 1'b1;
        end else begin
            rx_pin_sync1 <= rx_pin;
            rx_pin_sync2 <= rx_pin_sync1;
        end
    end

    //=========================================================================
    // 状态转移
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= RX_IDLE;
            rx_data <= '0;
            rx_valid <= 1'b0;
            shift_reg <= '0;
            bit_cnt <= '0;
            sample_cnt <= '0;
        end else begin
            rx_valid <= 1'b0;  // 默认不有效
            
            case (state)
                RX_IDLE: begin
                    if (rx_pin_sync2 == 1'b0) begin  // 检测起始位
                        state <= RX_START;
                        sample_cnt <= '0;
                    end
                end
                
                RX_START: begin
                    if (baud_tick) begin
                        sample_cnt <= sample_cnt + 1;
                        if (sample_cnt == 4'd7) begin  // 采样中间点
                            if (rx_pin_sync2 == 1'b0) begin  // 确认起始位
                                state <= RX_DATA;
                                bit_cnt <= '0;
                            end else begin
                                state <= RX_IDLE;  // 假起始位
                            end
                        end
                    end
                end
                
                RX_DATA: begin
                    if (baud_tick) begin
                        sample_cnt <= sample_cnt + 1;
                        if (sample_cnt == 4'd15) begin  // 采样中间点
                            shift_reg <= {rx_pin_sync2, shift_reg[7:1]};
                            bit_cnt <= bit_cnt + 1;
                            if (bit_cnt == 3'd7) begin
                                state <= RX_STOP;
                            end
                        end
                    end
                end
                
                RX_STOP: begin
                    if (baud_tick) begin
                        sample_cnt <= sample_cnt + 1;
                        if (sample_cnt == 4'd15) begin  // 采样中间点
                            if (rx_pin_sync2 == 1'b1) begin  // 确认停止位
                                state <= RX_IDLE;
                                rx_data <= shift_reg;
                                rx_valid <= 1'b1;
                            end else begin
                                state <= RX_IDLE;  // 帧错误
                            end
                        end
                    end
                end
                
                default: state <= RX_IDLE;
            endcase
        end
    end

endmodule
```

## 4. Testbench

### tb_uart.sv

```verilog
//=============================================================================
// Testbench: tb_uart
// Description: UART收发器测试平台
pubDate: 2025-01-01?n//=============================================================================

`timescale 1ns / 1ps

module tb_uart;

    //=========================================================================
    // 参数
    //=========================================================================
    parameter CLK_FREQ = 50_000_000;
    parameter BAUD_RATE = 115200;
    parameter CLK_PERIOD = 20;  // 50MHz → 20ns

    //=========================================================================
    // 信号
    //=========================================================================
    logic clk;
    logic rst_n;
    
    // TX信号
    logic [7:0] tx_data;
    logic tx_valid;
    logic tx_ready;
    logic tx_pin;
    
    // RX信号
    logic rx_pin;
    logic [7:0] rx_data;
    logic rx_valid;

    //=========================================================================
    // 时钟生成
    //=========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //=========================================================================
    // 实例化TX
    //=========================================================================
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),
        .tx_pin(tx_pin)
    );

    //=========================================================================
    // 实例化RX
    //=========================================================================
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx_pin(rx_pin),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    //=========================================================================
    // TX直接连接RX（自回环）
    //=========================================================================
    assign rx_pin = tx_pin;

    //=========================================================================
    // 测试激励
    //=========================================================================
    initial begin
        // 初始化
        rst_n = 0;
        tx_data = 0;
        tx_valid = 0;
        
        #100;
        rst_n = 1;
        #20;
        
        $display("=== UART测试开始 ===");
        
        //=====================================================================
        // 测试1: 发送单个字节
        //=====================================================================
        $display("--- 测试1: 发送0x55 ---");
        @(posedge clk);
        tx_data = 8'h55;
        tx_valid = 1;
        @(posedge clk);
        tx_valid = 0;
        
        // 等待发送完成（10位 * 8.68μs ≈ 87μs）
        #(100_000);
        
        if (rx_valid) begin
            $display("接收: 0x%h (期望: 0x55)", rx_data);
        end
        $display("");
        
        //=====================================================================
        // 测试2: 发送多个字节
        //=====================================================================
        $display("--- 测试2: 连续发送 ---");
        repeat(3) begin
            @(posedge clk);
            while (!tx_ready) @(posedge clk);
            tx_data = $random % 256;
            tx_valid = 1;
            $display("发送: 0x%h", tx_data);
            @(posedge clk);
            tx_valid = 0;
            #(100_000);
        end
        $display("");
        
        $display("=== UART测试结束 ===");
        $finish;
    end

    //=========================================================================
    // 监控
    //=========================================================================
    always @(posedge clk) begin
        if (rx_valid) begin
            $display("时间=%0t: RX收到 0x%h", $time, rx_data);
        end
    end

    //=========================================================================
    // 波形输出
    //=========================================================================
    initial begin
        $dumpfile("wave_uart.vcd");
        $dumpvars(0, tb_uart);
    end

endmodule
```

## 5. 关键设计点

### 波特率生成

```
系统时钟: 50MHz
波特率: 115200

分频系数 = 50,000,000 / 115200 ≈ 434

计数器: 0 → 433 → 0
每个波特周期: 434个时钟周期
```

### 16x过采样

```
为什么需要16x过采样？

1. 检测起始位下降沿
2. 采样数据位中间点（最稳定）
3. 抗干扰

采样点: 0, 16, 32, 48, ... (每个数据位中间)
```

### LSB先发

```
发送顺序: D0 → D1 → D2 → ... → D7

tx_data = 8'h55 = 8'b01010101
发送顺序: 1 → 0 → 1 → 0 → 1 → 0 → 1 → 0

移位寄存器: {rx_pin, shift_reg[7:1]}
每次右移，最低位先发
```

## 6. 进阶功能

### 奇偶校验

```verilog
// 发送校验位
logic parity;
assign parity = ^tx_data;  // 异或（奇校验）

// 发送帧
// 起始位 + 8数据 + 校验位 + 停止位

// 接收校验
logic rx_parity_calc;
assign rx_parity_calc = ^shift_reg;
if (rx_parity_bit != rx_parity_calc)
    parity_error <= 1'b1;
```

### 流控（RTS/CTS）

```verilog
// 硬件流控
output logic rts,  // Request To Send（我准备好接收了）
input  logic cts   // Clear To Send（对方准备好发送）

// 发送前检查CTS
if (cts) begin
    // 可以发送
end
```

## 7. 练习任务

### 任务1：基础验证（必做）

```bash
# 编译
iverilog -o tb_uart tb_uart.sv uart_tx.sv uart_rx.sv

# 运行仿真
vvp tb_uart

# 查看波形
gtkwave wave_uart.vcd
```

**观察并记录：**
- [ ] TX波形是否符合帧格式？
- [ ] RX是否正确接收？
- [ ] 波特率是否准确？

### 任务2：不同波特率测试（必做）

修改波特率，观察效果：

```verilog
parameter BAUD_RATE = 9600;   // 9600 baud
parameter BAUD_RATE = 19200;  // 19200 baud
parameter BAUD_RATE = 115200; // 115200 baud
```

### 任务3：功能扩展（选做）

```verilog
// 1. 添加奇偶校验
parameter PARITY_EN = 1,      // 0=无校验, 1=有校验
parameter PARITY_TYPE = 0,    // 0=偶校验, 1=奇校验

// 2. 添加帧错误检测
output logic frame_error,

// 3. 添加FIFO缓冲
parameter FIFO_DEPTH = 16,
```

## 8. 常见错误

| 错误 | 原因 | 解决方法 |
|---|---|---|
| 接收到错误数据 | 波特率不匹配 | 检查双方波特率设置 |
| 起始位检测不到 | 采样点不对 | 调整16x过采样逻辑 |
| 帧错误 | 停止位检测失败 | 检查停止位采样 |

## 9. 知识点总结

### UART参数

| 参数 | 说明 | 常用值 |
|---|---|---|
| 波特率 | 每秒位数 | 9600, 115200 |
| 数据位 | 每帧数据位数 | 7, 8 |
| 校验位 | 错误检测 | None, Even, Odd |
| 停止位 | 帧结束标志 | 1, 1.5, 2 |

### UART vs SPI vs I2C

| 协议 | 线数 | 速度 | 距离 | 用途 |
|---|---|---|---|---|
| UART | 2(TX/RX) | 低 | 远 | 调试串口 |
| SPI | 4(MOSI/MISO/SCLK/CS) | 高 | 近 | Flash、屏幕 |
| I2C | 2(SDA/SCL) | 中 | 中 | EEPROM、传感器 |

---

*完成本练习后，你应该掌握：*
- [x] UART帧格式
- [x] 波特率生成
- [x] 16x过采样原理
- [x] 发送/接收状态机

*最后更新: 2026-07-14*