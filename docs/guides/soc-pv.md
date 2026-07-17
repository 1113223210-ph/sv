---
title: "SoC PV"
description: "SoC PV模型相关内容"
pubDate: 2025-01-01
category: soc
order: 3
tags: [SOC, PV]
---

# SoC 性能验证（Performance Verification）

## 验证目标

SoC性能验证主要验证以下指标：

| 指标 | 验什么 | 关键参数 |
|------|--------|----------|
| **带宽** | 数据传输速率 | bits/ns, GB/s |
| **延迟** | 请求到响应时间 | cycles, ns |
| **吞吐量** | 单位时间处理量 | transactions/cycle |
| **仲裁公平性** | 多主设备竞争时的公平性 | 服务时间比 |
| **并发能力** | 多任务同时访问性能 | 并发数 |

---

## 基础测试用例

### 1. 带宽测试

```verilog
task measure_bandwidth;
    int start_time, end_time;
    int data_size = 1024;  // 传输1KB数据
    real bandwidth;
    begin
        start_time = $time;
        repeat(data_size) begin
            @(posedge clk);
            ddr_read_en = 1;
            ddr_addr = addr_counter;
            @(posedge ddr_ready);
        end
        end_time = $time;
        bandwidth = (data_size * 32) / (end_time - start_time);
        $display("Bandwidth: %0f Gbps", bandwidth * 1000);
    end
endtask
```

### 2. 延迟测试

```verilog
task measure_latency;
    int start_cycle, end_cycle;
    begin
        start_cycle = cycle_count;
        @(posedge clk);
        bus_req = 1;
        @(posedge bus_grant);
        bus_req = 0;
        end_cycle = cycle_count;
        $display("Latency: %0d cycles", end_cycle - start_cycle);
    end
endtask
```

### 3. 仲裁公平性测试

```verilog
task test_arbitration;
    begin
        fork
            master0_write(32'h0000, 32'hDEAD_BEEF);
            master1_read(32'h1000, 32);
            master2_write(32'h2000, 32'hCAFE_BABE);
            master3_read(32'h3000, 64);
        join
        check_fairness();
    end
endtask
```

---

## 关键指标定义

### 带宽（Bandwidth）

```
带宽 = (数据量 × 位宽) / 传输时间

例：DDR4-3200
    理论带宽 = 3200 MT/s × 64 bits = 25.6 GB/s
```

### 延迟（Latency）

```
延迟 = 请求发出 → 数据返回的总时间

组成：
    1. 仲裁延迟：等待总线授权
    2. 传输延迟：数据传输时间
    3. 处理延迟：目标设备处理时间
```

### 吞吐量（Throughput）

```
吞吐量 = 成功传输的总数据量 / 总时间

考虑因素：
    - 背靠背传输能力
    - 突发传输效率
    - 流水线深度
```

---

## 常见性能瓶颈

| 瓶颈类型 | 表现 | 解决方案 |
|----------|------|----------|
| 总线竞争 | 多主设备等待时间长 | 增加总线带宽、优化仲裁 |
| 存储带宽不足 | DDR访问延迟高 | 增加存储通道、提高频率 |
| 缓存命中率低 | 频繁访问主存 | 优化缓存策略、预取 |
| 中断响应慢 | CPU处理延迟 | 优化中断控制器、减少中断源 |

---

*最后更新: 2026-07-15*