---
title: "总线协议详解"
description: "AXI/AHB/APB等总线协议详解"
pubDate: 2025-01-01
category: soc
order: 2
tags: [SOC, 总线协议]
---

# SoC 总线协议详解

## 总线协议概述

### 什么是总线协议

**总线协议**是 SoC 中各模块之间通信的规范，定义了：
- 信号线命名和功能
- 时序关系（valid/ready 握手）
- 数据传输方式（突发、流水）
- 错误处理机制
- 多主设备仲裁

### 总线分类

```
                    总线协议
                       │
       ┌───────────────┼───────────────┐
       │               │               │
   片上总线          片间总线         系统总线
   (On-Chip)       (Inter-Chip)    (System)
       │               │               │
   ┌───┴───┐       ┌───┴───┐       ┌───┴───┐
   │       │       │       │       │       │
 AXI    PCIe   USB    DDR    PCIe
 AHB    SATA  Ethernet
 APB    HDMI   JTAG
```

---

## 1. AMBA 协议族

### AMBA 概述

**AMBA (Advanced Microcontroller Bus Architecture)** 是 ARM 公司制定的总线标准，是目前 SoC 中使用最广泛的片上总线。

```
AMBA 协议演进:
AXI4 ──→ ACE (缓存一致性)
  │
AHB ──→ AXI3 (早期版本)
  │
APB ──→ 低速外设
```

### AMBA 协议进化历程

```
进化路线:
APB (1996) → AHB (1999) → AXI3 (2003) → AXI4 (2010) → ACE (2011)

每一代解决上一代的瓶颈:
APB  太慢 → AHB  加了流水线
AHB  带宽不够 → AXI  通道独立 + Outstanding
AXI  多核一致性问题 → ACE  加了缓存一致性
```

#### APB → AHB：从串行到流水线

```
APB 的瓶颈: 每笔传输固定 2 拍，无法重叠

APB:
  T0: A0 SETUP    T1: A0 ACCESS    T2: A1 SETUP    T3: A1 ACCESS
  → 2 拍固定，串行执行

AHB 的突破: 地址阶段和数据阶段可以重叠

AHB:
  T0: A0 地址阶段
  T1: A0 数据阶段 + A1 地址阶段 ← 重叠！
  T2: A1 数据阶段 + A2 地址阶段 ← 重叠！
  → 流水线提高利用率

AHB 其他改进:
  + Burst 突发 (一次地址传 4/8/16 个数据)
  + 多主设备仲裁 (HBUSREQ/HGRANT)
  + Split 传输 (慢速从设备不阻塞总线)
```

#### AHB → AXI3：从共享到并发

```
AHB 的瓶颈: 所有事务共享一条总线，一个主设备传输时其他必须等待

AXI3 的突破: 五通道完全独立，可同时工作

AHB 写: 地址阶段(1拍) → 数据阶段(1拍) = 2拍，串行
AXI3 写: AW通道 + W通道 + B通道 可并行

AXI3 关键改进:
  + Outstanding 事务 (发完地址不用等数据，继续发下一个)
  + ID 标识 + 乱序完成 (不同 ID 可乱序返回)
  + 写交织 (不同事务的写数据可以交织)
  + Burst 长度扩展 (最大 16 拍)
```

#### AXI3 → AXI4：从复杂到简化

```
AXI3 的问题:
  1. 写数据可先于写地址 → 互联需要 Buffer 暂存 → 面积大
  2. 支持写交织 → 重排序逻辑复杂
  3. Burst 最大 16 拍 → DDR 效率不够高

AXI4 的简化:
  + 禁止写数据先于写地址 → 去掉 Buffer，节省面积
  + 禁止写交织 → 简化互联设计
  + Burst 扩展到 256 拍 → DDR 效率更高
  + 新增 QoS/Region → 更精细的流量控制
```

#### AXI4 → ACE：解决多核一致性

```
问题: 多核 CPU 各有 L1 Cache
  CPU0 写了 addr=0x100 → Cache0 更新为新值
  CPU1 的 Cache1 还是旧值 → 数据不一致

ACE 在 AXI 基础上增加了:
  + Snoop 通道 (监听): 互联可以"询问"每个 CPU 的 Cache
  + Cache 状态 (MOESI): M/O/E/S/I 五种状态
  + 监听请求: ReadShared/MakeUnique/CleanInvalid 等
  → 保证多核系统中 Cache 数据的一致性
```

#### 进化总结

| 协议 | 年份 | 关键突破 | 解决的问题 |
|------|------|---------|-----------|
| **APB** | 1996 | 最简总线 | 低速外设接口 |
| **AHB** | 1999 | 流水线 + Burst | 中速设备带宽 |
| **AXI3** | 2003 | 五通道独立 + Outstanding + ID | 高性能并发 |
| **AXI4** | 2010 | 简化写通道 + 扩展突发 | 降低复杂度、提高效率 |
| **ACE** | 2011 | Snoop + MOESI | 多核缓存一致性 |

### 1.1 AXI4 协议

#### 架构特点

```
AXI4 架构:
┌─────────────────────────────────────────────────────────────┐
│                      AXI4 Interconnect                      │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐    ┌──────────┐    ┌──────────┐               │
│  │ Master 0 │    │ Master 1 │    │ Master 2 │               │
│  │  (CPU)   │    │  (DMA)   │    │  (GPU)   │               │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘               │
│       │               │               │                     │
│       ▼               ▼               ▼                     │
│  ┌─────────────────────────────────────────────┐            │
│  │              Crossbar Switch                │            │
│  │           (交叉开关/互联矩阵)                 │           │
│  └─────────────────────────────────────────────┘            │
│       │               │               │                     │
│       ▼               ▼               ▼                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐               │
│  │ Slave 0  │    │ Slave 1  │    │ Slave 2  │               │
│  │  (DDR)   │    │  (SRAM)  │    │  (APB)   │               │
│  └──────────┘    └──────────┘    └──────────┘               │
└─────────────────────────────────────────────────────────────┘
```

#### 五个独立通道

| 通道 | 名称 | 方向 | 功能 |
|---|---|---|---|
| **AW** | Write Address | Master→Slave | 写地址+控制 |
| **W** | Write Data | Master→Slave | 写数据 |
| **B** | Write Response | Slave→Master | 写完成响应 |
| **AR** | Read Address | Master→Slave | 读地址+控制 |
| **R** | Read Data | Slave→Master | 读数据+响应 |

#### AXI4 信号接口

```verilog
// AXI4 完整接口定义
interface axi4_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter ID_WIDTH   = 4
)(
    input  logic aclk,
    input  logic aresetn
);

    // 写地址通道 (AW)
    logic [ID_WIDTH-1:0]    awid;
    logic [ADDR_WIDTH-1:0]  awaddr;
    logic [7:0]             awlen;      // 突发长度 (0-255)
    logic [2:0]             awsize;     // 突发大小
    logic [1:0]             awburst;    // 突发类型
    logic                   awlock;     // 锁定类型
    logic [3:0]             awcache;    // 缓存属性
    logic [2:0]             awprot;     // 保护属性
    logic [3:0]             awqos;      // QoS 标识
    logic [ID_WIDTH-1:0]    awregion;
    logic [3:0]             awuser;
    logic                   awvalid;
    logic                   awready;

    // 写数据通道 (W)
    logic [DATA_WIDTH-1:0]  wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;    // 字节选通
    logic                   wlast;      // 最后一个数据
    logic [3:0]             wuser;
    logic                   wvalid;
    logic                   wready;

    // 写响应通道 (B)
    logic [ID_WIDTH-1:0]    bid;
    logic [1:0]             bresp;      // 响应码
    logic [3:0]             buser;
    logic                   bvalid;
    logic                   bready;

    // 读地址通道 (AR)
    logic [ID_WIDTH-1:0]    arid;
    logic [ADDR_WIDTH-1:0]  araddr;
    logic [7:0]             arlen;
    logic [2:0]             arsize;
    logic [1:0]             arburst;
    logic                   arlock;
    logic [3:0]             arcache;
    logic [2:0]             arprot;
    logic [3:0]             arqos;
    logic [ID_WIDTH-1:0]    arregion;
    logic [3:0]             aruser;
    logic                   arvalid;
    logic                   arready;

    // 读数据通道 (R)
    logic [ID_WIDTH-1:0]    rid;
    logic [DATA_WIDTH-1:0]  rdata;
    logic [1:0]             rresp;
    logic                   rlast;
    logic [3:0]             ruser;
    logic                   rvalid;
    logic                   rready;

endinterface
```

#### AXI4 Burst 传输

```
AXI4 写突发时序 (INCR 类型):

         ┌─────┐     ┌─────┐     ┌─────┐
AW_VALID │     │     │     │     │     │
         └─────┘     └─────┘     └─────┘
              │           │           │
              ▼           ▼           ▼
AW_ADDR  ────A0──────────A1──────────A2────

         ┌─────┐     ┌─────┐     ┌─────┐
W_VALID  │     │     │     │     │     │
         └─────┘     └─────┘     └─────┘
              │           │           │
              ▼           ▼           ▼
W_DATA   ────D0──────────D1──────────D2────
                 W_LAST=0     W_LAST=1

         ┌─────┐
B_VALID  │     │
         └─────┘
              │
              ▼
B_RESP   ────OKAY────
```

#### AXI4 突发类型

| 类型 | `awburst` | 地址行为 | 用途 |
|---|---|---|---|
| **FIXED** | 2'b00 | 地址不变 | FIFO 访问 |
| **INCR** | 2'b01 | 地址递增 | 顺序访问（最常用） |
| **WRAP** | 2'b10 | 地址环绕 | 缓存行填充 |

#### AXI4 响应码

| 响应码 | 含义 | 说明 |
|---|---|---|
| `2'b00` (OKAY) | 正常访问 | 成功完成 |
| `2'b01` (EXOKAY) | 独占访问成功 | 原子操作 |
| `2'b10` (SLVERR) | 从设备错误 | 地址有效但从设备出错 |
| `2'b11` (DECERR) | 解码错误 | 地址无效，无从设备匹配 |

#### AXI4-Lite 精简版

```verilog
// AXI4-Lite 信号（无突发、无 ID）
interface axi4_lite_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic aclk,
    input  logic aresetn
);

    // 写地址通道 (无 awlen/awsize/awburst)
    logic [ADDR_WIDTH-1:0]  awaddr;
    logic [2:0]             awprot;
    logic                   awvalid;
    logic                   awready;

    // 写数据通道 (无 wstrb 可选)
    logic [DATA_WIDTH-1:0]  wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                   wvalid;
    logic                   wready;

    // 写响应通道 (无 bid)
    logic [1:0]             bresp;
    logic                   bvalid;
    logic                   bready;

    // 读地址通道 (无 arlen/arsize/arburst)
    logic [ADDR_WIDTH-1:0]  araddr;
    logic [2:0]             arprot;
    logic                   arvalid;
    logic                   arready;

    // 读数据通道 (无 rid/rlast)
    logic [DATA_WIDTH-1:0]  rdata;
    logic [1:0]             rresp;
    logic                   rvalid;
    logic                   rready;

endinterface
```

