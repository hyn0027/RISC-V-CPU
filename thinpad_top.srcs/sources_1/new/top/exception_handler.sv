`default_nettype none

module except_handler(
    input wire clk,
    input wire rst,
    output reg [1:0]  mode,
    input wire [1:0]  last_mode,
    input wire timeout,
    input wire [31:0] pc_i,
    input wire [7:0] inst_type_i_id,
    input wire [7:0] inst_type_i_exe,
    input wire [7:0] inst_type_i_mem,
    input wire [31:0] ls_addr_i,

    output reg [31:0] cause_o,
    input wire page_fault_if,
    input wire page_fault_mem
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
        ORI,//10
        SLLI, // 11
        SRLI, // 12
        XOR,
        BNE,
        LW,
        AUIPC,
        JAL,
        JALR,
        XNOR,
        MIN,
        CTZ,
        SLTU,
        CSRRW,
        CSRRC,
        CSRRS,
        ECALL,
        EBREAK,
        MRET,
        EXCEPT,
        INVALID,
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

    logic except_handling;

    always_comb begin
        cause_o = 32'hFFFFFFFF;
        if (timeout && (except_handling == 1'b0)) begin
            cause_o = 32'h80000007;
        end
        if (mode == 2'b0 && page_fault_mem == 1'b1) begin
            if (inst_type_i_mem == LB || inst_type_i_mem == LH || inst_type_i_mem == LBU || inst_type_i_mem == LHU || inst_type_i_mem == LW) begin
                cause_o = 32'hd;
            end else if (inst_type_i_mem == SB || inst_type_i_mem == SW || inst_type_i_mem == SH) begin
                cause_o = 32'hf;
            end
        end else if (((inst_type_i_exe == LW) && (ls_addr_i & 2'b11 != 2'b0)) || ((inst_type_i_exe == LHU || inst_type_i_exe == LH) && (ls_addr_i & 1'b1 != 1'b0))) begin
            cause_o = 32'h4;
        end else if ((inst_type_i_exe == LB || inst_type_i_exe == LH || inst_type_i_exe == LBU || inst_type_i_exe == LHU || inst_type_i_exe == LW) && 
                (ls_addr_i >= 32'h8000_0000 && ls_addr_i <= 32'h8000_0FFF) && (mode == 2'b0)) begin
            cause_o = 32'h5;
        end else if (((inst_type_i_exe == SW) && (ls_addr_i & 2'b11 != 2'b0)) || ((inst_type_i_exe == SH) && (ls_addr_i & 1'b1 != 1'b0))) begin
            cause_o = 32'h6;
        end else if ((inst_type_i_exe == SB || inst_type_i_exe == SH|| inst_type_i_exe == SW) && 
                (ls_addr_i >= 32'h8000_0000 && ls_addr_i <= 32'h8000_0FFF) && (mode == 2'b0)) begin
            cause_o = 32'h7;
        end else begin
            case (inst_type_i_id)
                ECALL: begin
                    if (mode == 2'b0) begin
                        cause_o = 32'h8;
                    end else if (mode == 2'b1) begin
                        cause_o = 32'h9;
                    end else if (mode == 2'b11) begin
                        cause_o = 32'hb;
                    end
                end
                EBREAK: begin
                    cause_o = 32'h3;
                end
                INVALID: begin
                    cause_o = 32'h2;
                end
                default: begin
                    if (pc_i & 2'b11 != 2'b0) begin
                        cause_o = 32'h0;
                    end else if ((pc_i >= 32'h8000_0000 && pc_i <= 32'h8000_00FF) && (mode == 2'b0)) begin
                        cause_o = 32'h1;
                    end else if (page_fault_if == 1'b1) begin
                        cause_o = 32'hc;
                    end
                end
            endcase
        end
    end
    
    always_ff @(posedge clk) begin
        if (timeout) begin
            except_handling <= 1'b1;
        end else begin
            except_handling <= 1'b0;
        end

        if (rst) begin
            mode <= 2'b11;
        end else if (inst_type_i_id == MRET) begin
            mode <= last_mode;
        end else if (inst_type_i_id == EXCEPT) begin
            mode <= 2'b11;
        end
    end

endmodule