---
title: "SoC 基本架构"
description: "SoC片上系统核心架构详解"
pubDate: 2025-01-01
category: soc
order: 1
tags: [SOC, 架构]
---
# SoC 基本架构

## 什么是 SoC

**SoC（System on Chip，片上系统）** 是将整个电子系统集成在单一芯片上的解决方案。它将处理器、存储器、外设接口、总线系统等所有功能模块集成在一个芯片中，形成完整的系统级芯片。

## SoC 核心架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        SoC 芯片                                  │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   CPU 核心   │   │   GPU 核心   │   │  DSP 核心    │         │
│  │  (处理器)    │   │  (图形处理)   │   │(数字信号处理)│         │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                 │
│                            │                                    │
│  ┌─────────────────────────▼─────────────────────────┐         │
│  │              系统总线 / 互联矩阵                   │         │
│  │           (AXI / AHB / APB / NoC)                 │         │
│  └───┬───────────┬───────────┬───────────┬───────────┘         │
│      │           │           │           │                     │
│  ┌───▼───┐   ┌───▼───┐   ┌───▼───┐   ┌───▼───┐               │
│  │  ROM  │   │  SRAM │   │  DRAM │   │ Flash │               │
│  │       │   │ 控制器 │  │ 控制器 │   │ 控制器 │               │
│  └───────┘   └───────┘   └───────┘   └───────┘               │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    外设接口层                            │ │
│  ├─────────┬─────────┬─────────┬─────────┬─────────┬───────┤ │
│  │  UART   │   SPI   │   I2C   │   USB   │  HDMI   │  ...  │ │
│  └─────────┴─────────┴─────────┴─────────┴─────────┴───────┘ │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    模拟/混合信号                         │ │
│  ├─────────┬─────────┬─────────┬─────────┬─────────────────┤ │
│  │   PLL   │   ADC   │   DAC   │   PHY   │   电源管理       │ │
│  └─────────┴─────────┴─────────┴─────────┴─────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## 核心组件详解

### 1. 处理器子系统

#### 1.1 CPU 核心

| 类型 | 说明 | 应用场景 |
|---|---|---|
| **RISC-V** | 开源指令集，可定制 | IoT、嵌入式、学习 |
| **ARM Cortex-M** | 低功耗微控制器 | MCU、可穿戴设备 |
| **ARM Cortex-A** | 高性能应用处理器 | 智能手机、平板 |
| **ARM Cortex-R** | 实时处理器 | 汽车、工业控制 |
| **x86** | 复杂指令集 | PC、服务器 |

#### 1.2 多核架构

```verilog
// 多核 SoC 顶层结构示意
module soc_top;
    // CPU 核心阵列
    cpu_core #(.CORE_ID(0)) cpu0 (.clk(clk), .rst_n(rst_n), .bus_if(bus));
    cpu_core #(.CORE_ID(1)) cpu1 (.clk(clk), .rst_n(rst_n), .bus_if(bus));
    cpu_core #(.CORE_ID(2)) cpu2 (.clk(clk), .rst_n(rst_n), .bus_if(bus));
    cpu_core #(.CORE_ID(3)) cpu3 (.clk(clk), .rst_n(rst_n), .bus_if(bus));
    
    // 一致性控制器 (确保多核缓存一致)
    cache_coherency_controller coh (.bus_if(bus), .snoop_if(snoop));
endmodule
```

### 2. 存储子系统

#### 2.1 存储层次结构

```
寄存器文件 (RF)
    ↓  延迟: 0 周期
L1 指令缓存 (I-Cache)
L1 数据缓存 (D-Cache)
    ↓  延迟: 1-2 周期
L2 缓存 (统一)
    ↓  延迟: 5-10 周期
L3 缓存 (可选)
    ↓  延迟: 20-50 周期
主存 (DDR/LPDDR)
    ↓  延迟: 100-200 周期
外部存储 (NAND/eMMC)
```

#### 2.2 存储控制器

| 控制器类型 | 功能 | 典型接口 |
|---|---|---|
| **DDR 控制器** | 主存访问 | DDR3/DDR4/LPDDR4/5 |
| **SRAM 控制器** | 片上高速存储 | SRAM/TCM |
| **Flash 控制器** | 非易失存储 | NAND/NOR/eMMC |
| **OTP 控制器** | 一次性编程 | eFuse |

### 3. 总线互联

#### 3.1 AXI 总线架构