#### AXI4 vs AXI4-Lite vs AXI4-Stream

| 特性 | AXI4 | AXI4-Lite | AXI4-Stream |
|---|---|---|---|
| **突发传输** | 支持 (INCR/WRAP) | 不支持 | 连续流 |
| **地址** | 有 | 有 | 无 |
| **ID 标识** | 有 | 无 | 无 |
| **字节选通** | 有 | 有 | 无 |
| **数据宽度** | 8/16/32/64/128/256/512/1024 | 32/64 | 任意 |
| **典型应用** | DDR、SRAM、高带宽 | 寄存器配置 | 视频流、DSP |

#### Outstanding 事务机制

```
Outstanding 事务原理:

主设备发送地址后，不必等待数据响应即可发送下一个地址
这种"流水线"方式可以隐藏从设备的访问延迟

时间线示例 (Outstanding 深度 = 4):

时钟:    T0   T1   T2   T3   T4   T5   T6   T7   T8
         │    │    │    │    │    │    │    │    │
Master:  A0   A1   A2   A3   ─    ─    ─    ─    ─
         │         │         │         │
         ▼         ▼         ▼         ▼
Slave:   ─    ─    ─    ─    D0   D1   D2   D3   ─
                                 (从设备响应)

没有 Outstanding (每笔事务等待完成):
T0: A0 → T3: D0 → T4: A1 → T7: D1 → T8: A2 ...
总延迟 = 4笔 × 4周期 = 16 周期

有 Outstanding (深度=4):
T0: A0, T1: A1, T2: A2, T3: A3 → T4: D0, T5: D1, T6: D2, T7: D3
总延迟 = 4 + 4 = 8 周期 (节省 50%)
```

```
Outstanding 深度选择:

深度 = 1:  无流水，每笔事务独立完成
           优点: 无乱序风险
           缺点: 延迟大

深度 = 2:  可流水 2 笔事务
           优点: 简单，适合中速外设
           缺点: 性能提升有限

深度 = 4-8: 常用于 DDR 控制器
           优点: 充分利用 DDR 的流水线
           缺点: 需要更大的 ID 缓冲

深度 = 16+: 用于高性能 SoC 核心互联
           优点: 最大化带宽利用率
           缺点: 面积和功耗代价
```

#### AXI4 交叉开关互联详解

```
3×3 全交叉开关内部结构:

          M0        M1        M2
          │         │         │
          ▼         ▼         ▼
       ┌──────┐ ┌──────┐ ┌──────┐
       │ ARB0 │ │ ARB1 │ │ ARB2 │  ← 每个 Slave 端口有仲裁器
       └──┬───┘ └──┬───┘ └──┬───┘
          │        │        │
     ┌────┴────┬───┴────┬───┴────┐
     │         │        │        │
     ▼         ▼        ▼        ▼
  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
  │SW_00 │ │SW_10 │ │SW_20 │ │ ...  │  ← 每个交叉点有开关
  │SW_01 │ │SW_11 │ │SW_21 │ │      │
  │SW_02 │ │SW_12 │ │SW_22 │ │      │
  └──────┘ └──────┘ └──────┘ └──────┘
     │         │        │
     ▼         ▼        ▼
   S0(DDR)  S1(SRAM)  S2(APB)

每个开关 SW_ij 控制 Master i 到 Slave j 的连接
仲裁器 ARB_j 决定哪个 Master 可以访问 Slave j
```

```
交叉开关连接矩阵:

Master\Slave  │  S0(DDR)  │  S1(SRAM)  │  S2(APB)
──────────────┼───────────┼────────────┼──────────
M0 (CPU)      │     ●     │     ●      │     ●
M1 (DMA)      │     ●     │     ●      │     ●
M2 (GPU)      │     ●     │     ○      │     ●

● = 可访问   ○ = 不可访问 (稀疏交叉开关)

Full Crossbar: 所有交叉点都有开关，面积 O(M×S)
Sparse Crossbar: 只在需要的交叉点有开关，面积 < O(M×S)
```

#### AXI4 写交织（Write Interleading）

```
写交织规则:

规则 1: 同一写事务的所有 W 拍不能交织
  Transaction A: W_A0 → W_A1 → W_A2
  Transaction B: W_B0 → W_B1

  正确:
  W_A0 → W_A1 → W_A2 → W_B0 → W_B1
  (A 的所有拍先发完，再发 B)

  错误:
  W_A0 → W_B0 → W_A1 → W_A2 → W_B1
  (A 和 B 交织，违反协议)

规则 2: 不同事务的 W 拍可以交织 (AXI3 允许, AXI4 不允许)
  AXI4 限制: W 通道不支持交织
  AXI3 允许: W_A0 → W_B0 → W_A1 → W_B1

规则 3: W 通道的写响应 B 必须按事务顺序返回
  先发的事务先收到 B 响应 (基于 ID 排序)
```

```
WLAST 信号:

WLAST 必须在突发的最后一个数据拍时为高

INCR 突发 (awlen=2, 3 拍):
  W_VALID:  ────1────1────1────0────
  W_LAST:   ────0────0────1────0────
            拍0   拍1   拍2  (结束)

FIXED 突发 (awlen=0, 1 拍):
  W_VALID:  ────1────0────
  W_LAST:   ────1────0────
            唯一一拍
```

#### AXI4 读重排（Read Reordering）

```
读重排规则:

规则 1: 同一 ID 的读事务必须按发送顺序返回响应
  AR_A (ID=0) → AR_B (ID=0) → AR_C (ID=0)
  必须: R_A → R_B → R_C (保序)

规则 2: 不同 ID 的读事务可以乱序返回
  AR_A (ID=0) → AR_B (ID=1) → AR_C (ID=2)
  可以: R_B → R_C → R_A (基于从设备响应速度)

规则 3: 交叉开关可基于 ID 重排响应顺序
  原因: 不同从设备响应延迟不同
  DDR 从设备: 50 周期
  SRAM 从设备: 5 周期
  → SRAM 的响应先返回，即使 DDR 的 AR 先发送
```

```
读重排时序示例:

AR 通道:
T0: AR_A (ID=0, DDR地址)
T1: AR_B (ID=1, SRAM地址)

R 通道 (SRAM 先响应):
T5:  R_B (ID=1, SRAM数据)  ← SRAM 快速响应
T50: R_A (ID=0, DDR数据)   ← DDR 慢速响应

这是允许的，因为 ID 不同
```

#### AXI4 窄传输与字节选通（Narrow Transfer）

```
窄传输原理:

当主设备数据宽度大于从设备数据宽度时:
- 32 位主设备访问 8 位从设备
- 需要多次传输来完成一个字的读写

字节通道映射 (32 位总线):
字节 0: wstrb[0] → 位 [7:0]
字节 1: wstrb[1] → 位 [15:8]
字节 2: wstrb[2] → 位 [23:16]
字节 3: wstrb[3] → 位 [31:24]
```

```
wstrb 示例:

写 32 位字到 8 位从设备:
  第 1 拍: wstrb = 4'b0001, wdata[7:0] = data[7:0]
  第 2 拍: wstrb = 4'b0010, wdata[15:8] = data[15:8]
  第 3 拍: wstrb = 4'b0100, wdata[23:16] = data[23:16]
  第 4 拍: wstrb = 4'b1000, wdata[31:24] = data[31:24]

写 16 位半字到 32 位从设备:
  wstrb = 4'b0011, wdata[15:0] = halfword

部分写 (读-改-写):
  wstrb = 4'b1100, 只写高 16 位，低 16 位保持不变
```

#### AXI4 WRAP 突发地址计算

```
WRAP 突发地址计算:

公式:
  wrap_boundary = (addr / (burst_size × (burst_len + 1))) × (burst_size × (burst_len + 1))
  lower_wrap = wrap_boundary
  upper_wrap = wrap_boundary + (burst_size × (burst_len + 1))
  地址递增到 upper_wrap 时，回到 lower_wrap

示例: awaddr=0x04, awsize=2(4字节), awlen=3(4拍), awburst=WRAP
  burst_bytes = 4 × 4 = 16 字节
  wrap_boundary = (0x04 / 16) × 16 = 0x00
  lower_wrap = 0x00
  upper_wrap = 0x00 + 16 = 0x10

  地址序列:
  拍 0: 0x04 (起始地址)
  拍 1: 0x08
  拍 2: 0x0C
  拍 3: 0x00 (环绕到 lower_wrap)
  拍 4: 0x04 (回到起始)

用途: 缓存行填充 (Cache Line Fill)
  CPU 请求地址 0x04，但缓存行大小为 16 字节
  → WRAP 突发从 0x04 开始，填充整个 0x00-0x0F 范围
```

#### AXI4 QoS 与 Region

```
QoS (Quality of Service) 编码:

awqos[3:0] / arqos[3:0]:
  0000 = 最高优先级 (默认)
  0001 = 较高优先级
  ...
  1111 = 最低优先级

应用场景:
- CPU: awqos = 0x0 (最高优先级，保证响应速度)
- DMA: awqos = 0x5 (中等优先级)
- GPU: awqos = 0x3 (较高优先级)
- 调试接口: awqos = 0xF (最低优先级)
```

```
Region 编码:

awregion[3:0] / arregion[3:0]:
  将多个从设备地址空间映射到一个逻辑区域

示例:
  Region 0: 0x0000_0000 - 0x0000_FFFF (SRAM 0)
  Region 1: 0x0001_0000 - 0x0001_FFFF (SRAM 1)
  Region 2: 0x0002_0000 - 0x0002_FFFF (SRAM 2)

用途: 简化地址译码，减少解码器延迟
```

```
Cache 属性 (awcache/arcache):

awcache[3:0]:
  [0] = Bufferable (可缓冲)
  [1] = Cacheable (可缓存)
  [2] = Read-Allocate (读分配)
  [3] = Write-Allocate (写分配)

典型配置:
  Device Non-bufferable:  4'b0000 (寄存器访问)
  Device Bufferable:      4'b0001 (I/O 访问)
  Normal Non-cacheable:   4'b0010 (普通非缓存)
  Normal Non-cacheable NB:4'b0110 (可缓冲非缓存)
  Write-Back Read/Write:  4'b1110 (回写缓存)
  Write-Through:          4'b1111 (直写缓存)
```

#### valid/ready 反压机制详解

