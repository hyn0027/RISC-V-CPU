`default_nettype none

module clint(
    input wire clk,
    input wire rst,

    input wire  [31:0] clint_raddr_a,
    output reg  [31:0] clint_rdata_a,

    input wire  [31:0] clint_waddr_a,
    input wire  [31:0] clint_wdata_a,
    input wire  clint_we,

    output wire  [31:0] mtime_low,
    output wire  [31:0] mtime_high,
    output wire  [31:0] mtimecmp_low,
    output wire  [31:0] mtimecmp_high

);

    logic [31:0] reg_file [0:3];
    // logic [31:0] clint_rdata_a_reg;
    // logic timeout_reg;

    // assign clint_rdata_a = clint_rdata_a_reg;
    // assign timeout = timeout_reg;
    assign mtime_low = reg_file[0];
    assign mtime_high = reg_file[1];
    assign mtimecmp_low = reg_file[2];
    assign mtimecmp_high = reg_file[3];
    always_comb begin
        clint_rdata_a = 32'b0;
        case (clint_raddr_a)
            32'h200BFF8:
                clint_rdata_a = reg_file[0];
            32'h200BFFC:
                clint_rdata_a = reg_file[1];
            32'h2004000:
                clint_rdata_a = reg_file[2];
            32'h2004004:
                clint_rdata_a = reg_file[3];
        endcase
    end
    
    logic [4:0] counter;
    logic enter;
    always_ff @(posedge clk) begin
        if (rst || enter) begin
            counter <= 5'b0;
        end else begin
            if (counter == 5'ha) begin
                counter <= 5'b0;
            end else begin
                counter <= counter + 1;
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if (rst) begin
            enter <= 1'b0;
            reg_file[0] <= 32'b0;
            reg_file[1] <= 32'b0;
            reg_file[2] <= 32'hFFFFFFFF;
            reg_file[3] <= 32'hFFFFFFFF;
        end else if (clint_we) begin
            case (clint_waddr_a)
                32'h200BFF8:
                    reg_file[0] <= clint_wdata_a;
                32'h200BFFC:
                    reg_file[1] <= clint_wdata_a;
                32'h2004000:
                    reg_file[2] <= clint_wdata_a;
                32'h2004004:
                    reg_file[3] <= clint_wdata_a;
            endcase
            enter <= 1'b1;
        end else if (counter == 5'ha) begin
            reg_file[0] <= reg_file[0]+1;
            if (reg_file[0] + 1 < reg_file[0]) begin
                reg_file[1] <= reg_file[1] + 1;
            end
        end else begin
            enter <= 1'b0;
        end
    end
endmodule