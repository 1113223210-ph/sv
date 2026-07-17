---
title: "AXI 常见问题详解"
description: "AXI协议核心问题深度解析"
pubDate: 2025-01-01
category: sv
order: 5
tags: [AXI, 总线协议, 验证]
---

# AXI 常见问题详解

## 问题 1：AXI 和 AHB 的区别在哪里，为什么 AXI 相比 AHB 有明显的性能优势？

### 架构差异

```
AHB 架构（共享总线）：

  Master 0 ──┐
  Master 1 ──┼──→ 仲裁器 ──→ 共享总线 ──→ Slave
  Master 2 ──┘

问题：同时只能有一个 Master 访问一个 Slave


AXI 架构（独立通道）：

  Master ──→ ┌─────────────────────────────────────────┐
             │  AW (写地址)  ←→  Slave 0               │
             │  W  (写数据)  ←→  Slave 1               │
             │  B  (写响应)  ←→  Slave 2               │
             │  AR (读地址)  ←→  Slave 3               │
             │  R  (读数据)  ←→  Slave 4               │
             └─────────────────────────────────────────┘

优势：5 个通道完全独立，可同时工作
```

### 关键差异详解

| 特性 | AHB | AXI | 性能影响 |
|---|---|---|---|
| **通道数量** | 1条共享总线 | 5个独立通道 | AXI可并行读写 |
| **流水线** | 无（地址/数据串行） | 有（地址/数据重叠） | AXI提高利用率 |
| **Outstanding** | 不支持 | 支持 | AXI隐藏延迟 |
| **乱序完成** | 不支持 | 通过ID支持 | AXI提高吞吐 |
| **突发长度** | 最大16拍 | 最大256拍(INCR) | AXI减少地址开销 |

### Outstanding 机制详解

```
AHB（无 Outstanding）：

  时钟:  T0   T1   T2   T3   T4   T5   T6   T7   T8
         │    │    │    │    │    │    │    │    │
  Master: A0   ─    ─    A1   ─    ─    A2   ─    ─
                  │              │              │
                  ▼              ▼              ▼
  Slave:  ─    ─    D0   ─    ─    D1   ─    ─    D2

  总延迟 = 3笔 × 3周期 = 9 周期


AXI（有 Outstanding，深度=4）：

  时钟:  T0   T1   T2   T3   T4   T5   T6   T7   T8
         │    │    │    │    │    │    │    │    │
  Master: A0   A1   A2   A3   ─    ─    ─    ─    ─
         │         │         │         │
         ▼         ▼         ▼         ▼
  Slave:  ─    ─    ─    ─    D0   D1   D2   D3   ─

  总延迟 = 4 + 4 = 8 周期（节省 50%）
```

**核心原理**：主设备发送地址后，不必等待数据响应即可发送下一个地址，这种"流水线"方式可以隐藏从设备的访问延迟。

---

## 问题 2：AXI3 和 AXI4 的区别在哪里？

### 主要差异总结

| 特性 | AXI3 | AXI4 | 影响 |
|---|---|---|---|
| **写交织** | 允许 | 禁止 | AXI4简化互联设计 |
| **INCR突发长度** | 最大16拍 | 最大256拍 | AXI4提高DDR效率 |
| **写数据先于写地址** | 允许 | 禁止 | AXI4去掉Buffer，节省面积 |
| **LOCK信号** | 2bit | 1bit | AXI4简化锁机制 |
| **QoS/Region** | 无 | 有 | AXI4增加流量控制 |

### 写交织（Write Interleaving）详解

```
AXI3 允许写交织：

  Transaction A: W_A0 → W_A1 → W_A2
  Transaction B: W_B0 → W_B1

  正确（交织）：
  W_A0 → W_B0 → W_A1 → W_B1 → W_A2
  （A 和 B 的数据拍可以交错）


AXI4 禁止写交织：

  Transaction A: W_A0 → W_A1 → W_A2
  Transaction B: W_B0 → W_B1

  正确：
  W_A0 → W_A1 → W_A2 → W_B0 → W_B1
  （A 的所有拍先发完，再发 B）

  错误：
  W_A0 → W_B0 → W_A1 → W_B1 → W_A2
  （交织违反协议）
```