```
反压 (Backpressure) 原理:

当从设备还没准备好接收/发送数据时，通过拉低 ready 信号
"反压"主设备，主设备必须保持信号不变直到握手完成。

这是 AXI 总线最核心的流控机制。
```

```
正常握手 (无反压):

CLK      ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐
           └──┘  └──┘  └──┘  └──┘

MASTER:
  AWADDR  ──── 0x1000 ──────────────────
  AWVALID ─────────1────────0──────────
  AWREADY ───────────────1──────────────
                   (从机就绪)

从机在第一个周期就返回 ready → 1 拍完成
```

```
从机反压 (从机没准备好):

MASTER:
  AWADDR  ──── 0x1000 ──────────────────────────
  AWVALID ─────────1────────────────0───────────
  AWREADY ───────────────0──────0───1───────────
                   │      │     │
                   ▼      ▼     ▼
              从机没空  还没空  终于好了

关键规则: ready=0 期间，主机的 AWADDR/AWVALID 等信号不能变！
```

```
违规示例 (主机在反压期间改了地址):

T0: AWADDR=0x1000, AWVALID=1, AWREADY=0
T1: AWADDR=0x2000, AWVALID=1, AWREADY=0  ← 违规！
T2: AWREADY=1

从机在 T2 采样到 AWADDR=0x2000
→ 从机认为主机要写 0x2000，实际主机想写 0x1000
→ 数据写到错误地址，系统崩溃
```

```
valid/ready 四种状态:

valid │ ready │ 含义
──────┼───────┼──────────────────────────
  0   │   0   │ 无事发生，总线空闲
  0   │   1   │ 从机就绪但主机无请求（允许）
  1   │   0   │ 主机请求但从机反压（主机必须保持）
  1   │   1   │ 握手完成，数据传输

协议规则:
- valid=1 后必须保持到 ready=1（不能提前撤销）
- ready=0 时主机信号必须稳定不变
- valid 和 ready 没有固定先后顺序（都可以先断言）
```

```
五通道反压示意:

AW 通道: 主机→从机 (写地址)
  主机发地址，从机反压 → 地址必须保持

W 通道:  主机→从机 (写数据)
  主机发数据，从机反压 → 数据和 wstrb 必须保持

B 通道:  从机→主机 (写响应)
  从机发响应，主机反压 → 响应必须保持

AR 通道: 主机→从机 (读地址)
  主机发地址，从机反压 → 地址必须保持

R 通道:  从机→主机 (读数据)
  从机发数据，主机反压 → 数据必须保持
```

```verilog
// valid/ready 握手断言 (协议检查)
property handshake_valid_ready;
    @(posedge aclk) disable iff (!aresetn)
    // valid 断言后必须保持直到 ready
    (awvalid && !awready) |=> awvalid;
endproperty

assert_handshake: assert property(handshake_valid_ready)
    else $error("Protocol violation: awvalid deasserted before awready");
```

---

### 1.2 AHB 协议

#### AHB 架构

```
AHB 总线架构:

  ┌─────────┐  ┌─────────┐  ┌─────────┐
  │ Master 0│  │ Master 1│  │ Master 2│
  │  (CPU)  │  │  (DMA)  │  │  (DSP)  │
  └────┬────┘  └────┬────┘  └────┬────┘
       │HBUSREQ     │HBUSREQ     │HBUSREQ
       ▼            ▼            ▼
  ┌─────────────────────────────────────┐
  │           仲裁器 (Arbiter)          │
  │  作用：决定哪个 Master 获得总线访问权 │
  │  输入：HBUSREQ[n]（请求信号）        │
  │  输出：HGRANT[n]（授权信号）         │
  └─────────────────────────────────────┘
                    │HMASTER
                    ▼
  ┌─────────────────────────────────────┐
  │           解码器 (Decoder)          │
  │  作用：根据地址选中目标 Slave         │
  │  输入：HADDR（地址总线）             │
  │  输出：HSEL[n]（从设备片选）         │
  └─────────────────────────────────────┘
       │HSEL        │HSEL        │HSEL
       ▼            ▼            ▼
  ┌─────────┐  ┌─────────┐  ┌─────────┐
  │ Slave 0 │  │ Slave 1 │  │ Slave 2 │
  │  (ROM)  │  │ (SRAM)  │  │ (APB桥) │
  └─────────┘  └─────────┘  └─────────┘
```

**工作流程**：Master 请求 → 仲裁器授权 → 发送地址 → 解码器选中 Slave → 数据传输

#### AHB 信号接口

```verilog
// AHB3-Lite 接口定义
interface ahb_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic HCLK,
    input  logic HRESETn
);

    // 全局信号
    logic [ADDR_WIDTH-1:0]  HADDR;      // 地址总线
    logic [1:0]             HTRANS;      // 传输类型
    logic [2:0]             HSIZE;       // 传输大小
    logic [2:0]             HBURST;      // 突发类型
    logic                   HWRITE;      // 读/写
    logic [DATA_WIDTH-1:0]  HWDATA;      // 写数据
    logic [DATA_WIDTH-1:0]  HRDATA;      // 读数据
    logic [1:0]             HRESP;       // 响应
    logic                   HREADY;      // 就绪
    logic                   HSEL;        // 片选

endinterface
```

#### AHB 传输类型

| 类型 | `HTRANS` | 说明 |
|---|---|---|
| **IDLE** | 2'b00 | 空闲，总线占用但无传输 |
| **BUSY** | 2'b01 | 主设备暂时无法传输 |
| **NONSEQ** | 2'b10 | 突发的第一个或单次传输 |
| **SEQ** | 2'b11 | 突发的后续传输 |

#### AHB 突发类型

| 类型 | `HBURST` | 传输次数 | 地址行为 |
|---|---|---|---|
| **SINGLE** | 3'b000 | 1 | - |
| **INCR** | 3'b001 | 任意 | 递增 |
| **WRAP4** | 3'b010 | 4 | 环绕 |
| **INCR4** | 3'b011 | 4 | 递增 |
| **WRAP8** | 3'b100 | 8 | 环绕 |
| **INCR8** | 3'b101 | 8 | 递增 |
| **WRAP16** | 3'b110 | 16 | 环绕 |
| **INCR16** | 3'b111 | 16 | 递增 |

#### AHB 时序

```
AHB 读传输时序:

HCLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
          └──┘  └──┘  └──┘  └──┘  └──┘
         ┌────────────┐
HTRANS   │   NONSEQ   │     SEQ        SEQ
         └────────────┘──────────────────
              │
              ▼
HADDR    ────A0────────A1────────A2────

HREADY   ──────────1───0───1────────────
                     │   │
                     ▼   ▼
HRDATA   ────────────D0──────D1────────
```

#### AHB vs AXI 对比

| 特性 | AHB | AXI |
|---|---|---|
| **流水线** | 无 | 有（地址/数据分离） |
| **并发传输** | 单一 | 多个同时进行 |
| **突发长度** | 最大 16 拍 | 最大 256 拍 |
| **ID 标识** | 无 | 有（支持乱序） |
| **握手信号** | HREADY | valid/ready |
| **复杂度** | 低 | 高 |
| **性能** | 中等 | 高 |
| **典型应用** | 低速外设、桥接 | DDR、高带宽 |

#### AHB-Lite vs 完整 AHB

```
AHB-Lite (单主设备):

  ┌─────────┐
  │ Master  │  (只有 CPU)
  └────┬────┘
       │
       ▼
  ┌─────────────────────────────────────┐
  │           解码器 (Decoder)          │  ← 无需仲裁器
  └─────────────────┬───────────────────┘
       │            │            │
       ▼            ▼            ▼
  ┌─────────┐  ┌─────────┐  ┌─────────┐
  │ Slave 0 │  │ Slave 1 │  │ Slave 2 │
  └─────────┘  └─────────┘  └─────────┘

特点: 无 HBUSREQ/HGRANT，HSEL 直接由地址译码产生
```

```
完整 AHB (多主设备):

  ┌─────────┐  ┌─────────┐  ┌─────────┐
  │ Master 0│  │ Master 1│  │ Master 2│
  │  (CPU)  │  │  (DMA)  │  │  (DSP)  │
  └────┬────┘  └────┬────┘  └────┬────┘
       │HBUSREQ     │HBUSREQ     │HBUSREQ
       ▼            ▼            ▼
  ┌─────────────────────────────────────┐
  │           仲裁器 (Arbiter)          │
  │  ┌─────────────────────────────┐   │
  │  │  输入: HBUSREQ[2:0]         │   │
  │  │  输出: HGRANT[2:0], HMASTLOCK│  │
  │  └─────────────────────────────┘   │
  └─────────────────┬───────────────────┘
                    │ HMASTER[3:0]
                    ▼
  ┌─────────────────────────────────────┐
  │           解码器 (Decoder)          │
  └─────────────────┬───────────────────┘
       │            │            │
       ▼            ▼            ▼
  ┌─────────┐  ┌─────────┐  ┌─────────┐
  │ Slave 0 │  │ Slave 1 │  │ Slave 2 │
  └─────────┘  └─────────┘  └─────────┘

新增信号:
- HBUSREQ[n]: 主设备 n 请求总线
- HGRANT[n]: 仲裁器授权主设备 n
- HMASTER[3:0]: 当前占用总线的主设备编号
- HMASTLOCK: 主设备锁定总线（原子操作）
```

#### AHB 仲裁机制

```
固定优先级仲裁:

  优先级: Master 0 > Master 1 > Master 2

  Master 2 请求 ──┐
  Master 1 请求 ──┤
  Master 0 请求 ──┤
                  ▼
           ┌────────────┐
           │ 固定优先级  │
           │   仲裁器   │
           └──────┬─────┘
                  │
                  ▼
           HGRANT[0] = 1  (M0 有最高优先级，只要请求就获得授权)

特点: 简单但可能饥饿（低优先级主设备永远无法获得总线）
```

```
轮询仲裁 (Round-Robin):

  时钟周期:    T0    T1    T2    T3    T4    T5
  Master 0:   REQ   REQ   REQ   REQ   REQ   REQ
  Master 1:   REQ   REQ   REQ   REQ   REQ   REQ
  Master 2:   REQ   REQ   REQ   REQ   REQ   REQ
  HGRANT:     M0    M1    M2    M0    M1    M2

  授权顺序: M0 → M1 → M2 → M0 → M1 → M2 → ...

特点: 公平，每个主设备轮流获得总线
```

```
AHB 仲裁时序:

HCLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
          └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

HBUSREQ ──────────1─────1─────0─────0─────1─────0
(M0请求)

HBUSREQ ─────1─────1─────1─────1─────1─────1────
(M1请求)

HGRANT  ──────────0─────0─────1─────1─────0─────0
         (M0)   (M0)  (M1)  (M1)  (M0)  (M0)

HTRANS   ─────NONSEQ─SEQ───NONSEQ─SEQ───NONSEQ─SEQ
         M0传输   M0传输  M1传输  M1传输  M0传输
```

