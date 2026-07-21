---
title: "芯片验证实习生：基础与高频考卷"
description: "基于本站 SV、UVM、CDC/FIFO 和 AMBA 文档整理的两套 100 分考卷，附参考答案与评分点"
pubDate: 2026-07-21
category: soc
order: 99
tags: [SystemVerilog, UVM, AXI, CDC, FIFO, 面试, 自测]
---

# 芯片验证实习生：基础与高频考卷

题目范围对应本站的 SystemVerilog、UVM、跨时钟域、FIFO 和总线协议文档。建议先独立作答，再查看文末答案；代码题可在 EDA Playground 中验证。

---

## A 卷：基础与编码能力

**建议用时：80 分钟；满分：100 分。**

### 一、单选题（每题 4 分，共 20 分）

1. 在时序逻辑的 `always_ff @(posedge clk)` 中，通常应使用哪一种赋值？
   - A. `=`
   - B. `<=`
   - C. `assign`
   - D. `initial`

2. `task` 与 `function` 的关键区别是：
   - A. `task` 必须有返回值
   - B. `function` 可以包含时延控制
   - C. `task` 可以消耗仿真时间，`function` 不应包含时延控制
   - D. 两者只能在 module 外定义

3. 下列 CDC 场景中，最适合使用两级触发器同步器的是：
   - A. 从源时钟域到目的时钟域的单比特、稳定电平信号
   - B. 连续变化的 32 位数据总线
   - C. 任意窄脉冲
   - D. 异步 FIFO 的存储器数据阵列

4. 深度为 16 的同步 FIFO，读写指针通常需要几位来区分空与满？
   - A. 4 位
   - B. 5 位
   - C. 16 位
   - D. 17 位

5. APB 一次正常传输的正确阶段是：
   - A. `PSEL=1,PENABLE=1` 后再撤销 `PENABLE`
   - B. `PENABLE=1` 后再拉高 `PSEL`
   - C. Setup：`PSEL=1,PENABLE=0`；下一拍 Access：`PSEL=1,PENABLE=1`，等待 `PREADY`
   - D. `PSEL` 与 `PENABLE` 无需保持稳定

### 二、判断并说明理由（每题 4 分，共 20 分）

6. 在 AXI 通道上，`VALID` 可以等待对方的 `READY` 拉高后才断言，以避免无效传输。

7. `uvm_sequence_item` 应派生自 `uvm_component`，因为它也需要参与 phase。

8. 异步复位的断言可以异步，但工程中常将其释放同步到各自时钟域。

9. 对同步 FIFO，`empty` 通常表示当前读指针等于写指针。

10. `covergroup` 的功能覆盖率达到 100%，就必然说明 DUT 不存在 bug。

### 三、简答题（每题 10 分，共 30 分）

11. 写出 UVM testbench 的典型数据流，并说明 Sequence、Sequencer、Driver、Monitor、Scoreboard 的各自职责。

12. 为什么跨时钟域会有亚稳态？两级同步器如何降低风险，又有什么局限？

13. 说明 AXI 写事务的三个独立通道及其握手条件。若 `AWVALID=1`、`AWREADY=0` 持续三拍，主设备应如何处理地址和控制信号？

### 四、代码与验证题（共 30 分）

14. （15 分）下面的边沿检测器意图是在 `sig` 的上升沿产生一个时钟周期宽的脉冲。指出问题并改写。

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    sig_d <= 1'b0;
    rise  <= 1'b0;
  end else begin
    sig_d <= sig;
    rise  <= sig & ~sig_d;
  end
