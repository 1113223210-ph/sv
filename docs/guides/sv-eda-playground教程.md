---
title: "EDA Playground 使用教程"
description: "在线 Verilog/SystemVerilog 仿真平台入门指南"
pubDate: 2025-01-01
category: sv
order: 4
tags: [验证, 工具, EDA Playground]
---

# EDA Playground 使用教程

## 1. 简介

### 什么是 EDA Playground？

```
EDA Playground = 在线数字电路仿真平台

特点：
  - 无需安装任何软件
  - 浏览器直接使用
  - 支持 Verilog/SystemVerilog
  - 内置仿真器和波形查看器
  - 免费使用
```

### 能做什么？

| 功能 | 说明 |
|---|---|
| 编写代码 | 在线编辑 Verilog/SystemVerilog |
| 运行仿真 | 支持 VCS、Icarus 等仿真器 |
| 查看波形 | 内置 GTKWave 波形查看器 |
| 保存分享 | 生成链接，可分享给他人 |

### 网址

```
https://www.edaplayground.com
```

---

## 2. 注册登录

### 步骤

```
1. 打开 edaplayground.com
2. 点击右上角 "Sign Up"
3. 填写邮箱和密码
4. 验证邮箱
5. 登录使用
```

### 注意事项

```
- 建议用工作邮箱注册
- 免费版有使用限制（每天仿真次数）
- 付费版无限制（个人学习免费版够用）
```

---

## 3. 界面介绍

### 主界面布局

```
┌─────────────────────────────────────────────────────────────┐
│  File  Edit  Help                              [Sign Out]   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────┐  ┌─────────────────────────┐  │
│  │                         │  │                         │  │
│  │    代码编辑区           │  │    仿真输出区           │  │
│  │    (test.sv)            │  │    (Console)            │  │
│  │                         │  │                         │  │
│  └─────────────────────────┘  └─────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  工具选择区                                          │   │
│  │  Simulator: [Icarus Verilog v0.9.7]                 │   │
│  │  Language:  [SystemVerilog/Verilog]                 │   │
│  │  [Run] [Stop] [Open in Tab]                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 关键区域说明

| 区域 | 作用 |
|---|---|
| **代码编辑区** | 编写你的 Verilog/SystemVerilog 代码 |
| **仿真输出区** | 显示仿真结果和错误信息 |
| **工具选择区** | 选择仿真器、语言、运行仿真 |

### 工具选择区详解

```
Simulator（仿真器）：
  - Icarus Verilog v0.9.7（推荐，免费）
  - Synopsys VCS（商业）
  - Cadence Xcelium（商业）

Language（语言）：
  - Verilog
  - SystemVerilog

Run 按钮：运行仿真
Stop 按钮：停止仿真
```

---

## 4. 第一个仿真示例

### 示例 1：时钟生成

```verilog
// testbench.sv
module testbench;
    reg clk;
    reg rst_n;

    // 时钟生成：每 5ns 翻转一次（周期 10ns，频率 100MHz）
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 复位信号
    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;
        #100;
        $finish;
    end

    // 打印信息
    initial begin
        $monitor("Time=%0t clk=%b rst_n=%b", $time, clk, rst_n);
    end
endmodule
```

### 操作步骤

```
1. 打开 edaplayground.com
2. 在代码编辑区粘贴上述代码
3. 选择 Simulator: Icarus Verilog v0.9.7
4. 选择 Language: SystemVerilog/Verilog
5. 点击 [Run] 按钮
6. 观察仿真输出
```

### 预期输出

```
Time=0 clk=0 rst_n=0
Time=5 clk=1 rst_n=0
Time=10 clk=0 rst_n=0
Time=15 clk=1 rst_n=0
Time=20 clk=0 rst_n=1
Time=25 clk=1 rst_n=1
...
```

---

## 5. 查看波形

### 步骤 1：添加波形查看代码

在 testbench 中添加以下代码：

```verilog
// 在 initial 块中添加
initial begin
    $dumpfile("dump.vcd");  // 生成波形文件
    $dumpvars(0, testbench); // 记录所有信号