**为什么 AXI4 禁止写交织？**
- 互联需要为每个事务的写数据开辟 Buffer
- 禁止后可以去掉这些 Buffer，节省面积
- 简化互联设计复杂度

### 突发长度扩展

```
AXI3 INCR 突发：awlen[3:0] = 0-15，最多 16 拍
AXI4 INCR 突发：awlen[7:0] = 0-255，最多 256 拍

应用场景：
- DDR 控制器：需要长突发提高效率
- AXI3：需要多次发送地址才能传输 256 拍数据
- AXI4：一次地址即可传输 256 拍数据
```

---

## 问题 3：Exclusive 访问是什么？它的实现机制是什么？相比于 Lock Access 的优势是什么？

### Lock Access 的问题

```
Lock Access 流程：

  1. 主设备发送 LOCK=1，锁定总线
  2. 主设备进行读-修改-写操作
  3. 操作完成后，主设备发送 LOCK=0，释放总线

问题：
  - 锁定期间，其他主设备无法访问任何从设备
  - 可能导致优先级反转（低优先级主设备锁定总线，高优先级主设备被阻塞）
  - 系统整体吞吐量下降
```

### Exclusive 访问机制

```
Exclusive 访问流程：

  1. 主设备发送 Exclusive 读请求
     AW/AR: LOCK=1, 打算进行原子操作

  2. 互联记录该地址被主设备 M0 独占
     互联内部：M0 拥有 addr=0x100 的独占权

  3. 主设备进行修改（在本地缓存中修改）

  4. 主设备发送 Exclusive 写请求
     AW: LOCK=1, 写 addr=0x100

  5. 互联检查该地址是否被其他主设备修改：
     - 未修改：写成功，返回 OKAY
     - 已修改：写失败，返回 EXOKAY（Exclusive OKAY）
```

### 互联监控逻辑

```verilog
// Exclusive 访问监控简化逻辑
module exclusive_monitor (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        arvalid,
    input  logic [31:0] araddr,
    input  logic [3:0]  arid,
    input  logic        awvalid,
    input  logic [31:0] awaddr,
    input  logic [3:0]  awid,
    output logic        exclusive_ok  // Exclusive 写是否成功
);

    // 记录每个地址的独占主设备
    typedef struct {
        logic [31:0] addr;
        logic [3:0]  owner_id;
        logic        valid;
    } exclusive_entry_t;

    exclusive_entry_t entries[16];

    // Exclusive 读：记录独占权
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++)
                entries[i].valid <= 1'b0;
        end else if (arvalid && arid == 4'h0) begin  // 假设 M0 发起
            // 找到空闲表项，记录独占权
            for (int i = 0; i < 16; i++) begin
                if (!entries[i].valid) begin
                    entries[i].addr <= araddr;
                    entries[i].owner_id <= arid;
                    entries[i].valid <= 1'b1;
                    break;
                end
            end
        end
    end

    // Exclusive 写：检查是否被其他主设备修改
    always_comb begin
        exclusive_ok = 1'b0;
        if (awvalid) begin
            for (int i = 0; i < 16; i++) begin
                if (entries[i].valid &&
                    entries[i].addr == awaddr &&
                    entries[i].owner_id == awid) begin
                    exclusive_ok = 1'b1;  // 未被修改，写成功
                end
            end
        end
    end

endmodule
```

### Lock vs Exclusive 对比

| 特性 | Lock Access | Exclusive Access |
|---|---|---|
| **总线锁定** | 是 | 否 |
| **其他主设备访问** | 完全阻塞 | 可访问其他地址 |
| **优先级反转** | 可能 | 不会 |
| **系统吞吐** | 降低 | 保持 |
| **实现复杂度** | 简单 | 较高 |

---

## 问题 4：AXI 的 Outstanding 数量如何计算？

### 影响因素

```
Outstanding 数量 = min(
    主设备缓冲深度,      // 主设备能缓存多少未完成事务
    互联支持的最大深度,   // 互联能路由多少并发事务
    从设备可处理的队列长度 // 从设备能接受多少并发请求
)
```

