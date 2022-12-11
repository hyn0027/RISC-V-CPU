`default_nettype none

module pc_mux(
    input wire clk,
    input wire rst,

    input wire pc_we,
    input wire PCSel,
    input wire [31:0] pc_i,
    output wire[31:0] pc
);
    reg [31:0] pc_reg;

    always @(posedge clk) begin
        if (rst == 1'b1) begin
            pc_reg <= 32'h80000000;
        end else if (pc_we == 1'b1) begin
            if (PCSel == 1'b0) begin
                pc_reg <= pc_reg + 32'd4;
            end else begin
                pc_reg <= pc_i;
            end
        end
    end
    assign pc = pc_reg;
endmodule