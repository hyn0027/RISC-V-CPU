`default_nettype none

module regfile_new(
    input wire clk,
    input wire rst,

    input wire [4:0] rf_raddr_a,
    output reg [31:0] rf_rdata_a,

    input wire [4:0] rf_raddr_b,
    output reg [31:0] rf_rdata_b,

    input wire [4:0] rf_waddr,
    input wire [31:0] rf_wdata,
    input wire rf_we,

    input wire pl_we_1,
    input wire [4:0] pl_addr_1,
    input wire[31:0] pl_data_1,

    input wire pl_we_2,
    input wire [4:0] pl_addr_2,
    input wire[31:0] pl_data_2

);
    reg [31:0] reg_file [0:31];
    
    always_comb begin
        if (rf_raddr_a == 5'b0) begin
            rf_rdata_a = 32'b0;
        end else if (pl_we_2 == 1'b1 && rf_raddr_a == pl_addr_2)begin
            rf_rdata_a = pl_data_2;
        end else if (pl_we_1 == 1'b1 && rf_raddr_a == pl_addr_1)begin
            rf_rdata_a = pl_data_1;
        end else if (rf_we == 1'b1 && rf_raddr_a == rf_waddr)begin
            rf_rdata_a = rf_wdata;
        end else begin
            rf_rdata_a = reg_file[rf_raddr_a];
        end

        if (rf_raddr_b == 5'b0) begin
            rf_rdata_b = 32'b0;
        end else if (pl_we_2 == 1'b1 && rf_raddr_b == pl_addr_2)begin
            rf_rdata_b = pl_data_2;
        end else if (pl_we_1 == 1'b1 && rf_raddr_b == pl_addr_1)begin
            rf_rdata_b = pl_data_1;
        end else if (rf_we == 1'b1 && rf_raddr_b == rf_waddr)begin
            rf_rdata_b = rf_wdata;
        end else begin
            rf_rdata_b = reg_file[rf_raddr_b];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            reg_file[10] <= 32'b0;
            reg_file[11] <= 32'h1020;
        end else if (rf_we && rf_waddr != 5'b0) begin
            reg_file[rf_waddr] <= rf_wdata;
        end
    end
endmodule