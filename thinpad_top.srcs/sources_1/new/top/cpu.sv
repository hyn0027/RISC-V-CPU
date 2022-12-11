`default_nettype none

module cpu #
(
    parameter FORWARD_TARGET_NUM = 5
)
(
    input wire clk,
    input wire rst,

    output reg pc_we,   // control sig
    output reg pc_sel, //为0 pc+4 ；为1 pc_jump 
    input wire [31:0] pc_save, //存如果不跳转的正常下一条pc 
    input wire [31:0] pc_new, //id阶段输入给状态机的 跳转到的新pc
    output reg [31:0] pc_jump, //pc需要跳转到的下一个地方 （有可能是pc_new 有可能是pc_target 有可能是恢复pc_recover）

    output reg if_we,   // control sig
    input wire if_ack,
    output reg if_empty,    // control sig
    input wire is_jump_if, //if阶段是否为跳转指令
    input wire is_jump_id, //id阶段是否为跳转指令

    output reg id_we,       // control sig
    input wire id_ack,
    output reg id_empty,    // control sig
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire cmp_res,
    input wire [7:0] inst_type_id,

    output reg exe_we,      // control sig
    input wire exe_ack,
    output reg exe_empty,   // control sig
 

    output reg mem_we,      // control sig
    input wire mem_ack,
    output reg mem_empty,   // control sig

    output reg wb_we,       // control sig
    input wire wb_ack,
    output reg wb_empty,     // control sig

    input wire [4:0] rd_0,
    input wire [7:0] inst_type_exe2mem,
    output reg pl_we_2,
    input reg rf_wen_exe2mem,

    input wire [31:0] except_i,
    output reg [31:0] except_o,
    output reg id_exception,
    input wire [31:0] pc_except,
    output reg [31:0] pc_mepc,
    input wire [31:0] pc_wb,
    input wire [31:0] pc_mem,
    input wire [31:0] pc_exe,
    input wire [31:0] pc_id,
    input wire [31:0] pc_if,
    input wire [31:0] pc_pc,

    output reg flash_we,
    input wire flash_ack
);
    typedef enum logic[3:0] {
        WAITING_FOR_DONE,
        WAITING_BRANCH,
        FORWARDING,
        EXCEPTION,
        INTERRUPT_PC,
        INTERRUPT_DONE
    } state_t;

    state_t state;
    logic if_done;
    logic id_done;
    logic exe_done;
    logic mem_done;
    logic wb_done;
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
    always_comb begin
        if (rf_wen_exe2mem == 1'b1 && inst_type_exe2mem != LB && inst_type_exe2mem != LBU && inst_type_exe2mem != LH && inst_type_exe2mem != LHU && inst_type_exe2mem != LW) begin
            pl_we_2 = 1'b1;
        end
        else begin
            pl_we_2 = 1'b0;
        end
    end

    logic [31:0] pc_target [0:FORWARD_TARGET_NUM-1]; //存一组：预测的pc值
    logic [31:0] pc_target_origin [0:FORWARD_TARGET_NUM-1];//存一组：预测的pc值所对应的 原始跳转指令pc
    logic [2:0]  pc_target_idx; //存访问的pc_target下标
    logic [2:0]  pc_target_update_idx; //更新pc_target的时候 选中更替的下标 
    logic [31:0] pc_recover;//存：跳转指令不跳转 恢复该条跳转指令pc的值

    // logic [31:0] except_cause;
    logic except_handling;
    logic [1:0] if_except;
    logic id_except;
    logic flash_doing;
    logic flash_done;
    // logic [1:0] id_except_reg;
    
    // assign except_o = except_cause;
    // assign id_except_reg = id_except;

    always @(posedge clk) begin
        if (flash_doing === 1'b1) begin
            if (flash_ack) begin
                flash_we <= 1'b0;//关flash
                pc_we <= 1'b1;
                pc_sel <= 1'b0;
                flash_doing <= 1'b0;
                flash_done <= 1'b1;
                pc_target[0] <= 32'h8000_0000; // 预测pc寄存器
                pc_target[1] <= 32'h8000_0000; // 预测pc寄存器
                pc_target[2] <= 32'h8000_0000; // 预测pc寄存器
                pc_target[3] <= 32'h8000_0000; // 预测pc寄存器
                pc_target[4] <= 32'h8000_0000; // 预测pc寄存器
                pc_target_origin [0] <= 32'h8000_0000;
                pc_target_origin [1] <= 32'h8000_0000;
                pc_target_origin [2] <= 32'h8000_0000;
                pc_target_origin [3] <= 32'h8000_0000;
                pc_target_origin [4] <= 32'h8000_0000;
                pc_target_idx <= 0;
                pc_target_update_idx <= 0;
                pc_recover <= 32'h8000_0000; // 不跳转恢复pc寄存器
                pc_jump <= 32'h8000_0000; //初始化 新pc 

                if_we <= 1'b1;
                if_empty <= 1'b0;
                id_we <= 1'b1;
                id_empty <= 1'b0;
                exe_we <= 1'b1;
                exe_empty <= 1'b0;
                mem_we <= 1'b1;
                mem_empty <= 1'b0;
                wb_we <= 1'b1;
                wb_empty <= 1'b0;

                id_except <= 1'b0;
                if_except <= 2'b0;

                if_done <= 1'b0;
                id_done <= 1'b0;
                exe_done <= 1'b0;
                mem_done <= 1'b0;
                wb_done <= 1'b0;
                except_handling <= 1'b0;
                state <= WAITING_FOR_DONE;
            end
        end else if (rst == 1'b1) begin
            // 如果需要flash工作，打开以下五行，否则注释以下五行
            if (!(flash_done === 1'b1)) begin
                flash_doing <= 1'b1;
                flash_done <= 1'b0;
                flash_we <= 1'b1;//让flash工作先写入base_ram
            end      
            // 如果需要flash工作，注释214~253行，否则打开214~253行
                // flash_we <= 1'b0;//关flash
                // pc_we <= 1'b1;
                // pc_sel <= 1'b0;
                // flash_doing <= 1'b0;
                // pc_target[0] <= 32'h8000_0000; // 预测pc寄存器
                // pc_target[1] <= 32'h8000_0000; // 预测pc寄存器
                // pc_target[2] <= 32'h8000_0000; // 预测pc寄存器
                // pc_target[3] <= 32'h8000_0000; // 预测pc寄存器
                // pc_target[4] <= 32'h8000_0000; // 预测pc寄存器
                // pc_target_origin [0] <= 32'h8000_0000;
                // pc_target_origin [1] <= 32'h8000_0000;
                // pc_target_origin [2] <= 32'h8000_0000;
                // pc_target_origin [3] <= 32'h8000_0000;
                // pc_target_origin [4] <= 32'h8000_0000;
                // pc_target_idx <= 0;
                // pc_target_update_idx <= 0;
                // pc_recover <= 32'h8000_0000; // 不跳转恢复pc寄存器
                // pc_jump <= 32'h8000_0000; //初始化 新pc 

                // if_we <= 1'b1;
                // if_empty <= 1'b0;
                // id_we <= 1'b1;
                // id_empty <= 1'b0;
                // exe_we <= 1'b1;
                // exe_empty <= 1'b0;
                // mem_we <= 1'b1;
                // mem_empty <= 1'b0;
                // wb_we <= 1'b1;
                // wb_empty <= 1'b0;

                // id_except <= 1'b0;
                // if_except <= 2'b0;

                // if_done <= 1'b0;
                // id_done <= 1'b0;
                // exe_done <= 1'b0;
                // mem_done <= 1'b0;
                // wb_done <= 1'b0;
                // state <= WAITING_FOR_DONE;
        end else if (except_i[31:30] == 2'b10) begin
            // interrupt
            case (state)
            WAITING_FOR_DONE, FORWARDING: begin
                except_o <= except_i;
                case (except_i) 
                    32'h80000007, 32'h80000005: begin
                        if_we <= 1'b1;
                        if_empty <= 1'b1;
                        id_we <= 1'b1;
                        id_exception <= 1'b1;
                        id_empty <= 1'b0;
                        pc_mepc <= pc_wb;
                        exe_we <= 1'b1;
                        exe_empty <= 1'b1;
                        mem_we <= 1'b1;
                        mem_empty <= 1'b1;
                        wb_we <= 1'b1;
                        wb_empty <= 1'b1;
                        
                        if_done <= 1'b0;
                        id_done <= 1'b0;
                        exe_done <= 1'b0;
                        mem_done <= 1'b0;
                        wb_done <= 1'b0;
                        except_handling <= 1'b1;
                        state <= INTERRUPT_PC;
                    end
                endcase
            end
            WAITING_BRANCH: begin
                except_o <= except_i;
                case (except_i) 
                    32'h80000007, 32'h80000005: begin
                        if_we <= 1'b1;
                        if_empty <= 1'b1;
                        id_we <= 1'b1;
                        id_exception <= 1'b1;
                        pc_mepc <= pc_pc;
                        exe_we <= 1'b1;
                        exe_empty <= 1'b1;
                        mem_we <= 1'b1;
                        mem_empty <= 1'b1;
                        wb_we <= 1'b1;
                        wb_empty <= 1'b1;
                        
                        if_done <= 1'b0;
                        id_done <= 1'b0;
                        exe_done <= 1'b0;
                        mem_done <= 1'b0;
                        wb_done <= 1'b0;
                        except_handling <= 1'b1;
                        state <= INTERRUPT_PC;
                    end
                endcase
            end
            endcase
        end else if (except_i == 32'hc || except_i == 32'hd || except_i == 32'hf) begin
            except_o <= except_i;
            case (except_i) 
                32'hd, 32'hf: begin
                    if_we <= 1'b1;
                    if_empty <= 1'b1;
                    id_we <= 1'b1;
                    id_exception <= 1'b1;
                    id_empty <= 1'b0;
                    pc_mepc <= pc_mem;
                    exe_we <= 1'b1;
                    exe_empty <= 1'b1;
                    mem_we <= 1'b1;
                    mem_empty <= 1'b1;
                    wb_we <= 1'b1;
                    wb_empty <= 1'b1;
                    except_handling <= 1'b1;
                end
                32'hc: begin
                    pc_we <= 1'b0;
                    if_we <= 1'b0;
                    if_done <= 1'b1;
                    id_we <= 1'b1;
                    id_empty <= 1'b1;
                    id_done <= 1'b0;
                    exe_we <= 1'b1;
                    exe_done <= 1'b0;
                    mem_we <= 1'b1;
                    mem_done <= 1'b0;
                    wb_we <= 1'b1;
                    wb_done <= 1'b0;
                    if_except <= 2'b10;
                end
            endcase
        end else if (except_i[31] == 1'b0 || except_i == 32'hFFFFFFFF) begin
            flash_done <= 1'b0;
            case (state)
                WAITING_FOR_DONE: begin
                    if ((if_done | if_ack) == 1'b1 && (id_done | id_ack) == 1'b1 && (exe_done | exe_ack) == 1'b1 && (mem_done  | mem_ack) == 1'b1 && (wb_done | wb_ack) == 1'b1) begin
                    // if (if_done == 1'b1 && id_done == 1'b1 && exe_done == 1'b1 && mem_done == 1'b1 && wb_done == 1'b1) begin
                        if (((rs1 != 5'b0 && (rs1 == rd_0)) || (rs2 != 5'b0 && (rs2 == rd_0))) && (inst_type_exe2mem == LW || inst_type_exe2mem == LHU || inst_type_exe2mem == LH || inst_type_exe2mem == LBU || inst_type_exe2mem == LB)) begin
                            // 数据装入冲突
                            if_we <= 1'b0;

                            id_we <= 1'b0;

                            exe_we <= 1'b1;
                            pc_we <= 1'b0;
                            exe_empty <= 1'b1;//气泡

                            mem_we <= 1'b1;
                            mem_empty <= 1'b0;
                            wb_we <= 1'b1;
                            wb_empty <= 1'b0;
                            if_done <= 1'b1;
                            id_done <= 1'b1;
                            exe_done <= 1'b0;
                            mem_done <= 1'b0;
                            wb_done <= 1'b0;
                        end else if (inst_type_id == MRET || inst_type_id == SRET) begin
                            if_we <= 1'b0;
                            id_we <= 1'b0;
                            exe_we <= 1'b0;
                            mem_we <= 1'b0;
                            wb_we <= 1'b0;

                            if_done <= 1'b0;
                            id_done <= 1'b0;
                            mem_done <= 1'b0;
                            exe_done <= 1'b0;
                            wb_done <= 1'b0;

                            pc_we <= 1'b1;
                            pc_sel <= 1'b1;
                            pc_jump <= pc_except; 
                            pc_target[pc_target_idx] <= pc_except; 
                            state <= WAITING_BRANCH;  
                        end else if (except_i != 32'hFFFFFFFF || if_except != 2'b0) begin
                            case (except_i)
                                // exe阶段触发异常
                                32'h4 , 32'h5 , 32'h6 , 32'h7: begin
                                    except_o <= except_i;
                                    if_we <= 1'b1;
                                    if_empty <= 1'b1;
                                    id_we <= 1'b1;
                                    id_exception <= 1'b1;
                                    id_empty <= 1'b0;
                                    pc_mepc <= pc_exe;
                                    exe_we <= 1'b1;
                                    exe_empty <= 1'b1;
                                    mem_we <= 1'b1;
                                    mem_empty <= 1'b1;
                                    wb_we <= 1'b1;
                                    wb_empty <= 1'b0;
                                    except_handling <= 1'b1;
                                end
                                // id阶段触发异常
                                32'h2 , 32'h3 , 32'h8, 32'h9, 32'hb: begin
                                    except_o <= except_i;
                                    if (id_except == 1'b0) begin
                                        pc_we <= 1'b0;
                                        if_we <= 1'b0;
                                        id_we <= 1'b0;
                                        exe_we <= 1'b1;
                                        exe_empty <= 1'b1;
                                        mem_we <= 1'b1;
                                        wb_we <= 1'b1;
                                        if_done <= 1'b1;
                                        id_done <= 1'b1;
                                        mem_done <= 1'b0;
                                        exe_done <= 1'b0;
                                        wb_done <= 1'b0;
                                    end else begin
                                        if_we <= 1'b1;
                                        if_empty <= 1'b1;
                                        id_we <= 1'b1;
                                        id_exception <= 1'b1;
                                        id_empty <= 1'b0;
                                        pc_mepc <= pc_id;
                                        exe_we <= 1'b1;
                                        exe_empty <= 1'b1;
                                        mem_we <= 1'b1;
                                        mem_empty <= 1'b0;
                                        wb_we <= 1'b1;
                                        wb_empty <= 1'b0;
                                        except_handling <= 1'b1;
                                    end
                                    id_except <= id_except+1;
                                end
                                // pc阶段触发异常
                                32'h0, 32'h1: begin
                                    except_o <= except_i;
                                    if (if_except == 2'b0) begin
                                        pc_we <= 1'b0;
                                        if_we <= 1'b0;
                                        if_done <= 1'b1;
                                        if (inst_type_id == MRET || inst_type_id == SRET || (cmp_res == 1'b1 && pc_target[pc_target_idx] != pc_new)) begin
                                            id_we <= 1'b0;
                                        end else begin
                                            id_we <= 1'b1;
                                        end
                                        exe_we <= 1'b1;
                                        mem_we <= 1'b1;
                                        wb_we <= 1'b1;
                                    end else if (if_except == 2'b1) begin
                                        pc_we <= 1'b0;
                                        if_we <= 1'b0;
                                        id_we <= 1'b0;
                                        id_done <= 1'b1;
                                        exe_we <= 1'b1;
                                        mem_we <= 1'b1;
                                        wb_we <= 1'b1;
                                    end else if (if_except == 2'b10) begin
                                        pc_we <= 1'b1;
                                        pc_sel <= 1'b1;
                                        pc_jump <= 32'b0;
                                        if_we <= 1'b0;
                                        id_we <= 1'b0;
                                        id_empty <= 1'b0;
                                        exe_we <= 1'b0;
                                        exe_done <= 1'b1;
                                        mem_we <= 1'b1;
                                        wb_we <= 1'b1;
                                    end else begin
                                        if_we <= 1'b1;
                                        if_empty <= 1'b1;
                                        id_we <= 1'b1;
                                        id_exception <= 1'b1;
                                        id_done <= 1'b0;
                                        id_empty <= 1'b0;
                                        pc_mepc <= pc_pc-4;
                                        exe_we <= 1'b1;
                                        exe_empty <= 1'b1;
                                        mem_we <= 1'b1;
                                        mem_empty <= 1'b1;
                                        wb_we <= 1'b1;
                                        except_handling <= 1'b1;
                                    end
                                    if_except <= if_except+1;
                                end
                                default: begin
                                    if (except_o == 32'hc) begin
                                        if (if_except == 2'b10) begin
                                            pc_we <= 1'b0;
                                            if_we <= 1'b0;
                                            id_we <= 1'b0;
                                            id_empty <= 1'b0;
                                            exe_we <= 1'b0;
                                            exe_done <= 1'b1;
                                            mem_we <= 1'b1;
                                            wb_we <= 1'b1;
                                        end else begin
                                            if_we <= 1'b1;
                                            if_empty <= 1'b1;
                                            id_we <= 1'b1;
                                            id_exception <= 1'b1;
                                            id_empty <= 1'b0;
                                            pc_mepc <= pc_if;
                                            exe_we <= 1'b1;
                                            exe_empty <= 1'b1;
                                            mem_we <= 1'b1;
                                            mem_empty <= 1'b1;
                                            wb_we <= 1'b1;
                                            except_handling <= 1'b1;
                                        end
                                        if_except <= if_except + 1;
                                    end else begin
                                        if_we <= 1'b1;
                                        if_empty <= 1'b1;
                                        id_we <= 1'b1;
                                        id_exception <= 1'b1;
                                        id_empty <= 1'b0;
                                        pc_mepc <= pc_exe;
                                        exe_we <= 1'b1;
                                        exe_empty <= 1'b1;
                                        mem_we <= 1'b1;
                                        mem_empty <= 1'b1;
                                        wb_we <= 1'b1;
                                        wb_empty <= 1'b1;
                                    end
                                end
                            endcase
                        end else if (except_handling == 1'b1) begin
                            // branch
                            except_handling <= 1'b0;
                            if_except <= 2'b0;
                            id_except <= 1'b0;
                            if_we <= 1'b0;
                            id_we <= 1'b0;
                            id_exception <= 1'b0;
                            exe_we <= 1'b0;
                            mem_we <= 1'b0;
                            wb_we <= 1'b0;

                            if_empty <= 1'b0;
                            id_empty <= 1'b0;
                            exe_empty <= 1'b0;
                            mem_empty <= 1'b0;
                            wb_empty <= 1'b0;

                            if_done <= 1'b0;
                            id_done <= 1'b0;
                            mem_done <= 1'b0;
                            exe_done <= 1'b0;
                            wb_done <= 1'b0;

                            pc_we <= 1'b1;
                            pc_sel <= 1'b1;
                            pc_jump <= pc_except; 
                            pc_target[pc_target_idx] <= pc_except; //更新分支预测的pc值
                            state <= EXCEPTION;                          
                        end else if (cmp_res == 1'b1 && pc_target[pc_target_idx] != pc_new) begin //第一次跳转 和预测跳转错误  更新预测跳转的寄存器
                            if_we <= 1'b0;
                            id_we <= 1'b0;
                            exe_we <= 1'b0;
                            mem_we <= 1'b0;
                            wb_we <= 1'b0;

                            if_done <= 1'b0;
                            id_done <= 1'b0;
                            mem_done <= 1'b0;
                            exe_done <= 1'b0;
                            wb_done <= 1'b0;

                            pc_we <= 1'b1;
                            pc_sel <= 1'b1;
                            pc_jump <= pc_new; 
                            pc_target[pc_target_idx] <= pc_new; //更新分支预测的pc值
                            state <= WAITING_BRANCH;
                        end else if (cmp_res == 1'b0 && is_jump_id == 1'b1 && pc_target[pc_target_idx] != pc_recover) begin //下一条已经改为跳转后的指令，但是实际上该条跳转指令没有跳转 需要恢复
                            if_we <= 1'b0;
                            id_we <= 1'b0;
                            exe_we <= 1'b0;
                            mem_we <= 1'b0;
                            wb_we <= 1'b0;

                            if_done <= 1'b0;
                            id_done <= 1'b0;
                            mem_done <= 1'b0;
                            exe_done <= 1'b0;
                            wb_done <= 1'b0;

                            pc_we <= 1'b1; //改pc
                            pc_sel <= 1'b1;
                            pc_jump <= pc_recover; //恢复下一条指令的pc值
                            pc_target[pc_target_idx] <= pc_recover; 
                            state <= WAITING_BRANCH;
                        end else if (is_jump_if == 1'b1) begin //改下一条pc为分支预测的target_pc、存下来该跳转指令的pc（如果后续不满足跳转条件可恢复pc）
                            //stall住所有的阶段
                            if_we <= 1'b0;
                            id_we <= 1'b0;
                            exe_we <= 1'b0;
                            mem_we <= 1'b0;
                            wb_we <= 1'b0;

                            pc_we <= 1'b1;
                            pc_sel <= 1'b1;
                            if(pc_save == pc_target_origin[0])begin //当前跳转指令的pc可以在表pc_target_origin中找到匹配的条目
                                pc_target_idx <= 3'd0; //存下使用的pc_target表的下标
                                pc_jump <= pc_target[0]; //将匹配到的预测表中的跳转目的pc 输出给pc_mux 
                            end else if(pc_save == pc_target_origin[1]) begin
                                pc_target_idx <= 3'd1;
                                pc_jump <= pc_target[1];
                            end else if(pc_save == pc_target_origin[2]) begin
                                pc_target_idx <= 3'd2;
                                pc_jump <= pc_target[2];
                            end else if(pc_save == pc_target_origin[3]) begin
                                pc_target_idx <= 3'd3;
                                pc_jump <= pc_target[3];
                            end else if(pc_save == pc_target_origin[4]) begin
                                pc_target_idx <= 3'd4;
                                pc_jump <= pc_target[4];
                            end else begin //pc_target_origin没有匹配的条目
                                pc_jump <= pc_save + 32'd4; //下一条pc正常执行后面的
                                //清除掉target和pc表中的一对儿 存这对儿pc和target
                                pc_target_origin[pc_target_update_idx] <= pc_save;//更新 原始跳转指令pc
                                pc_target_idx <= pc_target_update_idx; //记录当前更新的下标 
                                pc_target[pc_target_update_idx] <= pc_save + 32'd4; //更新跳转的地址
                                pc_target_update_idx <= (pc_target_update_idx + 3'd1) %  FORWARD_TARGET_NUM; //更新pc_target_update_idx
                            end
                            pc_recover <= pc_save + 32'd4; //存上原本的（不跳转）下一条pc地址
                            state <= FORWARDING;
                        end else begin
                            // 没有冲突
                            pc_we <= 1'b1;
                            pc_sel <= 1'b0;

                            if_we <= 1'b1;
                            if_empty <= 1'b0;

                            id_we <= 1'b1;
                            id_empty <= 1'b0;
                            id_exception <= 1'b0;
                            pc_mepc <= 32'b0;

                            exe_we <= 1'b1;
                            exe_empty <= 1'b0;

                            mem_we <= 1'b1;
                            mem_empty <= 1'b0;

                            wb_we <= 1'b1;
                            wb_empty <= 1'b0;

                            if_done <= 1'b0;
                            id_done <= 1'b0;
                            exe_done <= 1'b0;
                            mem_done <= 1'b0;
                            wb_done <= 1'b0;
                        end
                    end else begin //还有的阶段没工作完
                        if (if_ack == 1'b1) begin
                            if_done <= 1'b1;
                            if_we <= 1'b0;
                        end
                        if (id_ack == 1'b1) begin
                            id_done <= 1'b1;
                            id_we <= 1'b0;
                        end
                        if (exe_ack == 1'b1) begin
                            exe_done <= 1'b1;
                            exe_we <= 1'b0;
                        end
                        if (mem_ack == 1'b1) begin
                            mem_done <= 1'b1;
                            mem_we <= 1'b0;
                        end
                        if (wb_ack == 1'b1) begin
                            wb_done <= 1'b1;
                            wb_we <= 1'b0;
                        end
                        pc_we <= 1'b0; //不让pc工作
                    end
                end
                WAITING_BRANCH: begin //擦掉下一条指令（id）
                    pc_we <= 1'b1;
                    pc_sel <= 1'b0;

                    if_we <= 1'b1;
                    if_empty <= 1'b0;

                    id_we <= 1'b1;
                    id_empty <= 1'b1;

                    exe_we <= 1'b1;
                    exe_empty <= 1'b0;

                    mem_we <= 1'b1;
                    mem_empty <= 1'b0;

                    wb_we <= 1'b1;
                    wb_empty <= 1'b0;

                    if_done <= 1'b0;
                    id_done <= 1'b0;
                    exe_done <= 1'b0;
                    mem_done <= 1'b0;
                    wb_done <= 1'b0;
                    state <= WAITING_FOR_DONE;
                end
                FORWARDING: begin //所有指令都可正常执行
                    pc_we <= 1'b1;
                    pc_sel <= 1'b0;

                    if_we <= 1'b1;
                    if_empty <= 1'b0;

                    id_we <= 1'b1;
                    id_empty <= 1'b0;

                    exe_we <= 1'b1;
                    exe_empty <= 1'b0;

                    mem_we <= 1'b1;
                    mem_empty <= 1'b0;

                    wb_we <= 1'b1;
                    wb_empty <= 1'b0;

                    if_done <= 1'b0;
                    id_done <= 1'b0;
                    exe_done <= 1'b0;
                    mem_done <= 1'b0;
                    wb_done <= 1'b0;
                    state <= WAITING_FOR_DONE;
                end
                EXCEPTION: begin
                    pc_we <= 1'b0;
                    if_we <= 1'b0;
                    id_we <= 1'b0;
                    exe_we <= 1'b0;
                    mem_we <= 1'b0;
                    wb_we <= 1'b0;

                    if_done <= 1'b1;
                    id_done <= 1'b1;
                    exe_done <= 1'b1;
                    mem_done <= 1'b1;
                    wb_done <= 1'b1;
                    state <= WAITING_FOR_DONE;
                end
                INTERRUPT_PC: begin
                    if ((if_done | if_ack) == 1'b1 && (id_done | id_ack) == 1'b1 && (exe_done | exe_ack) == 1'b1 && (mem_done  | mem_ack) == 1'b1 && (wb_done | wb_ack) == 1'b1) begin
                        except_handling <= 1'b0;
                        if_except <= 2'b0;
                        id_except <= 1'b0;
                        if_we <= 1'b0;
                        id_we <= 1'b0;
                        id_exception <= 1'b0;
                        exe_we <= 1'b0;
                        mem_we <= 1'b0;
                        wb_we <= 1'b0;

                        if_done <= 1'b0;
                        id_done <= 1'b0;
                        mem_done <= 1'b0;
                        exe_done <= 1'b0;
                        wb_done <= 1'b0;

                        pc_we <= 1'b1;
                        pc_sel <= 1'b1;
                        pc_jump <= pc_except; 
                        pc_target[pc_target_idx] <= pc_except; //更新分支预测的pc值
                        state <= INTERRUPT_DONE;
                    end
                end
                INTERRUPT_DONE: begin
                    pc_we <= 1'b0;
                    if_we <= 1'b0;
                    id_we <= 1'b0;
                    exe_we <= 1'b0;
                    mem_we <= 1'b0;
                    wb_we <= 1'b0;

                    if_done <= 1'b1;
                    id_done <= 1'b1;
                    exe_done <= 1'b1;
                    mem_done <= 1'b1;
                    wb_done <= 1'b1;
                    state <= WAITING_FOR_DONE;
                end
            endcase
        end
    end
endmodule