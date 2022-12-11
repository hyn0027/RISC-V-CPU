`default_nettype none

module id(
    input wire clk,
    input wire rst,
    input wire[31:0] inst_i,
    input wire id_we,
    input wire [31:0]pc_i,
    input wire empty,
    input wire [1:0] mode, 

    output reg id_ack,
    output reg [1:0] id_mode,
    output wire [31:0] data_a,
    output wire [31:0] data_b,
    output wire [4:0] rs1_o,
    output wire [4:0] rs2_o,
    output wire [7:0] inst_type_o,
    output wire ex_en,
    output reg [3:0] alu_op,
    output wire [3:0] imm_type_o,
    output wire [31:0] imm,
    output wire use_rs1,
    output wire use_rs2,
    output wire [31:0] pc_o,
    output wire mem_w_en,
    output wire mem_r_en,
    output wire rf_wen,
    output wire [4:0] rf_waddr_o,
    output reg [11:0] csr_waddr_a_o,
    output reg [31:0] csr_wdata_a_o,
    output reg [11:0] csr_waddr_b_o,
    output reg [31:0] csr_wdata_b_o,
    output reg [11:0] csr_waddr_c_o,
    output reg [31:0] csr_wdata_c_o,
    output reg [1:0]  csr_we_o,
    output wire [31:0] data_c,
    output reg use_csr_alu,
    output reg use_csr_alu_imm,
    output wire cmp_res,
    output reg signed [31:0] pc_new,
    output wire is_jump, //输出给cpu的是否为跳转指令

    
    output reg  [4:0]  rf_raddr_a,
    input  wire [31:0] rf_rdata_a,
    output reg  [4:0]  rf_raddr_b,
    input  wire [31:0] rf_rdata_b,

    output reg  [11:0] csr_raddr_a,
    input  wire [31:0] csr_rdata_a,

    input  wire [31:0] except,
    input  wire [31:0] pc_mepc,
    input  wire id_exception

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
        SFENCE_VMA, //20 
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
    } state_t;

    typedef enum logic[2:0] {
        IMM_R,
        IMM_I, 
        IMM_S,
        IMM_B, 
        IMM_U,
        IMM_J,
        IMM_C
    } immType;

    state_t state;

    instType inst_type;
    immType imm_type;
    logic signed [31:0] pc_reg;
    logic signed [31:0] imm_reg;
    logic [31:0] inst;
    logic read_1;
    logic read_2;
    logic signed [31:0] csr_wdata_a_reg;
    logic [31:0] pc_mepc_reg;
    logic signed [31:0] rf_rdata_a_signed;
    logic signed [31:0] rf_rdata_b_signed;
    logic [1:0] mode_reg;
    assign rf_rdata_a_signed = rf_rdata_a;
    assign rf_rdata_b_signed = rf_rdata_b;
    assign data_a = rf_rdata_a;
    assign data_b = rf_rdata_b;
    assign data_c = csr_rdata_a;
    assign inst_type_o = inst_type;
    assign imm_type_o = imm_type;
    assign pc_o = pc_reg;
    assign rs1_o = (read_1 == 1'b1 || read_2 == 1'b1) ? inst[19:15] : 5'b0;
    assign rs2_o = (read_2 == 1'b1) ? inst[24:20]: 5'b0;
    assign ex_en = (inst_type == LUI || inst_type == CSRRW || inst_type == CSRRWI || inst_type == EXCEPT || inst_type == MRET || inst_type == SRET || inst_type == FENCE || inst_type == SFENCE_VMA) ? 1'b0: 1'b1;
    assign imm = (inst_type == JAL || inst_type == JALR) ? 32'd4: imm_reg;
    assign use_rs1 = (imm_type == IMM_B || inst_type == AUIPC || inst_type == JAL || inst_type == JALR) ? 1'b0: 1'b1;
    assign use_rs2 = (imm_type == IMM_R) ? 1'b1: 1'b0;
    assign mem_w_en = (inst_type == SB || inst_type == SH || inst_type == SW) ? 1'b1: 1'b0;
    assign mem_r_en = (inst_type == LB || inst_type == LH || inst_type == LW || inst_type == LBU || inst_type == LHU) ? 1'b1: 1'b0;
    assign rf_wen = (imm_type == IMM_B || inst_type == SB || inst_type == SH || inst_type == SW || inst_type == MRET || inst_type == SRET || inst_type == FENCE || inst_type == SFENCE_VMA) ? 1'b0: 1'b1;
    assign rf_waddr_o = (imm_type == IMM_B || inst_type == SB || inst_type == SH || inst_type == SW || inst_type == MRET || inst_type == SRET || inst_type == FENCE || inst_type == SFENCE_VMA)? 5'b0: inst[11:7];
    assign cmp_res = ((inst_type == BLT && (rf_rdata_a_signed < rf_rdata_b_signed)) || (inst_type == BGE && (rf_rdata_a_signed >= rf_rdata_b_signed)) || 
            (inst_type == BLTU && (rf_rdata_a < rf_rdata_b)) || (inst_type == BGEU && (rf_rdata_a >= rf_rdata_b)) ||
            (inst_type == BEQ && rf_rdata_a == rf_rdata_b) || (inst_type == BNE && rf_rdata_a != rf_rdata_b) || inst_type == JAL || inst_type == JALR) ? 1'b1: 1'b0;
    assign is_jump = (inst_type == JAL || inst_type == JALR || imm_type == IMM_B) ? 1'b1 : 1'b0; //是否为跳转指令
    always_comb begin
        // id_ack = id_ack_reg;
        // data_a = rf_rdata_a;
        // data_b = rf_rdata_b;
        // data_c = csr_rdata_a;
        // rs1_o = (read_1 == 1'b1 || read_2 == 1'b1) ? inst[19:15] : 5'b0;
        // rs2_o = (read_2 == 1'b1) ? inst[24:20]: 5'b0;
        // inst_type_o = inst_type;
        // ex_en = (inst_type == LUI || inst_type == CSRRW || inst_type == CSRRWI || inst_type == EXCEPT || inst_type == MRET || inst_type == SRET || inst_type == FENCE || inst_type == SFENCE_VMA) ? 1'b0: 1'b1;
        csr_waddr_b_o = 12'b0;
        csr_wdata_b_o = 32'b0;
        csr_waddr_c_o = 12'b0;
        csr_wdata_c_o = 32'b0;
        csr_wdata_a_reg = csr_rdata_a;
        use_csr_alu = 1'b0;
        use_csr_alu_imm = 1'b0;
        case (inst_type) 
            CSRRW: begin
                csr_we_o = 2'b01;
                csr_waddr_a_o = inst[31:20];
                csr_wdata_a_o = data_a;
            end
            CSRRS: begin
                csr_we_o = 2'b01;
                csr_waddr_a_o = inst[31:20];
                csr_wdata_a_o = data_a;
                use_csr_alu = 1'b1;
            end
            CSRRC: begin
                csr_we_o = 2'b01;
                csr_waddr_a_o = inst[31:20];
                csr_wdata_a_o = data_a;
                use_csr_alu = 1'b1;
            end
            CSRRWI: begin
                csr_we_o = 2'b01;
                csr_waddr_a_o = inst[31:20];
                csr_wdata_a_o = imm_reg;
            end
            CSRRSI: begin
                csr_we_o = 2'b01;
                csr_waddr_a_o = inst[31:20];
                csr_wdata_a_o = imm_reg;
                use_csr_alu = 1'b1;
                use_csr_alu_imm = 1'b1;
            end
            CSRRCI: begin
                csr_we_o = 2'b01;
                csr_waddr_a_o = inst[31:20];
                csr_wdata_a_o = imm_reg;
                use_csr_alu = 1'b1;
                use_csr_alu_imm = 1'b1;
            end
            EXCEPT: begin
                csr_we_o = 2'b11;
                csr_waddr_a_o = 12'h341; // mepc
                csr_wdata_a_o = pc_mepc_reg;
                csr_waddr_b_o = 12'h342; // mcause
                csr_wdata_b_o = except;
                csr_waddr_c_o = 12'h300;
                csr_wdata_c_o = {19'b0, mode_reg, 11'b0};
                use_csr_alu = 1'b0;
            end
            MRET: begin
                csr_we_o = 2'b10;
                csr_waddr_a_o = 12'h342;
                csr_wdata_a_o = 32'hFFFFFFFF;
                csr_waddr_b_o = 12'h300;
                csr_wdata_b_o = {19'h0, 2'b11, 11'h0};
                use_csr_alu = 1'b0;
            end
            SRET: begin
                csr_we_o = 2'b10;
                csr_waddr_a_o = 12'h142;
                csr_wdata_a_o = 32'hFFFFFFFF;
                csr_waddr_b_o = 12'h100;
                csr_wdata_b_o = {19'h0, 2'b01, 11'h0};
            end
            default: begin
                csr_we_o = 2'b0;
                csr_waddr_a_o = 12'b0;
                csr_wdata_a_o = 32'b0;
            end
        endcase
        case (inst_type)
            XNOR: begin
                alu_op = 4'b0010;
                pc_new = 32'b0;
            end
            SRLI, SRL: begin
                alu_op = 4'b0011;
                pc_new = 32'b0;
            end
            SLLI, SLL: begin
                alu_op = 4'b0100;
                pc_new = 32'b0;
            end
            XOR, XORI: begin
                alu_op = 4'b0101;
                pc_new = 32'b0;
            end
            ORI, OR: begin
                alu_op = 4'b0110;
                pc_new = 32'b0;
            end
            ANDI, AND: begin
                alu_op = 4'b0111;
                pc_new = 32'b0;
            end
            SRA, SRAI: begin
                alu_op = 4'b1100;
                pc_new = 32'b0;
            end
            SUB: begin
                alu_op = 4'b1101;
                pc_new = 32'b0;
            end
            MIN: begin
                alu_op = 4'b1000;
                pc_new = 32'b0;
            end
            CTZ: begin
                alu_op = 4'b1001;
                pc_new = 32'b0;
            end
            BEQ, BNE, BLT, BLTU, BGE, BGEU: begin
                alu_op = 4'b0;
                pc_new = pc_reg + imm_reg;
            end
            JAL: begin
                alu_op = 4'b0;
                pc_new = pc_reg + imm_reg;
            end
            JALR: begin
                alu_op = 4'b0;
                pc_new = rf_rdata_a + imm_reg;
            end
            SLTU, SLTIU: begin
                alu_op = 4'b1010;
                pc_new = 32'b0;
            end
            SLTI, SLT: begin
                alu_op = 4'b1110;
                pc_new = 32'b0;
            end
            CSRRS, CSRRSI: begin
                alu_op = 4'b0110;
                pc_new = 32'b0;
            end
            CSRRC, CSRRCI: begin
                alu_op = 4'b1011;
                pc_new = 32'b0;
            end
            default: begin
                alu_op = 4'b0000;
                pc_new = 32'b0;
            end
        endcase
        // alu_op = (inst_type == ANDI) ? 4'b0111: 4'b0000; 
        // imm_type_o = imm_type;
        // imm = (inst_type == JAL || inst_type == JALR) ? 32'd4: imm_reg;
        // use_rs1 = (imm_type == IMM_B || inst_type == AUIPC || inst_type == JAL || inst_type == JALR) ? 1'b0: 1'b1;
        // use_rs2 = (imm_type == IMM_R) ? 1'b1: 1'b0;
        // pc_o = pc_reg;
        // mem_w_en = (inst_type == SB || inst_type == SH || inst_type == SW) ? 1'b1: 1'b0;
        // mem_r_en = (inst_type == LB || inst_type == LH || inst_type == LW || inst_type == LBU || inst_type == LHU) ? 1'b1: 1'b0;
        // rf_wen = (imm_type == IMM_B || inst_type == SB || inst_type == SH || inst_type == SW || inst_type == MRET || inst_type == SRET || inst_type == FENCE || inst_type == SFENCE_VMA) ? 1'b0: 1'b1;
        // rf_waddr_o = (imm_type == IMM_B || inst_type == SB || inst_type == SH || inst_type == SW || inst_type == MRET || inst_type == SRET || inst_type == FENCE || inst_type == SFENCE_VMA)? 5'b0: inst[11:7];
        // cmp_res = ((inst_type == BLT && (rf_rdata_a_signed < rf_rdata_b_signed)) || (inst_type == BGE && (rf_rdata_a_signed >= rf_rdata_b_signed)) || 
        //     (inst_type == BLTU && (rf_rdata_a < rf_rdata_b)) || (inst_type == BGEU && (rf_rdata_a >= rf_rdata_b)) ||
        //     (inst_type == BEQ && rf_rdata_a == rf_rdata_b) || (inst_type == BNE && rf_rdata_a != rf_rdata_b) || inst_type == JAL || inst_type == JALR) ? 1'b1: 1'b0;
        // is_jump = (inst_type == JAL || inst_type == JALR || imm_type == IMM_B) ? 1'b1 : 1'b0; //是否为跳转指令
    end
    
    always @(posedge clk) begin
        if (rst == 1'b1) begin
            inst <= 32'h00000013;
            inst_type <= ADDI;
            imm_type <= IMM_I;
            imm_reg <= 32'b0;
            read_1 <= 1'b1;
            read_2 <= 1'b0;
            pc_reg <= 32'b0;
            id_mode <= mode;
            rf_raddr_a <= 5'b0;
            rf_raddr_b <= 5'b0;
            csr_raddr_a <= 12'b0;
            id_ack <= 1'b0;
            state <= IDLE;
        end else if (id_we == 1'b1 && empty == 1'b1) begin
            inst <= 32'h00000013;
            inst_type <= ADDI;
            imm_type <= IMM_I;
            imm_reg <= 32'b0;
            read_1 <= 1'b1;
            read_2 <= 1'b0;
            pc_reg <= 32'b0;
            id_mode <= mode;
            rf_raddr_a <= 5'b0;
            rf_raddr_b <= 5'b0;
            csr_raddr_a <= 12'b0;
            id_ack <= 1'b1;
            state <= IDLE;
        // 虚假处理异常为一条指令
        end else if (id_we == 1'b1 && id_exception == 1'b1) begin
            mode_reg <= mode;
            inst <= 32'h00000013;
            inst_type <= EXCEPT;
            imm_type <= IMM_I;
            imm_reg <= 32'b0;
            read_1 <= 1'b0;
            read_2 <= 1'b0;
            pc_mepc_reg <= pc_mepc;
            pc_reg <= 32'b0;
            id_mode <= 2'b11;
            rf_raddr_a <= 5'b0;
            rf_raddr_b <= 5'b0;
            csr_raddr_a <= 12'h305;
            id_ack <= 1'b1;
            state <= IDLE;
        end else if (id_we == 1'b1)  begin
            id_mode <= mode;
            case (state)
                IDLE: begin
                    inst <= inst_i;
                    pc_reg <= pc_i;
                    case (inst_i[6:0])
                        7'b0110111: begin
                            inst_type <= LUI;
                            imm_type <= IMM_U;
                            imm_reg <= {inst_i[31:12], 12'b0};
                            read_1 <= 1'b0;
                            read_2 <= 1'b0;
                            rf_raddr_a <= 5'b0;
                            rf_raddr_b <= 5'b0;
                            csr_raddr_a <= 12'b0;
                        end
                        7'b0010111: begin
                            inst_type <= AUIPC;
                            imm_type <= IMM_U;
                            imm_reg <= {inst_i[31:12], 12'b0};
                            read_1 <= 1'b0;
                            read_2 <= 1'b0;
                            rf_raddr_a <= 5'b0;
                            rf_raddr_b <= 5'b0;
                            csr_raddr_a <= 12'b0;
                        end
                        7'b1101111: begin
                            inst_type <= JAL;
                            imm_type <= IMM_J;
                            if (inst_i[31] == 1'b0) begin
                                imm_reg <= {11'b0, inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                            end else begin
                                imm_reg <= {11'b11111111111, inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                            end
                            read_1 <= 1'b0;
                            read_2 <= 1'b0;
                            rf_raddr_a <= 5'b0;
                            rf_raddr_b <= 5'b0;
                            csr_raddr_a <= 12'b0;
                        end
                        7'b1100111: begin
                            inst_type <= JALR;
                            imm_type <= IMM_I;
                            if (inst_i[31] == 1'b0) begin
                                imm_reg <= {20'b0, inst_i[31:20]};
                            end else begin
                                imm_reg <= {20'b11111111111111111111, inst_i[31:20]};
                            end
                            read_1 <= 1'b1;
                            read_2 <= 1'b0;
                            rf_raddr_a <= inst_i[19:15];
                            rf_raddr_b <= 5'b0;
                            csr_raddr_a <= 12'b0;
                        end
                        7'b1100011: begin
                            imm_type <= IMM_B;
                            if (inst_i[31] == 1'b0) begin
                                imm_reg <= {19'b0, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                            end else begin
                                imm_reg <= {19'b1111111111111111111, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                            end
                            read_1 <= 1'b0;
                            read_2 <= 1'b1;
                            rf_raddr_a <= inst_i[19:15];
                            rf_raddr_b <= inst_i[24:20];
                            csr_raddr_a <= 12'b0;
                            case (inst_i[14:12])
                                3'b000: begin
                                    inst_type <= BEQ;
                                end
                                3'b001: begin
                                    inst_type <= BNE;
                                end
                                3'b100: begin
                                    inst_type <= BLT;
                                end
                                3'b101: begin
                                    inst_type <= BGE;
                                end
                                3'b110: begin
                                    inst_type <= BLTU;
                                end
                                3'b111: begin
                                    inst_type <= BGEU;
                                end
                                default: begin
                                    inst_type <= INVALID;
                                end
                            endcase
                        end
                        7'b0000011: begin
                            imm_type <= IMM_I;
                            
                            if (inst_i[31] == 1'b0 || inst_i[14] == 1'b1) begin
                                imm_reg <= {20'b0, inst_i[31:20]};
                            end else begin
                                imm_reg <= {20'b11111111111111111111, inst_i[31:20]};
                            end
                            // imm_reg <= {20'b0, inst_i[31:20]};
                            read_1 <= 1'b1;
                            read_2 <= 1'b0;
                            rf_raddr_a <= inst_i[19:15];
                            rf_raddr_b <= 5'b0;
                            csr_raddr_a <= 12'b0;
                            case (inst_i[14:12])
                                3'b000: begin
                                    inst_type <= LB;
                                end
                                3'b001: begin
                                    inst_type <= LH;
                                end
                                3'b010: begin
                                    inst_type <= LW;
                                end
                                3'b100: begin
                                    inst_type <= LBU;
                                end
                                3'b101: begin
                                    inst_type <= LHU;
                                end
                                default: begin
                                    inst_type <= INVALID;
                                end
                            endcase
                        end
                        7'b0100011: begin
                            imm_type <= IMM_S;
                            if (inst_i[31] == 1'b0) begin
                                imm_reg <= {22'b0, inst_i[31:25], inst_i[11:7]};
                            end else begin
                                imm_reg <= {22'b1111111111111111111111, inst_i[31:25], inst_i[11:7]};
                            end
                            read_1 <= 1'b0;
                            read_2 <= 1'b1;
                            rf_raddr_a <= inst_i[19:15];
                            rf_raddr_b <= inst_i[24:20];
                            csr_raddr_a <= 12'b0;
                            case (inst_i[14:12])
                                3'b000: begin
                                    inst_type <= SB;
                                end
                                3'b001: begin
                                    inst_type <= SH;
                                end
                                3'b010: begin
                                    inst_type <= SW;
                                end
                                default: begin
                                    inst_type <= INVALID;
                                end
                            endcase
                        end
                        7'b0010011: begin
                            imm_type <= IMM_I;
                            if (inst_i[31] == 1'b0) begin
                                imm_reg <= {20'b0, inst_i[31:20]};
                            end else begin
                                imm_reg <= {20'b11111111111111111111, inst_i[31:20]};
                            end
                            // imm_reg <= {20'b0, inst_i[31:20]};
                            read_1 <= 1'b1;
                            read_2 <= 1'b0;
                            rf_raddr_a <= inst_i[19:15];
                            rf_raddr_b <= 5'b0;
                            csr_raddr_a <= 12'b0;
                            case (inst_i[14:12])
                                3'b000: begin
                                    inst_type <= ADDI;
                                end
                                3'b001: begin
                                    if (inst_i[31:25] == 7'b0110000) begin
                                        inst_type <= CTZ;
                                    end else if (inst_i[31:25] == 7'b0) begin
                                        inst_type <= SLLI;
                                    end else begin
                                        inst_type <= INVALID;
                                    end
                                end
                                3'b010: begin
                                    inst_type <= SLTI;
                                end
                                3'b011: begin
                                    inst_type <= SLTIU;
                                end
                                3'b100: begin
                                    inst_type <= XORI;
                                end
                                3'b101: begin
                                    if (inst_i[31:25] == 7'b0) begin
                                        inst_type <= SRLI;
                                    end else if (inst_i[31:25] == 7'b0100000) begin
                                        inst_type <= SRAI;
                                    end else begin
                                        inst_type <= INVALID;
                                    end
                                end
                                3'b110: begin
                                    inst_type <= ORI;
                                end
                                3'b111: begin
                                    inst_type <= ANDI;
                                end
                                default: begin
                                    inst_type <= INVALID;
                                end
                            endcase
                        end
                        7'b0110011: begin
                            imm_type <= IMM_R;
                            imm_reg <= 32'b0;
                            read_1 <= 1'b0;
                            read_2 <= 1'b1;
                            rf_raddr_a <= inst_i[19:15];
                            rf_raddr_b <= inst_i[24:20];
                            csr_raddr_a <= 12'b0;
                            case (inst_i[14:12])
                                3'b000: begin
                                    if (inst_i[31:25] == 7'b0000000) begin
                                        inst_type <= ADD;
                                    end else if (inst_i[31:25] == 7'b0100000) begin
                                        inst_type <= SUB;
                                    end else begin
                                        inst_type <= INVALID;
                                    end
                                end
                                3'b001: begin
                                    inst_type <= SLL;
                                end 
                                3'b010: begin
                                    inst_type <= SLT;
                                end
                                3'b100: begin
                                    if (inst_i[31:25] == 7'b0000101) begin
                                        inst_type <= MIN;
                                    end else if (inst_i[31:25] == 7'b0100000) begin
                                        inst_type <= XNOR;
                                    end else if (inst_i[31:25] == 7'b0) begin
                                        inst_type <= XOR;
                                    end else begin
                                        inst_type <= INVALID;
                                    end
                                end
                                3'b011: begin
                                    inst_type <= SLTU;
                                end
                                3'b101: begin
                                    if (inst_i[31:25] == 7'b0) begin
                                        inst_type <= SRL;
                                    end else if (inst_i[31:25] == 7'b0100000) begin
                                        inst_type <= SRA;
                                    end else begin
                                        inst_type <= INVALID;
                                    end
                                end
                                3'b110: begin
                                    inst_type <= OR;
                                end
                                3'b111: begin
                                    inst_type <= AND;
                                end
                                default: begin
                                    inst_type <= INVALID;
                                end
                            endcase
                        end
                        7'b1110011: begin
                            if (inst_i[31:25] == 7'b1001 && inst_i[14:0] == 15'b1110011) begin
                                imm_type  <= IMM_R;
                                imm_reg <= 32'b0;
                                rf_raddr_a <= 5'b0;
                                rf_raddr_b <= 5'b0;
                            end else begin
                                imm_type <= IMM_C;
                                imm_reg <= 32'b0;
                                rf_raddr_a <= inst_i[19:15];
                                rf_raddr_b <= 5'b0;
                            end
                            if (inst_i[29:28] > mode) begin
                                inst_type <= INVALID;
                                csr_raddr_a <= 12'b0;
                            end else begin
                                case (inst_i[14:12])
                                    3'b000: begin
                                        imm_reg <= 32'b0;
                                        if (inst_i[31:20] == 12'b0) begin
                                            inst_type <= ECALL;
                                            csr_raddr_a <= 12'b0;
                                            read_1 <= 1'b1;
                                            read_2 <= 1'b0;
                                        end else if (inst_i[31:20] == 12'b1) begin
                                            inst_type <= EBREAK;
                                            csr_raddr_a <= 12'b0;
                                            read_1 <= 1'b1;
                                            read_2 <= 1'b0;
                                        end else if (inst_i[31:20] == 12'b000100000010) begin
                                            inst_type <= SRET;
                                            csr_raddr_a <= 12'h141;
                                            read_1 <= 1'b1;
                                            read_2 <= 1'b0;
                                        end else if (inst_i[31:20] == 12'b001100000010) begin
                                            inst_type <= MRET;
                                            csr_raddr_a <= 12'h341;
                                            read_1 <= 1'b1;
                                            read_2 <= 1'b0;
                                        end else if (inst_i[31:25] == 7'b0001001) begin
                                            inst_type <= SFENCE_VMA;
                                            read_1 <= 1'b0;
                                            read_2 <= 1'b1;
                                        end else begin
                                            inst_type <= INVALID;
                                            read_1 <= 1'b1;
                                            read_2 <= 1'b0;
                                            csr_raddr_a <= 12'b0;
                                        end
                                    end
                                    3'b001: begin
                                        read_1 <= 1'b1;
                                        read_2 <= 1'b0;
                                        imm_reg <= 32'b0;
                                        inst_type <= CSRRW;
                                        csr_raddr_a <= inst_i[31:20];
                                    end
                                    3'b010: begin
                                        read_1 <= 1'b1;
                                        read_2 <= 1'b0;
                                        imm_reg <= 32'b0;
                                        inst_type <= CSRRS;
                                        csr_raddr_a <= inst_i[31:20];
                                    end
                                    3'b011: begin
                                        read_1 <= 1'b1;
                                        read_2 <= 1'b0;
                                        imm_reg <= 32'b0;
                                        inst_type <= CSRRC;
                                        csr_raddr_a <= inst_i[31:20];
                                    end
                                    3'b100: begin
                                        read_1 <= 1'b0;
                                        read_2 <= 1'b0;
                                        imm_reg <= {27'b0, inst_i[19:15]};
                                        inst_type <= CSRRWI;
                                        csr_raddr_a <= inst_i[31:20];
                                    end
                                    3'b110: begin
                                        read_1 <= 1'b0;
                                        read_2 <= 1'b0;
                                        imm_reg <= {27'b0, inst_i[19:15]};
                                        inst_type <= CSRRSI;
                                        csr_raddr_a <= inst_i[31:20];
                                    end
                                    3'b111: begin
                                        read_1 <= 1'b0;
                                        read_2 <= 1'b0;
                                        imm_reg <= {27'b0, inst_i[19:15]};
                                        inst_type <= CSRRCI;
                                        csr_raddr_a <= inst_i[31:20];
                                    end
                                    default: begin
                                        read_1 <= 1'b0;
                                        read_2 <= 1'b0;
                                        imm_reg <= 32'b0;
                                        inst_type <= INVALID;
                                        csr_raddr_a <= 12'b0;
                                    end
                                endcase
                            end
                        end
                        7'b0001111: begin
                            imm_type <= IMM_R;
                            read_1 <= 1'b0;
                            read_2 <= 1'b0;
                            rf_raddr_a <= 5'b0;
                            rf_raddr_b <= 5'b0;
                            inst_type <= FENCE;
                            csr_raddr_a <= 12'b0;
                        end
                        default: begin
                            inst_type <= INVALID;
                            imm_type <= IMM_R;
                        end
                    endcase
                    id_ack <= 1'b1;
                    state <= WAIT;
                end
                WAIT: begin
                    id_ack <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
        else begin
            state <= IDLE;
            id_ack <= 1'b0;
        end
    end
endmodule