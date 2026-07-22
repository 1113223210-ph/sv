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

### 常见互连按使用范围分类

```
片上互连: AXI / AHB / APB / CHI / NoC
芯片间或板级互连: PCIe / USB / Ethernet / SATA / HDMI / JTAG
存储器接口: DDR / LPDDR / HBM
```

这些类别可能在具体系统中交叉，例如 PCIe 控制器内部仍会通过 AXI 连接 SoC；DDR 则是存储器接口，不应与 AXI/APB 视为同一层协议。

---

## 1. AMBA 协议族

### AMBA 概述

**AMBA (Advanced Microcontroller Bus Architecture)** 是 ARM 公司制定的总线标准，是目前 SoC 中使用最广泛的片上总线。

```
AMBA 常见分层:
高性能/高并发: AXI；需要硬件一致性时使用 ACE/CHI
流水化系统互连: AHB/AHB-Lite
低复杂度外设: APB
```

### AMBA 协议进化历程

```
AMBA 在不同版本中陆续加入 APB、AHB、AXI 和 ACE。它们不是简单的替代关系，而是面向不同性能层级并存：
APB 用于低复杂度外设，AHB/AHB-Lite 用于流水化系统互连，AXI 用于高并发高带宽，ACE 在 AXI 基础上增加一致性能力。
```

#### APB → AHB：从串行到流水线

```
APB 的瓶颈: 每笔传输至少 2 拍，存在等待状态时更长，且相邻传输不能流水重叠

APB:
  T0: A0 SETUP    T1: A0 ACCESS    T2: A1 SETUP    T3: A1 ACCESS
  → 无等待时每笔至少 2 拍，串行执行

AHB 的突破: 地址阶段和数据阶段可以重叠

AHB:
  T0: A0 地址阶段
  T1: A0 数据阶段 + A1 地址阶段 ← 重叠！
  T2: A1 数据阶段 + A2 地址阶段 ← 重叠！
  → 流水线提高利用率

AHB 其他能力:
  + Burst 突发（固定 4/8/16 拍或不定长 INCR；每拍仍有自己的地址阶段）
  + 多主设备仲裁 (HBUSREQ/HGRANT)
  + Split 传输 (慢速从设备不阻塞总线)
```

#### AHB → AXI3：从共享到并发

```
AHB 的瓶颈: 所有事务共享一条总线，一个主设备传输时其他必须等待

AXI3 的突破: 五通道完全独立，可同时工作

AHB: 地址/数据虽可流水重叠，但共享同一套传输控制，通常只维护当前流水传输
AXI3: AW、W、B 通道解耦，可并行推进多笔未完成事务

AXI3 关键改进:
  + Outstanding 事务 (发完地址不用等数据，继续发下一个)
  + ID 标识 + 乱序完成 (不同 ID 可乱序返回)
  + 写交织 (不同事务的写数据可以交织)
  + Burst 长度扩展 (最大 16 拍)
```

#### AXI3 → AXI4：从复杂到简化

```
AXI3 的复杂点:
  1. WID 支持不同写事务的数据拍交织 → 互联重排序逻辑复杂
  2. AxLEN 只有 4 位，突发最多 16 拍
  3. 还包含较复杂的 locked transaction 语义

AXI4 的简化:
  + AW 与 W 通道仍然独立，W 可以先于 AW 到达，接收端必须正确处理
  + 删除 WID，禁止不同写事务的数据拍交织 → 简化互联设计
  + INCR Burst 扩展到 256 拍；FIXED/WRAP 仍最多 16 拍
  + 新增 QoS/Region → 更精细的流量控制
```

#### AXI4 → ACE：解决多核一致性

```
问题: 多核 CPU 各有 L1 Cache
  CPU0 写了 addr=0x100 → Cache0 更新为新值
  CPU1 的 Cache1 还是旧值 → 数据不一致

ACE 在 AXI 基础上增加了:
  + Snoop 通道 (监听): 互联可以"询问"每个 CPU 的 Cache
  + Cache line 状态: I/UC/UD/SC/SD
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
    logic [3:0]             awregion;
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
    logic [3:0]             arregion;
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

    modport master (
        input  aclk, aresetn, awready, wready, bid, bresp, buser, bvalid,
               arready, rid, rdata, rresp, rlast, ruser, rvalid,
        output awid, awaddr, awlen, awsize, awburst, awlock, awcache,
               awprot, awqos, awregion, awuser, awvalid,
               wdata, wstrb, wlast, wuser, wvalid, bready,
               arid, araddr, arlen, arsize, arburst, arlock, arcache,
               arprot, arqos, arregion, aruser, arvalid, rready
    );

    modport slave (
        input  aclk, aresetn, awid, awaddr, awlen, awsize, awburst, awlock,
               awcache, awprot, awqos, awregion, awuser, awvalid,
               wdata, wstrb, wlast, wuser, wvalid, bready,
               arid, araddr, arlen, arsize, arburst, arlock, arcache,
               arprot, arqos, arregion, aruser, arvalid, rready,
        output awready, wready, bid, bresp, buser, bvalid,
               arready, rid, rdata, rresp, rlast, ruser, rvalid
    );

endinterface
```

#### AXI4 Burst 传输