#### AHB Split 传输

```
Split 传输原理:

当慢速从设备（如 Flash）无法及时响应时:
1. 从设备通过 HSPLIT 信号请求分离
2. 仲裁器撤销当前主设备授权
3. 仲裁器授权其他主设备访问
4. 慢速从设备完成操作后，通知仲裁器
5. 仲裁器重新授权原主设备

时序:
HCLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
          └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

HTRANS   ─────NONSEQ───────SEQ───────NONSEQ──SEQ──
         M0访问   M0访问   M0访问   M0访问

HREADY   ──────────0────────0────────0──────1────
                    │        │        │
                    ▼        ▼        ▼
HSPLIT   ──────────────────────────1──────────
         (Flash请求分离)

HGRANT   ──────────────────────────1──────────
         (M1 获得授权)

HTRANS(M1) ──────────────────────────NONSEQ────
         (M1 开始访问)

... Flash 完成后 ...

HSPLIT   ─────────────────────────────────────0
HGRANT   ─────────────────────────────────────0
         (M0 重新获得授权)
```

#### AHB 总线保持协议

```
HREADY 协议:

规则:
1. HREADY=1 时，当前数据传输完成
2. HREADY=0 时，从设备插入等待状态
3. 等待期间，地址阶段和数据阶段同时保持

HCLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
          └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

         ┌────────────┐
HTRANS   │   NONSEQ   │     SEQ        SEQ
         └────────────┘────────────────────────

HADDR    ────A0────────A1────────A2────────A3────

HREADY   ──────────1───0───0───1───1───1────
                     │   │
                     ▼   ▼
HRDATA   ────────────D0──────────────D1────D2────
                     (等待)          (完成)

HWDATA   ────────────────W0──────────W1────W2────
         (A1/A0 地址阶段保持)
```

#### AHB 传输大小与对齐

```
HSIZE 编码:

HSIZE[2:0]  传输大小    字节 lanes
─────────────────────────────────
3'b000      8 位 (1字节)  byte[0] 或 byte[1] 或 byte[2] 或 byte[3]
3'b001      16 位 (2字节) halfword[0:1] 或 halfword[2:3]
3'b010      32 位 (4字节) word[0:3]
3'b011      64 位 (8字节) doubleword[0:7]
3'b100      128 位        16 字节
3'b101      256 位        32 字节
3'b110      512 位        64 字节
3'b111      1024 位       128 字节

地址对齐规则:
- 32 位访问: 地址低 2 位必须为 0
- 16 位访问: 地址低 1 位必须为 0
- 8 位访问:  地址任意
```

#### HSEL 与地址解码器详解

```
HSEL 的作用: 根据主设备发出的地址，选中目标从设备

完整流程:
步骤 1: 主设备发出地址
  Master → HADDR = 0x2000_1234

步骤 2: 解码器译码
  ┌─────────────────────────────────┐
  │         地址解码器 (Decoder)     │
  │                                 │
  │  输入: HADDR = 0x2000_1234     │
  │                                 │
  │  规则:                          │
  │  0x0000_xxxx → HSEL_ROM  = 1  │
  │  0x2000_xxxx → HSEL_SRAM = 1  │  ← 匹配这条
  │  0x4000_xxxx → HSEL_APB  = 1  │
  │                                 │
  │  输出: HSEL_SRAM = 1           │
  └─────────────────────────────────┘

步骤 3: SRAM 被选中，开始响应
  HSEL_SRAM = 1 → SRAM 监听总线并响应
  HSEL_ROM  = 0 → ROM 忽略总线
  HSEL_APB  = 0 → APB 忽略总线
```

```verilog
// AHB 地址解码器
module ahb_decoder #(
    parameter ADDR_WIDTH = 32
)(
    input  logic [ADDR_WIDTH-1:0] HADDR,
    output logic                  HSEL_ROM,
    output logic                  HSEL_SRAM,
    output logic                  HSEL_APB
);

    always_comb begin
        HSEL_ROM  = 1'b0;
        HSEL_SRAM = 1'b0;
        HSEL_APB  = 1'b0;

        casez (HADDR[31:16])
            16'h0000: HSEL_ROM  = 1'b1;  // 0x0000_0000 - 0x0000_FFFF
            16'h2000: HSEL_SRAM = 1'b1;  // 0x2000_0000 - 0x2000_FFFF
            16'h4000: HSEL_APB  = 1'b1;  // 0x4000_0000 - 0x4000_FFFF
            default:  begin
                // 无效地址，所有 HSEL 为 0
                // 解码器不选中任何从设备 → 产生 DECERR 响应
            end
        endcase
    end

endmodule
```

```
HSEL 与 HREADY 的关系:

规则: HSEL=0 的从设备必须忽略所有总线信号

HSEL   ───────0────────0────────1────────0────
HTRANS ──NONSEQ──SEQ──NONSEQ──SEQ──
HRDATA ──────────────────D0──────────────
HREADY ──────────────────1──────────────

从设备 0 (HSEL=0): 无响应
从设备 1 (HSEL=0): 无响应
从设备 2 (HSEL=1): 提供数据，HREADY=1 表示完成

如果所有 HSEL 都为 0:
  → 解码器产生 DECERR 响应 (HRESP=2'b11)
  → 主设备收到错误响应
```

```
4GB 地址空间划分示例:

0x0000_0000 ┌──────────────┐
            │   ROM        │ 64KB
0x0000_FFFF ├──────────────┤
            │   (未使用)    │
0x1FFF_FFFF ├──────────────┤
            │   SRAM       │ 256KB
0x2000_FFFF ├──────────────┤
            │   (未使用)    │
0x3FFF_FFFF ├──────────────┤
            │   APB 外设   │ 64KB
0x4000_FFFF ├──────────────┤
            │   ...        │

解码器只需比较高位地址:
  HADDR[31:16] == 16'h0000 → ROM
  HADDR[31:16] == 16'h2000 → SRAM
  HADDR[31:16] == 16'h4000 → APB
```

---

### 1.3 APB 协议

#### APB 架构

```
APB 总线架构:

         AHB / AXI 总线
              │
              ▼
        ┌─────────────┐
        │   APB 桥    │  (协议转换)
        │(APB Master) │
        └──────┬──────┘
               │
    ┌──────────┼──────────┐
    │          │          │
    ▼          ▼          ▼
┌───────┐  ┌───────┐  ┌───────┐
│UART   │  │Timer  │  │GPIO   │
│       │  │       │  │       │
└───────┘  └───────┘  └───────┘
  APB         APB         APB
 Slave       Slave       Slave
```

#### APB 信号接口

```verilog
// APB4 接口定义
interface apb_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic PCLK,
    input  logic PRESETn
);

    logic [ADDR_WIDTH-1:0]  PADDR;      // 地址
    logic                   PSEL;       // 片选
    logic                   PENABLE;    // 使能
    logic                   PWRITE;     // 读/写
    logic [DATA_WIDTH-1:0]  PWDATA;     // 写数据
    logic [DATA_WIDTH-1:0]  PRDATA;     // 读数据
    logic                   PREADY;     // 就绪
    logic                   PSLVERR;    // 错误响应

endinterface
```

#### APB 状态机

```
APB 状态机:

                    ┌─────────┐
          ┌────────│  IDLE   │────────┐
          │        └─────────┘        │
          │             │             │
          │    PSEL=1 & PENABLE=0    │
          │             │             │
          │             ▼             │
          │        ┌─────────┐        │
          └───────│ SETUP   │        │
                  └─────────┘        │
                       │             │
                  PSEL=1 & PENABLE=1 │
                       │             │
                       ▼             │
                  ┌─────────┐        │
                  │ ACCESS  │────────┘
                  └─────────┘
                       │
                  PREADY=1
                       │
                       ▼
                  ┌─────────┐
                  │  IDLE   │
                  └─────────┘
```

#### APB 时序

```
APB 写传输时序:

PCLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
          └──┘  └──┘  └──┘  └──┘
         ┌────┐
PSEL     │    │     ┌────────────┐
         └────┘     │            │
                    │            │
PENABLE ────────────┘            │
                                 │
         ┌────┐     ┌────┐       │
PWRITE   │    │     │    │       │
         └────┘     └────┘       │
              │       │          │
              ▼       ▼          │
PWDATA  ────D0──────D0──────────

              │                  │
              ▼                  ▼
PREADY  ──────────────0────────1─
```

#### APB4 信号定义

| 信号 | 方向 | 说明 |
|---|---|---|
| `PADDR[31:0]` | Master→Slave | 地址总线 |
| `PSEL` | Master→Slave | 从设备片选 |
| `PENABLE` | Master→Slave | 传输使能 |
| `PWRITE` | Master→Slave | 0=读，1=写 |
| `PWDATA[31:0]` | Master→Slave | 写数据 |
| `PRDATA[31:0]` | Slave→Master | 读数据 |
| `PREADY` | Slave→Master | 传输完成 |
| `PSLVERR` | Slave→Master | 错误响应 |

#### APB 应用场景

| 设备类型 | 说明 | 示例 |
|---|---|---|
| **UART** | 串口通信 | 波特率配置、数据收发 |
| **SPI** | 同步串行 | 时钟分频、模式设置 |
| **I2C** | 双线串行 | 地址配置、数据传输 |
| **Timer** | 定时器 | 计数值、中断使能 |
| **GPIO** | 通用IO | 方向、数据、中断 |
| **Watchdog** | 看门狗 | 超时值、喂狗 |

#### APB 版本演进

| 特性 | APB2 | APB3 | APB4 |
|------|------|------|------|
| **PREADY** | ❌ | ✅ | ✅ |
| **PSLVERR** | ❌ | ✅ | ✅ |
| **PSTRB** | ❌ | ❌ | ✅ |
| **PPROT** | ❌ | ❌ | ✅ |
| **适用场景** | 简单外设 | 中速外设 | 安全/高性能外设 |

#### APB3 PREADY 详解

```
APB3 传输（PREADY=1，无等待）:

PCLK    ──┐  ┌──┐  ┌──┐  ┌──┐
          └──┘  └──┘  └──┘  └──┘
         ┌────┐
PSEL     │    │
         └────┘
              ┌────┐
PENABLE       │    │
              └────┘
              │    │
PREADY  ──────1────1────

传输在 SETUP 阶段后 1 个周期完成
```