### 典型配置

| 从设备类型 | 典型 Outstanding | 原因 |
|---|---|---|
| DDR 控制器 | 4-8 | DDR 流水线较深，需要较深队列 |
| SRAM | 2-4 | SRAM 响应快，队列可较浅 |
| APB 外设 | 1 | APB 每次只处理一个事务 |
| 高速缓存 | 8-16 | 缓存命中率高，需要深队列 |

### Outstanding 深度与性能关系

```
性能 vs Outstanding 深度：

  性能
   ↑
   │        ┌─────────────────  深度=16
   │       /
   │      /
   │     /  ┌───────────────  深度=8
   │    /   /
   │   /   /
   │  /   /  ┌─────────────  深度=4
   │ /   /   /
   │/   /   /
   └───┴───┴──────────────→ 从设备延迟

  从设备延迟越大，需要越深的 Outstanding 才能隐藏延迟
```

### 面积与性能权衡

```
深度=1：无流水，每笔事务独立完成
        优点：无乱序风险，面积最小
        缺点：延迟大

深度=2-4：可流水 2-4 笔事务
          优点：适合中速外设，面积适中
          缺点：性能提升有限

深度=8+：深度流水
        优点：最大化带宽利用率
        缺点：面积和功耗代价大
```

---

## 问题 5：Burst 中的 WRAP 类型，如何计算上下界地址？

### WRAP 地址计算公式

```
突发总字节数 = burst_size × (burst_len + 1)
下界 = (起始地址 / 突发总字节数) × 突发总字节数
上界 = 下界 + 突发总字节数

地址行为：
从起始地址开始，每次递增 burst_size
当地址达到上界时，回绕到下界
```

### 详细示例

```
参数：awaddr=0x04, awsize=2(4字节), awlen=3(4拍), awburst=WRAP

步骤 1：计算突发总字节数
  burst_bytes = 4 × (3+1) = 16 字节

步骤 2：计算下界
  下界 = (0x04 / 16) × 16 = 0x00

步骤 3：计算上界
  上界 = 0x00 + 16 = 0x10

步骤 4：计算地址序列
  拍 0：0x04 (起始地址)
  拍 1：0x04 + 4 = 0x08
  拍 2：0x08 + 4 = 0x0C
  拍 3：0x0C + 4 = 0x10 (达到上界，回绕)
         → 回绕到下界 0x00
  拍 4：0x00 + 4 = 0x04 (回到起始)

地址序列：0x04 → 0x08 → 0x0C → 0x00
```

### WRAP 的应用场景

```
缓存行填充（Cache Line Fill）：

  场景：CPU 请求地址 0x04，但缓存行大小为 16 字节
  目标：填充整个 0x00-0x0F 范围

  如果用 INCR：
  0x04 → 0x08 → 0x0C → 0x10 (超出缓存行)

  用 WRAP：
  0x04 → 0x08 → 0x0C → 0x00 (正确填充)
```

---

## 问题 6：AXI 哪些情况可能出现死锁，如何避免此问题？

### 死锁场景 1：valid/ready 违反

```
场景：valid 提前撤销

  Master:  AWVALID ────1────────0──────────
                    (valid 在 ready 之前撤销)

  Slave:   AWREADY ───────────────1────────

问题：Slave 在 T2 采样到 AWVALID=0，认为事务未开始
     但 Master 认为事务已完成
     → 状态不一致，可能死锁

避免：严格遵守 valid/ready 协议
     valid=1 后必须保持到 ready=1
```

### 死锁场景 2：循环依赖

```
场景：读写通道循环等待

  Master 等待：AR 通道响应
  Slave 等待：W 通道数据
  但 Master 因为缓冲满，无法发送 W

  形成死锁：Master ↔ Slave 互相等待

避免：
  - 合理分配 ID，避免资源耗尽
  - 设置合理的超时机制
```

### 死锁场景 3：从设备长时间阻塞

