
`timescale 1ns/1ps

module async_fifo (
    input        wr_clk,
    input        wr_rst,
    input        wr_en,
    input  [7:0] wr_data,

    input        rd_clk,
    input        rd_rst,
    input        rd_en,
    output reg [7:0] rd_data,

    output       full,
    output       empty
);

    reg [7:0] mem [0:7];

    reg [3:0] wr_ptr, rd_ptr;
    reg [3:0] wr_gray, rd_gray;

    reg [3:0] rd_gray_sync1, rd_gray_sync2;
    reg [3:0] wr_gray_sync1, wr_gray_sync2;

    wire [3:0] wr_ptr_next = wr_ptr + 4'd1;
    wire [3:0] rd_ptr_next = rd_ptr + 4'd1;

    // Binary-to-Gray conversion
    wire [3:0] wr_gray_next =
        wr_ptr_next ^ (wr_ptr_next >> 1);

    wire [3:0] rd_gray_next =
        rd_ptr_next ^ (rd_ptr_next >> 1);

    // Full and empty detection
    assign full =
        (wr_gray ==
        {~rd_gray_sync2[3:2], rd_gray_sync2[1:0]});

    assign empty = (rd_gray == wr_gray_sync2);

    // Write clock domain
    always @(posedge wr_clk) begin
        if (wr_rst) begin
            wr_ptr  <= 4'b0000;
            wr_gray <= 4'b0000;
        end
        else if (wr_en && !full) begin
            mem[wr_ptr[2:0]] <= wr_data;
            wr_ptr  <= wr_ptr_next;
            wr_gray <= wr_gray_next;
        end
    end

    // Read clock domain
    always @(posedge rd_clk) begin
        if (rd_rst) begin
            rd_ptr  <= 4'b0000;
            rd_gray <= 4'b0000;
            rd_data <= 8'b0;
        end
        else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr[2:0]];
            rd_ptr  <= rd_ptr_next;
            rd_gray <= rd_gray_next;
        end
    end

    // Synchronize read pointer into write domain
    always @(posedge wr_clk) begin
        if (wr_rst) begin
            rd_gray_sync1 <= 4'b0000;
            rd_gray_sync2 <= 4'b0000;
        end
        else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;
        end
    end

    // Synchronize write pointer into read domain
    always @(posedge rd_clk) begin
        if (rd_rst) begin
            wr_gray_sync1 <= 4'b0000;
            wr_gray_sync2 <= 4'b0000;
        end
        else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
        end
    end

endmodule