end
```

要求：解释复位时可能遗漏的设计考虑，并给出能综合的代码。

15. （15 分）为一个深度 8、数据宽度 8 位的同步 FIFO 制定最小验证计划。至少包含：激励场景、参考模型/检查方法、断言或覆盖点；特别说明满、空、同时读写和复位后的检查。

---

## B 卷：项目与面试高频

**建议用时：90 分钟；满分：100 分。**

### 一、单选题（每题 4 分，共 20 分）

1. AXI 的 `AW`、`W`、`B` 通道关系中，正确的是：
   - A. `AW` 与 `W` 必须同拍握手
   - B. 写响应 `B` 可在地址和全部写数据均被从设备接收后返回
   - C. `BVALID` 必须依赖 `BREADY` 才能拉高
   - D. `W` 通道不需要 `WLAST`

2. AXI4 的 INCR burst 长度字段 `AxLEN=7` 表示：
   - A. 7 个字节
   - B. 7 拍
   - C. 8 拍
   - D. 8 个地址

3. AXI burst 不能跨越 4KB 地址边界，验证该规则时最关键的输入是：
   - A. `AxID` 与 `AxLOCK`
   - B. 起始地址、`AxLEN` 与 `AxSIZE`
   - C. `AxPROT` 与 `AxCACHE`
   - D. `RRESP` 与 `BRESP`

4. UVM 中用 factory 创建对象的主要价值是：
   - A. 减少所有对象的内存占用
   - B. 支持不修改原环境源码的类型替换（override）
   - C. 自动连接 TLM port
   - D. 自动结束 run_phase

5. 下面最适合放在 `build_phase` 的工作是：
   - A. 对 DUT 逐拍采样
   - B. 创建 component，并从 `config_db` 获取 virtual interface
   - C. 启动 sequence
   - D. 等待一个时钟边沿

### 二、判断并说明理由（每题 4 分，共 20 分）

6. AXI 从设备可以在 `READY=0` 的周期改变已经有效的 `RDATA`，只要最终会完成握手即可。

7. 对 AXI-Lite，读地址和读数据分别经 AR 与 R 通道传输，且均使用 `VALID/READY` 握手。

8. 如果 sequence 没有 raise objection，run_phase 可能在该 sequence 完成前结束。

9. `uvm_config_db` 可用于由高层向低层传递 virtual interface 或配置对象。

10. 使用 Gray code 传递异步 FIFO 指针的目的，是让每次指针递增时只改变一位，从而减小跨域采样多位不一致的风险。

### 三、简答与计算题（每题 10 分，共 30 分）

11. 写出一个 AXI 写通道的高频协议检查清单，至少列出 5 项，并说明其中任意 2 项的典型 bug 后果。

12. 一个 128 bit AXI 数据口工作在 250 MHz。在无空拍、每拍均为有效数据时，理论单向带宽是多少？列出实际带宽通常低于理论值的至少 3 个原因。

13. 解释 UVM 中 component 与 object 的区别；并说明为什么 driver/monitor 应是 component，而 transaction 通常是 object。

### 四、场景设计题（共 30 分）

14. （15 分）你要验证一个 AXI4-Lite slave 的寄存器读写功能。请设计一个可执行的测试矩阵，覆盖复位、正常读写、地址非法、写响应/读响应、backpressure 和并发/时序扰动。说明 scoreboard 如何得到期望值，以及至少 3 条有价值的 SVA。

15. （15 分）某模块把源时钟域的 `req` 脉冲传给较慢的目的时钟域。仿真偶发丢请求。请：

   1. 分析两级同步器为什么不足以保证此请求不丢失；
   2. 给出 request/acknowledge 握手同步的核心状态与时序；
   3. 给出验证激励、检查器和覆盖目标。

---

## 参考答案与评分点

### A 卷答案

**一、单选：** 1-B，2-C，3-A，4-B，5-C。

**二、判断：**

6. 错。发送方不得等待 `READY` 才拉高 `VALID`；一旦拉高 `VALID`，在握手前必须保持 `VALID` 及对应 payload 稳定，否则可能形成死锁。

7. 错。sequence item 是短生命周期的事务对象，派生自 `uvm_sequence_item`（其基类为 `uvm_object`）；component 才有父子层次和 phase。

8. 对。这样兼顾异步断言的及时性与释放时避免恢复相关问题；目的时钟域分别同步释放。

9. 对。同步 FIFO 常以 `rptr == wptr` 判空；需基于当前或下一状态的定义一致实现。

10. 错。覆盖率只说明被定义的场景被命中；遗漏的需求、错误的 checker/覆盖模型及数据正确性仍可能隐藏 bug。

**三、简答评分要点：**

11. 主路径：`Sequence → Sequencer → Driver → virtual interface → DUT`；观测路径：`DUT/interface → Monitor → Scoreboard/coverage`。Sequence 产生事务；Sequencer 仲裁并向 Driver 提供事务；Driver 将事务转换为引脚活动；Monitor 被动采样并重组成事务；Scoreboard 将实际结果与预测/期望结果比较。完整答出链路 4 分，五项职责各 1 分，说明 Monitor 不驱动 DUT 1 分。

12. 异步输入若靠近目的触发器采样边沿变化，会违反 setup/hold，触发器输出可能暂时无法在要求时间内收敛到 0 或 1。两级同步器给第一级额外一个周期的恢复时间，显著提升 MTBF；它不能保证消除亚稳态，也不能可靠传递窄脉冲或多位相关数据。原理 4 分、效果 3 分、局限 3 分。

13. `AW` 传写地址/控制，`W` 传写数据/`WLAST`，`B` 传写响应；每个通道以本通道 `VALID && READY` 完成传输。前三拍地址未握手时，主机保持 `AWVALID=1`，且 `AWADDR/AWLEN/AWSIZE/AWBURST` 等 payload 不变，直到握手。通道与握手 6 分，稳定性 4 分。

**四、代码与验证：**

14. 题中代码功能本身在同步输入前提下可产生上升沿脉冲；更完整的答案应明确 `sig` 若来自异步域，不能直接使用，应先同步。复位值应与系统对复位后 `sig` 已为 1 时是否产生伪脉冲的规格保持一致。示例：

```systemverilog
logic sig_d;
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    sig_d <= 1'b0;
    rise  <= 1'b0;
  end else begin
    rise  <= sig & ~sig_d;
    sig_d <= sig;
  end
