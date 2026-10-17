
`timescale 1ns/1ps

module tb_async_fifo;

    reg wr_clk = 0;
    reg rd_clk = 0;

    reg wr_rst = 1;
    reg rd_rst = 1;

    reg wr_en = 0;
    reg rd_en = 0;
    reg [7:0] wr_data = 0;

    wire [7:0] rd_data;
    wire full;
    wire empty;

    integer errors = 0;
    integer i;

    reg [7:0] expected_data [0:7];

    async_fifo dut (
        .wr_clk(wr_clk),
        .wr_rst(wr_rst),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .rd_clk(rd_clk),
        .rd_rst(rd_rst),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .full(full),
        .empty(empty)
    );

    // Write clock: 100 MHz
    always #5 wr_clk = ~wr_clk;

    // Read clock: approximately 71.4 MHz
    always #7 rd_clk = ~rd_clk;

    // Write one word when the FIFO is not full
    task write_word;
        input [7:0] data;
        begin
            @(negedge wr_clk);
            wr_data = data;
            wr_en = 1;

            @(posedge wr_clk);
            #1;

            if (full) begin
                $display("ERROR: FIFO became full during accepted write");
                errors = errors + 1;
            end

            @(negedge wr_clk);
            wr_en = 0;
        end
    endtask

    // Read and compare one word
    task read_word;
        input [7:0] expected;
        begin
            wait (empty == 0);

            @(negedge rd_clk);
            rd_en = 1;

            @(posedge rd_clk);
            #1;

            if (rd_data !== expected) begin
                $display(
                    "ERROR: Expected %02h, received %02h at time %0t",
                    expected, rd_data, $time
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: Expected %02h, received %02h",
                    expected, rd_data
                );
            end

            @(negedge rd_clk);
            rd_en = 0;
        end
    endtask

    initial begin
        $dumpfile("async_fifo.vcd");
        $dumpvars(0, tb_async_fifo);

        $display("--------------------------------");
        $display("Starting Asynchronous FIFO Tests");
        $display("--------------------------------");

        // Allow both clock domains to reset
        repeat (4) @(negedge wr_clk);
        wr_rst = 0;
        rd_rst = 0;

        repeat (4) @(negedge rd_clk);

        // Test 1: FIFO should be empty after reset
        if (empty !== 1'b1) begin
            $display("ERROR: FIFO is not empty after reset");
            errors = errors + 1;
        end
        else begin
            $display("PASS: FIFO empty after reset");
        end

        // Test 2: Attempt read while empty
        @(negedge rd_clk);
        rd_en = 1;

        @(posedge rd_clk);
        #1;

        if (empty !== 1'b1) begin
            $display("ERROR: Empty flag deasserted unexpectedly");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Read while empty was blocked");
        end

        @(negedge rd_clk);
        rd_en = 0;

        // Test 3: Fill all eight entries
        $display("Test: Filling FIFO");

        for (i = 0; i < 8; i = i + 1) begin
            expected_data[i] = 8'h20 + i;
            write_word(expected_data[i]);
        end

        // Allow synchronized pointer and flag logic to settle
        wait (full == 1'b1);
        $display("PASS: FIFO full after eight writes");

        // Test 4: Attempt write while full
        @(negedge wr_clk);
        wr_data = 8'hFF;
        wr_en = 1;

        @(posedge wr_clk);
        #1;

        if (full !== 1'b1) begin
            $display("ERROR: Full flag unexpectedly deasserted");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Write while full was blocked");
        end

        @(negedge wr_clk);
        wr_en = 0;

        // Test 5: Read all eight entries in order
        $display("Test: Reading FIFO in order");

        for (i = 0; i < 8; i = i + 1)
            read_word(expected_data[i]);

        wait (empty == 1'b1);
        $display("PASS: FIFO empty after draining");

        // Test 6: Refill and drain to exercise pointer wraparound
        $display("Test: Pointer wraparound");

        for (i = 0; i < 8; i = i + 1) begin
            expected_data[i] = 8'hA0 + i;
            write_word(expected_data[i]);
        end

        wait (full == 1'b1);

        for (i = 0; i < 8; i = i + 1)
            read_word(expected_data[i]);

        wait (empty == 1'b1);
        $display("PASS: Pointer wraparound test completed");

        // Final result
        $display("--------------------------------");

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d errors", errors);

        $display("--------------------------------");
        $finish;
    end

    // Prevent simulation from running indefinitely
    initial begin
        #10000;
        $display("ERROR: Simulation timeout");
        $finish;
    end

endmodule