```
AXI4 单个三拍写突发时序 (INCR 类型，AWLEN=2):

         ┌─────┐     ┌─────┐     ┌─────┐
AW_VALID │     │
         └─────┘
              │
              ▼
AW_ADDR  ────A0────────────────────────────

         ┌─────┐     ┌─────┐     ┌─────┐
W_VALID  │     │     │     │     │     │
         └─────┘     └─────┘     └─────┘
              │           │           │
              ▼           ▼           ▼
W_DATA   ────D0──────────D1──────────D2────
          W_LAST=0    W_LAST=0    W_LAST=1

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

    // 写数据通道；WSTRB 是 AXI4-Lite 的标准信号
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

    modport master (
        input  aclk, aresetn, awready, wready, bresp, bvalid,
               arready, rdata, rresp, rvalid,
        output awaddr, awprot, awvalid, wdata, wstrb, wvalid, bready,
               araddr, arprot, arvalid, rready
    );

    modport slave (
        input  aclk, aresetn, awaddr, awprot, awvalid, wdata, wstrb,
               wvalid, bready, araddr, arprot, arvalid, rready,
        output awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid
    );

endinterface
```

#### AXI4 vs AXI4-Lite vs AXI4-Stream

| 特性 | AXI4 | AXI4-Lite | AXI4-Stream |
|---|---|---|---|
| **突发传输** | 支持 FIXED/INCR/WRAP | 不支持 | 连续流，不使用 AxBURST |
| **地址** | 有 | 有 | 无 |
| **ID 标识** | 有 | 无 | 可选 TID；另有可选 TDEST |
| **字节选通** | WSTRB | WSTRB | 可选 TKEEP/TSTRB |
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

#### AXI4 写交织（Write Interleaving）

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

规则 3: 同一 ID 的写响应 B 必须按请求顺序返回
  不同 ID 的写响应可以乱序返回，接收端通过 BID 匹配事务
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

当 `AxSIZE` 指定的单拍字节数小于 AXI 数据总线宽度时，称为窄传输。
例如在 32 位总线上进行 8 位或 16 位访问。若主从设备的数据总线宽度不同，
则属于总线宽度转换，通常由 interconnect/width converter 拆分或合并传输。

字节通道映射 (32 位总线):
字节 0: wstrb[0] → 位 [7:0]
字节 1: wstrb[1] → 位 [15:8]
字节 2: wstrb[2] → 位 [23:16]
字节 3: wstrb[3] → 位 [31:24]
```

```
wstrb 示例:

32 位数据总线上的典型写选通:
  地址低两位为 2'b00 的 8 位写:  wstrb = 4'b0001
  地址低两位为 2'b01 的 8 位写:  wstrb = 4'b0010
  地址低两位为 2'b10 的 16 位写: wstrb = 4'b1100
  对齐的 32 位写:                 wstrb = 4'b1111

WSTRB 为 0 的字节不能被更新。若存储体没有原生字节写使能，从设备内部可能需要
读-改-写；这不是 AXI Master 必须额外发起的总线读事务。
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

  地址序列（共 4 拍）:
  拍 0: 0x04 (起始地址)
  拍 1: 0x08
  拍 2: 0x0C
  拍 3: 0x00 (环绕到 lower_wrap)

用途: 缓存行填充 (Cache Line Fill)
  CPU 请求地址 0x04，但缓存行大小为 16 字节
  → WRAP 突发从 0x04 开始，填充整个 0x00-0x0F 范围
```

#### AXI4 QoS 与 Region

```
QoS (Quality of Service) 编码:

awqos[3:0] / arqos[3:0]:
  0000 = 默认值，表示该接口不参与 QoS 方案
  0001 = 低优先级
  ...
  1111 = 高优先级

AXI 建议数值越大优先级越高，但不规定互联必须如何使用 QoS；具体仲裁、带宽保证和
防饥饿策略属于系统级定义，不能仅凭某类 Master 固定推断 AxQOS 值。
```

```
Region 编码:

awregion[3:0] / arregion[3:0]:
  最多标识同一物理 Slave 接口后的 16 个逻辑区域，可替代一部分高位地址译码

示例:
  Region 0: 0x0000_0000 - 0x0000_FFFF (SRAM 0)
  Region 1: 0x0001_0000 - 0x0001_FFFF (SRAM 1)
  Region 2: 0x0002_0000 - 0x0002_FFFF (SRAM 2)

用途: 一个 Slave 的数据通路与控制寄存器可位于不同系统地址区域，但共用同一物理接口。
AxREGION 不会创建新的独立地址空间，并且在任意 4KB 地址范围内必须保持不变。
```

```
Cache 属性 (awcache/arcache):

AxCACHE[3:0]（AXI4）:
  [0] = Bufferable (可缓冲)
  [1] = Modifiable (允许互联拆分、合并或修改事务属性)
  [3:2] = 缓存查找/分配提示；读写通道的精确含义可能不同

常用非缓存类型:
  4'b0000 = Device Non-bufferable
  4'b0001 = Device Bufferable
  4'b0010 = Normal Non-cacheable Non-bufferable
  4'b0011 = Normal Non-cacheable Bufferable

缓存型内存的 ARCACHE 与 AWCACHE 可能使用不同编码，不能只用一个笼统的
“Write-Back/Write-Through”常量同时驱动两个通道；应按所用 AXI 版本的内存类型表配置。
```

#### valid/ready 反压机制详解

```
反压 (Backpressure) 原理:

当接收端还没准备好接收数据时，通过拉低 READY 信号反压发送端。
发送端一旦断言 VALID，就必须保持 VALID 和通道负载不变，直到握手完成。

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
  0   │   1   │ 接收端就绪但发送端无有效负载（允许）
  1   │   0   │ 发送端有效但被反压（发送端必须保持）
  1   │   1   │ 握手完成，数据传输

协议规则:
- valid=1 后必须保持到 ready=1（不能提前撤销）
- valid=1 且 ready=0 时，发送端的通道负载必须稳定
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
    (awvalid && !awready) |=>
        awvalid && $stable({awaddr, awlen, awsize, awburst, awprot});
endproperty

assert_handshake: assert property(handshake_valid_ready)
    else $error("Protocol violation: AW changed before handshake");