end
```

若 `sig` 异步：先用两级同步器得到 `sig_sync`，再以 `sig_sync` 替代 `sig`；若要求复位释放后不把已高的输入视为边沿，可在初始化/使能策略中同步历史值。指出同步前提 5 分，正确实现 6 分，复位语义 4 分。

15. 激励至少包含：复位后读、单写单读、连续写到满、连续读到空、空时读、满时写、读写同时发生、不同数据图样。参考模型用队列：接受的写入 push，接受的读取与队首比较；只有在实际握手允许时更新。检查 `empty/full` 与模型大小、数据顺序、溢出/下溢不改变指针或存储语义。覆盖：占用度 0/1/7/8、读写使能组合、满/空与读写交叉、复位前后。激励 5 分，模型/检查 6 分，断言/覆盖 4 分。

### B 卷答案

**一、单选：** 1-B，2-C，3-B，4-B，5-B。

**二、判断：**

6. 错。`RVALID=1 && RREADY=0` 时，`RDATA`、`RRESP`、`RLAST` 等必须保持稳定，直到握手。

7. 对。AXI-Lite 的 AR 与 R 是独立通道，各自以 `VALID/READY` 握手。

8. 对。run phase 由 objection 控制；未持有 objection 时，phase 可结束。实际工程还要考虑其他 component 的 objection。

9. 对。常见方式是 test/top 在构建前 set，agent/driver 在 build_phase get。

10. 对。Gray code 降低同一增量多个比特跨域被不同步采样的风险；仍需同步器与正确空满比较逻辑。

**三、简答评分要点：**

11. 可答：各通道 valid 保持至 ready；payload 在等待时稳定；AW/W 可独立到达；`WLAST` 仅在最后一个被接受的数据拍断言；响应只能在相应写数据完成后给出；burst 长度合法；不得跨 4KB；`BRESP` 合法；复位期间信号要求；ID/响应匹配。每项 1.5 分，任答 5 项满分 8 分；后果如提前撤 valid 导致丢事务/死锁、错误 WLAST 导致 burst 边界错位、跨 4KB 导致互联或从设备处理失败，各 1 分。

12. `128 / 8 × 250 MHz = 4,000 MB/s`，即 **4 GB/s（十进制）** 或约 **3.73 GiB/s**。常见折损：地址/响应与数据空拍，`READY` 反压，仲裁竞争，burst 太短，读写方向切换，DDR/从设备延迟，协议/编码开销。计算 4 分，至少三项原因 6 分。

13. component 有层次、parent、phase，通常由 factory 创建后长期存在；object 无 component 层次/phase，通常短生命周期。driver/monitor 需要在 build/connect/run phase 获取配置、连接端口、持续运行，故是 component；transaction 表示一次可创建、随机化、复制和比较的数据传输，故通常是 object/sequence item。区别 4 分，角色解释 6 分。

**四、场景设计评分要点：**

14. 测试矩阵应含：复位默认值与复位中访问；每个寄存器的全 0/全 1/随机/字段边界写读回；只读、只写、保留位和 byte strobe（若接口支持）；未映射地址的错误或定义返回；`BREADY/RREADY` 延后；`AW` 与 `W` 不同拍、读写交错。Scoreboard 维护按地址索引的寄存器镜像，在成功写握手后按规格更新；读响应与镜像比较，错误地址按规格比较响应和数据。示例 SVA：`VALID` 等待时 payload 稳定；`BVALID` 只在已完整接受一笔写后出现；读/写地址握手后最终有响应（可加 timeout/liveness checker）；复位时输出状态合法。矩阵 6 分、scoreboard 4 分、3 条有效检查 5 分。

15. 窄 `req` 即使经过两级同步，也可能完全落在目的时钟的两个采样边沿之间而未被采到。握手做法：源域收到新请求后置 `req` 并保持，目的域同步 `req` 后处理一次并置 `ack`，源域同步 `ack` 后清 `req`，目的域看到 `req` 清除后再清 `ack`，完成一次往返；每个跨域控制信号都需在接收域同步。验证：改变两时钟比和相位，产生不同宽度/间隔的请求，复位中断；计数源侧已接受请求与目的侧已消费请求，检查一一对应、无重复、无丢失和握手最终返回 idle。覆盖请求相对目的时钟的相位、最短间隔、复位位置、两种时钟比和连续请求。问题根因 4 分，协议 6 分，验证闭环 5 分。

---

## 建议使用方式

- 初学阶段先完成 A 卷，目标 **80 分**；低于该分数时优先回看 SV、CDC 和 FIFO 文档。
- 参与 AXI/UVM 项目前完成 B 卷，目标 **85 分**；错题应转写为可运行的 assertion 或 directed/random test。
- 批改代码题时，除功能正确外，应单独检查复位、边界条件、时序稳定性和可观测性。