```
APB3 传输（PREADY=0，插入等待）:

PCLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐
          └──┘  └──┘  └──┘  └──┘  └──┘  └──┘
         ┌────┐
PSEL     │    │
         └────┘
              ┌────────────────┐
PENABLE       │                │
              └────────────────┘
              │                │
PREADY  ──────0────────────────1────

PENABLE 保持高，直到 PREADY 为高
从设备可在任意周期拉低 PREADY 插入等待
```

#### APB4 PSTRB 字节选通

```
APB4 PSTRB 规则:
- PSTRB[n] = 1 表示 PWDATA 的第 n 字节有效
- PSTRB 全为 1 时等同于 APB3（全字节写入）
- PSTRB 部分为 0 时进行子字节写入

32 位总线示例:
PSTRB[3:0] = 4'b1111 → 写全部 4 字节
PSTRB[3:0] = 4'b0001 → 只写最低字节
PSTRB[3:0] = 4'b0011 → 写低 2 字节
PSTRB[3:0] = 4'b1100 → 写高 2 字节
```

#### APB 桥设计

```
AHB/APB 桥接状态机:

               ┌─────────┐
     ┌─────────│  IDLE   │─────────┐
     │         └─────────┘         │
     │              │              │
     │        HTRANS!=IDLE         │
     │              │              │
     │              ▼              │
     │         ┌─────────┐         │
     │         │  SETUP  │         │
     │         │ PSEL=1  │         │
     │         │ PENABLE=0         │
     │         └────┬────┘         │
     │              │              │
     │         下一个时钟沿         │
     │              │              │
     │              ▼              │
     │         ┌─────────┐         │
     └─────────│ ACCESS  │         │
               │ PENABLE=1         │
               └────┬────┘         │
                    │              │
                PREADY=1           │
                    │              │
                    ▼              │
               ┌─────────┐         │
               │  DONE   │ ────────┘
               │ HREADY=1│
               └─────────┘

关键点:
- SETUP 阶段: PSEL=1, PENABLE=0, 地址/数据建立
- ACCESS 阶段: PENABLE=1, 等待 PREADY
- 从设备慢速时，PREADY 保持低，PENABLE 保持高
```

#### APB 多从设备译码

```
APB 地址译码示例:

地址范围          PSEL 信号
────────────────────────────
0x0000_0000-0x0000_0FFF  PSEL_UART = 1
0x0000_1000-0x0000_1FFF  PSEL_SPI  = 1
0x0000_2000-0x0000_2FFF  PSEL_I2C  = 1
0x0000_3000-0x0000_3FFF  PSEL_GPIO = 1

译码逻辑:
PSEL_UART = (PADDR[15:12] == 4'h0);
PSEL_SPI  = (PADDR[15:12] == 4'h1);
PSEL_I2C  = (PADDR[15:12] == 4'h2);
PSEL_GPIO = (PADDR[15:12] == 4'h3);
```

#### UART 外设详解

```
UART (Universal Asynchronous Receiver/Transmitter)
通用异步收发器 —— 最常见的 APB 外设之一

核心功能:
┌─────────────────────────────────────────────────────┐
│                     UART 模块                       │
│                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐      │
│  │ 发送器   │    │ 接收器    │    │ 波特率   │      │
│  │ (TX)     │    │ (RX)     │    │ 发生器   │      │
│  │          │    │          │    │          │      │
│  │ 并行→串行│     │ 串行→并行│    │ 分频时钟  │      │
│  └────┬─────┘    └────┬─────┘    └──────────┘      │
│       │               │                             │
│  ┌────┴─────┐    ┌────┴─────┐                      │
│  │ TX FIFO  │    │ RX FIFO  │  ← 缓冲数据          │
│  └──────────┘    └──────────┘                      │
│                                                     │
│  ┌──────────┐    ┌──────────┐                      │
│  │ 状态寄存 │    │ 控制寄存 │  ← APB 接口          │
│  └──────────┘    └──────────┘                      │
└─────────────────────────────────────────────────────┘
          │                    │
          ▼                    ▼
       TX 引脚              RX 引脚
    (发送到 PC)          (从 PC 接收)
```

```
UART 数据帧格式:

空闲(IDLE)  起始位  D0  D1  D2  D3  D4  D5  D6  D7  停止位  空闲
  ─────┐    ┌───┐ ┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌─────┐──────
       │    │   │ │   ││   ││   ││   ││   ││   ││   ││     │
       └────┘   └─┘   └┘   └┘   └┘   └┘   └┘   └┘   └┘     └──────
            1bit  1bit←── 8 bits data ──→  1bit
                   (可选: 校验位)

波特率 = 每秒传输的比特数
  9600 bps  → 每 bit 约 104 us (慢速设备)
  115200 bps → 每 bit 约 8.7 us (常用)
```

```
UART 在 SoC 中的位置:

  CPU
   │ (AXI/AHB 总线)
   ▼
  ┌─────────────────────────────────┐
  │           APB 总线              │
  └──┬────────┬────────┬────────┬───┘
     │        │        │        │
     ▼        ▼        ▼        ▼
  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
  │ UART │ │ SPI  │ │ I2C  │ │ GPIO │
  │      │ │      │ │      │ │      │
  └──┬───┘ └──────┘ └──────┘ └──────┘
     │ TX/RX
     ▼
  外部设备 (PC/传感器)

UART 寄存器映射示例:
  0x1000_0000 + 0x00 = 数据寄存器 (读/写)
  0x1000_0000 + 0x04 = 状态寄存器 (只读)
  0x1000_0000 + 0x08 = 控制寄存器 (读/写)
  0x1000_0000 + 0x0C = 波特率寄存器 (读/写)
```

```verilog
// UART 发送器简化模块
module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0] tx_data,
    input  logic tx_valid,
    output logic tx_ready,
    output logic tx_pin
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    typedef enum logic [1:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    } state_t;

    state_t state;
    logic [8:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx_pin <= 1'b1; // 空闲高电平
        end else begin
            case (state)
                IDLE: begin
                    tx_pin <= 1'b1;
                    if (tx_valid) begin
                        state <= START_BIT;
                        shift_reg <= tx_data;
                        clk_count <= 0;
                    end
                end
                START_BIT: begin
                    tx_pin <= 1'b0; // 起始位 = 0
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        state <= DATA_BITS;
                        clk_count <= 0;
                        bit_index <= 0;
                    end else
                        clk_count <= clk_count + 1;
                end
                DATA_BITS: begin
                    tx_pin <= shift_reg[bit_index];
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        if (bit_index == 7)
                            state <= STOP_BIT;
                        else
                            bit_index <= bit_index + 1;
                    end else
                        clk_count <= clk_count + 1;
                end
                STOP_BIT: begin
                    tx_pin <= 1'b1; // 停止位 = 1
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        state <= IDLE;
                        tx_ready <= 1'b1;
                    end else
                        clk_count <= clk_count + 1;
                end
            endcase
        end
    end

endmodule
```

---

### 1.4 ACE 协议 (AXI Coherency Extensions)

#### 缓存一致性问题

```
多核缓存一致性问题:

┌─────────────┐    ┌─────────────┐
│   CPU 0     │    │   CPU 1     │
│ ┌─────────┐ │    │ ┌─────────┐ │
│ │ L1 Cache│ │    │ │ L1 Cache│ │
│ │  addr=0x100   │ │ │  addr=0x100   │
│ │  data=0x5│ │    │ │  data=0x3│ │
│ └─────────┘ │    │ └─────────┘ │
└─────────────┘    └─────────────┘
        │                │
        ▼                ▼
┌─────────────────────────────────┐
│           Main Memory           │
│         addr=0x100 = 0x5        │
└─────────────────────────────────┘

问题: CPU1 的缓存中是旧值 0x3，但内存和 CPU0 是 0x5
```

#### ACE 架构

```
ACE 缓存一致性架构:

┌─────────┐  ┌─────────┐  ┌─────────┐
│ CPU 0   │  │ CPU 1   │  │ CPU 2   │
│ AXI+SNP │  │ AXI+SNP │  │ AXI+SNP │
└────┬────┘  └────┬────┘  └────┬────┘
     │            │            │
     ▼            ▼            ▼
┌─────────────────────────────────────┐
│      ACE Interconnect               │
│  ┌─────────────────────────────┐    │
│  │    Snoop Control Unit       │    │
│  │    (监听控制单元)            │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
                    │
                    ▼
              ┌───────────┐
              │   DDR     │
              │ Controller│
              └───────────┘
```

#### ACE 监听协议

| 监听请求 | 说明 | 响应 |
|---|---|---|
| **ReadOnce** | 读取，不分配 | ReadDone |
| **ReadShared** | 读取，可能共享 | ReadDone (Shared) |
| **ReadUnique** | 读取，独占 | ReadDone (Unique) |
| **CleanShared** | 清理共享副本 | CleanDone |
| **CleanInvalid** | 清理并无效化 | CleanDone |
| **MakeUnique** | 变为独占 | MakeDone |

#### MOESI 状态

| 状态 | 含义 | 可写 | 数据有效 |
|---|---|---|---|
| **M** (Modified) | 已修改 | ✅ | ✅ |
| **O** (Owned) | 拥有 | ❌ | ✅ |
| **E** (Exclusive) | 独占 | ✅ | ✅ |
| **S** (Shared) | 共享 | ❌ | ✅ |
| **I** (Invalid) | 无效 | ❌ | ❌ |

---

## 2. 总线互联拓扑

### 2.1 共享总线（Shared Bus）

```
共享总线架构:

  ┌─────────┐  ┌─────────┐  ┌─────────┐
  │ Master 0│  │ Master 1│  │ Master 2│
  └────┬────┘  └────┬────┘  └────┬────┘
       │            │            │
       ▼            ▼            ▼
  ┌─────────────────────────────────────┐
  │           仲裁器 (Arbiter)          │
  │  ┌─────────────────────────────┐   │
  │  │    选择一个 Master 接入总线    │   │
  │  └─────────────────────────────┘   │
  └─────────────────┬───────────────────┘
                    │
       ┌────────────┼────────────┐
       │            │            │
       ▼            ▼            ▼
  ┌─────────┐  ┌─────────┐  ┌─────────┐
  │ Slave 0 │  │ Slave 1 │  │ Slave 2 │
  └─────────┘  └─────────┘  └─────────┘

特点: 同一时刻只有一个 Master 可以访问一个 Slave
```

| 优点 | 缺点 |
|------|------|
| 面积小、设计简单 | 带宽受限于单条总线 |
| 仲裁逻辑简单 | 多 Master 竞争时延迟大 |
| 适用于低速外设 | 无法并行访问 |

### 2.2 多层总线（Multilayer Bus）

