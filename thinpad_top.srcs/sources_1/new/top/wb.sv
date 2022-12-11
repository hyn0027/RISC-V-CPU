`default_nettype none

module wb (
    input wire clk,
    input wire rst,
    input wire wb_we,
    input reg empty,
    output reg wb_ack,
    input wire [31:0] pc_i,

    input wire rf_wen_i,
    input wire [4:0] rf_waddr_i,
    input wire [31:0] rf_wdata_i,
    input wire [11:0] csr_waddr_a_i,
    input wire [31:0] csr_wdata_a_i,
    input wire [11:0] csr_waddr_b_i,
    input wire [31:0] csr_wdata_b_i,
    input wire [11:0] csr_waddr_c_i,
    input wire [31:0] csr_wdata_c_i,
    input wire [1:0]  csr_we_i,

    output reg [31:0] pc_o,
  
    output reg  [4:0]  rf_waddr,
    output reg  [31:0] rf_wdata,
    output reg  rf_we,

    output reg [11:0] csr_waddr_a,
    output reg [31:0] csr_wdata_a,
    output reg [11:0] csr_waddr_b,
    output reg [31:0] csr_wdata_b,
    output reg [11:0] csr_waddr_c,
    output reg [31:0] csr_wdata_c,
    output reg [1:0]  csr_we
);

    typedef enum logic[1:0] {
        IDLE,
        WAIT
    } state_t;

    state_t state;

    always_ff @(posedge clk) begin
        if (rst == 1'b1) begin
            wb_ack <= 1'b0;
            rf_we <= 1'b0;
            csr_we <= 2'b0;
            state <= IDLE;
        end else if (wb_we == 1'b1 && empty == 1'b1) begin
            wb_ack <= 1'b1;
            rf_we <= 1'b0;
            csr_we <= 2'b0;
            state <= IDLE;
        end else if (wb_we == 1'b1) begin
            case (state) 
                IDLE: begin
                    pc_o <= pc_i;
                    wb_ack <= 1'b1;
                    state <= WAIT;
                    if (rf_wen_i == 1'b1 && csr_we_i != 2'b0) begin
                        rf_we <= 1'b1;
                        rf_waddr <= rf_waddr_i;
                        rf_wdata <= rf_wdata_i;
                        csr_we <= csr_we_i;
                        csr_waddr_a <= csr_waddr_a_i;
                        csr_wdata_a <= csr_wdata_a_i;
                        csr_waddr_b <= csr_waddr_b_i;
                        csr_wdata_b <= csr_wdata_b_i;
                        csr_waddr_c <= csr_waddr_c_i;
                        csr_wdata_c <= csr_wdata_c_i;
                    end else if (rf_wen_i == 1'b1) begin
                        rf_we <= 1'b1;
                        rf_waddr <= rf_waddr_i;
                        rf_wdata <= rf_wdata_i;
                    end else if (csr_we_i != 2'b0) begin
                        csr_we <= csr_we_i;
                        csr_waddr_a <= csr_waddr_a_i;
                        csr_wdata_a <= csr_wdata_a_i;
                        csr_waddr_b <= csr_waddr_b_i;
                        csr_wdata_b <= csr_wdata_b_i;
                        csr_waddr_c <= csr_waddr_c_i;
                        csr_wdata_c <= csr_wdata_c_i;
                    end
                end
                WAIT: begin
                    rf_we <= 1'b0;
                    csr_we <= 2'b0;
                    wb_ack <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end else begin
            wb_ack <= 1'b0;
            state <= IDLE;
        end
    end

endmodule