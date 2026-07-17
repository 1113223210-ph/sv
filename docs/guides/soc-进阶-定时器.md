---
title: "定时器"
description: "进阶级数字设计练习：定时器"
pubDate: 2025-01-01category: soc
order: 8
tags: [SOC, 进阶, 定时器]
---

# 定时器 完整练习

## 1. 模块功能说明

定时器（Timer）是嵌入式系统的基础外设，用于产生定时中断和PWM波形。

```
应用场景:
- 定时中断（操作系统心跳）
- PWM输出（电机控制、LED调光）
- 输入捕获（测量脉冲宽度）
- 看门狗（系统监控）
```

## 2. 定时器原理

```
定时器结构:
系统时钟 → 分频器 → 计数器 → 比较器 → 中断/PWM

计数器: 0 → 1 → 2 → ... → 阈值 → 0 → 1 → ...
                           ↓
                        产生中断
```

### 为什么需要定时器？

```
场景1: 操作系统心跳
每1ms产生一次中断，用于任务调度

场景2: PWM控制
产生固定频率、可调占空比的波形

场景3: 精确延时
不占用CPU，硬件自动计时
```

## 3. 完整代码

### timer.sv

```verilog
//=============================================================================
// Module: timer
// Description: 定时器
pubDate: 2025-01-01?n//              支持APB配置、定时中断、PWM输出
// Author: 学习笔记
// Date: 2026-07-13
//=============================================================================

module timer #(
    parameter CLK_FREQ = 50_000_000    // 系统时钟
)(
    input  logic        clk,
    input  logic        rst_n,
    
    // APB配置接口
    input  logic [3:0]  addr,      // 寄存器地址
    input  logic        wr_en,     // 写使能
    input  logic [31:0] wr_data,   // 写数据
    input  logic        rd_en,     // 读使能
    output logic [31:0] rd_data,   // 读数据
    
    // PWM输出
    output logic        pwm_out,
    
    // 中断输出
    output logic        irq
);

    //=========================================================================
    // 寄存器定义
    //=========================================================================
    localparam ADDR_CTRL     = 4'h0;
    localparam ADDR_STATUS   = 4'h4;
    localparam ADDR_CNT      = 4'h8;
    localparam ADDR_THRESHOLD = 4'hC;
    localparam ADDR_PRESCALE = 4'h10;
    localparam ADDR_PWM_DUTY = 4'h14;

    //=========================================================================
    // 控制寄存器位定义
    //=========================================================================
    localparam CTRL_ENABLE     = 0;
    localparam CTRL_IRQ_EN     = 1;
    localparam CTRL_AUTO_RELOAD = 2;
    localparam CTRL_PWM_EN     = 3;

    //=========================================================================
    // 寄存器声明
    //=========================================================================
    logic [31:0] ctrl;
    logic [31:0] threshold;
    logic [31:0] prescale;
    logic [31:0] pwm_duty;
    logic [31:0] cnt;
    logic        irq_pending;

    //=========================================================================
    // 分频器
    //=========================================================================
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

    //=========================================================================
    // 主计数器
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= '0;
            irq_pending <= 1'b0;
        end else if (ctrl[CTRL_ENABLE] && prescale_tick) begin
            if (cnt >= threshold) begin
                cnt <= '0;
                irq_pending <= 1'b1;
                if (!ctrl[CTRL_AUTO_RELOAD])
                    ctrl[CTRL_ENABLE] <= 1'b0;
            end else begin
                cnt <= cnt + 1;
            end
        end
    end

    //=========================================================================
    // 中断输出
    //=========================================================================
    assign irq = irq_pending & ctrl[CTRL_IRQ_EN];

    //=========================================================================
    // PWM输出
    //=========================================================================
    assign pwm_out = ctrl[CTRL_PWM_EN] && (cnt < pwm_duty);

    //=========================================================================
    // APB写操作
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl <= '0;
            threshold <= '0;
            prescale <= '0;
            pwm_duty <= '0;
        end else if (wr_en) begin
            case (addr)
                ADDR_CTRL:     ctrl <= wr_data;
                ADDR_THRESHOLD: threshold <= wr_data;
                ADDR_PRESCALE: prescale <= wr_data;
                ADDR_PWM_DUTY: pwm_duty <= wr_data;
            endcase
        end
    end

    //=========================================================================
    // APB读操作
    //=========================================================================
    always_comb begin
        rd_data = '0;
        if (rd_en) begin
            case (addr)
                ADDR_CTRL:     rd_data = ctrl;
                ADDR_STATUS:   rd_data = {31'b0, irq_pending};
                ADDR_CNT:      rd_data = cnt;
                ADDR_THRESHOLD: rd_data = threshold;
                ADDR_PRESCALE: rd_data = prescale;
                ADDR_PWM_DUTY: rd_data = pwm_duty;
            endcase
        end
    end

    //=========================================================================
    // 状态寄存器写1清除
    //=========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            irq_pending <= 1'b0;
        else if (wr_en && addr == ADDR_STATUS && wr_data[0])
            irq_pending <= 1'b0;
        else if (ctrl[CTRL_ENABLE] && prescale_tick && cnt >= threshold)
            irq_pending <= 1'b1;
    end

endmodule
```

