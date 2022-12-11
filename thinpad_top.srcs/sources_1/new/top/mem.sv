`default_nettype none

module mem(
    input wire clk,
    input wire rst,
    input wire mem_we,
    input reg empty,
    output reg mem_ack,

    input wire mem_w_en,
    input wire mem_r_en,
    input wire [31:0] mem_w_data,
    input wire [31:0] ex_data_i, 
    input wire [7:0] inst_type_i,
    input wire rf_wen_i,
    input wire [4:0] rf_waddr_i,
    input wire [31:0] pc_i,
    input wire [11:0] csr_waddr_a_i,
    input wire [31:0] csr_wdata_a_i,
    input wire [11:0] csr_waddr_b_i,
    input wire [31:0] csr_wdata_b_i,
    input wire [11:0] csr_waddr_c_i,
    input wire [31:0] csr_wdata_c_i,
    input wire [1:0]  csr_we_i,

    output reg [7:0] inst_type_o,
    output reg [31:0] pc_o,
    output reg rf_wen_o,
    output reg [4:0] rf_waddr_o,
    output reg [31:0] rf_wdata_o,
    output reg [11:0] csr_waddr_a_o,
    output reg [31:0] csr_wdata_a_o,
    output reg [11:0] csr_waddr_b_o,
    output reg [31:0] csr_wdata_b_o,
    output reg [11:0] csr_waddr_c_o,
    output reg [31:0] csr_wdata_c_o,
    output reg [1:0]  csr_we_o,

    output reg mmu_we,//mmu工不工作
    input wire mmu_ack,//mmu是不是做完了
    output reg [31:0] mmu_w_data,//给mmu写的数据
    output reg [31:0] mmu_addr,//给mmu写的地址
    output reg [3:0] mmu_sel_o,
    output reg  mmu_w_or_r,//mmu 写1 或者 读0
    input wire [31:0] mmu_data_i,//从mmu读到的数据

    output reg  [31:0] clint_raddr_a,
    input wire  [31:0] clint_rdata_a,

    output reg  [31:0] clint_waddr_a,
    output reg  [31:0] clint_wdata_a,
    output reg  clint_we,

    output reg cache_clear,
    input wire cache_clear_ack,
    
    output reg mmu_clear
);

    typedef enum logic[2:0] {
        IDLE,
        WRITE_ACTION,
        READ_ACTION,
        CLINT,
        CACHE_CLEAR,
        MMU_CLEAR,
        WAIT
    } state_t;
    state_t state;

    typedef enum logic[7:0] {
        LUI,//0
        BEQ,//1
        LB,//2
        SB,//3
        SW,//4
        ADDI,//5
        ANDI,//6
        ADD,//7
        AND,//8
        OR,//9
        ORI,//a
        SLLI, //b
        SRLI, //c
        XOR, //d
        BNE, //e
        LW, //f
        AUIPC, //10
        JAL, //11
        JALR, //12
        XNOR, //13
        MIN, //14
        CTZ, //15
        SLTU, //16
        CSRRW, //17
        CSRRC, //18
        CSRRS, //19
        ECALL, //1a
        EBREAK, //1b
        MRET, //1c
        EXCEPT, //1d
        INVALID ,//1e
        FENCE, // 1f
        SFENCE_VMA,
        SLTI,
        SLTIU,
        XORI,
        SRAI,
        SUB,
        SLL,
        SLT,
        SRL,
        SRA,
        BLT,
        BGE,
        BLTU,
        BGEU,
        LH,
        LBU,
        LHU,
        SH,
        CSRRWI,
        CSRRSI,
        CSRRCI,
        SRET
    } instType;

    // logic [7:0] inst_type_reg;

    always @(posedge clk) begin
        if (rst == 1'b1) begin
            rf_wen_o <= 1'b0;
            rf_waddr_o <= 5'b0;
            rf_wdata_o <= 32'b0;
            csr_we_o <= 2'b0;
            csr_waddr_a_o <= 12'b0;
            csr_wdata_a_o <= 32'b0;
            csr_waddr_b_o <= 12'b0;
            csr_wdata_b_o <= 32'b0;
            csr_waddr_c_o <= 12'b0;
            csr_wdata_c_o <= 32'b0;
            clint_waddr_a <= 32'b0;
            clint_raddr_a <= 32'b0;
            clint_wdata_a <= 32'b0;
            clint_we <= 1'b0;
            cache_clear <= 1'b0;
            mmu_we <= 1'b0;
            mmu_clear <= 1'b0;
            mem_ack <= 1'b0;
            inst_type_o <= ADDI;
            state <= IDLE;
        end else if (mem_we == 1'b1 && empty == 1'b1) begin 
            inst_type_o <= ADDI;
            rf_wen_o <= 1'b0;
            rf_waddr_o <= 5'b0;
            rf_wdata_o <= 32'b0;
            csr_we_o <= 2'b0;
            csr_waddr_a_o <= 12'b0;
            csr_wdata_a_o <= 32'b0;
            csr_waddr_b_o <= 12'b0;
            csr_wdata_b_o <= 32'b0;
            csr_waddr_c_o <= 12'b0;
            csr_wdata_c_o <= 32'b0;
            clint_waddr_a <= 32'b0;
            clint_raddr_a <= 32'b0;
            clint_wdata_a <= 32'b0;
            clint_we <= 1'b0;
            cache_clear <= 1'b0;
            mmu_we <= 1'b0;
            mmu_clear <= 1'b0;
            mem_ack <= 1'b1;
            state <= IDLE;
        end else if (mem_we == 1'b1) begin 
            case (state)
                IDLE: begin
                    pc_o <= pc_i;
                    inst_type_o <= inst_type_i;
                    rf_wen_o <= rf_wen_i;
                    rf_waddr_o <= rf_waddr_i;
                    csr_waddr_a_o <= csr_waddr_a_i;
                    csr_wdata_a_o <= csr_wdata_a_i;
                    csr_waddr_b_o <= csr_waddr_b_i;
                    csr_wdata_b_o <= csr_wdata_b_i;
                    csr_waddr_c_o <= csr_waddr_c_i;
                    csr_wdata_c_o <= csr_wdata_c_i;
                    csr_we_o <= csr_we_i;
                    if (inst_type_i == FENCE) begin
                        cache_clear <= 1'b1;
                        mmu_we <= 1'b0;
                        mmu_clear <= 1'b0;
                        mem_ack <= 1'b0;
                        rf_wdata_o <= 32'b0;
                        state <= CACHE_CLEAR;
                    end else if (inst_type_i == SFENCE_VMA) begin
                        mmu_clear <= 1'b1;
                        mmu_we <= 1'b0;
                        cache_clear <= 1'b0;
                        mem_ack <= 1'b0;
                        rf_wdata_o <= 32'b0;
                        state <= MMU_CLEAR;
                    end else if (mem_w_en) begin //写内存
                        // sb sw
                        if (ex_data_i == 32'h200BFF8 || ex_data_i == 32'h200BFFC || ex_data_i == 32'h2004000 || ex_data_i == 32'h2004004) begin
                            mem_ack <= 1'b0;
                            cache_clear <= 1'b0;
                            mmu_clear <= 1'b0;
                            mmu_we <= 1'b0;
                            clint_waddr_a <= ex_data_i;
                            clint_wdata_a <= mem_w_data;
                            clint_we <= 1'b1;
                            // inst_type_reg <= inst_type_i;
                            state <= CLINT;
                        end else begin
                            mem_ack <= 1'b0;
                            mmu_we <= 1'b1;//mmu工作
                            mmu_clear <= 1'b0;
                            cache_clear <= 1'b0;
                            mmu_addr <= ex_data_i;
                            mmu_w_data <= mem_w_data;
                            // inst_type_reg <= inst_type_i;
                            if (inst_type_i == SB) begin
                                mmu_sel_o <= (4'b0001 << (ex_data_i[1:0]));
                            end else if (inst_type_i == SH) begin
                                mmu_sel_o <= (4'b0011 << (ex_data_i[1:0]));
                            end else begin
                                mmu_sel_o <= 4'b1111;
                            end
                            mmu_w_or_r <= 1'b1;
                            state <= WRITE_ACTION;
                        end
                    end else if (mem_r_en) begin //读内存
                        // lb
                        if (ex_data_i == 32'h200BFF8 || ex_data_i == 32'h200BFFC || ex_data_i == 32'h2004000 || ex_data_i == 32'h2004004) begin
                            mem_ack <= 1'b0;
                            mmu_clear <= 1'b0;
                            mmu_we <= 1'b0;
                            cache_clear <= 1'b0;
                            clint_raddr_a <= ex_data_i;
                            // inst_type_reg <= inst_type_i;
                            state <= CLINT;
                        end else begin
                            mem_ack <= 1'b0;
                            mmu_clear <= 1'b0;
                            cache_clear <= 1'b0;
                            mmu_we <= 1'b1;//mmu工作
                            mmu_addr <= ex_data_i;
                            // inst_type_reg <= inst_type_i;
                            if (inst_type_i == LB || inst_type_i == LBU) begin
                                mmu_sel_o <= (4'b0001 << (ex_data_i[1:0]));
                            end else if (inst_type_i == LH || inst_type_i == LHU) begin
                                mmu_sel_o <= (4'b0011 << (ex_data_i[1:0]));
                            end else begin
                                mmu_sel_o <= 4'b1111;
                            end
                            mmu_w_or_r <= 1'b0;//mmu读
                            state <= READ_ACTION;
                        end
                    end else begin
                        rf_wdata_o <= ex_data_i;
                        mem_ack <= 1'b1;
                        state <= WAIT;
                    end
                end
                WRITE_ACTION: begin //写
                    if (mmu_ack == 1'b1) begin
                        mmu_we <= 1'b0;
                        mmu_addr <= 32'h0;
                        mmu_sel_o <= 4'b0;
                        mmu_w_or_r <= 1'b0;
                        mem_ack <= 1'b1;
                        state <= WAIT;
                    end
                end
                READ_ACTION: begin //读
                    if (mmu_ack == 1'b1) begin //收到mmu的ack（mmu工作完成）
                        mmu_we <= 1'b0;
                        mmu_addr <= 32'h0;
                        mmu_sel_o <= 4'b0;
                        mmu_w_or_r <= 1'b0;
                        if (inst_type_o == LB) begin
                            if (mmu_data_i[7] == 1'b1) rf_wdata_o <= {24'hfff, mmu_data_i[7:0]};
                            else rf_wdata_o <= {24'h0, mmu_data_i[7:0]};
                        end else if (inst_type_o == LH) begin
                            if (mmu_data_i[15] == 1'b1) rf_wdata_o <= {16'hff, mmu_data_i[15:0]};
                            else rf_wdata_o <= {16'h0, mmu_data_i[15:0]};
                        end else begin
                            rf_wdata_o <= mmu_data_i;
                        end
                        mem_ack <= 1'b1;
                        state <= WAIT;
                    end
                end
                CLINT: begin
                    mem_ack <= 1'b1;
                    if (inst_type_o == LB || inst_type_o == LBU || inst_type_o == LH || inst_type_o == LHU || inst_type_o == LW) begin
                        rf_wdata_o <= clint_rdata_a;
                    end else if (inst_type_o == SB || inst_type_o == SH || inst_type_o == SW) begin
                        clint_we <= 1'b0;
                    end
                    state <= WAIT;
                end
                CACHE_CLEAR: begin
                    if (cache_clear_ack == 1'b1) begin
                        cache_clear <= 1'b0;
                        mem_ack <= 1'b1;
                        state <= WAIT;
                    end
                end
                MMU_CLEAR: begin
                    mmu_clear <= 1'b0;
                    mem_ack <= 1'b1;
                    state <= WAIT;
                end
                WAIT: begin
                    mem_ack <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end else begin
            mem_ack <= 1'b0;
            state <= IDLE;
        end
    end


endmodule