```
主设备 (Master)                    从设备 (Slave)
┌─────────┐                    ┌─────────┐
│  CPU    │───AXI Master──────│  DDR    │
│  Core   │    读/写通道       │ 控制器   │
└─────────┘                    └─────────┘
     │                              │
     │    ┌─────────────────────┐   │
     └────│    AXI 互联矩阵     │───┘
          │  (Crossbar/NoC)     │
     ┌────│                     │───┐
     │    └─────────────────────┘   │
     │                              │
┌─────────┐                    ┌─────────┐
│  DMA    │───AXI Master──────│  SRAM   │
│ 控制器   │                    │ 控制器   │
└─────────┘                    └─────────┘
```

#### 3.2 AXI 信号接口

```verilog
// AXI4 接口定义 (简化版)
interface axi_if(input logic aclk, input logic aresetn);
    // 写地址通道
    logic [31:0] awaddr;
    logic [7:0]  awlen;
    logic [2:0]  awsize;
    logic        awvalid;
    logic        awready;
    
    // 写数据通道
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wlast;
    logic        wvalid;
    logic        wready;
    
    // 写响应通道
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;
    
    // 读地址通道
    logic [31:0] araddr;
    logic [7:0]  arlen;
    logic [2:0]  arsize;
    logic        arvalid;
    logic        arready;
    
    // 读数据通道
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rlast;
    logic        rvalid;
    logic        rready;
endinterface
```

### 4. 外设接口

#### 4.1 通信接口

| 接口 | 速率 | 特点 | 应用 |
|---|---|---|---|
| **UART** | 115.2K-3M bps | 异步、简单 | 调试、低速通信 |
| **SPI** | 1-100 MHz | 同步、全双工 | Flash、传感器 |
| **I2C** | 100K-3.4M bps | 多主、多从 | EEPROM、RTC |
| **USB** | 1.5-20 Gbps | 即插即用 | 外设连接 |
| **PCIe** | 2.5-32 GT/s | 高速、点对点 | 显卡、SSD |
| **Ethernet** | 10M-400Gbps | 网络通信 | 以太网 |
| **HDMI** | 2.25-48 Gbps | 高清视频 | 显示输出 |

#### 4.2 低速外设

| 外设 | 功能 |
|---|---|
| **GPIO** | 通用输入输出，可配置方向 |
| **Timer** | 定时器，产生中断或PWM |
| **Watchdog** | 看门狗，防止系统死锁 |
| **RTC** | 实时时钟，低功耗计时 |
| **ADC/DAC** | 模数/数模转换 |

### 5. 中断系统

#### 5.1 中断控制器架构

```
外设中断源                    中断控制器                 CPU
┌─────────┐                ┌─────────────┐          ┌─────────┐
│  UART   │──IRQ[0]───────│             │───FIQ────│         │
│  SPI    │──IRQ[1]───────│   GIC       │───IRQ────│  CPU    │
│  I2C    │──IRQ[2]───────│  (通用中断   │          │  Core   │
│  Timer  │──IRQ[3]───────│   控制器)    │          │         │
│  GPIO   │──IRQ[4]───────│             │          │         │
│  DMA    │──IRQ[5]───────│  ┌────────┐ │          │         │
│  ...    │──...──────────│  │优先级   │ │          │         │
│  SGI    │──IRQ[n]───────│  │仲裁器   │ │          │         │
└─────────┘                │  └────────┘ │          └─────────┘
                           └─────────────┘
```

#### 5.2 中断类型

| 类型 | 说明 |
|---|---|
| **FIQ** (Fast IRQ) | 快速中断，低延迟 |
| **IRQ** (Interrupt Request) | 普通中断 |
| **SGI** (Software Generated) | 软件触发中断 |
| **PPI** (Private Peripheral) | 私有外设中断 |
| **SPI** (Shared Peripheral) | 共享外设中断 |

### 6. DMA 控制器

```verilog
// DMA 控制器简化模型
module dma_controller (
    input  logic        clk,
    input  logic        rst_n,
    
    // AXI Master 接口
    axi_if.master       axi_m,
    
    // 通道控制
    input  logic [31:0] src_addr,
    input  logic [31:0] dst_addr,
    input  logic [31:0] transfer_size,
    input  logic        start,
    output logic        done
);
    // DMA 传输状态机
    typedef enum logic [2:0] {
        IDLE,
        READ_BURST,
        WRITE_BURST,
        DONE
    } state_t;
    
    state_t state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: if (start) state <= READ_BURST;
                READ_BURST: if (arready) state <= WRITE_BURST;
                WRITE_BURST: if (wready) state <= DONE;
                DONE: state <= IDLE;
            endcase
        end
    end
endmodule
```