## 4. Testbench

### tb_timer.sv

```verilog
//=============================================================================
// Testbench: tb_timer
// Description: 定时器测试平台
pubDate: 2025-01-01?n//=============================================================================

`timescale 1ns / 1ps

module tb_timer;

    //=========================================================================
    // 参数
    //=========================================================================
    parameter CLK_FREQ = 50_000_000;
    parameter CLK_PERIOD = 20;  // 50MHz -> 20ns

    //=========================================================================
    // 信号
    //=========================================================================
    logic clk;
    logic rst_n;
    
    // APB接口
    logic [3:0] addr;
    logic wr_en;
    logic [31:0] wr_data;
    logic rd_en;
    logic [31:0] rd_data;
    
    // 输出
    logic pwm_out;
    logic irq;

    //=========================================================================
    // 时钟生成
    //=========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //=========================================================================
    // 实例化
    //=========================================================================
    timer #(
        .CLK_FREQ(CLK_FREQ)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .pwm_out(pwm_out),
        .irq(irq)
    );

    //=========================================================================
    // 任务：写寄存器
    //=========================================================================
    task write_reg(input logic [3:0] a, input logic [31:0] d);
        begin
            @(posedge clk);
            addr = a;
            wr_en = 1;
            wr_data = d;
            @(posedge clk);
            wr_en = 0;
        end
    endtask

    //=========================================================================
    // 任务：读寄存器
    //=========================================================================
    task read_reg(input logic [3:0] a, output logic [31:0] d);
        begin
            @(posedge clk);
            addr = a;
            rd_en = 1;
            @(posedge clk);
            d = rd_data;
            rd_en = 0;
        end
    endtask

    //=========================================================================
    // 测试激励
    //=========================================================================
    logic [31:0] read_data;
    
    initial begin
        // 初始化
        rst_n = 0;
        addr = 0;
        wr_en = 0;
        wr_data = 0;
        rd_en = 0;
        
        #100;
        rst_n = 1;
        #20;
        
        $display("=== 定时器测试开始 ===");
        
        //=====================================================================
        // 测试1: 基本定时功能
        //=====================================================================
        $display("--- 测试1: 基本定时 ---");
        write_reg(4'h10, 32'd4);    // prescale = 4
        write_reg(4'hC, 32'd9);     // threshold = 9
        write_reg(4'h0, 32'h07);    // enable=1, irq_en=1, auto_reload=1
        
        // 等待10个定时周期
        #(10 * 20 * 5 * 10);
        
        read_reg(4'h4, read_data);
        $display("STATUS: %h (irq_pending should be 1)", read_data);
        
        // 清除中断
        write_reg(4'h4, 32'h01);
        read_reg(4'h4, read_data);
        $display("STATUS after clear: %h", read_data);
        $display("");
        
        //=====================================================================
        // 测试2: PWM输出
        //=====================================================================
        $display("--- 测试2: PWM输出 ---");
        write_reg(4'h14, 32'd7);    // pwm_duty = 7
        write_reg(4'h0, 32'h09);    // enable=1, pwm_en=1
        
        // 观察10个周期
        repeat(10) begin
            @(posedge clk);
            $display("cnt=%0d, pwm_out=%b", uut.cnt, pwm_out);
        end
        $display("");
        
        $display("=== 定时器测试结束 ===");
        $finish;
    end

    //=========================================================================
    // 监控中断
    //=========================================================================
    always @(posedge clk) begin
        if (irq) begin
            $display("时间=%0t: 中断产生", $time);
        end
    end

    //=========================================================================
    // 波形输出
    //=========================================================================
    initial begin
        $dumpfile("wave_timer.vcd");
        $dumpvars(0, tb_timer);
    end

endmodule
```

## 5. 关键设计点

### 寄存器映射

| 偏移 | 名称 | 读写 | 说明 |
|---|---|---|---|
| 0x00 | CTRL | R/W | 控制寄存器 |
| 0x04 | STATUS | R/W1C | 状态寄存器（写1清除） |
| 0x08 | CNT | R | 当前计数值 |
| 0x0C | THRESHOLD | R/W | 阈值 |
| 0x10 | PRESCALE | R/W | 分频器 |
| 0x14 | PWM_DUTY | R/W | PWM占空比 |

### 控制寄存器位

```
bit[0]: ENABLE     - 使能定时器
bit[1]: IRQ_EN     - 中断使能
bit[2]: AUTO_RELOAD - 自动重载
bit[3]: PWM_EN     - PWM使能
```

### 分频原理

```
系统时钟: 50MHz
prescale = 4

分频后: 50MHz / (4+1) = 10MHz
每个计数周期: 100ns
```

### PWM原理

```
pwm_duty = 7
threshold = 9

占空比 = 7/9 ≈ 77.8%

cnt: 0 1 2 3 4 5 6 7 8 9 0 1 2 ...
pwm: 1 1 1 1 1 1 1 1 0 0 1 1 1 ...
     └─────────────┘ └─────┘
      duty=7          off=2
```

## 6. 进阶功能

### 输入捕获

```verilog
// 测量外部信号脉冲宽度
input  logic cap_pin,

// 捕获边沿时记录计数值
always_ff @(posedge clk) begin
    if (cap_pos_edge) begin
        cap_value <= cnt;
        cap_valid <= 1'b1;
    end
end

// 脉冲宽度 = cap_value * 时钟周期
```

### 看门狗

```verilog
// 看门狗定时器
// 超时未喂狗，产生复位

input  logic wdt_feed,  // 喂狗信号

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        wdt_cnt <= '0;
    else if (wdt_feed)
        wdt_cnt <= '0;  // 喂狗，清零
    else if (ctrl[CTRL_ENABLE])
        wdt_cnt <= wdt_cnt + 1;
end

assign wdt_reset = (wdt_cnt >= threshold) && ctrl[CTRL_ENABLE];
```

### 多通道PWM

```verilog
// 多通道PWM输出
parameter CH_NUM = 4,

output logic [CH_NUM-1:0] pwm_out,

// 每个通道独立占空比
logic [31:0] pwm_duty [CH_NUM];

generate
    for (genvar i = 0; i < CH_NUM; i++) begin : gen_pwm
        assign pwm_out[i] = ctrl[CTRL_PWM_EN] && (cnt < pwm_duty[i]);
    end
endgenerate
```

## 7. 练习任务

### 任务1：基础验证（必做）

```bash
# 编译
iverilog -o tb_timer tb_timer.sv timer.sv

# 运行仿真
vvp tb_timer

# 查看波形
gtkwave wave_timer.vcd
```

**观察并记录：**
- [ ] 定时器是否正确计数？
- [ ] 中断是否正确产生？
- [ ] PWM波形是否正确？

### 任务2：不同参数测试（必做）

修改参数，观察效果：

```verilog
// 测试不同分频
write_reg(4'h10, 32'd9);    // prescale = 9
write_reg(4'h10, 32'd99);   // prescale = 99

// 测试不同阈值
write_reg(4'hC, 32'd99);    // threshold = 99
write_reg(4'hC, 32'd999);   // threshold = 999
```

### 任务3：功能扩展（选做）

```verilog
// 1. 添加输入捕获
input  logic cap_pin,
output logic [31:0] cap_value,
output logic        cap_valid,

// 2. 添加输出比较
output logic        compare_out,
input  logic [31:0] compare_value,

// 3. 添加死区控制（电机驱动用）
parameter DEAD_TIME = 10,
output logic        pwm_h,
output logic        pwm_l
```

## 8. 常见错误

| 错误 | 原因 | 解决方法 |
|---|---|---|
| 中断不产生 | 中断使能未设置 | 检查CTRL寄存器bit[1] |
| 计数器不计数 | 使能位未设置 | 检查CTRL寄存器bit[0] |
| PWM波形不对 | 占空比大于阈值 | 确保pwm_duty < threshold |
| 分频不正确 | prescale值错误 | 检查分频计算公式 |

## 9. 知识点总结

### 定时器类型

| 类型 | 用途 | 特点 |
|---|---|---|
| 基本定时器 | 定时中断 | 简单计数 |
| PWM定时器 | 电机/LED控制 | 可调占空比 |
| 输入捕获 | 脉冲测量 | 记录边沿时刻 |
| 看门狗 | 系统监控 | 超时复位 |

### APB接口要点

1. **写操作**：wr_en有效时，将wr_data写入对应寄存器
2. **读操作**：rd_en有效时，输出对应寄存器值
3. **W1C**：写1清除（Write 1 to Clear），用于清除状态位

---

*完成本练习后，你应该掌握：*
- [x] 定时器工作原理
- [x] 寄存器映射设计
- [x] 分频器设计
- [x] PWM波形生成

*最后更新: 2026-07-14*