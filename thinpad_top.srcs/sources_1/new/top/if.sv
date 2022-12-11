`default_nettype none

module if_state (
    input wire clk,
    input wire rst,
    input wire[31:0] pc,
    input wire if_we,
    input wire empty,
    output reg[31:0] inst, //解析跳转指令
    output reg if_ack,
    output reg[31:0] pc_o,
    output reg is_jump, //是否为跳转指令

    output reg [31:0] mmu_r_addr,
    input wire [31:0] mmu_r_data,
    output reg mmu_r_we,
    input wire mmu_r_ack,

    output reg cache_clear,
    input wire cache_clear_ack,

    output reg mmu_clear
);
    typedef enum logic [2:0] {
        ST_IDLE,
        READ_WAIT_ACTION,
        WAIT_CACHE_CLEAR,
        WAIT_MMU_CLEAR,
        WAIT
    } state_t;
    state_t state;
    always_comb begin
        //跳转指令            JAL                        JALR                    BEQ 和 BNE
        if (inst[6:0] == 7'b1101111 || inst[6:0] == 7'b1100111 || inst[6:0] == 7'b1100011)begin
            is_jump = 1'b1; //是跳转指令
        end else begin
            is_jump = 1'b0; //不是跳转指令
        end
    end

    always @(posedge clk) begin
        if (rst == 1'b1) begin
            inst <= 32'h00000013;
            pc_o <= 32'b0;
            if_ack <= 1'b0;
            mmu_r_we <= 1'b0;
            mmu_clear <= 1'b0;
            cache_clear <= 1'b0;
            state <= ST_IDLE;
        end else if (if_we == 1'b1 && empty == 1'b1) begin //气泡
            inst <= 32'h00000013;
            pc_o <= 32'b0;
            if_ack <= 1'b1;
            mmu_r_we <= 1'b0;
            state <= ST_IDLE;
            mmu_clear <= 1'b0;
            cache_clear <= 1'b0;
        end else if (if_we) begin //工作
            case (state)
                ST_IDLE: begin
                    mmu_r_we <= 1'b1;
                    mmu_r_addr <= pc;
                    pc_o <= pc;
                    if_ack <= 1'b0;
                    cache_clear <= 1'b0;
                    state <= READ_WAIT_ACTION;
                    mmu_clear <= 1'b0;
                    cache_clear <= 1'b0;
                end
                READ_WAIT_ACTION: begin
                    if (mmu_r_ack == 1'b1) begin
                        inst <= mmu_r_data;
                        mmu_r_we <= 1'b0;
                        if (mmu_r_data[6:0] == 7'b0001111) begin
                            cache_clear <= 1'b1;
                            state <= WAIT_CACHE_CLEAR;
                        end else if (mmu_r_data[14:0] == 15'b1110011 && mmu_r_data[31:25] == 7'b1001) begin
                            mmu_clear <= 1'b1;
                            state <= WAIT_MMU_CLEAR;
                        end else begin
                            if_ack <= 1'b1;
                            state <= WAIT;
                        end
                    end
                end
                WAIT_CACHE_CLEAR: begin
                    if (cache_clear_ack == 1'b1) begin
                        cache_clear <= 1'b0;
                        state <= WAIT;
                        if_ack <= 1'b1;
                    end
                end
                WAIT_MMU_CLEAR: begin
                    mmu_clear <= 1'b0;
                    state <= WAIT;
                    if_ack <= 1'b1;
                end
                WAIT: begin//得到正确的指令
                    if_ack <= 1'b0;
                    cache_clear <= 1'b0;
                    mmu_clear <= 1'b0;    
                    state <= ST_IDLE;
                    mmu_r_we <= 1'b0;
                end
            endcase
        end
        else begin
            state <= ST_IDLE;
            if_ack = 1'b0;
            mmu_r_we <= 1'b0;
        end
    end
endmodule