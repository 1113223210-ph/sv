---
title: "Class 实用示例"
description: "SystemVerilog面向对象编程实用示例"
pubDate: 2025-01-01
category: sv
order: 4
tags: [SV, class, 面向对象]
---

# Class 实用示例

## 示例1：基础transaction

```verilog
class transaction;
    // 属性
    logic [31:0] addr;
    logic [31:0] data;
    logic        wr;      // 1=写, 0=读

    // 构造函数
    function new(input logic [31:0] a = 0, 
                 input logic [31:0] d = 0, 
                 input logic        w = 1);
        addr = a;
        data = d;
        wr   = w;
    endfunction

    // 显示方法
    function void display();
        $display("wr=%b, addr=%h, data=%h", wr, addr, data);
    endfunction
endclass

// 使用
transaction txn;
initial begin
    txn = new(32'h100, 32'hABCD, 1);  // 写操作
    txn.display();
    
    txn = new(32'h200, 0, 0);         // 读操作
    txn.display();
end
```

---

## 示例2：继承 - 基础与扩展transaction

```verilog
// 基础transaction
class base_transaction;
    logic [31:0] addr;
    logic        wr;

    function new(input logic [31:0] a = 0, input logic w = 0);
        addr = a;
        wr   = w;
    endfunction

    function void display();
        $display("wr=%b, addr=%h", wr, addr);
    endfunction
endclass

// 扩展transaction（增加data字段）
class ext_transaction extends base_transaction;
    logic [31:0] data;

    function new(input logic [31:0] a = 0, 
                 input logic [31:0] d = 0, 
                 input logic w = 0);
        super.new(a, w);  // 调用父类
        data = d;
    endfunction

    // 重写display
    function void display();
        $display("wr=%b, addr=%h, data=%h", wr, addr, data);
    endfunction
endclass

// 使用
ext_transaction ext_txn;
initial begin
    ext_txn = new(32'h100, 32'hDEAD_BEEF, 1);
    ext_txn.display();
end
```

---

## 示例3：随机化 - 带约束的transaction

```verilog
class rand_transaction;
    rand logic [31:0] addr;
    rand logic [31:0] data;
    rand logic        wr;
    randc bit [7:0]   id;     // 循环不重复

    // 地址约束：0x000~0x0FF
    constraint c_addr {
        addr inside {[32'h0000:32'h00FF]};
    }

    // 数据约束：不能为0
    constraint c_data {
        data != 0;
    }

    // 写操作时数据范围
    constraint c_wr_data {
        if (wr)
            data inside {[32'h0000:32'h0000_FFFF]};
    }
endclass

// 使用
rand_transaction txn;
initial begin
    txn = new();
    repeat(5) begin
        assert(txn.randomize())
            $display("id=%0d, wr=%b, addr=%h, data=%h", 
                     txn.id, txn.wr, txn.addr, txn.data);
    end
end
```

---

## 示例4：队列 - 存储多个transaction

```verilog
class transaction_queue;
    transaction queue[$];  // 队列存储transaction

    // 入队
    function void push(transaction txn);
        queue.push_back(txn);
    endfunction

    // 出队
    function transaction pop();
        return queue.pop_front();
    endfunction

    // 显示所有
    function void display_all();
        foreach(queue[i])
            $display("[%0d] %h", i, queue[i].addr);
    endfunction
endclass

// 使用
transaction_queue tq;
transaction txn;

initial begin
    tq = new();
    
    // 添加多个transaction
    repeat(5) begin
        txn = new($urandom_range(0, 255), $urandom);
        tq.push(txn);
    end
    
    tq.display_all();
end
```

---

## 示例5：driver - 驱动DUT

```verilog
class driver;
    virtual axi_if vif;  // 虚接口连接DUT

    function new(virtual axi_if vif);
        this.vif = vif;  // this.访问成员变量
    endfunction

    // 写操作
    task write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge vif.clk);
        vif.awvalid <= 1;
        vif.awaddr  <= addr;
        @(posedge vif.clk);
        vif.wvalid  <= 1;
        vif.wdata   <= data;
        @(posedge vif.clk);
        vif.wvalid  <= 0;
        vif.awvalid <= 0;
    endtask

    // 读操作
    task read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge vif.clk);
        vif.arvalid <= 1;
        vif.araddr  <= addr;
        @(posedge vif.clk);
        vif.arvalid <= 0;
        @(posedge vif.rvalid);
        data = vif.rdata;
    endtask
endclass

// 使用
driver drv;
initial begin
    drv = new(vif);  // 传入接口
    drv.write(32'h100, 32'hDEAD_BEEF);
end
```

---

## 示例6：monitor - 采集DUT信号

```verilog
class monitor;
    virtual axi_if vif;
    transaction txn;

    function new(virtual axi_if vif);
        this.vif = vif;
    endfunction

    // 监测写操作
    task run();
        forever begin
            @(posedge vif.clk);
            if (vif.awvalid && vif.awready) begin
                txn = new(vif.awaddr, vif.wdata, 1);
                $display("Monitor: %h", txn.addr);
            end
        end
    endtask
endclass

// 使用
monitor mon;
initial begin
    mon = new(vif);
    mon.run();
end
```

---

## 示例7：scoreboard - 比较结果

```verilog
class scoreboard;
    int pass_count = 0;
    int fail_count = 0;

    // 比较预期和实际
    function void check(input logic [31:0] expected, 
                        input logic [31:0] actual);
        if (expected === actual) begin
            $display("PASS: %h == %h", expected, actual);
            pass_count++;
        end else begin
            $display("FAIL: %h != %h", expected, actual);
            fail_count++;
        end
    endfunction

    // 显示统计
    function void report();
        $display("Pass: %0d, Fail: %0d", pass_count, fail_count);
    endfunction
endclass
```

---

## 示例8：parameterized class - 参数化类

```verilog
// 通用FIFO类，位宽可配置
class fifo #(parameter WIDTH = 8, DEPTH = 16);
    logic [WIDTH-1:0] queue[$];

    function void push(input logic [WIDTH-1:0] data);
        if (queue.size() < DEPTH)
            queue.push_back(data);
        else
            $error("FIFO full");
    endfunction

    function logic [WIDTH-1:0] pop();
        if (queue.size() > 0)
            return queue.pop_front();
        else
            $error("FIFO empty");
    endfunction

    function int size();
        return queue.size();
    endfunction
endclass

// 使用
fifo #(8, 16)   fifo8;    // 8位宽，深度16
fifo #(32, 64)  fifo32;   // 32位宽，深度64

initial begin
    fifo8 = new();
    fifo8.push(8'hAA);
    fifo8.push(8'hBB);
end
```

---

*最后更新: 2026-07-15*