```
场景：从设备不响应

  Master:  AR_VALID=1, 等待 R_VALID
  Slave:   因为内部状态机卡住，不发送 R_VALID

  如果没有超时，Master 会永远等待

避免：
  - 实现看门狗定时器
  - 检测超时并重置事务
```

### 死锁预防策略

| 策略 | 说明 | 实现方式 |
|---|---|---|
| **协议遵守** | 严格遵守 valid/ready | 协议检查断言 |
| **超时机制** | 检测长时间阻塞 | 看门狗定时器 |
| **资源管理** | 避免资源耗尽 | ID 分配策略 |
| **死锁检测** | 主动检测死锁 | 状态机监控 |

---

## 问题 7：AXI Stream 中如何进行反压？

### 反压机制

```
AXI Stream 通过 TREADY/TVALID 握手实现反压：

  发送端：
  - 当 TREADY=0 时，必须保持 TVALID=1 和所有数据信号
  - 不能撤销 TVALID 或改变数据

  接收端：
  - 通过 TREADY 控制流量
  - 当无法处理数据时，拉低 TREADY
```

### 反压时序示例

```
正常传输（无反压）：

  CLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
           └──┘  └──┘  └──┘  └──┘

  TVALID ──────1─────1─────1─────0────
  TREADY ──────1─────1─────1─────1────
  TDATA  ──── D0 ──── D1 ──── D2 ────

  每个周期都传输数据


反压场景（接收端忙）：

  CLK    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
           └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

  TVALID ──────1─────1─────1─────1─────1─────0────
  TREADY ──────1─────0─────0─────1─────1─────1────
  TDATA  ──── D0 ──── D1 ──── D1 ──── D2 ──── D2 ────
                │      │      │
                │      └──────┴────── 反压期间数据保持不变
                └────── 第一个传输完成
```

### 反压期间的信号要求

```
规则：
1. TVALID=1 且 TREADY=0 时，TDATA/TSTRB/TKEEP 必须保持稳定
2. 不能撤销 TVALID（除非复位）
3. 接收端可以在任意时刻拉低 TREADY

违规示例：
  TVALID ────1────0────1────  ← 违规！TVALID 被撤销
  TREADY ──────0────0────1────
  TDATA  ──── D0 ──── D1 ────
```

---

## 问题 8：AXI 中各个 Channel 之间的依赖关系是什么？

### 通道依赖图

```
读通道依赖关系：

  AR (读地址) ─────→ R (读数据)
       │                │
       └────────────────┘
       （无其他依赖）

  读操作：Master 发送 AR → Slave 返回 R
  AR 和 R 之间是简单的请求-响应关系


写通道依赖关系：

  AW (写地址) ──┐
               │
  W  (写数据) ─┼──→ B (写响应)
               │
               └─────

  写操作：Master 发送 AW 和 W → Slave 返回 B
  AW 和 W 可以并行（AXI4 中 W 必须在 AW 之后）
  B 必须在 AW 和 W 都完成后才能返回
```

### 关键依赖规则

| 依赖 | 说明 | 原因 |
|---|---|---|
| **AR → R** | R 依赖 AR | 必须先知道读地址，才能返回数据 |
| **AW + W → B** | B 依赖 AW 和 W | 必须完成写地址和写数据，才能返回响应 |
| **AR ∥ AW** | 读写地址可并行 | 读写通道完全独立 |
| **AR ∥ W** | 读地址和写数据可并行 | 读写通道完全独立 |

### 并行性优势

```
AXI 可以同时进行读写：

  时钟:  T0   T1   T2   T3   T4   T5
         │    │    │    │    │    │
  AW:    A0   ─    ─    ─    ─    ─
  W:     ─    D0   ─    ─    ─    ─
  B:     ─    ─    ─    R0   ─    ─
  AR:    ─    A1   ─    ─    ─    ─
  R:     ─    ─    ─    ─    D1   ─

  写操作和读操作同时进行，提高带宽利用率
```

---

## 问题 9：如何计算 AXI 最大传输带宽？

### 理论带宽计算

