// AXI4 Burst 传输示例
// 演示 INCR 类型突发：一次地址，连续传输多个数据
module axi_burst_tb;
    reg clk;
    reg rst_n;

    // 写地址通道
    reg awvalid;
    reg awready;
    reg [3:0] awid;
    reg [31:0] awaddr;
    reg [7:0] awlen;    // 突发长度：0=1拍，1=2拍，...，3=4拍
    reg [2:0] awsize;   // 突发大小：2=4字节
    reg [1:0] awburst;  // 突发类型：01=INCR

    // 写数据通道
    reg wvalid;
    reg wready;
    reg [31:0] wdata;
    reg [3:0] wstrb;
    reg wlast;

    // 写响应通道
    reg bvalid;
    reg bready;
    reg [1:0] bresp;

    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 波形输出
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, axi_burst_tb);
    end

    // 从机模型：收到地址后，依次接收4拍数据
    reg [2:0] beat_cnt;  // 拍计数

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awready <= 0;
            wready <= 0;
            bvalid <= 0;
            bresp <= 0;
            beat_cnt <= 0;
        end else begin
            // AW 通道：接受地址
            if (awvalid && !awready) begin
                awready <= 1;
                beat_cnt <= 0;
            end else begin
                awready <= 0;
            end

            // W 通道：接受数据
            if (wvalid && !wready) begin
                wready <= 1;
                beat_cnt <= beat_cnt + 1;
                // 最后一拍时拉高 wlast
                if (beat_cnt == awlen) begin
                    bvalid <= 1;
                    bresp <= 2'b00;  // OKAY
                end
            end else begin
                wready <= 0;
            end

            // B 通道：发送响应
            if (bvalid && bready) begin
                bvalid <= 0;
            end
        end
    end

    // 主机模型：发送地址 + 4拍数据
    integer i;

    initial begin
        rst_n = 0;
        awvalid = 0;
        awid = 0;
        awaddr = 0;
        awlen = 0;
        awsize = 0;
        awburst = 0;
        wvalid = 0;
        wdata = 0;
        wstrb = 0;
        wlast = 0;
        bready = 0;

        #20;
        rst_n = 1;

        // ==============================
        // 场景：INCR 突发，4拍，每拍4字节
        // 起始地址：0x0000_1000
        // 数据：0xDEAD0001, 0xDEAD0002, 0xDEAD0003, 0xDEAD0004
        // ==============================

        #10;

        // 1. 发送写地址（AW通道）
        awvalid = 1;
        awid = 4'hA;
        awaddr = 32'h0000_1000;
        awlen = 8'd3;       // 4拍（len+1）
        awsize = 3'b010;    // 每拍4字节
        awburst = 2'b01;    // INCR类型
        @(posedge clk);     // 等待时钟沿
        while (!awready) @(posedge clk);  // 等待从机准备好
        awvalid = 0;

        // 2. 发送4拍数据（W通道）
        for (i = 0; i < 4; i = i + 1) begin
            @(posedge clk);
            wvalid = 1;
            wdata = 32'hDEAD_0000 + i + 1;
            wstrb = 4'hF;    // 全字节有效
            wlast = (i == 3) ? 1 : 0;  // 最后一拍拉高
            while (!wready) @(posedge clk);  // 等待从机准备好
        end
        wvalid = 0;
        wlast = 0;

        // 3. 等待写响应（B通道）
        bready = 1;
        while (!bvalid) @(posedge clk);
        @(posedge clk);
        bready = 0;

        #50;
        $finish;
    end
endmodule