end
```

### 步骤 2：运行仿真

```
1. 点击 [Run] 运行仿真
2. 等待仿真完成
3. 点击 "Open in Tab" 按钮
4. 选择 "Waveform Viewer (GTKWave)"
```

### 步骤 3：在 GTKWave 中查看波形

```
GTKWave 界面：

┌─────────────────────────────────────────────────────────────┐
│  File  Edit  View  Search  Signal  Data  Time  Help        │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌─────────────────────────────────────┐ │
│  │ 信号列表     │  │  波形显示区                         │ │
│  │              │  │                                     │ │
│  │  testbench   │  │  clk  ─┐┌─┐┌─┐┌─┐┌─┐┌─┐          │ │
│  │    clk       │  │  rst_n ─┘└─┘└─┘└─┘└─┘└─┘          │ │
│  │    rst_n     │  │                                     │ │
│  │              │  │                                     │ │
│  └──────────────┘  └─────────────────────────────────────┘ │
│                                                             │
│  [Zoom In] [Zoom Out] [Zoom Fit] [Cursor]                  │
└─────────────────────────────────────────────────────────────┘
```

### 添加信号到波形

```
1. 在左侧信号列表中，双击信号名称
2. 信号会添加到波形显示区
3. 使用 Zoom Fit 按钮查看完整波形
4. 使用鼠标滚轮缩放波形
```

---

## 6. 波形解读

### 基本信号含义

| 信号 | 含义 | 波形特征 |
|---|---|---|
| **clk** | 时钟信号 | 规律的方波 |
| **rst_n** | 复位信号（低有效） | 正常为1，复位时为0 |
| **valid** | 有效信号 | 1=有效，0=无效 |
| **ready** | 就绪信号 | 1=就绪，0=忙 |
| **data** | 数据信号 | 多位总线，显示十六进制值 |

### 波形解读示例

```
时钟信号 (clk)：

  ┌───┐   ┌───┐   ┌───┐   ┌───┐
  │   │   │   │   │   │   │   │
──┘   └───┘   └───┘   └───┘   └───

  ↑       ↑       ↑       ↑
  上升沿  上升沿  上升沿  上升沿

  周期 = 两个上升沿之间的时间
  频率 = 1 / 周期
```

```
复位信号 (rst_n)：

  ──────────────────────┐           ┌──────────
                        │           │
                        └───────────┘
                        ↑           ↑
                      复位开始    复位结束

  低电平期间，系统处于复位状态
```

```
握手信号 (valid/ready)：

  valid ──────┐     ┌─────────────┐     ┌──────
              └─────┘             └─────┘

  ready ──────────────┐     ┌─────────────┐
                      └─────┘             └─────

              ↑           ↑
           传输完成    传输完成

  valid=1 且 ready=1 时，数据传输完成
```

### 测量工具

```
GTKWave 测量功能：

1. 点击 [Cursor] 按钮
2. 在波形上点击，添加光标
3. 查看时间信息：
   - 光标位置的时间
   - 两个光标之间的时间差

用途：
  - 测量时钟周期
  - 测量信号延迟
  - 测量脉冲宽度
```

---

## 7. 常用技巧

### 技巧 1：保存设计

```
1. 点击 File → Save
2. 输入设计名称
3. 生成保存链接
4. 可以随时通过链接访问
```

### 技巧 2：分享给他人

```
1. 保存设计后，复制浏览器地址栏的链接
2. 发送给同事/朋友
3. 他们打开链接即可查看代码和仿真结果
```

### 技巧 3：调试方法

```
方法 1：添加 $display 打印
  $display("Time=%0t data=%h", $time, data);

方法 2：添加 $monitor 监控
  $monitor("Time=%0t valid=%b ready=%b data=%h", 
           $time, valid, ready, data);

方法 3：查看波形
  - 找到问题时间点
  - 追踪信号变化
  - 分析原因
```

### 技巧 4：使用预设模板

```
EDA Playground 提供多种模板：
  - Basic Verilog
  - SystemVerilog
  - UVM Testbench