```
多层总线架构 (Layered Interconnect):

  ┌─────────┐  ┌─────────┐  ┌─────────┐
  │ Master 0│  │ Master 1│  │ Master 2│
  │  (CPU)  │  │  (DMA)  │  │  (GPU)  │
  └────┬────┘  └────┬────┘  └────┬────┘
       │            │            │
       ▼            ▼            ▼
  ┌─────────────────────────────────────────┐
  │          多层互联矩阵 (Multilayer)       │
  │                                         │
  │  Layer 0: M0 ──────→ Slave 0 (DDR)     │
  │  Layer 1: M1 ──────→ Slave 1 (SRAM)    │
  │  Layer 2: M2 ──────→ Slave 2 (APB)     │
  │                                         │
  │  ┌─────────────────────────────────┐   │
  │  │    跨层访问需要仲裁/开关切换      │   │
  │  └─────────────────────────────────┘   │
  └─────────────────────────────────────────┘

特点: 多个 Master 可同时访问不同 Slave
```

| 优点 | 缺点 |
|------|------|
| 支持并行访问 | 面积随 Master/Slave 数量增长 |
| 高带宽 | 跨层访问仍需仲裁 |
| 适用于中等规模 SoC | 设计复杂度中等 |

### 2.3 交叉开关互联（Crossbar）

```
全交叉开关 (Full Crossbar) 3×3:

            Slave 0    Slave 1    Slave 2
              │          │          │
Master 0 ─────┼──────────┼──────────┤
              │          │          │
Master 1 ─────┼──────────┼──────────┤
              │          │          │
Master 2 ─────┼──────────┼──────────┤

每个交叉点有一个开关，任意 Master 可连接任意 Slave
支持 3 个 Master 同时访问 3 个不同的 Slave
```

```
稀疏交叉开关 (Sparse Crossbar):

            Slave 0    Slave 1    Slave 2
              │          │          │
Master 0 ─────●──────────●──────────○    ← M0 不能访问 S2
              │          │          │
Master 1 ─────○──────────●──────────●    ← M1 不能访问 S0
              │          │          │
Master 2 ─────●──────────○──────────●    ← M2 不能访问 S1

● = 连接   ○ = 无连接
根据实际访问需求减少开关数量，节省面积
```

#### 交叉开关仲裁

```
交叉开关仲裁示例 (Round-Robin):

Master 0 和 Master 1 同时请求访问 Slave 0:

时钟周期:    T0    T1    T2    T3    T4
Master 0:   REQ───REQ───REQ───GNT───
Master 1:   REQ───REQ───GNT───REQ───
Slave 0:    M0→S0 M0→S0 M1→S0 M0→S0

仲裁器轮询分配，两个 Master 交替访问
```

#### 仲裁器（Arbiter）详解

```
仲裁器的作用: 当多个主设备同时请求总线时，决定谁获得访问权

问题:
  ┌─────────┐  ┌─────────┐  ┌─────────┐
  │ CPU     │  │ DMA     │  │ GPU     │
  │ REQ─────┤  │ REQ─────┤  │ REQ─────┤
  └────┬────┘  └────┬────┘  └────┬────┘
       │            │            │
       ▼            ▼            ▼
  ┌─────────────────────────────────────┐
  │           仲裁器 (Arbiter)          │ ← 决定谁赢
  └─────────────────┬───────────────────┘
                    │ GNT (授权)
                    ▼
              ┌──────────┐
              │ 共享总线  │
              └──────────┘

没有仲裁器 → 两个主设备同时驱动总线 → 总线冲突/数据损坏
```

```
仲裁算法对比:

┌─────────────┬───────────────────┬──────────────┬──────────────┐
│    算法     │       原理        │     优点     │     缺点     │
├─────────────┼───────────────────┼──────────────┼──────────────┤
│ 固定优先级  │ 编号越小优先级越高│ 简单、确定性 │ 低优先级饥饿 │
├─────────────┼───────────────────┼──────────────┼──────────────┤
│ 轮询        │ 每次授权后切换    │ 公平         │ 无优先级区分 │
│(Round-Robin)│ 到下一个主设备    │              │              │
├─────────────┼───────────────────┼──────────────┼──────────────┤
│ TDMA        │ 按时间片分配      │ 硬实时保证   │ 灵活性差     │
├─────────────┼───────────────────┼──────────────┼──────────────┤
│ QoS 加权    │ 按优先级值加权    │ 兼顾公平与   │ 复杂度较高   │
│             │ 轮询              │ 优先级       │              │
└─────────────┴───────────────────┴──────────────┴──────────────┘
```

```
固定优先级仲裁时序 (CPU 优先级 > DMA):

CLK      ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
          └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

CPU_REQ  ──────1─────1─────1─────0─────1─────0
DMA_REQ  ──────1─────1─────1─────1─────1─────1

CPU_GNT  ──────1─────1─────1─────0─────1─────0
DMA_GNT  ──────0─────0─────0─────1─────0─────1

         M0占用  M0占用  M0占用  M1占用  M0占用  M1占用
                   (CPU 释放后 DMA 才能获得总线)
```

```
轮询仲裁时序 (Round-Robin):

CLK      ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
          └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

CPU_REQ  ──────1─────1─────1─────1─────1─────1
DMA_REQ  ──────1─────1─────1─────1─────1─────1

CPU_GNT  ──────1─────0─────1─────0─────1─────0
DMA_GNT  ──────0─────1─────0─────1─────0─────1

         M0占用  M1占用  M0占用  M1占用  M0占用  M1占用
         (轮流授权，即使 CPU 一直请求)
```

```verilog
// 固定优先级仲裁器
module fixed_priority_arbiter #(
    parameter NUM_MASTER = 4
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [NUM_MASTER-1:0] req,
    output logic [NUM_MASTER-1:0] gnt
);

    always_comb begin
        gnt = '0;
        for (int i = NUM_MASTER - 1; i >= 0; i--) begin
            if (req[i]) begin
                gnt[i] = 1'b1;
                break; // 最高优先级的获胜
            end
        end
    end

endmodule

// 轮询仲裁器
module round_robin_arbiter #(
    parameter NUM_MASTER = 4
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [NUM_MASTER-1:0] req,
    output logic [NUM_MASTER-1:0] gnt
);

    logic [NUM_MASTER-1:0] mask; // 优先级掩码
    logic [NUM_MASTER-1:0] masked_req;
    logic [NUM_MASTER-1:0] masked_gnt;
    logic [NUM_MASTER-1:0] unmasked_gnt;

    always_comb begin
        masked_req = req & mask;
        // 带掩码的优先级仲裁
        masked_gnt = '0;
        for (int i = NUM_MASTER - 1; i >= 0; i--) begin
            if (masked_req[i]) begin
                masked_gnt[i] = 1'b1;
                break;
            end
        end
        // 无掩码的优先级仲裁（回绕）
        unmasked_gnt = '0;
        for (int i = NUM_MASTER - 1; i >= 0; i--) begin
            if (req[i]) begin
                unmasked_gnt[i] = 1'b1;
                break;
            end
        end
        // 选择: 如果带掩码有结果则用，否则回绕
        gnt = (|masked_gnt) ? masked_gnt : unmasked_gnt;
    end

    // 更新掩码: 下次从授权位的下一位开始
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mask <= {NUM_MASTER{1'b1}};
        else if (|gnt)
            mask <= ~((gnt << 1) - 1); // 掩码更新
    end

endmodule
```

#### MUX 在交叉开关中的应用

```
交叉开关本质: 仲裁器 + MUX 的组合

仲裁器决定"谁赢" → MUX 选择"赢家的数据"输出

  Master 0 数据 ────┐
                    │
  Master 1 数据 ────┤── MUX ──→ Slave 0 数据
                    │
  Master 2 数据 ────┤
                    │
  SELECT[2:0] ──────┘ (来自仲裁器)

仲裁器输出 SELECT 值 → MUX 选择对应的 Master 数据
```

```
3×3 交叉开关内部结构:

          M0        M1        M2
          │         │         │
          ▼         ▼         ▼
       ┌──────┐ ┌──────┐ ┌──────┐
       │ ARB0 │ │ ARB1 │ │ ARB2 │  ← 每个 Slave 端口有仲裁器
       └──┬───┘ └──┬───┘ └──┬───┘
          │        │        │
     ┌────┴────┬───┴────┬───┴────┐
     │         │        │        │
     ▼         ▼        ▼        ▼
  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
  │MUX_00│ │MUX_10│ │MUX_20│ │ ...  │  ← 每个输出端口有 MUX
  │MUX_01│ │MUX_11│ │MUX_21│ │      │
  │MUX_02│ │MUX_12│ │MUX_22│ │      │
  └──────┘ └──────┘ └──────┘ └──────┘
     │         │        │
     ▼         ▼        ▼
   S0(DDR)  S1(SRAM)  S2(APB)

每个 MUX_ij 选择: Master 0/1/2 中哪个的数据送到 Slave j
```

```
MUX vs 三态门:

┌────────┬──────────────────┬──────────────────────┐
│  方式  │      结构        │        特点          │
├────────┼──────────────────┼──────────────────────┤
│  MUX   │ 组合逻辑选择     │ 面积大，适合片上     │
├────────┼──────────────────┼──────────────────────┤
│ 三态门 │ 多驱动挂总线     │ 面积小，适合片外/板级│
└────────┴──────────────────┴──────────────────────┘

片上 SoC 互联几乎全部使用 MUX
原因: 三态总线在芯片内部有信号完整性问题
```

```verilog
// 3:1 MUX (交叉开关中的单个开关)
module crossbar_mux #(
    parameter DATA_WIDTH = 32
)(
    input  logic [DATA_WIDTH-1:0] din_0,  // Master 0
    input  logic [DATA_WIDTH-1:0] din_1,  // Master 1
    input  logic [DATA_WIDTH-1:0] din_2,  // Master 2
    input  logic [1:0]            sel,    // 仲裁器选择
    output logic [DATA_WIDTH-1:0] dout    // 到 Slave
);

    always_comb begin
        case (sel)
            2'b00:  dout = din_0;
            2'b01:  dout = din_1;
            2'b10:  dout = din_2;
            default: dout = '0; // 无授权时输出 0
        endcase
    end

endmodule
```

### 2.4 互联拓扑对比

| 拓扑 | 并行度 | 面积 | 延迟 | 适用场景 |
|------|--------|------|------|---------|
| **共享总线** | 无 | 极小 | 高 | 低速外设（APB） |
| **多层总线** | 中等 | 中等 | 中 | 中速外设（AHB） |
| **全交叉开关** | 高 | 大 | 低 | 高性能核心（AXI） |
| **稀疏交叉开关** | 中高 | 中 | 低 | 按需连接 |

### 2.5 带宽与延迟分析