```

#### Master/Slave 行为示例

```verilog
// AXI Master 的 AW 通道：VALID 和地址保持到握手完成
always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        awvalid <= 1'b0;
    end else if (!awvalid && start_write) begin
        awaddr  <= next_write_addr;
        awvalid <= 1'b1;
    end else if (awvalid && awready) begin
        awvalid <= 1'b0;
    end
end

// AXI Slave：只在 AWVALID && AWREADY 时接收地址
assign awready = can_accept_aw;
always_ff @(posedge aclk) begin
    if (awvalid && awready)
        accepted_awaddr <= awaddr;
end
```

AW、W、B、AR、R 五个通道都独立使用各自的 VALID/READY；写地址和写数据不能合并成一个通用 `bus.valid/bus.ready` 握手。

#### Master vs Slave 信号对比

| 信号 | Master 产生 | Slave 产生 |
|---|---|---|
| `valid` | ✅ | ❌ |
| `ready` | ❌ | ✅ |
| `addr` | ✅ | ❌ |
| `rdata`/`wdata` | 读时等，写时提供 | 读时提供，写时等 |

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
    logic [3:0]             HPROT;       // 保护/缓存属性
    logic                   HMASTLOCK;   // 锁定传输指示
    logic                   HWRITE;      // 读/写
    logic [DATA_WIDTH-1:0]  HWDATA;      // 写数据
    logic [DATA_WIDTH-1:0]  HRDATA;      // 读数据
    logic                   HRESP;       // AHB-Lite: 0=OKAY, 1=ERROR
    logic                   HREADY;      // 互联返回给 Master 的全局就绪
    logic                   HREADYOUT;   // 当前 Slave 输出的就绪
    logic                   HSEL;        // 片选

    modport master (
        input  HCLK, HRESETn, HRDATA, HRESP, HREADY,
        output HADDR, HTRANS, HSIZE, HBURST, HPROT, HMASTLOCK,
               HWRITE, HWDATA
    );

    modport slave (
        input  HCLK, HRESETn, HADDR, HTRANS, HSIZE, HBURST, HPROT,
               HMASTLOCK, HWRITE, HWDATA, HREADY, HSEL,
        output HRDATA, HRESP, HREADYOUT
    );

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
| **流水线** | 地址阶段与数据阶段重叠 | 五个独立通道并发工作 |
| **并发传输** | 单一 | 多个同时进行 |
| **突发长度** | 固定突发最多 16 拍；INCR 可不定长 | AXI4 INCR 最大 256 拍 |
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
1. 从设备通过 HRESP 返回 SPLIT 响应
2. 仲裁器撤销当前主设备授权
3. 仲裁器授权其他主设备访问
4. 慢速从设备完成操作后，通过 HSPLITx 通知仲裁器原 Master 可重新参与仲裁
5. 仲裁器重新授权原主设备

概念时序:
1. M0 以 NONSEQ 发起访问。
2. 从设备返回两周期 SPLIT 响应；仲裁器记录 M0 被 split，并可授权 M1。
3. 从设备完成内部操作后，断言 HSPLITx[M0]，表示 M0 可以重新参与仲裁。
4. M0 再次获授权后，必须重新发起原传输；SPLIT 本身并不代表传输已经完成。
```

注意：以上机制仅适用于完整 AHB。AHB-Lite 是单 Master 子集，HRESP 只有
OKAY/ERROR，不支持 RETRY、SPLIT、HSPLITx 或总线仲裁。

#### AHB 总线保持协议

```
HREADY 协议:

规则:
1. HREADY=1 时，当前数据传输完成
2. HREADY=0 时，从设备插入等待状态
3. 等待期间，后续地址/控制和当前写数据保持稳定，流水线整体停顿

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
                // 解码器不选中任何从设备 → 由 default slave 返回 AHB ERROR
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
  → default slave 产生 ERROR 响应 (AHB-Lite HRESP=1'b1)
  → 主设备收到错误响应
```

```
4GB 地址空间划分示例:

0x0000_0000 ┌──────────────┐
            │   ROM        │ 64KB
0x0000_FFFF ├──────────────┤
            │   (未使用)    │
0x1FFF_FFFF ├──────────────┤
            │   SRAM       │ 64KB
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
    logic [DATA_WIDTH/8-1:0] PSTRB;     // APB4 写字节选通
    logic [2:0]             PPROT;      // APB4 保护属性
    logic [DATA_WIDTH-1:0]  PRDATA;     // 读数据
    logic                   PREADY;     // 就绪
    logic                   PSLVERR;    // 错误响应

    modport master (
        input  PCLK, PRESETn, PRDATA, PREADY, PSLVERR,
        output PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB, PPROT
    );

    modport slave (
        input  PCLK, PRESETn, PADDR, PSEL, PENABLE, PWRITE,
               PWDATA, PSTRB, PPROT,
        output PRDATA, PREADY, PSLVERR
    );

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
| `PSTRB[3:0]` | Master→Slave | APB4 写字节选通 |
| `PPROT[2:0]` | Master→Slave | APB4 保护属性 |
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

PSEL 和 PENABLE 保持高，地址、控制与写数据保持稳定，直到 PREADY 为高
PREADY 只在 ACCESS 阶段（PSEL && PENABLE）参与传输完成判断
```

#### APB4 PSTRB 字节选通