```
理论带宽 = 数据位宽 × 时钟频率

示例：
- 32位 AXI4, 200MHz: 32 × 200MHz = 6.4 Gbps
- 64位 AXI4, 500MHz: 64 × 500MHz = 32 Gbps
- 128位 AXI4, 400MHz: 128 × 400MHz = 51.2 Gbps
```

### 实际带宽计算

```
实际带宽 = 理论带宽 × 效率因子

效率因子考虑：
1. 握手开销（valid/ready 延迟）
2. Outstanding 深度
3. 突发长度
4. 地址阶段开销
```

### 效率因子估算

```
效率因子 = (数据传输周期) / (总周期)

示例：64位 AXI4, 500MHz, Outstanding=4, Burst=16

数据传输周期 = 16 拍（每笔事务）
地址阶段开销 = 1 拍（每笔事务）
总周期 = 16 + 1 = 17 拍

效率因子 = 16 / 17 ≈ 94%

实际带宽 = 32 Gbps × 94% ≈ 30 Gbps
```

### 不同配置的带宽对比

| 配置 | 理论带宽 | 实际带宽(估算) | 效率 |
|---|---|---|---|
| 32位, 200MHz | 6.4 Gbps | ~4.8 Gbps | 75% |
| 64位, 500MHz | 32 Gbps | ~24 Gbps | 75% |
| 128位, 400MHz | 51.2 Gbps | ~38 Gbps | 75% |

---

## 问题 10：Interleave 和乱序的区别是什么？

### 定义对比

| 特性 | Interleave | 乱序(Out of Order) |
|---|---|---|
| **定义** | 不同事务的数据拍交错传输 | 不同ID的事务不按顺序完成 |
| **作用层面** | W通道数据级别 | 事务级别 |
| **AXI4支持** | 禁止 | 支持 |

### Interleave 详解

```
AXI3 允许写交织：

  Transaction A: W_A0 → W_A1 → W_A2
  Transaction B: W_B0 → W_B1

  交织方式：
  W_A0 → W_B0 → W_A1 → W_B1 → W_A2

  特点：
  - A 和 B 的数据拍交错
  - 每个事务的拍必须按顺序（A0→A1→A2）
  - 但不同事务的拍可以交错


AXI4 禁止写交织：

  正确：
  W_A0 → W_A1 → W_A2 → W_B0 → W_B1

  错误：
  W_A0 → W_B0 → W_A1 → W_B1 → W_A2
```

### 乱序详解

```
乱序完成：

  AR_A (ID=0) → AR_B (ID=1) → AR_C (ID=2)

  可以：
  R_B → R_C → R_A（基于从设备响应速度）

  特点：
  - 不同 ID 的事务可以乱序返回
  - 同一 ID 的事务必须按顺序返回
  - 提高带宽利用率
```

### 核心区别

```
Interleave：数据拍级别的交错
  - 作用于 W 通道的单个数据拍
  - AXI4 已禁止

乱序：事务级别的重排
  - 作用于完整的读/写事务
  - AXI4 仍然支持
  - 通过 ID 机制实现
```

---

## 问题 11：AXI 的 Out of Order 应该怎么去实现？

### 实现架构

```
Out of Order 实现组件：

  Master ──→ ┌─────────────────────────────────────────┐
             │           AXI Interconnect              │
             │  ┌─────────────────────────────────┐   │
             │  │      ID 分配器                   │   │
             │  │   (为每个事务分配唯一ID)          │   │
             │  └─────────────────────────────────┘   │
             │                 │                       │
             │                 ▼                       │
             │  ┌─────────────────────────────────┐   │
             │  │      重排序队列                   │   │
             │  │   (根据ID重新排序响应)            │   │
             │  └─────────────────────────────────┘   │
             │                 │                       │
             │                 ▼                       │
             │  ┌─────────────────────────────────┐   │
             │  │      ID 缓冲器                   │   │
             │  │   (缓存未完成事务的ID)            │   │
             │  └─────────────────────────────────┘   │
             └─────────────────────────────────────────┘
```

### 关键实现步骤

