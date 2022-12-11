`default_nettype none

module csr_reg(
    input wire clk,
    input wire rst,

    input wire [11:0] csr_raddr_a,
    output reg [31:0] csr_rdata_a,
    output reg [31:0] satp,

    input wire [11:0] csr_waddr_a,
    input wire [31:0] csr_wdata_a,
    input wire [11:0] csr_waddr_b,
    input wire [31:0] csr_wdata_b,
    input wire [11:0] csr_waddr_c,
    input wire [31:0] csr_wdata_c,

    input wire [1:0]  csr_we,
    input wire [1:0]  mode,
    output wire [1:0] last_mode,
    output wire timeout,

    input wire [1:0]  pl_we_mem,
    input wire [11:0] pl_addr_mem_a,
    input wire [31:0] pl_data_mem_a,
    input wire [11:0] pl_addr_mem_b,
    input wire [31:0] pl_data_mem_b,
    input wire [11:0] pl_addr_mem_c,
    input wire [31:0] pl_data_mem_c,

    input wire [1:0]  pl_we_exe,
    input wire [11:0] pl_addr_exe_a,
    input wire [31:0] pl_data_exe_a,
    input wire [11:0] pl_addr_exe_b,
    input wire [31:0] pl_data_exe_b,
    input wire [11:0] pl_addr_exe_c,
    input wire [31:0] pl_data_exe_c,

    input wire [31:0] mtime_low,
    input wire [31:0] mtime_high,
    input wire [31:0] mtimecmp_low,
    input wire [31:0] mtimecmp_high

);

    logic [31:0] reg_file [0:11];
    // attention: 20&21是只读寄存器
    // logic [31:0] csr_rdata_a_reg;
    logic [11:0] csr_waddr_a_reg;
    logic [11:0] csr_waddr_b_reg;
    logic [11:0] csr_waddr_c_reg;

    assign last_mode = reg_file[4][12:11];
    assign reg_file[8] = 32'b0;

    // assign reg_file[19] = (mtime_high > mtimecmp_high) || ((mtime_high == mtimecmp_high) && (mtime_low > mtimecmp_low));
    assign timeout = (mode < 2'b11 || reg_file[4][3] == 1'b1) && (reg_file[6][7] == 1'b1) && (reg_file[5][7] == 1'b1);

    always_comb begin
        reg_file[6] = 32'b0;
        if ((mtime_high > mtimecmp_high) || ((mtime_high == mtimecmp_high) && (mtime_low > mtimecmp_low))) begin
            reg_file[6] = 32'h00000080;
        end

        csr_rdata_a = 32'b0;
        if (pl_we_exe != 2'b0 && (pl_addr_exe_a == csr_raddr_a || pl_addr_exe_b == csr_raddr_a || pl_addr_exe_c == csr_raddr_a)) begin
            case (csr_raddr_a)
                pl_addr_exe_a:
                    csr_rdata_a = pl_data_exe_a;
                pl_addr_exe_b:
                    csr_rdata_a = pl_data_exe_b;
                pl_addr_exe_c:
                    csr_rdata_a = pl_data_exe_c;
            endcase
        end else if (pl_we_mem != 2'b0 && (pl_addr_mem_a == csr_raddr_a || pl_addr_mem_b == csr_raddr_a || pl_addr_mem_c == csr_raddr_a)) begin
            case (csr_raddr_a)
                pl_addr_mem_a:
                    csr_rdata_a = pl_data_mem_a;
                pl_addr_mem_b:
                    csr_rdata_a = pl_data_mem_b;
                pl_addr_mem_c:
                    csr_rdata_a = pl_data_mem_c;
            endcase
        end else if (csr_we != 2'b0 && (csr_waddr_a == csr_raddr_a || csr_waddr_b == csr_raddr_a || csr_waddr_c == csr_raddr_a)) begin
            case (csr_raddr_a)
                csr_waddr_a:
                    csr_rdata_a = csr_wdata_a;
                csr_waddr_b:
                    csr_rdata_a = csr_wdata_b;
                csr_waddr_c:
                    csr_rdata_a = csr_wdata_c;
            endcase
        end else begin
            case (csr_raddr_a)
                12'h305: // mtvec
                    csr_rdata_a = reg_file[0];
                12'h340: // mscratch
                    csr_rdata_a = reg_file[1];
                12'h341: // mepc
                    csr_rdata_a = reg_file[2];
                12'h342: // mcause
                    csr_rdata_a = reg_file[3];
                12'h300: // mstatus
                    csr_rdata_a = reg_file[4];
                12'h304: // mie
                    csr_rdata_a = reg_file[5];
                12'h344: // mip
                    csr_rdata_a = reg_file[6];
                12'h180: // satp
                    csr_rdata_a = reg_file[7];
                12'hF14: // mhartid
                    csr_rdata_a = reg_file[8];
                12'h302: // medeleg
                    csr_rdata_a = reg_file[9];
                12'h303: // mideleg
                    csr_rdata_a = reg_file[10];
                12'h343: // mtval
                    csr_rdata_a = reg_file[11];
                // 12'h100: // sstatus
                //     csr_rdata_a = reg_file[12];
                // 12'h104: // sie
                //     csr_rdata_a = reg_file[13];
                // 12'h105: // stvec
                //     csr_rdata_a = reg_file[14];
                // 12'h140: // sscratch
                //     csr_rdata_a = reg_file[15];
                // 12'h141: // sepc
                //     csr_rdata_a = reg_file[16];
                // 12'h142: // scause
                //     csr_rdata_a = reg_file[17];
                // 12'h143: // stval
                //     csr_rdata_a = reg_file[18];
                // 12'h144: // sip
                //     csr_rdata_a = reg_file[19];
                12'hC01: // time
                    csr_rdata_a = mtime_low;
                12'hC81: // timeh
                    csr_rdata_a = mtime_high;
            endcase
        end

        satp = 32'b0;
        if (pl_we_exe != 2'b0 && (pl_addr_exe_a == 12'h180 || pl_addr_exe_b == 12'h180 || pl_addr_exe_c == 12'h180)) begin
            case (12'h180)
                pl_addr_exe_a:
                    satp = pl_data_exe_a;
                pl_addr_exe_b:
                    satp = pl_data_exe_b;
                pl_addr_exe_c:
                    satp = pl_data_exe_c;
            endcase
        end else if (pl_we_mem != 2'b0 && (pl_addr_mem_a == 12'h180 || pl_addr_mem_b == 12'h180 || pl_addr_mem_c == 12'h180)) begin
            case (12'h180)
                pl_addr_mem_a:
                    satp = pl_data_mem_a;
                pl_addr_mem_b:
                    satp = pl_data_mem_b;
                pl_addr_mem_c:
                    satp = pl_data_mem_c;
            endcase
        end else if (csr_we != 2'b0 && (csr_waddr_a == 12'h180 || csr_waddr_b == 12'h180 || csr_waddr_c == 12'h180)) begin
            case (12'h180)
                csr_waddr_a:
                    satp = csr_wdata_a;
                csr_waddr_b:
                    satp = csr_wdata_b;
                csr_waddr_c:
                    satp = csr_wdata_c;
            endcase
        end else begin
            satp = reg_file[7];
        end
    end
    assign csr_waddr_a_reg = (csr_we == 2'b1 || csr_we == 2'b10 || csr_we == 2'b11) ? csr_waddr_a: 12'h0;
    assign csr_waddr_b_reg = (csr_we == 2'b10 || csr_we == 2'b11) ? csr_waddr_b: 12'h0;
    assign csr_waddr_c_reg = (csr_we == 2'b11) ? csr_waddr_c: 12'h0;

    always_ff @(posedge clk) begin
        if (rst) begin
            reg_file[4] <= 32'h0;
            reg_file[12] <= 32'h0;
        end else if (csr_we != 2'b0) begin
            case (csr_waddr_a_reg)
                12'h305: // mtvec
                    reg_file[0] <= csr_wdata_a;
                12'h340: // mscratch
                    reg_file[1] <= csr_wdata_a;
                12'h341: // mepc
                    reg_file[2] <= csr_wdata_a;
                12'h342: // mcause
                    reg_file[3] <= csr_wdata_a;
                12'h300: // mstatus
                begin
                    reg_file[4] <= csr_wdata_a;
                    if (csr_wdata_a[12:11] == 2'b0 || csr_wdata_a == 2'b1) begin
                        reg_file[12][8] <= csr_wdata_a[11];
                    end
                end
                12'h304: // mie
                    reg_file[5] <= csr_wdata_a;
                // 12'h344: // mip
                //     reg_file[6] <= csr_wdata_a;
                12'h180: // satp
                    reg_file[7] <= csr_wdata_a;
                // 12'hF14: // mhartid
                //     reg_file[8] <= csr_wdata_a;
                12'h302: // medeleg
                    reg_file[9] <= csr_wdata_a;
                12'h303: // mideleg
                    reg_file[10] <= csr_wdata_a;
                12'h343: // mtval
                    reg_file[11] <= csr_wdata_a;
                // 12'h100: // sstatus
                //     reg_file[12] <= csr_wdata_a;
                // 12'h104: // sie
                //     reg_file[13] <= csr_wdata_a;
                // 12'h105: // stvec
                //     reg_file[14] <= csr_wdata_a;
                // 12'h140: // sscratch
                //     reg_file[15] <= csr_wdata_a;
                // 12'h141: // sepc
                //     reg_file[16] <= csr_wdata_a;
                // 12'h142: // scause
                //     reg_file[17] <= csr_wdata_a;
                // 12'h143: // stval
                //     reg_file[18] <= csr_wdata_a;
                // 12'h144: // sip
                //     reg_file[19] <= csr_wdata_a;
            endcase
            case (csr_waddr_b_reg)
                12'h305: // mtvec
                    reg_file[0] <= csr_wdata_b;
                12'h340: // mscratch
                    reg_file[1] <= csr_wdata_b;
                12'h341: // mepc
                    reg_file[2] <= csr_wdata_b;
                12'h342: // mcause
                    reg_file[3] <= csr_wdata_b;
                12'h300: // mstatus
                begin
                    reg_file[4] <= csr_wdata_b;
                    if (csr_wdata_b[12:11] == 2'b0 || csr_wdata_b == 2'b1) begin
                        reg_file[12][8] <= csr_wdata_b[11];
                    end
                end
                12'h304: // mie
                    reg_file[5] <= csr_wdata_b;
                // 12'h344: // mip
                //     reg_file[6] <= csr_wdata_b;
                12'h180:
                    reg_file[7] <= csr_wdata_b;
                // 12'hF14: // mhartid
                //     reg_file[8] <= csr_wdata_b;
                12'h302: // medeleg
                    reg_file[9] <= csr_wdata_b;
                12'h303: // mideleg
                    reg_file[10] <= csr_wdata_b;
                12'h343: // mtval
                    reg_file[11] <= csr_wdata_b;
                // 12'h100: // sstatus
                //     reg_file[12] <= csr_wdata_b;
                // 12'h104: // sie
                //     reg_file[13] <= csr_wdata_b;
                // 12'h105: // stvec
                //     reg_file[14] <= csr_wdata_b;
                // 12'h140: // sscratch
                //     reg_file[15] <= csr_wdata_b;
                // 12'h141: // sepc
                //     reg_file[16] <= csr_wdata_b;
                // 12'h142: // scause
                //     reg_file[17] <= csr_wdata_b;
                // 12'h143: // stval
                //     reg_file[18] <= csr_wdata_b;
                // 12'h144: // sip
                //     reg_file[19] <= csr_wdata_b;
            endcase
            case (csr_waddr_c_reg)
                12'h305: // mtvec
                    reg_file[0] <= csr_wdata_c;
                12'h340: // mscratch
                    reg_file[1] <= csr_wdata_c;
                12'h341: // mepc
                    reg_file[2] <= csr_wdata_c;
                12'h342: // mcause
                    reg_file[3] <= csr_wdata_c;
                12'h300: // mstatus
                begin
                    reg_file[4] <= csr_wdata_c;
                    if (csr_wdata_c[12:11] == 2'b0 || csr_wdata_c == 2'b1) begin
                        reg_file[12][8] <= csr_wdata_c[11];
                    end
                end
                12'h304: // mie
                    reg_file[5] <= csr_wdata_c;
                // 12'h344: // mip
                //     reg_file[6] <= csr_wdata_c;
                12'h180:
                    reg_file[7] <= csr_wdata_c;
                // 12'hF14: // mhartid
                //     reg_file[8] <= csr_wdata_c;
                12'h302: // medeleg
                    reg_file[9] <= csr_wdata_c;
                12'h303: // mideleg
                    reg_file[10] <= csr_wdata_c;
                12'h343: // mtval
                    reg_file[11] <= csr_wdata_c;
                // 12'h100: // sstatus
                //     reg_file[12] <= csr_wdata_c;
                // 12'h104: // sie
                //     reg_file[13] <= csr_wdata_c;
                // 12'h105: // stvec
                //     reg_file[14] <= csr_wdata_c;
                // 12'h140: // sscratch
                //     reg_file[15] <= csr_wdata_c;
                // 12'h141: // sepc
                //     reg_file[16] <= csr_wdata_c;
                // 12'h142: // scause
                //     reg_file[17] <= csr_wdata_c;
                // 12'h143: // stval
                //     reg_file[18] <= csr_wdata_c;
                // 12'h144: // sip
                //     reg_file[19] <= csr_wdata_c;
            endcase
        end
    end
    // assign csr_rdata_a = csr_rdata_a_reg;

endmodule