```
带宽计算:

共享总线 (APB, 32位, 100MHz):
  带宽 = 32bit × 100MHz = 3.2 Gbps (理论最大)
  实际: 由于仲裁开销，约 1.6-2.4 Gbps

多层总线 (AHB, 32位, 200MHz):
  带宽 = 32bit × 200MHz × N (N为可并行层数)
  实际: 2-3 层时约 6.4-9.6 Gbps

交叉开关 (AXI4, 64位, 500MHz):
  带宽 = 64bit × 500MHz × min(M, S)
  3M × 3S 时理论最大: 96 Gbps
  实际: 约 48-72 Gbps (考虑仲裁和流水线开销)
```

```
延迟分析:

APB:   SETUP(1周期) + ACCESS(1+N周期) = 2+N 周期
       N 为 PREADY 等待周期数

AHB:   地址阶段(1周期) + 数据阶段(1+N周期) = 2+N 周期
       流水线: 连续传输时每笔 1 周期（理想情况）

AXI4:  Outstanding 模式:
       发送地址: 1 周期
       数据响应: 取决于从设备延迟
       关键优势: 多笔事务可同时进行
```

---

## 3. 协议桥接

### 3.1 AXI→AHB 桥

```
AXI→AHB 桥接原理:

AXI Master                  AXI→AHB 桥                  AHB Slave
    │                          │                           │
    │  AW (地址+控制)          │                           │
    │─────────────────────────>│                           │
    │                          │  HADDR/HTRANS/HWRITE     │
    │                          │──────────────────────────>│
    │                          │                           │
    │  W (数据)               │  HWDATA                   │
    │─────────────────────────>│──────────────────────────>│
    │                          │                           │
    │                          │  HRDATA/HRESP/HREADY     │
    │                          │<──────────────────────────│
    │  B (响应)               │                           │
    │<─────────────────────────│                           │

关键转换:
- AXI burst → AHB 单拍 (逐拍发送)
- AXI valid/ready → AHB HREADY
- AXI ID → 透传（如果 AHB 支持）
- AXI WRAP → AHB 需要特殊处理（地址重映射）
```

```verilog
// AXI→AHB 桥简化状态机
module axi_to_ahb_bridge #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic aclk,
    input  logic aresetn,
    // AXI Slave Interface
    axi4_if.slave  s_axi,
    // AHB Master Interface
    ahb_if.master  m_ahb
);

    typedef enum logic [2:0] {
        IDLE,
        ADDR_PHASE,
        DATA_PHASE,
        WRITE_DATA,
        READ_RESP
    } state_t;

    state_t state;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state <= IDLE;
            m_ahb.HTRANS <= 2'b00; // IDLE
        end else begin
            case (state)
                IDLE: begin
                    if (s_axi.awvalid || s_axi.arvalid) begin
                        state <= ADDR_PHASE;
                        m_ahb.HTRANS <= 2'b10; // NONSEQ
                        m_ahb.HADDR <= s_axi.awvalid ? s_axi.awaddr : s_axi.araddr;
                        m_ahb.HWRITE <= s_axi.awvalid;
                    end
                end

                ADDR_PHASE: begin
                    if (m_ahb.HREADY) begin
                        if (m_ahb.HWRITE) begin
                            state <= WRITE_DATA;
                            m_ahb.HWDATA <= s_axi.wdata;
                            s_axi.awready <= 1'b1;
                        end else begin
                            state <= READ_RESP;
                        end
                    end
                end

                WRITE_DATA: begin
                    if (m_ahb.HREADY) begin
                        s_axi.wready <= 1'b1;
                        s_axi.bvalid <= 1'b1;
                        s_axi.bresp <= m_ahb.HRESP ? 2'b10 : 2'b00;
                        state <= IDLE;
                    end
                end

                READ_RESP: begin
                    if (m_ahb.HREADY) begin
                        s_axi.rdata <= m_ahb.HRDATA;
                        s_axi.rvalid <= 1'b1;
                        s_axi.rresp <= m_ahb.HRESP ? 2'b10 : 2'b00;
                        s_axi.rlast <= 1'b1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
```

### 3.2 AXI→APB 桥

```
AXI→APB 桥接原理 (适用于 AXI4-Lite):

AXI4-Lite Master             AXI→APB 桥                  APB Slave
    │                          │                           │
    │  AW (写地址)             │                           │
    │─────────────────────────>│                           │
    │                          │  PADDR/PWRITE            │
    │                          │──────────────────────────>│
    │                          │                           │
    │  W (写数据)              │  PWDATA/PSEL             │
    │─────────────────────────>│──────────────────────────>│
    │                          │                           │
    │                          │  PENABLE (下一周期)       │
    │                          │──────────────────────────>│
    │                          │                           │
    │                          │  PRDATA/PREADY/PSLVERR   │
    │                          │<──────────────────────────│
    │  B (写响应)              │                           │
    │<─────────────────────────│                           │

时序对应:
AXI: AW valid → AW ready → W valid → W ready → B valid → B ready
APB: PSEL(SETUP) → PENABLE(ACCESS) → PREADY → 完成
```

### 3.3 AHB→APB 桥

```
AHB→APB 桥接原理:

AHB Master                  AHB→APB 桥                  APB Slave
    │                          │                           │
    │  HADDR/HTRANS/HWRITE    │                           │
    │─────────────────────────>│                           │
    │                          │  PADDR/PWRITE/PSEL       │
    │                          │──────────────────────────>│
    │                          │                           │
    │                          │  PENABLE (下一周期)       │
    │                          │──────────────────────────>│
    │                          │                           │
    │  HREADY                  │  PRDATA/PREADY/PSLVERR   │
    │<─────────────────────────│<──────────────────────────│
    │  HRDATA                  │                           │

状态机:
┌──────┐  HTRANS!=IDLE   ┌────────┐  PSEL=1   ┌────────┐
│ IDLE │────────────────>│ SETUP  │──────────>│ ACCESS │
└──────┘                 └────────┘           └────────┘
                            ▲                     │
                            │     PREADY=1        │
                            └─────────────────────┘
```

```verilog
// AHB→APB 桥简化状态机
module ahb_to_apb_bridge #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic HCLK,
    input  logic HRESETn,
    // AHB Slave Interface
    ahb_if.slave  s_ahb,
    // APB Master Interface
    apb_if.master m_apb
);

    typedef enum logic {
        SETUP,
        ACCESS
    } state_t;

    state_t state;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state <= SETUP;
            m_apb.PSEL <= 1'b0;
            m_apb.PENABLE <= 1'b0;
            s_ahb.HREADY <= 1'b1;
        end else begin
            case (state)
                SETUP: begin
                    if (s_ahb.HTRANS != 2'b00) begin // 非 IDLE
                        m_apb.PADDR <= s_ahb.HADDR;
                        m_apb.PWRITE <= s_ahb.HWRITE;
                        m_apb.PSEL <= 1'b1;
                        m_apb.PWDATA <= s_ahb.HWDATA;
                        s_ahb.HREADY <= 1'b0; // 插入等待
                        state <= ACCESS;
                    end
                end

                ACCESS: begin
                    m_apb.PENABLE <= 1'b1;
                    if (m_apb.PREADY) begin
                        m_apb.PENABLE <= 1'b0;
                        m_apb.PSEL <= 1'b0;
                        s_ahb.HREADY <= 1'b1;
                        s_ahb.HRDATA <= m_apb.PRDATA;
                        s_ahb.HRESP <= m_apb.PSLVERR ? 2'b01 : 2'b00;
                        state <= SETUP;
                    end
                end
            endcase
        end
    end

endmodule
```

### 3.4 桥接设计要点

| 要点 | 说明 |
|------|------|
| **时钟域** | AXI 高频 → APB 低频，需同步器 |
| **数据宽度** | AXI 64位 → APB 32位，需分两次传输 |
| **突发处理** | AXI burst → AHB/APB 单拍，逐拍转换 |
| **ID 透传** | AHB 无 ID，需缓存 AXI ID 并在响应时匹配 |
| **错误传播** | AHB HRESP/SPLIT → AXI SLVERR |
| **独占访问** | AXI LOCK → AHB HLOCK（需仲裁器配合） |

---

## 4. NoC (Network on Chip)

### NoC 概述

**NoC (Network on Chip)** 是片上网络，将计算机网络的概念引入芯片设计，用于超大规模 SoC 中模块间的通信。

### NoC vs 传统总线

```
传统总线 vs NoC:

传统总线 (共享):
┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
│ M0  │ │ M1  │ │ M2  │ │ M3  │
└──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘
   │       │       │       │
   └───────┴───┬───┴───────┘
               │
        ┌──────┴──────┐
        │  共享总线    │  ← 带宽受限，仲裁延迟
        └─────────────┘

NoC (包交换):
┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
│ N0  │─│ N1  │─│ N2  │─│ N3  │
└─────┘ └─────┘ └─────┘ └─────┘
   │       │       │       │
┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
│ M0  │ │ M1  │ │ M2  │ │ M3  │
└─────┘ └─────┘ └─────┘ └─────┘

每个节点(N)有路由器，支持并发通信
```

### NoC 架构

```
2D Mesh NoC 架构:

┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐
│ R00 │───│ R01 │───│ R02 │───│ R03 │
└──┬──┘   └──┬──┘   └──┬──┘   └──┬──┘
   │         │         │         │
┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐
│ R10 │───│ R11 │───│ R12 │───│ R13 │
└──┬──┘   └──┬──┘   └──┬──┘   └──┬──┘
   │         │         │         │
┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐
│ R20 │───│ R21 │───│ R22 │───│ R23 │
└──┬──┘   └──┬──┘   └──┬──┘   └──┬──┘
   │         │         │         │
┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐
│ R30 │───│ R31 │───│ R32 │───│ R33 │
└─────┘   └─────┘   └─────┘   └─────┘

R = 路由器 (Router)
每个路由器连接一个 IP 核 (CPU/GPU/Memory)
```

### NoC 路由器微架构

```
NoC 路由器内部:

                    ┌─────────────────┐
        北输入 ────>│                 │────> 北输出
                    │   ┌─────────┐   │
        南输入 ────>│   │  交叉   │   │────> 南输出
                    │   │  开关   │   │
        东输入 ────>│   │ (Cross  │   │────> 东输出
                    │   │  bar)   │   │
        西输入 ────>│   └─────────┘   │────> 西输出
                    │        │        │
                    │   ┌────┴────┐   │
                    │   │ 路由    │   │
                    │   │ 计算    │   │
                    │   │ + 缓冲  │   │
                    │   └─────────┘   │
                    └─────────────────┘
```

### NoC 路由算法

| 算法 | 说明 | 特点 |
|---|---|---|
| **XY Routing** | 先 X 方向，再 Y 方向 | 简单，无死锁 |
| **Odd-Even** | 基于奇偶列的路由 | 避免死锁 |
| **West-First** | 优先向西 | 低延迟 |
| **Adaptive** | 根据拥塞自适应 | 高吞吐 |