```
步骤 1：ID 分配

  主设备发送事务时，互联为每个事务分配唯一 ID
  例如：
  - 事务 A：分配 ID=0
  - 事务 B：分配 ID=1
  - 事务 C：分配 ID=2


步骤 2：从设备响应

  从设备收到请求后，按自己内部顺序处理
  可能返回响应的顺序：
  - 先返回 ID=1（SRAM 响应快）
  - 再返回 ID=0（DDR 响应慢）
  - 最后返回 ID=2


步骤 3：重排序

  互联收到响应后，根据 ID 重新排序
  缓存所有响应，直到可以按序返回

  缓存内容：
  - ID=0: 等待中
  - ID=1: 已收到，等待 ID=0
  - ID=2: 已收到，等待 ID=0


步骤 4：按序返回

  当 ID=0 的响应到达后，按顺序返回：
  R_A (ID=0) → R_B (ID=1) → R_C (ID=2)
```

### 重排序队列实现

```verilog
// 简化的重排序队列
module reorder_buffer #(
    parameter ID_WIDTH = 4,
    parameter DEPTH = 16
)(
    input  logic        clk,
    input  logic        rst_n,
    // 响应输入（乱序）
    input  logic [ID_WIDTH-1:0] resp_id,
    input  logic [63:0] resp_data,
    input  logic        resp_valid,
    output logic        resp_ready,
    // 响应输出（按序）
    output logic [ID_WIDTH-1:0] out_id,
    output logic [63:0] out_data,
    output logic        out_valid,
    input  logic        out_ready
);

    typedef struct {
        logic [ID_WIDTH-1:0] id;
        logic [63:0] data;
        logic valid;
    } entry_t;

    entry_t buffer[DEPTH];
    logic [ID_WIDTH-1:0] next_id;  // 下一个应该输出的 ID

    // 接收乱序响应
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++)
                buffer[i].valid <= 1'b0;
            next_id <= '0;
        end else if (resp_valid && resp_ready) begin
            // 找到对应 ID 的表项，存储数据
            for (int i = 0; i < DEPTH; i++) begin
                if (buffer[i].id == resp_id) begin
                    buffer[i].data <= resp_data;
                    buffer[i].valid <= 1'b1;
                    break;
                end
            end
        end
    end

    // 按序输出
    always_comb begin
        out_valid = 1'b0;
        out_id = '0;
        out_data = '0;
        resp_ready = 1'b1;

        for (int i = 0; i < DEPTH; i++) begin
            if (buffer[i].valid && buffer[i].id == next_id) begin
                out_valid = 1'b1;
                out_id = buffer[i].id;
                out_data = buffer[i].data;
                if (out_ready) begin
                    // 标记为已输出，更新 next_id
                    buffer[i].valid = 1'b0;
                end
                break;
            end
        end
    end

    // 更新 next_id
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_id <= '0;
        end else if (out_valid && out_ready) begin
            next_id <= next_id + 1;
        end
    end

endmodule
```

### 实现要点总结

| 要点 | 说明 |
|---|---|
| **ID 分配** | 为每个事务分配唯一 ID |
| **响应缓存** | 缓存所有乱序到达的响应 |
| **重排序逻辑** | 根据 ID 重新排序响应 |
| **按序输出** | 按 ID 顺序返回给主设备 |
| **缓冲管理** | 及时释放已输出的缓冲区 |

---

## 知识点总结

| 问题 | 核心要点 |
|---|---|
| **AXI vs AHB** | 5通道独立、Outstanding、乱序 |
| **AXI3 vs AXI4** | 禁止写交织、突发长度扩展 |
| **Exclusive 访问** | 原子操作、不锁定总线、提高并发 |
| **Outstanding 计算** | min(主设备、互联、从设备) |
| **WRAP 地址** | 下界对齐、上界回绕 |
| **死锁避免** | 协议遵守、超时机制、资源管理 |
| **AXI Stream 反压** | TREADY/TVALID 握手 |
| **Channel 依赖** | AR→R, AW+W→B, 读写独立 |
| **带宽计算** | 位宽×频率×效率因子 |
| **Interleave vs 乱序** | 数据拍交错 vs 事务重排 |
| **Out of Order 实现** | ID分配、缓存、重排序、按序输出 |