使用方法：
  点击 Load → 选择模板 → 修改代码
```

### 技巧 5：查看编译错误

```
如果仿真失败：
1. 查看仿真输出区的错误信息
2. 常见错误：
   - 语法错误（缺少分号、括号不匹配）
   - 信号未声明
   - 模块未定义
3. 根据错误信息修改代码
```

---

## 8. AXI 握手示例

### 简单的 valid/ready 握手仿真

```verilog
module axi_handshake_tb;
    reg clk;
    reg rst_n;
    reg valid;
    reg ready;
    reg [31:0] data;

    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 复位和激励
    initial begin
        rst_n = 0;
        valid = 0;
        ready = 0;
        data = 0;

        #20;
        rst_n = 1;

        // 第一次传输：主机发送，从机立即接收
        #10;
        valid = 1;
        ready = 1;
        data = 32'hDEAD_BEEF;
        #10;
        valid = 0;
        ready = 0;
        data = 0;

        // 第二次传输：主机发送，从机反压
        #10;
        valid = 1;
        ready = 0;  // 从机没准备好
        data = 32'hCAFE_BABE;
        #20;  // 等待 2 个周期
        ready = 1;  // 从机准备好
        #10;
        valid = 0;
        ready = 0;
        data = 0;

        #50;
        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, axi_handshake_tb);
    end

    // 打印信息
    initial begin
        $monitor("Time=%0t valid=%b ready=%b data=%h", 
                 $time, valid, ready, data);
    end
endmodule
```

### 波形解读

```
预期波形：

Time=0:   valid=0, ready=0, data=00000000  (空闲)
Time=30:  valid=1, ready=1, data=DEADBEEF (传输完成)
Time=40:  valid=0, ready=0, data=00000000 (空闲)
Time=50:  valid=1, ready=0, data=CAFEBABE (反压)
Time=70:  valid=1, ready=1, data=CAFEBABE (传输完成)
Time=80:  valid=0, ready=0, data=00000000 (空闲)

关键观察：
  - valid=1 且 ready=1 时，数据传输完成
  - valid=1 且 ready=0 时，从机反压，主机必须保持
```

---

## 9. 常见问题

### Q1：仿真很慢怎么办？

```
原因：
  - 仿真时间太长
  - 代码中有无限循环

解决：
  - 减少仿真时间（#100 → #50）
  - 检查是否有死循环
```

### Q2：波形显示不全？

```
解决：
  - 点击 Zoom Fit 按钮
  - 检查仿真时间是否足够
  - 检查 $dumpvars 是否正确
```

### Q3：找不到信号？

```
解决：
  - 检查信号是否声明
  - 检查模块层次是否正确
  - 在信号列表中搜索信号名
```

### Q4：如何查看内部信号？

```
方法：
  - 在 $dumpvars 中指定模块层次
  - 例如：$dumpvars(0, axi_handshake_tb.u_axi_master)
```

---

## 10. 学习建议

### 学习路径

```
第 1 阶段：熟悉工具（1-2天）
  - 注册账号
  - 运行第一个仿真
  - 学会查看波形

第 2 阶段：基础练习（1周）
  - 时钟、复位生成
  - 简单状态机
  - 握手协议

第 3 阶段：协议实践（2-3周）
  - AXI 握手
  - AHB 传输
  - APB 读写

第 4 阶段：项目实战（持续）
  - 完整模块验证
  - 断言编写
  - 覆盖率收集
```

### 推荐练习顺序

```
1. 时钟和复位
2. 计数器
3. 状态机
4. FIFO
5. AXI Slave
6. AHB Master
7. 完整 SoC 模块
```

---

## 总结

| 内容 | 要点 |
|---|---|
| **工具** | EDA Playground（在线免费） |
| **核心操作** | 写代码 → 运行仿真 → 查看波形 |
| **波形解读** | 时钟、复位、valid/ready 握手 |
| **调试方法** | $display 打印 + 波形分析 |
| **学习路径** | 从简单到复杂，逐步深入 |

**核心目标**：能够独立完成仿真，看懂波形，定位问题。