```
APB4 PSTRB 规则:
- PSTRB[n] = 1 表示 PWDATA 的第 n 字节有效
- PSTRB 全为 1 时表示全部字节有效
- PSTRB 部分为 0 时进行子字节写入
- 读传输时 PSTRB 必须为全 0

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
- 背靠背传输可在一次 ACCESS 完成后直接进入下一笔 SETUP；目标从设备相同时 PSEL 可保持高
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
    localparam COUNT_WIDTH = (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);
    logic [COUNT_WIDTH-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx_pin <= 1'b1; // 空闲高电平
            tx_ready <= 1'b1;
            clk_count <= '0;
            bit_index <= '0;
            shift_reg <= '0;
        end else begin
            case (state)
                IDLE: begin
                    tx_pin <= 1'b1;
                    tx_ready <= 1'b1;
                    if (tx_valid) begin
                        state <= START_BIT;
                        shift_reg <= tx_data;
                        clk_count <= 0;
                        tx_ready <= 1'b0;
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
                        clk_count <= 0;
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

#### ACE 一致性事务示例

| 一致性事务 | 典型目的 |
|---|---|
| **ReadOnce** | 读取数据快照，不要求保留缓存副本 |
| **ReadShared** | 获取可共享的缓存副本 |
| **ReadUnique** | 获取唯一副本，为后续修改做准备 |
| **CleanShared** | 推进脏数据的清理，使副本可共享 |
| **CleanInvalid** | 清理并无效化缓存副本 |
| **MakeUnique** | 在已有副本基础上取得唯一权限 |

ACE 请求仍通过扩展后的 AXI 地址通道发出，数据/完成响应使用 R/B 通道；互联对其他
缓存发出的 snoop 则使用 AC（snoop address）、CR（snoop response）和可选 CD
（snoop data）通道。`ReadDone`、`CleanDone` 并不是 ACE 的标准响应信号名。

#### ACE Cache Line 状态

| 状态 | 含义 | 可写 | 数据有效 |
|---|---|---|---|
| **UD** (Unique Dirty) | 本缓存持有唯一、已修改副本 | ✅ | ✅ |
| **UC** (Unique Clean) | 本缓存持有唯一、干净副本 | ✅ | ✅ |
| **SD** (Shared Dirty) | 多缓存可共享，内存可能不是最新值 | ❌ | ✅ |
| **SC** (Shared Clean) | 多缓存可共享的干净副本 | ❌ | ✅ |
| **I** (Invalid) | 无有效副本 | ❌ | ❌ |

这些状态与常见 MOESI 概念可以近似对应，但 ACE 规范使用的是
I/UC/UD/SC/SD 术语，不应直接把协议状态信号写成 M/O/E/S/I。

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

特点: 同一时刻只有一个 Master 占用共享通路，即使目标 Slave 不同也不能并行
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

时钟周期:    T0    T1    T2    T3
M0_REQ:      1     1     1     1
M1_REQ:      1     1     1     1
GNT:         M0    M1    M0    M1
Slave 0:     M0→S0 M1→S0 M0→S0 M1→S0

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

    logic granted;

    always_comb begin
        gnt = '0;
        granted = 1'b0;
        // 约定编号越小优先级越高：Master 0 的优先级最高
        for (int i = 0; i < NUM_MASTER; i++) begin
            if (req[i] && !granted) begin
                gnt[i] = 1'b1;
                granted = 1'b1;
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

    integer rr_ptr; // 下一次搜索的起始 Master

    always_comb begin
        gnt = '0;
        for (int offset = 0; offset < NUM_MASTER; offset++) begin
            int idx;
            idx = rr_ptr + offset;
            if (idx >= NUM_MASTER)
                idx = idx - NUM_MASTER;
            if (req[idx] && !(|gnt)) begin
                gnt[idx] = 1'b1;
            end
        end
    end

    // 每次授权后，从获胜者的下一位开始下一轮搜索
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rr_ptr <= 0;
        else begin
            for (int i = 0; i < NUM_MASTER; i++) begin
                if (gnt[i])
                    rr_ptr <= (i == NUM_MASTER-1) ? 0 : i + 1;
            end
        end
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
  原始数据线速率 = 32bit × 100MHz = 3.2 Gbps
  APB 每笔传输至少包含 SETUP+ACCESS 两周期，因此无等待时有效上限为 1.6 Gbps

多层总线 (AHB, 32位, 200MHz):
  单层理想带宽 = 32bit × 200MHz = 6.4 Gbps
  若 N 个独立 Slave 层确实并行且均为连续无等待传输，总聚合上限 = 6.4 × N Gbps
  2-3 层的理想聚合上限为 12.8-19.2 Gbps

交叉开关 (AXI4, 64位, 500MHz):
  带宽 = 64bit × 500MHz × min(M, S)
  3M × 3S 时理论最大: 96 Gbps
  实际值取决于地址分布、读写方向、仲裁、响应延迟和反压，不能仅由接口位宽推定
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

### 3.1 AXI4-Lite→AHB-Lite 桥

```
AXI4-Lite→AHB-Lite 桥接原理（同一时钟域）:

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
- AXI4-Lite 的 AW 与 W 通道彼此独立，桥必须分别握手和缓存
- 一笔 AXI4-Lite 访问对应一笔 AHB-Lite SINGLE 传输
- AXI VALID/READY 背压转换为 AHB HREADY 等待状态
- AHB-Lite 没有事务 ID；若扩展到完整 AXI，桥必须在内部保存 ID 并在响应时返回
- 完整 AXI 的突发、乱序和窄传输需要额外的拆分、排队与地址生成逻辑，本例不覆盖
```

```verilog
// AXI4-Lite→AHB-Lite 简化桥：一次只处理一笔事务，仅支持全字写
module axi_lite_to_ahb_bridge #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic aclk,
    input  logic aresetn,
    // AXI Slave Interface
    axi4_lite_if.slave s_axi,
    // AHB Master Interface
    ahb_if.master  m_ahb
);

    // 限制：AXI 与 AHB 使用同一时钟，一次只允许一笔未完成事务，
    // 且只接受 WSTRB 全为 1 的全宽写。

    typedef enum logic [2:0] {
        IDLE,
        AHB_W_ADDR,
        AHB_W_DATA,
        AXI_B_RESP,
        AHB_R_ADDR,
        AHB_R_DATA,
        AXI_R_RESP
    } state_t;

    state_t state;
    logic aw_hold, w_hold;
    logic [ADDR_WIDTH-1:0] awaddr_reg;
    logic [2:0] awprot_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic [DATA_WIDTH/8-1:0] wstrb_reg;

    // 写地址和写数据可独立到达，分别缓存；读请求在没有待处理写请求时接收
    assign s_axi.awready = (state == IDLE) && !aw_hold;
    assign s_axi.wready  = (state == IDLE) && !w_hold;
    assign s_axi.arready = (state == IDLE) && !aw_hold && !w_hold &&
                           !s_axi.awvalid && !s_axi.wvalid;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state <= IDLE;
            aw_hold <= 1'b0;
            w_hold <= 1'b0;
            s_axi.bvalid <= 1'b0;
            s_axi.bresp <= 2'b00;
            s_axi.rvalid <= 1'b0;
            s_axi.rresp <= 2'b00;
            s_axi.rdata <= '0;
            m_ahb.HTRANS <= 2'b00; // IDLE
            m_ahb.HADDR <= '0;
            m_ahb.HWRITE <= 1'b0;
            m_ahb.HSIZE <= $clog2(DATA_WIDTH/8);
            m_ahb.HBURST <= 3'b000; // SINGLE
            m_ahb.HPROT <= 4'b0011; // Data、Privileged、Non-cacheable、Non-bufferable
            m_ahb.HMASTLOCK <= 1'b0;
            m_ahb.HWDATA <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (s_axi.awvalid && s_axi.awready) begin
                        awaddr_reg <= s_axi.awaddr;
                        awprot_reg <= s_axi.awprot;
                        aw_hold <= 1'b1;
                    end
                    if (s_axi.wvalid && s_axi.wready) begin
                        wdata_reg <= s_axi.wdata;
                        wstrb_reg <= s_axi.wstrb;
                        w_hold <= 1'b1;
                    end

                    if (aw_hold && w_hold) begin
                        aw_hold <= 1'b0;
                        w_hold <= 1'b0;
                        if (wstrb_reg != '1) begin
                            // AHB-Lite 没有字节选通；本简化桥拒绝部分写
                            s_axi.bresp <= 2'b10; // SLVERR
                            s_axi.bvalid <= 1'b1;
                            state <= AXI_B_RESP;
                        end else begin
                            m_ahb.HADDR <= awaddr_reg;
                            m_ahb.HWRITE <= 1'b1;
                            m_ahb.HPROT <= {2'b00, awprot_reg[0], ~awprot_reg[2]};
                            m_ahb.HWDATA <= wdata_reg;
                            m_ahb.HTRANS <= 2'b10; // NONSEQ
                            state <= AHB_W_ADDR;
                        end
                    end else if (s_axi.arvalid && s_axi.arready) begin
                        m_ahb.HADDR <= s_axi.araddr;
                        m_ahb.HWRITE <= 1'b0;
                        m_ahb.HPROT <= {2'b00, s_axi.arprot[0], ~s_axi.arprot[2]};
                        m_ahb.HTRANS <= 2'b10; // NONSEQ
                        state <= AHB_R_ADDR;
                    end
                end

                AHB_W_ADDR: begin
                    if (m_ahb.HREADY) begin
                        m_ahb.HTRANS <= 2'b00;
                        state <= AHB_W_DATA;
                    end
                end

                AHB_W_DATA: begin
                    if (m_ahb.HREADY) begin
                        s_axi.bvalid <= 1'b1;
                        s_axi.bresp <= m_ahb.HRESP ? 2'b10 : 2'b00;
                        state <= AXI_B_RESP;
                    end
                end

                AXI_B_RESP: begin
                    if (s_axi.bvalid && s_axi.bready) begin
                        s_axi.bvalid <= 1'b0;
                        state <= IDLE;
                    end
                end

                AHB_R_ADDR: begin
                    if (m_ahb.HREADY) begin
                        m_ahb.HTRANS <= 2'b00;
                        state <= AHB_R_DATA;
                    end
                end

                AHB_R_DATA: begin
                    if (m_ahb.HREADY) begin
                        s_axi.rdata <= m_ahb.HRDATA;
                        s_axi.rvalid <= 1'b1;
                        s_axi.rresp <= m_ahb.HRESP ? 2'b10 : 2'b00;
                        state <= AXI_R_RESP;
                    end
                end

                AXI_R_RESP: begin
                    if (s_axi.rvalid && s_axi.rready) begin
                        s_axi.rvalid <= 1'b0;
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
AXI: AW 与 W 可按任意先后顺序独立握手；两者都被桥接收后，才能发起 APB 写
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

状态机（与下方简化 RTL 对应）:
                   读请求
┌──────┐ ─────────────────────────> ┌───────────┐
│ IDLE │                            │ APB_SETUP │
└──┬───┘                            └─────┬─────┘
   │ 写请求                               │
   ▼                                      ▼
┌───────────────┐                    ┌────────────┐
│ CAPTURE_WDATA │───────────────────>│ APB_ACCESS│
└───────────────┘                    └─────┬──────┘
                                          │ PREADY=1
                                          └────────> IDLE
```

```verilog
// AHB-Lite→APB4 简化桥：同一时钟域，一次只处理一笔事务
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

    typedef enum logic [2:0] {
        IDLE,
        CAPTURE_WDATA,
        APB_SETUP,
        APB_ACCESS,
        AHB_ERROR_2
    } state_t;

    state_t state;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state <= IDLE;
            m_apb.PSEL <= 1'b0;
            m_apb.PENABLE <= 1'b0;
            m_apb.PADDR <= '0;
            m_apb.PWRITE <= 1'b0;
            m_apb.PWDATA <= '0;
            m_apb.PSTRB <= '0;
            m_apb.PPROT <= '0;
            s_ahb.HREADYOUT <= 1'b1;
            s_ahb.HRESP <= 1'b0;
            s_ahb.HRDATA <= '0;
        end else begin
            // 默认无错误；仅在 APB 传输完成时采样 PSLVERR
            s_ahb.HRESP <= 1'b0;
            case (state)
                IDLE: begin
                    m_apb.PSEL <= 1'b0;
                    m_apb.PENABLE <= 1'b0;
                    s_ahb.HREADYOUT <= 1'b1;

                    // 只在有效且被接受的 AHB 地址阶段锁存控制信息
                    if (s_ahb.HSEL && s_ahb.HREADY && s_ahb.HTRANS[1]) begin
                        s_ahb.HREADYOUT <= 1'b0;
                        if ((s_ahb.HSIZE != $clog2(DATA_WIDTH/8)) ||
                            ((s_ahb.HADDR % (DATA_WIDTH/8)) != 0)) begin
                            // 本简化桥只支持与数据总线同宽且自然对齐的访问
                            s_ahb.HRESP <= 1'b1;
                            state <= AHB_ERROR_2;
                        end else begin
                            m_apb.PADDR <= s_ahb.HADDR;
                            m_apb.PWRITE <= s_ahb.HWRITE;
                            m_apb.PSTRB <= '1;
                            // PPROT={instruction, non-secure, privileged}
                            m_apb.PPROT <= {~s_ahb.HPROT[0], 1'b0,
                                            s_ahb.HPROT[1]};

                            // AHB 写数据在地址阶段之后一拍才有效，不能在此处采样
                            state <= s_ahb.HWRITE ? CAPTURE_WDATA : APB_SETUP;
                        end
                    end
                end

                CAPTURE_WDATA: begin
                    m_apb.PWDATA <= s_ahb.HWDATA;
                    state <= APB_SETUP;
                end

                APB_SETUP: begin
                    m_apb.PSEL <= 1'b1;
                    m_apb.PENABLE <= 1'b0;
                    state <= APB_ACCESS;
                end

                APB_ACCESS: begin
                    m_apb.PENABLE <= 1'b1;
                    if (m_apb.PREADY) begin
                        m_apb.PENABLE <= 1'b0;
                        m_apb.PSEL <= 1'b0;
                        if (!m_apb.PWRITE)
                            s_ahb.HRDATA <= m_apb.PRDATA;
                        if (m_apb.PSLVERR) begin
                            // AHB-Lite ERROR 的第一周期：HRESP=1、HREADYOUT=0
                            s_ahb.HRESP <= 1'b1;
                            s_ahb.HREADYOUT <= 1'b0;
                            state <= AHB_ERROR_2;
                        end else begin
                            s_ahb.HREADYOUT <= 1'b1;
                            state <= IDLE;
                        end
                    end
                end

                AHB_ERROR_2: begin
                    // AHB-Lite ERROR 的第二周期：HRESP=1、HREADYOUT=1
                    s_ahb.HRESP <= 1'b1;
                    s_ahb.HREADYOUT <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
```

### 3.4 桥接设计要点

| 要点 | 说明 |
|------|------|
| **时钟域** | 异步时钟域不能只用单比特同步器；需异步 FIFO、握手机制或专用异步桥 |
| **数据宽度** | 下游位宽更窄时需拆分访问，并正确重算地址、SIZE 和字节选通 |
| **突发处理** | 可把兼容突发映射为 AHB burst；APB 无突发，必须拆成单拍并汇总响应 |
| **ID 处理** | AHB/APB 无事务 ID，桥需缓存 AXI ID 并在响应时匹配；不能直接透传 |
| **错误传播** | 下游执行错误通常映射为 AXI SLVERR；地址译码失败通常映射为 DECERR |
| **独占访问** | AXI exclusive 与 AHB locked sequence 语义不同，不能直接连线；需专用监视器或明确报不支持 |

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
| **XY Routing** | 先 X 方向，再 Y 方向 | 在常规 2D Mesh 通道模型下简单且无路由死锁 |
| **Odd-Even** | 用奇偶列限制转向 | 可支持无死锁的部分自适应路由 |
| **West-First** | 所有向西的转向必须先完成 | 转向模型可避免路由死锁 |
| **Adaptive** | 根据拥塞选择候选路径 | 可提高吞吐，但需另行保证死锁/活锁安全 |

### NoC 流控机制

| 机制 | 说明 | 优点 | 缺点 |
|---|---|---|---|
| **Store-and-Forward** | 存储转发 | 完整包接收 | 延迟高 |
| **Cut-Through** | 直通 | 低延迟 | 需要大缓冲 |
| **Wormhole** | 虫孔 | 低延迟、小缓冲 | 可能阻塞 |
| **Virtual Channel** | 虚拟通道 | 正确划分类别时可打破通道依赖并缓解阻塞 | 复杂度高 |

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

高带宽、多个未完成事务或乱序需求?
├── 是 → AXI4；规模很大且通信分布复杂时评估 NoC
└── 否
    ├── 流水化存储器/外设访问 → AHB-Lite
    ├── 单拍寄存器访问且希望统一 AXI 生态 → AXI4-Lite
    └── 低速、低复杂度外设寄存器 → APB

协议选择还取决于现有 IP、时钟/电源域、位宽、验证成本和生态授权，
不能仅按 IP 数量或“是否低功耗”决定。
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

#### 6.1 VALID/READY 握手与负载稳定性

```
规则: VALID 一旦断言，必须保持到与 READY 握手；等待期间，与该通道
      对应的地址、控制、数据或响应负载也必须保持稳定。

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
// 以下展示 AW、W 和 B 通道；AR、R 通道应使用相同规则。
property axi_aw_stable_while_stalled;
    @(posedge aclk) disable iff (!aresetn)
    awvalid && !awready |=>
        awvalid && $stable({awid, awaddr, awlen, awsize, awburst,
                            awlock, awcache, awprot, awqos, awregion, awuser});
endproperty

property axi_w_stable_while_stalled;
    @(posedge aclk) disable iff (!aresetn)
    wvalid && !wready |=>
        wvalid && $stable({wdata, wstrb, wlast, wuser});
endproperty

property axi_b_stable_while_stalled;
    @(posedge aclk) disable iff (!aresetn)
    bvalid && !bready |=>
        bvalid && $stable({bid, bresp, buser});
endproperty

assert_aw_stable: assert property(axi_aw_stable_while_stalled)
    else $error("AXI AW changed while stalled");
assert_w_stable: assert property(axi_w_stable_while_stalled)
    else $error("AXI W changed while stalled");
assert_b_stable: assert property(axi_b_stable_while_stalled)
    else $error("AXI B changed while stalled");
```

#### 6.2 突发属性与 4KB 边界检查

```
规则:
- AXI4 INCR 突发: awlen 范围 0-255（1-256 拍）
- AXI4 WRAP 突发: awlen 只能是 1/3/7/15（2/4/8/16 拍）
- AXI4 FIXED 突发: awlen 范围 0-15（1-16 拍）
- awburst=2'b11 是保留编码
- 突发不能跨越 4KB 地址边界
```

```verilog
// 该辅助函数假设 ADDR_WIDTH < 64。WRAP 必须按回绕区域计算，不能简单地
// 使用“起始地址 + 总字节数”，否则会误报合法的回绕突发。
function automatic bit axi_burst_within_4kb(
    logic [ADDR_WIDTH-1:0] addr,
    logic [7:0]            len,
    logic [2:0]            size,
    logic [1:0]            burst
);
    longint unsigned start_addr;
    longint unsigned beat_bytes;
    longint unsigned total_bytes;
    longint unsigned low_addr;
    longint unsigned high_addr;

    start_addr = $unsigned(addr);
    beat_bytes = 64'd1 << size;
    total_bytes = beat_bytes * ($unsigned(len) + 1);

    case (burst)
        2'b00: begin // FIXED
            low_addr  = (start_addr / beat_bytes) * beat_bytes;
            high_addr = low_addr + beat_bytes - 1;
        end
        2'b01: begin // INCR
            low_addr  = (start_addr / beat_bytes) * beat_bytes;
            high_addr = low_addr + total_bytes - 1;
        end
        2'b10: begin // WRAP
            low_addr  = (start_addr / total_bytes) * total_bytes;
            high_addr = low_addr + total_bytes - 1;
        end
        default: return 1'b0;
    endcase

    return (low_addr >> 12) == (high_addr >> 12);
endfunction

property axi_burst_type_valid;
    @(posedge aclk) disable iff (!aresetn)
    (awvalid && awready) |-> awburst inside {2'b00, 2'b01, 2'b10};
endproperty

property axi_aw_control_valid;
    @(posedge aclk) disable iff (!aresetn)
    (awvalid && awready) |->
        !$isunknown({awaddr, awlen, awsize, awburst}) &&
        (awsize <= $clog2(DATA_WIDTH/8));
endproperty

property axi_burst_len_wrap;
    @(posedge aclk) disable iff (!aresetn)
    (awvalid && awready && awburst == 2'b10) |->
        awlen inside {1, 3, 7, 15};
endproperty

property axi_burst_len_fixed;
    @(posedge aclk) disable iff (!aresetn)
    (awvalid && awready && awburst == 2'b00) |-> awlen <= 8'd15;
endproperty

property axi_wrap_start_aligned;
    @(posedge aclk) disable iff (!aresetn)
    (awvalid && awready && awburst == 2'b10) |->
        (awaddr % (64'd1 << awsize)) == 0;
endproperty

property axi_4kb_boundary;
    @(posedge aclk) disable iff (!aresetn)
    (awvalid && awready) |->
        axi_burst_within_4kb(awaddr, awlen, awsize, awburst);
endproperty

assert_burst_type: assert property(axi_burst_type_valid)
    else $error("AXI: reserved AWBURST encoding");
assert_aw_control: assert property(axi_aw_control_valid)
    else $error("AXI: unknown control or AWSIZE exceeds bus width");
assert_burst_len_wrap: assert property(axi_burst_len_wrap)
    else $error("AXI: WRAP burst length must be 2/4/8/16 beats");
assert_burst_len_fixed: assert property(axi_burst_len_fixed)
    else $error("AXI: FIXED burst exceeds 16 beats");
assert_wrap_alignment: assert property(axi_wrap_start_aligned)
    else $error("AXI: WRAP start address is not transfer-size aligned");
assert_4kb_boundary: assert property(axi_4kb_boundary)
    else $error("AXI: Burst crosses 4KB boundary");
```

`AWLEN` 本身是 8 位，因此 INCR 的 1～256 拍范围无需再用
`awlen inside {[0:255]}` 检查；该表达式对所有已知的 8 位值恒为真。上例同时检查了
`AWSIZE` 上限、WRAP 起始地址对齐和控制字段中的 X/Z。

#### 6.3 WLAST 检查

```
规则: wlast 必须在突发的最后一个数据拍时为高
      AWLEN 表示“拍数减 1”。若 w_count 从 0 开始，则最后一拍满足
      w_count == awlen_reg。
```

```verilog
// 假设 w_count 是当前写突发从 0 开始的已握手拍索引，awlen_reg 与该突发匹配
property axi_wlast_check;
    @(posedge aclk) disable iff (!aresetn)
    (wvalid && wready) |-> (wlast == (w_count == awlen_reg));
endproperty

assert_wlast: assert property(axi_wlast_check)
    else $error("AXI: wlast not asserted at correct beat");
```

有多笔未完成写事务时，验证组件必须按 AXI4 写数据顺序把每个 W 拍与正确的 AW
关联；只保存一个全局 `awlen_reg` 会产生误判。

#### 6.4 响应码检查

```
规则:
- BRESP/RRESP 只能是: OKAY(00), EXOKAY(01), SLVERR(10), DECERR(11)
- EXOKAY 只在独占访问时出现
```

```verilog
// 2 位信号的四种二进制编码都已定义，真正需要捕获的是 X/Z。
property axi_bresp_known;
    @(posedge aclk) disable iff (!aresetn)
    bvalid |-> !$isunknown(bresp);
endproperty

// b_exclusive_reg 由监视器记录该响应是否对应独占写事务。
property axi_exokay_only_for_exclusive;
    @(posedge aclk) disable iff (!aresetn)
    (bvalid && bready && bresp == 2'b01) |-> b_exclusive_reg;
endproperty

assert_bresp_known: assert property(axi_bresp_known)
    else $error("AXI: BRESP contains X/Z");
assert_exokay_context: assert property(axi_exokay_only_for_exclusive)
    else $error("AXI: EXOKAY returned for a non-exclusive write");
```

### AHB 协议违规检查

#### 6.5 HTRANS 与等待周期检查

```
规则:
- HTRANS 只能是: IDLE(00), BUSY(01), NONSEQ(10), SEQ(11)
- 突发传输中第一笔有效传输是 NONSEQ，后续有效传输是 SEQ；BUSY 可插在突发中
- HREADY 为低时，主设备必须保持地址阶段控制信号稳定
```

```verilog
property ahb_htrans_valid;
    @(posedge HCLK) disable iff (!HRESETn)
    !$isunknown(HTRANS);
endproperty

property ahb_control_stable_while_stalled;
    @(posedge HCLK) disable iff (!HRESETn)
    !HREADY |=>
        $stable({HADDR, HTRANS, HWRITE, HSIZE, HBURST,
                 HPROT, HMASTLOCK, HWDATA});
endproperty

assert_htrans: assert property(ahb_htrans_valid)
    else $error("AHB: HTRANS contains X/Z");
assert_ahb_stable: assert property(ahb_control_stable_while_stalled)
    else $error("AHB: address/control changed while HREADY was low");
```

检查 NONSEQ/SEQ 的完整关系通常需要一个按 `HREADY` 更新的突发状态监视器；简单使用
`$past(HTRANS)` 会在等待周期或 BUSY 插入时误报。

#### 6.6 AHB-Lite HRESP 检查

```
规则:
- AHB-Lite 的 HRESP 是 1 位：0 表示 OKAY，1 表示 ERROR
- ERROR 是两周期响应：第一周期 HRESP=1、HREADY=0，第二周期 HRESP=1、HREADY=1
- RETRY/SPLIT 属于完整 AHB，不属于 AHB-Lite
```

```verilog
property ahb_error_second_cycle;
    @(posedge HCLK) disable iff (!HRESETn)
    HRESP && !HREADY |=> HRESP && HREADY;
endproperty

property ahb_error_has_first_cycle;
    @(posedge HCLK) disable iff (!HRESETn)
    HRESP && HREADY |-> $past(HRESP && !HREADY);
endproperty

assert_error_second: assert property(ahb_error_second_cycle)
    else $error("AHB-Lite: malformed second ERROR cycle");
assert_error_first: assert property(ahb_error_has_first_cycle)
    else $error("AHB-Lite: ERROR completed without its first cycle");
```

### APB 协议违规检查

#### 6.7 PENABLE 时序

```
规则:
- PENABLE 必须在 PSEL 之后的下一个时钟周期断言
- 等待期间，PSEL/PENABLE 和全部请求负载必须保持稳定
- 只有 PSEL、PENABLE、PREADY 同时为高的时钟沿才完成传输
```

```verilog
property apb_penable_timing;
    @(posedge PCLK) disable iff (!PRESETn)
    (PSEL && !PENABLE) |=> PSEL && PENABLE;
endproperty

property apb_stable_while_waiting;
    @(posedge PCLK) disable iff (!PRESETn)
    PSEL && PENABLE && !PREADY |=>
        PSEL && PENABLE && $stable({PADDR, PWRITE, PWDATA, PSTRB, PPROT});
endproperty

assert_penable: assert property(apb_penable_timing)
    else $error("APB: PENABLE not asserted after PSEL");
assert_stable: assert property(apb_stable_while_waiting)
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

- [**AMBA AXI/ACE**：Arm IHI 0022](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/IHI0022H_amba_axi_protocol_spec.pdf)
- [**AMBA AHB-Lite**：Arm IHI 0033](https://documentation-service.arm.com/static/5f914801f86e16515cdc2a27)
- [**AMBA APB**：Arm IHI 0024](https://documentation-service.arm.com/static/64257f64314e245d086bc8b7)

### 推荐书籍

- 《AMBA Protocol Specification》
- 《ARM System Developer's Guide》
- 《Computer Architecture: A Quantitative Approach》
- 《On-Chip Networks》

---

*最后更新: 2026-07-22*
