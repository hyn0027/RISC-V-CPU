`default_nettype none

module exe (
    input wire clk,
    input wire rst,
    input wire exe_we,
    input reg empty,
    output reg exe_ack,

    input wire ex_en, 
    input wire [3:0] alu_op_i,
    input wire [3:0] imm_type,
    input wire [31:0] imm,
    input wire [31:0] data_a,
    input wire [31:0] data_b,
    input wire [31:0] data_c,
    input wire use_rs1,
    input wire use_rs2,
    input wire [31:0]pc_i,
    input wire use_csr_alu,
    input wire use_csr_alu_imm,
    
    input wire mem_w_en_i,
    input wire mem_r_en_i,
    input wire [7:0] inst_type_i,
    input wire rf_wen_i,
    input wire [4:0] rf_waddr_i,
    input wire [11:0] csr_waddr_a_i,
    input wire [31:0] csr_wdata_a_i,
    input wire [11:0] csr_waddr_b_i,
    input wire [31:0] csr_wdata_b_i,
    input wire [11:0] csr_waddr_c_i,
    input wire [31:0] csr_wdata_c_i,
    input wire [1:0]  csr_we_i,
    input wire [1:0]  mode_i,

    output reg [1:0]  mode_o,
    output reg [31:0] ex_data_o,
    output reg mem_w_en_o, //
    output reg mem_r_en_o, // 
    output reg [7:0] inst_type_o, //
    output reg rf_wen_o, // 
    output reg [4:0] rf_waddr_o, // 
    output reg [31:0] data_b_o, //
    output reg [31:0]pc_o,
    output reg [11:0] csr_waddr_a_o,
    output reg [31:0] csr_wdata_a_o,
    output reg [11:0] csr_waddr_b_o,
    output reg [31:0] csr_wdata_b_o,
    output reg [11:0] csr_waddr_c_o,
    output reg [31:0] csr_wdata_c_o,
    output reg [1:0]  csr_we_o,

    output wire  [31:0] alu_a,
    output wire  [31:0] alu_b,
    output wire  [ 3:0] alu_op,
    input  wire [31:0] alu_y
);
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
        SFENCE_VMA, // 20
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

    typedef enum logic[0:0] {
        IDLE,
        WAIT
    }state_t;

    state_t state;

    assign alu_op = alu_op_i;
    assign alu_a = (use_rs1 == 1'b1) ? data_a: (use_csr_alu_imm) ? imm: pc_i;
    assign alu_b = (use_rs2 == 1'b1) ? data_b: (use_csr_alu) ? data_c : imm;

    always @(posedge clk) begin
        if (rst == 1'b1) begin
            mode_o <= mode_i;
            ex_data_o <= 32'b0;
            mem_w_en_o <= 1'b0;
            mem_r_en_o <= 1'b0;
            inst_type_o <= ADDI;
            rf_wen_o <= 1'b0;
            rf_waddr_o <= 32'b0;
            csr_we_o <= 2'b0;
            csr_waddr_a_o <= 12'b0;
            csr_wdata_a_o <= 32'b0;
            csr_waddr_b_o <= 12'b0;
            csr_wdata_b_o <= 32'b0;
            csr_waddr_c_o <= 12'b0;
            csr_wdata_c_o <= 32'b0;
            data_b_o <= 32'b0;
            exe_ack <= 1'b0;
            pc_o <= 32'b0;
            state <= IDLE;
        end else if (exe_we == 1'b1 && empty == 1'b1) begin
            mode_o <= mode_i;
            ex_data_o <= 32'b0;
            mem_w_en_o <= 1'b0;
            mem_r_en_o <= 1'b0;
            inst_type_o <= ADDI;
            rf_wen_o <= 1'b0;
            rf_waddr_o <= 32'b0;
            csr_we_o <= 2'b0;
            csr_waddr_a_o <= 12'b0;
            csr_wdata_a_o <= 32'b0;
            csr_waddr_b_o <= 12'b0;
            csr_wdata_b_o <= 32'b0;
            csr_waddr_c_o <= 12'b0;
            csr_wdata_c_o <= 32'b0;
            data_b_o <= 32'b0;
            exe_ack <= 1'b1;
            pc_o <= 32'b0;
            state <= IDLE;
        end else if (exe_we == 1'b1) begin
            mode_o <= mode_i;
            case (state)
                IDLE: begin
                    mem_w_en_o <= mem_w_en_i;
                    mem_r_en_o <= mem_r_en_i;
                    rf_wen_o <= rf_wen_i;
                    rf_waddr_o <= rf_waddr_i;
                    csr_waddr_a_o <= csr_waddr_a_i;
                    csr_waddr_b_o <= csr_waddr_b_i;
                    csr_wdata_b_o <= csr_wdata_b_i;
                    csr_waddr_c_o <= csr_waddr_c_i;
                    csr_wdata_c_o <= csr_wdata_c_i;
                    csr_we_o <= csr_we_i;
                    inst_type_o <= inst_type_i;
                    data_b_o <= data_b;
                    pc_o <= pc_i;
                    if (ex_en == 1'b1) begin 
                        // exe_ack <= 1'b0;
                        ex_data_o <= alu_y;
                        csr_wdata_a_o <= alu_y;
                        exe_ack <= 1'b1;
                        state <= WAIT;
                    end
                    else if (inst_type_i == CSRRW || inst_type_i == CSRRWI) begin
                        ex_data_o <= data_c;
                        csr_wdata_a_o <= csr_wdata_a_i;
                        exe_ack <= 1'b1;
                        state <= WAIT;
                    end
                    else begin
                        ex_data_o <= imm;
                        csr_wdata_a_o <= csr_wdata_a_i;
                        exe_ack <= 1'b1;
                        state <= WAIT;
                    end
                end
                WAIT: begin
                    state <= IDLE;
                    exe_ack <= 1'b0;
                end
            endcase
        end else begin
            state <= IDLE;
            exe_ack <= 1'b0;
        end
    end

endmodule