### NoC 流控机制

| 机制 | 说明 | 优点 | 缺点 |
|---|---|---|---|
| **Store-and-Forward** | 存储转发 | 完整包接收 | 延迟高 |
| **Cut-Through** | 直通 | 低延迟 | 需要大缓冲 |
| **Wormhole** | 虫孔 | 低延迟、小缓冲 | 可能阻塞 |
| **Virtual Channel** | 虚拟通道 | 避免死锁 | 复杂度高 |

---

## 5. 总线协议对比总结

### 性能对比

| 协议 | 最大数据带宽 | 延迟 | 复杂度 | 适用场景 |
|---|---|---|---|---|
| **AXI4** | 极高 | 低 | 高 | 高性能 SoC |
| **AXI4-Lite** | 中等 | 低 | 中 | 寄存器配置 |
| **AHB** | 中等 | 中 | 低 | 中速外设 |
| **APB** | 低 | 高 | 极低 | 低速外设 |
| **NoC** | 极高 | 中 | 高 | 大规模 SoC |

### 选择指南

```
选择总线协议的决策树:

需要高性能?
├── 是 → AXI4 / NoC
│        ├── 大规模 SoC (>100 IP)? → NoC
│        └── 中小规模 SoC → AXI4
│
└── 否 → 需要低功耗?
         ├── 是 → APB / AXI4-Lite
         └── 否 → 需要开源?
└── 否 → 看平台
                            └── ARM → AMBA (AXI/AHB/APB)
```

### 典型 SoC 总线架构

```
现代 SoC 总线层次:

┌─────────────────────────────────────────────────────────────┐
│                        高速域                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   CPU Cluster          GPU           Video Codec            │
│   ┌─────┐            ┌─────┐         ┌─────┐              │
│   │CPU 0│            │     │         │     │              │
│   │CPU 1│─────AXI────│ GPU │────AXI──│ VPU │              │
│   │CPU 2│            │     │         │     │              │
│   └─────┘            └─────┘         └─────┘              │
│        │                 │                 │                │
│        └─────────────────┼─────────────────┘                │
│                          │                                  │
│              ┌───────────┴───────────┐                      │
│              │     AXI 互联矩阵      │                      │
│              │   (Bandwidth Filter)  │                      │
│              └───────────┬───────────┘                      │
│                          │                                  │
├──────────────────────────┼──────────────────────────────────┤
│                          │        中速域                    │
│              ┌───────────┴───────────┐                      │
│              │       AHB 总线        │                      │
│              └───────────┬───────────┘                      │
│                          │                                  │
│         ┌────────────────┼────────────────┐                 │
│         │                │                │                 │
│    ┌────┴────┐      ┌────┴────┐      ┌────┴────┐           │
│    │  DMA    │      │  USB    │      │ Ethernet│           │
│    └─────────┘      └─────────┘      └─────────┘           │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                          │        低速域                    │
│              ┌───────────┴───────────┐                      │
│              │       APB 总线        │                      │
│              └───────────┬───────────┘                      │
│                          │                                  │
│    ┌─────────┬───────────┼───────────┬─────────┐            │
│    │         │           │           │         │            │
│  ┌─┴─┐   ┌──┴──┐    ┌───┴───┐   ┌───┴───┐ ┌───┴───┐       │
│  │UAR│   │ SPI │    │  I2C  │   │Timer │ │ GPIO │       │
│  └───┘   └─────┘    └───────┘   └───────┘ └───────┘       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. 总线验证协议检查

### AXI4 协议违规检查

#### 7.1 valid/ready 握手规则

```
规则: valid 信号一旦断言，必须保持直到 ready 也断言（握手完成）

正确:
         ┌───────────────┐
VALID    │               │
         └───────────────┘
              │
              ▼
READY    ──────1─────────────

错误 (valid 提前撤销):
         ┌───────┐
VALID    │       │  ← 违规！valid 在 ready 之前撤销
         └───────┘
              │
              ▼
READY    ─────────1─────────
```

```verilog
// AXI valid/ready 握手断言
property axi_aw_handshake;
    @(posedge aclk) disable iff (!aresetn)
    awvalid && !awready |=> awvalid;
endproperty

property axi_w_handshake;
    @(posedge aclk) disable iff (!aresetn)
    wvalid && !wready |=> wvalid;
endproperty

property axi_ar_handshake;
    @(posedge aclk) disable iff (!aresetn)
    arvalid && !arready |=> arvalid;
endproperty

assert_aw_handshake: assert property(axi_aw_handshake)
    else $error("AW: valid deasserted before ready");
assert_w_handshake: assert property(axi_w_handshake)
    else $error("W: valid deasserted before ready");
assert_ar_handshake: assert property(axi_ar_handshake)
    else $error("AR: valid deasserted before ready");
```

#### 7.2 突发长度检查

```
规则:
- AXI4 INCR 突发: awlen 范围 0-255（1-256 拍）
- AXI4 WRAP 突发: awlen 只能是 3/7/15/63（4/8/16/128 拍）
- AXI4 FIXED 突发: awlen 范围 0-15（1-16 拍）
- 突发不能跨越 4KB 地址边界
```

```verilog
// 突发长度合法性检查
property axi_burst_len_incr;
    @(posedge aclk) disable iff (!aresetn)
    (awvalid && awready) |-> (awburst == 2'b01) |-> (awlen inside {[0:255]});
endproperty

property axi_burst_len_wrap;
    @(posedge aclk) disable iff (!aresetn)
    (awvalid && awready) |-> (awburst == 2'b10) |-> (awlen inside {3, 7, 15, 63});
endproperty

// 4KB 边界检查
property axi_4kb_boundary;
    @(posedge aclk) disable iff (!aresetn)
    (awvalid && awready) |-> (
        ((awaddr & 12'hFFF) + ((awlen + 1) << awsize)) <= 12'h1000
    );
endproperty

assert_burst_len_incr: assert property(axi_burst_len_incr)
    else $error("AXI: INCR burst length out of range");
assert_burst_len_wrap: assert property(axi_burst_len_wrap)
    else $error("AXI: WRAP burst length must be 4/8/16/128");
assert_4kb_boundary: assert property(axi_4kb_boundary)
    else $error("AXI: Burst crosses 4KB boundary");
```

#### 7.3 WLAST 检查

```
规则: wlast 必须在突发的最后一个数据拍时为高
      对于 INCR 突发，wlast 在 awlen+1 拍后的最后一个数据时断言
```

```verilog
// wlast 检查
property axi_wlast_check;
    @(posedge aclk) disable iff (!aresetn)
    (wvalid && wready && wlast) |-> (w_count == awlen_reg + 1);
endproperty

assert_wlast: assert property(axi_wlast_check)
    else $error("AXI: wlast not asserted at correct beat");
```

#### 7.4 响应码检查

```
规则:
- BRESP/RRESP 只能是: OKAY(00), EXOKAY(01), SLVERR(10), DECERR(11)
- EXOKAY 只在独占访问时出现
```

```verilog
property axi_resp_valid;
    @(posedge aclk) disable iff (!aresetn)
    (bvalid && bready) |-> (bresp inside {2'b00, 2'b01, 2'b10, 2'b11});
endproperty

assert_bresp: assert property(axi_resp_valid)
    else $error("AXI: Invalid BRESP value");
```

### AHB 协议违规检查

#### 7.5 HTRANS 合法性

```
规则:
- HTRANS 只能是: IDLE(00), BUSY(01), NONSEQ(10), SEQ(11)
- 突发传输中: 第一拍必须是 NONSEQ，后续必须是 SEQ
- IDLE/BUSY 不应出现在从设备响应中
```

```verilog
property ahb_htrans_valid;
    @(posedge HCLK) disable iff (!HRESETn)
    $isoneof(HTRANS, 2'b00, 2'b01, 2'b10, 2'b11);
endproperty

// 突发传输检查
property ahb_burst_seq;
    @(posedge HCLK) disable iff (!HRESETn)
    (HTRANS == 2'b11) |-> ($past(HTRANS) inside {2'b10, 2'b11});
endproperty

assert_htrans: assert property(ahb_htrans_valid)
    else $error("AHB: Invalid HTRANS value");
assert_burst_seq: assert property(ahb_burst_seq)
    else $error("AHB: SEQ without prior NONSEQ");
```

#### 7.6 HRESP 检查

```
规则:
- HRESP 只能是 OKAY(00) 或 ERROR(01)
- 两周期响应: ERROR 在第一周期为 01，第二周期为 00（Split/Retry）
```

```verilog
property ahb_hresp_valid;
    @(posedge HCLK) disable iff (!HRESETn)
    HRESP inside {2'b00, 2'b01};
endproperty

assert_hresp: assert property(ahb_hresp_valid)
    else $error("AHB: Invalid HRESP value");
```

### APB 协议违规检查

#### 7.7 PENABLE 时序

```
规则:
- PENABLE 必须在 PSEL 之后的下一个时钟周期断言
- PENABLE 断言期间，PADDR/PWDATA/PWRITE 必须保持稳定
- PREADY 为高时传输完成
```

```verilog
property apb_penable_timing;
    @(posedge PCLK) disable iff (!PRESETn)
    (PSEL && !PENABLE) |=> PENABLE;
endproperty

property apb_penable_stable;
    @(posedge PCLK) disable iff (!PRESETn)
    PENABLE && !PREADY |=> $stable(PADDR) && $stable(PWDATA) && $stable(PWRITE);
endproperty

assert_penable: assert property(apb_penable_timing)
    else $error("APB: PENABLE not asserted after PSEL");
assert_stable: assert property(apb_penable_stable)
    else $error("APB: Address/data changed during transfer");
```

### 协议检查总结

| 协议 | 检查项 | 违规后果 |
|------|--------|---------|
| **AXI4** | valid/ready 握手 | 死锁、数据丢失 |
| **AXI4** | 突发长度/4KB 边界 | 地址越界、数据覆盖 |
| **AXI4** | WLAST 正确性 | 事务结束判断错误 |
| **AXI4** | 响应码合法性 | 错误处理异常 |
| **AHB** | HTRANS 合法性 | 总线协议状态机错误 |
| **AHB** | HRESP 两周期响应 | 从设备响应时序错误 |
| **APB** | PENABLE 时序 | 传输失败、数据错误 |

---

## 7. 参考资源

### 官方规范

- **AMBA AXI4**: ARM IHI 0022
- **AMBA AHB**: ARM IHI 0033
- **AMBA APB**: ARM IHI 0024

### 推荐书籍

- 《AMBA Protocol Specification》
- 《ARM System Developer's Guide》
- 《Computer Architecture: A Quantitative Approach》
- 《On-Chip Networks》

---

*最后更新: 2026-07-13*