### 7. 时钟与复位

#### 7.1 时钟域

```
外部晶振 (24MHz)
    │
    ▼
┌─────────┐
│   PLL   │──── CPU_CLK (1.2GHz)
│         │──── MEM_CLK (800MHz)
│         │──── PER_CLK (100MHz)
│         │──── IO_CLK (48MHz)
└─────────┘
    │
    ▼
┌─────────────────────────────────────┐
│           时钟分发网络                │
├─────────────────────────────────────┤
│  CPU 域     │  存储域   │  外设域    │
│  (高频)     │  (中频)   │  (低频)    │
└─────────────────────────────────────┘
```

#### 7.2 复位策略

| 复位类型 | 说明 | 优先级 |
|---|---|---|
| **Power-on Reset** | 上电复位 | 最高 |
| **External Reset** | 外部复位引脚 | 高 |
| **Watchdog Reset** | 看门狗超时 | 中 |
| **Software Reset** | 软件触发 | 低 |
| **Brown-out Reset** | 欠压复位 | 自动 |

### 8. 电源管理

#### 8.1 电源域划分

```
┌─────────────────────────────────────────┐
│              电源域 (Power Domain)        │
├─────────────────────────────────────────┤
│  PD_ALWAYS    │ 始终供电 (RTC, WDT)      │
├───────────────┼─────────────────────────┤
│  PD_CPU       │ CPU 域 (可关闭)          │
├───────────────┼─────────────────────────┤
│  PD_GPU       │ GPU 域 (可关闭)          │
├───────────────┼─────────────────────────┤
│  PD_IO        │ IO 域 (可降压)           │
├───────────────┼─────────────────────────┤
│  PD_MEM       │ 存储域 (自刷新)          │
└─────────────────────────────────────────┘
```

#### 8.2 低功耗模式

| 模式 | 功耗 | 唤醒时间 | 说明 |
|---|---|---|---|
| **Active** | 高 | - | 正常工作 |
| **Idle** | 中 | 立即 | CPU 时钟停止 |
| **Sleep** | 低 | 毫秒 | 大部分模块关闭 |
| **Deep Sleep** | 极低 | 秒 | 仅保持 RAM |
| **Power-off** | 0 | 手动 | 完全断电

### 9. 安全架构

#### 9.1 安全组件

```
┌─────────────────────────────────────────────┐
│                安全子系统                     │
├─────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
│  │ TrustZone│  │   TEE   │  │ Crypto  │     │
│  │  (ARM)  │  │  安全区  │  │ Engine  │     │
│  └─────────┘  └─────────┘  └─────────┘     │
│                                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
│  │ Secure  │  │  Debug  │  │  eFuse  │     │
│  │ Boot    │  │  Auth   │  │  密钥   │     │
│  └─────────┘  └─────────┘  └─────────┘     │
└─────────────────────────────────────────────┘
```

#### 9.2 TrustZone 区域

| 区域 | 权限 | 用途 |
|---|---|---|
| **Secure World** | 高权限 | 安全启动、密钥管理、DRM |
| **Non-secure World** | 普通权限 | 正常应用运行 |
| **Monitor Mode** | 切换 | 世界切换处理 |

### 10. 典型 SoC 产品对比

| 产品线 | CPU | GPU | 应用 |
|---|---|---|---|
| **STM32** | Cortex-M | 无 | MCU、工业控制 |
| **i.MX RT** | Cortex-M7 | 无 | IoT、边缘计算 |
| **RP2040** | Cortex-M0+ | 无 | 教育、原型 |
| **Snapdragon** | Cortex-A78 | Adreno | 智能手机 |
| **Apple M系列** | Firestorm/Icestorm | Apple GPU | PC、工作站 |

## SoC 设计流程

```
需求分析 → 架构设计 → RTL 编写 → 功能验证 → 综合实现 → 后端设计 → 流片
    │          │          │          │          │          │         │
    ▼          ▼          ▼          ▼          ▼          ▼         ▼
  规格书    模块划分   Verilog   Testbench  门级网表   物理版图   芯片
```

## 参考资源

- **AMBA 协议规范**: ARM 官方文档
- **RISC-V 架构手册**: riscv.org
- **《数字设计与计算机体系结构》**: Harris & Harris
- **《SoC 设计方法与实现》**: 蒋本珊

---

*最后更新: 2026-07-13*