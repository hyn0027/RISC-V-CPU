`default_nettype none

module thinpad_top (
    input wire clk_50M,     // 50MHz 时钟输入
    input wire clk_11M0592, // 11.0592MHz 时钟输入（备用，可不用）

    input wire push_btn,  // BTN5 按钮开关，带消抖电路，按下时为 1
    input wire reset_btn, // BTN6 复位按钮，带消抖电路，按下时为 1

    input  wire [ 3:0] touch_btn,  // BTN1~BTN4，按钮开关，按下时为 1
    input  wire [31:0] dip_sw,     // 32 位拨码开关，拨到“ON”时为 1
    output wire [15:0] leds,       // 16 位 LED，输出时 1 点亮
    output wire [ 7:0] dpy0,       // 数码管低位信号，包括小数点，输出 1 点亮
    output wire [ 7:0] dpy1,       // 数码管高位信号，包括小数点，输出 1 点亮

    // CPLD 串口控制器信号
    output wire uart_rdn,        // 读串口信号，低有效
    output wire uart_wrn,        // 写串口信号，低有效
    input  wire uart_dataready,  // 串口数据准备好
    input  wire uart_tbre,       // 发送数据标志
    input  wire uart_tsre,       // 数据发送完毕标志

    // BaseRAM 信号
    inout wire [31:0] base_ram_data,  // BaseRAM 数据，低 8 位与 CPLD 串口控制器共享
    output wire [19:0] base_ram_addr,  // BaseRAM 地址
    output wire [3:0] base_ram_be_n,  // BaseRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
    output wire base_ram_ce_n,  // BaseRAM 片选，低有效
    output wire base_ram_oe_n,  // BaseRAM 读使能，低有效
    output wire base_ram_we_n,  // BaseRAM 写使能，低有效

    // ExtRAM 信号
    inout wire [31:0] ext_ram_data,  // ExtRAM 数据
    output wire [19:0] ext_ram_addr,  // ExtRAM 地址
    output wire [3:0] ext_ram_be_n,  // ExtRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
    output wire ext_ram_ce_n,  // ExtRAM 片选，低有效
    output wire ext_ram_oe_n,  // ExtRAM 读使能，低有效
    output wire ext_ram_we_n,  // ExtRAM 写使能，低有效

    // 直连串口信号
    output wire txd,  // 直连串口发送端
    input  wire rxd,  // 直连串口接收端

    // Flash 存储器信号，参考 JS28F640 芯片手册
    output wire [22:0] flash_a,  // Flash 地址，a0 仅在 8bit 模式有效，16bit 模式无意义
    inout wire [15:0] flash_d,  // Flash 数据
    output wire flash_rp_n,  // Flash 复位信号，低有效
    output wire flash_vpen,  // Flash 写保护信号，低电平时不能擦除、烧写
    output wire flash_ce_n,  // Flash 片选信号，低有效
    output wire flash_oe_n,  // Flash 读使能信号，低有效
    output wire flash_we_n,  // Flash 写使能信号，低有效
    output wire flash_byte_n, // Flash 8bit 模式选择，低有效。在使用 flash 的 16 位模式时请设为 1

    // USB 控制器信号，参考 SL811 芯片手册
    output wire sl811_a0,
    // inout  wire [7:0] sl811_d,     // USB 数据线与网络控制器的 dm9k_sd[7:0] 共享
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    // 网络控制器信号，参考 DM9000A 芯片手册
    output wire dm9k_cmd,
    inout wire [15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input wire dm9k_int,

    // 图像输出信号
    output wire [2:0] video_red,    // 红色像素，3 位
    output wire [2:0] video_green,  // 绿色像素，3 位
    output wire [1:0] video_blue,   // 蓝色像素，2 位
    output wire       video_hsync,  // 行同步（水平同步）信号
    output wire       video_vsync,  // 场同步（垂直同步）信号
    output wire       video_clk,    // 像素时钟输出
    output wire       video_de      // 行数据有效信号，用于区分消隐区
);


    /* =========== Demo code begin =========== */

    // PLL 分频示例
    logic locked, clk_10M, clk_90M, clk_100M;
    pll_example clock_gen (
        // Clock in ports
        .clk_in1(clk_50M),  // 外部时钟输入
        // Clock out ports
        .clk_out1(clk_10M),  // 时钟输出 1，频率在 IP 配置界面中设置
        .clk_out2(clk_90M),  // 时钟输出 2，频率在 IP 配置界面中设置
        .clk_out3(clk_100M),
        // Status and control signals
        .reset(reset_btn),  // PLL 复位输入
        .locked(locked)  // PLL 锁定指示输出，"1"表示时钟稳定，
                       // 后级电路复位信号应当由它生成（见下）
    );

    logic [18:0] bram_addra;
    logic [7:0] dina;
    logic [0:0] wea;

    logic [18:0] bram_addrb;
    logic [7:0] doutb;
    logic enb;
    bram videoRAM(
        .addra  (bram_addra),
        .clka   (clk_90M),
        .dina   (dina),
        .ena    (1'b1),
        .wea    (wea),

        .addrb  (bram_addrb),
        .clkb   (clk_50M),
        .doutb  (doutb),
        .enb    (1'b1)
    );

    logic reset_of_clk90M;
    // 异步复位，同步释放，将 locked 信号转为后级电路的复位 reset_of_clk90M
    always_ff @(posedge clk_90M or negedge locked) begin
        if (~locked) reset_of_clk90M <= 1'b1;
        else reset_of_clk90M <= 1'b0;
    end
    // logic reset_of_clk10M;
    // always_ff @(posedge clk_10M or negedge locked) begin
    //     if (~locked) reset_of_clk10M <= 1'b1;
    //     else reset_of_clk10M <= 1'b0;
    // end
    logic reset_of_clk50M;
    always_ff @(posedge clk_50M or negedge locked) begin
        if (~locked) reset_of_clk50M <= 1'b1;
        else reset_of_clk50M <= 1'b0;
    end
    logic [1:0] last_mode;
    logic [1:0] mode;
    logic [1:0] mode_id2exe;
    logic [1:0] mode_exe2mem;
    logic timeout;
    
    logic pc_we;
    logic [31:0]pc_pc2if;
    logic [31:0] pc_jump;
    logic pc_sel;
    pc_mux m_pc_mux (
        .clk    (clk_90M),
        .rst    (reset_of_clk90M),
        .pc_we  (pc_we),
        .PCSel  (pc_sel),
        .pc     (pc_pc2if),
        .pc_i   (pc_jump)
    );

    logic mmu_we_if; //mmu是否工作
    logic mmu_ack_if;//mmu是否工作完成
    logic [31:0] addr_if2mmu; //mmu收到的IF的虚拟地址
    logic [31:0] data_mmu2if;//mmu转换得到的物理地址给if

    logic cache_we_r_if; //cache是否工作
    logic cache_ack_r_if;
    logic [31:0] addr_mmu2cache_if;//给cache的让其查找表项的地址
    logic [31:0] data_cache2mmu_if;//从cache得到的数据
    logic [31:0] satp;

    logic mmu_clear_if;
    logic page_fault_if;
    mmu m_mmu_if(
        .clk    (clk_90M),
        .rst    (reset_of_clk90M),

        .mmu_we (mmu_we_if),
        .mmu_ack(mmu_ack_if),

        .cpu_adr_i      (addr_if2mmu),
        .cpu_data_i     (32'b0),
        .cpu_w_or_r     (1'b0),
        .sel_i          (4'b1111),
        .cpu_data_o     (data_mmu2if),

        .cache_we_w     (),
        .cache_we_r     (cache_we_r_if),    
        .cache_ack_w    (),
        .cache_ack_r    (cache_ack_r_if),
        
        .cache_adr_o    (addr_mmu2cache_if),
        .cache_w_data_o (),
        .cache_data_i   (data_cache2mmu_if),
        .sel_o          (),

        .mmu_clear      (mmu_clear_if),

        // .csr_raddr_a    (),
        .satp           (satp),
        .mode           (mode),
        .page_fault     (page_fault_if)
    );
    logic cache_clear_i;
    logic clear_ack_i; 

    logic        wbm_cyc_o_if;
    logic        wbm_stb_o_if;
    logic        wbm_ack_i_if;
    logic [31:0] wbm_adr_o_if;
    logic [31:0] wbm_dat_o_if;
    logic [31:0] wbm_dat_i_if;
    logic [ 3:0] wbm_sel_o_if;
    logic        wbm_we_o_if;

    cache i_cache (
        .clk        (clk_90M),
        .rst        (reset_of_clk90M),

        .r_addr         (addr_mmu2cache_if),
        .r_data         (data_cache2mmu_if),
        .r_we           (cache_we_r_if),
        .r_ack          (cache_ack_r_if),
        .r_sel          (4'b1111),

        .w_addr         (32'b0),
        .w_data         (32'b0),
        .w_we           (1'b0),
        .w_ack          (),
        .w_sel          (4'b1111),

        .clear          (cache_clear_i),
        .clear_ack      (clear_ack_i),

        .wb_cyc_o   (wbm_cyc_o_if),
        .wb_stb_o   (wbm_stb_o_if),
        .wb_ack_i   (wbm_ack_i_if),
        .wb_adr_o   (wbm_adr_o_if),
        .wb_dat_o   (wbm_dat_o_if),
        .wb_dat_i   (wbm_dat_i_if),
        .wb_sel_o   (wbm_sel_o_if),
        .wb_we_o    (wbm_we_o_if)
    );

    logic if_we;
    logic [31:0] inst_if2id;
    logic if_ack;
    logic [31:0] pc_if2id;
    logic if_empty;
    logic is_jump_if; //是否为跳转指令

    if_state m_if (
        .clk    (clk_90M),
        .rst    (reset_of_clk90M),
        .pc     (pc_pc2if),
        .if_we  (if_we),
        .empty  (if_empty),
        .inst   (inst_if2id),
        .if_ack (if_ack),
        .pc_o   (pc_if2id), //将这里的跳转指令给cpu 存下来 以防不跳转的时候恢复
        .is_jump(is_jump_if), //是否为跳转指令

        .mmu_r_addr       (addr_if2mmu),
        .mmu_r_data       (data_mmu2if),
        .mmu_r_we         (mmu_we_if),
        .mmu_r_ack        (mmu_ack_if),
        
        .cache_clear    (cache_clear_i),
        .cache_clear_ack    (clear_ack_i),

        .mmu_clear          (mmu_clear_if)
    );

    logic is_jump_id; //是否为跳转指令
    logic [31:0] pc_new;
    logic id_we;
    logic id_empty;
    logic id_ack;
    logic [31:0] data_a_id2exe;
    logic [31:0] data_b_id2exe;
    logic [31:0] data_c_id2exe;
    logic [4:0] rs1_id2exe;
    logic [4:0] rs2_id2exe;
    logic [7:0] inst_type_id2exe;
    logic cmp_res_id2exe;
    logic ex_en_id2exe;
    logic [3:0] alu_op_id2exe;
    logic [3:0] imm_type_id2exe;
    logic [31:0] imm_id2exe;
    logic use_rs1_id2exe;
    logic use_rs2_id2exe;
    logic [31:0] pc_id2exe;
    logic mem_w_en_id2exe;
    logic mem_r_en_id2exe;
    logic rf_wen_id2exe;
    logic [4:0]rf_waddr_id2exe;

    logic [4:0] rf_raddr_a;
    logic signed [31:0] rf_rdata_a;
    logic [4:0] rf_raddr_b;
    logic signed [31:0] rf_rdata_b;
    logic [4:0] rf_waddr;
    logic signed [31:0] rf_wdata;
    logic rf_we;

    logic [11:0] csr_raddr_a;
    logic signed [31:0] csr_rdata_a;

    logic [11:0] csr_waddr_a;
    logic signed [31:0] csr_wdata_a;
    logic [11:0] csr_waddr_b;
    logic signed [31:0] csr_wdata_b;
    logic [11:0] csr_waddr_c;
    logic signed [31:0] csr_wdata_c;
    logic [1:0]  csr_we;

    logic [11:0] csr_waddr_a_id2exe;
    logic signed [31:0] csr_wdata_a_id2exe;
    logic [11:0] csr_waddr_b_id2exe;
    logic signed [31:0] csr_wdata_b_id2exe;
    logic [11:0] csr_waddr_c_id2exe;
    logic signed [31:0] csr_wdata_c_id2exe;
    logic [1:0] csr_we_id2exe;

    logic use_csr_alu;
    logic use_csr_alu_imm;
    logic [31:0] except_cause;
    logic [31:0] except_cause_cpu;
    logic [31:0] pc_mepc;
    logic id_exception;

    logic [31:0] mtime_low;
    logic [31:0] mtime_high;
    logic [31:0] mtimecmp_low;
    logic [31:0] mtimecmp_high;

    id m_id (
        .clk        (clk_90M),
        .rst        (reset_of_clk90M),
        .inst_i     (inst_if2id),
        .id_we      (id_we),
        .pc_i       (pc_if2id),
        .empty      (id_empty),
        .mode       (mode),

        .id_ack         (id_ack),
        .id_mode        (mode_id2exe),
        .data_a         (data_a_id2exe),
        .data_b         (data_b_id2exe),
        .rs1_o          (rs1_id2exe),
        .rs2_o          (rs2_id2exe),
        .inst_type_o    (inst_type_id2exe),
        .ex_en          (ex_en_id2exe),
        .alu_op         (alu_op_id2exe),
        .imm_type_o     (imm_type_id2exe),
        .imm            (imm_id2exe),
        .use_rs1        (use_rs1_id2exe),
        .use_rs2        (use_rs2_id2exe),
        .pc_o           (pc_id2exe),
        .mem_w_en       (mem_w_en_id2exe),
        .mem_r_en       (mem_r_en_id2exe),
        .rf_wen         (rf_wen_id2exe),
        .rf_waddr_o     (rf_waddr_id2exe),
        .csr_waddr_a_o    (csr_waddr_a_id2exe),
        .csr_waddr_b_o    (csr_waddr_b_id2exe),
        .csr_waddr_c_o    (csr_waddr_c_id2exe),
        .csr_wdata_a_o    (csr_wdata_a_id2exe),
        .csr_wdata_b_o    (csr_wdata_b_id2exe),
        .csr_wdata_c_o    (csr_wdata_c_id2exe),
        .csr_we_o       (csr_we_id2exe),
        .data_c         (data_c_id2exe),
        .use_csr_alu    (use_csr_alu),
        .use_csr_alu_imm(use_csr_alu_imm),
        .cmp_res        (cmp_res_id2exe),
        .pc_new         (pc_new),
        .is_jump        (is_jump_id), //id 阶段给cpu的是否为跳转指令

        .rf_raddr_a     (rf_raddr_a),
        .rf_rdata_a     (rf_rdata_a),
        .rf_raddr_b     (rf_raddr_b),
        .rf_rdata_b     (rf_rdata_b),

        .csr_raddr_a    (csr_raddr_a),
        .csr_rdata_a    (csr_rdata_a),

        .except         (except_cause_cpu),
        .pc_mepc        (pc_mepc),
        .id_exception   (id_exception)
    );

    logic pl_we_2;

    regfile_new m_regfile (
        .clk        (clk_90M),
        .rst        (reset_of_clk90M),

        .rf_raddr_a     (rf_raddr_a),
        .rf_rdata_a     (rf_rdata_a),
        .rf_raddr_b     (rf_raddr_b),
        .rf_rdata_b     (rf_rdata_b),

        .rf_waddr       (rf_waddr),
        .rf_wdata       (rf_wdata),
        .rf_we          (rf_we),

        .pl_we_1        (rf_wen_mem2wb),
        .pl_addr_1      (rf_waddr_mem2wb),
        .pl_data_1      (rf_wdata_mem2wb),
        
        .pl_we_2        (pl_we_2),
        .pl_addr_2      (rf_waddr_exe2mem),
        .pl_data_2      (data_o_ex2mem)
    );

    csr_reg m_csr_reg (
        .clk       (clk_90M),
        .rst       (reset_of_clk90M),

        .csr_raddr_a (csr_raddr_a),
        .csr_rdata_a (csr_rdata_a),
        .satp        (satp),

        .csr_waddr_a (csr_waddr_a),
        .csr_wdata_a (csr_wdata_a),
        .csr_waddr_b (csr_waddr_b),
        .csr_wdata_b (csr_wdata_b),
        .csr_waddr_c (csr_waddr_c),
        .csr_wdata_c (csr_wdata_c),

        .csr_we      (csr_we),
        .mode        (mode),
        .last_mode   (last_mode),
        .timeout     (timeout),

        .pl_we_mem        (csr_we_mem2wb),
        .pl_addr_mem_a    (csr_waddr_a_mem2wb),
        .pl_data_mem_a    (csr_wdata_a_mem2wb),
        .pl_addr_mem_b    (csr_waddr_b_mem2wb),
        .pl_data_mem_b    (csr_wdata_b_mem2wb),
        .pl_addr_mem_c    (csr_waddr_c_mem2wb),
        .pl_data_mem_c    (csr_wdata_c_mem2wb),

        .pl_we_exe        (csr_we_exe2mem),
        .pl_addr_exe_a    (csr_waddr_a_exe2mem),
        .pl_data_exe_a    (csr_wdata_a_exe2mem),
        .pl_addr_exe_b    (csr_waddr_b_exe2mem),
        .pl_data_exe_b    (csr_wdata_b_exe2mem),
        .pl_addr_exe_c    (csr_waddr_c_exe2mem),
        .pl_data_exe_c    (csr_wdata_c_exe2mem),

        .mtime_low        (mtime_low),
        .mtime_high       (mtime_high),
        .mtimecmp_low     (mtimecmp_low),
        .mtimecmp_high    (mtimecmp_high)
    );

    logic exe_we;
    logic exe_empty;
    logic exe_ack;
    logic mem_w_en_exe2mem;
    logic mem_r_en_exe2mem;
    logic [7:0] inst_type_exe2mem;
    logic rf_wen_exe2mem;
    logic [4:0] rf_waddr_exe2mem;
    logic [31:0] data_b_exe2mem;
    logic [31:0] pc_exe2mem;
    logic signed [31:0] alu_a;
    logic signed [31:0] alu_b;
    logic [3:0] alu_op;
    logic signed [31:0] alu_y;
    logic [31:0] data_o_ex2mem;
    
    logic [11:0] csr_waddr_a_exe2mem;
    logic signed [31:0] csr_wdata_a_exe2mem;
    logic [11:0] csr_waddr_b_exe2mem;
    logic signed [31:0] csr_wdata_b_exe2mem;
    logic [11:0] csr_waddr_c_exe2mem;
    logic signed [31:0] csr_wdata_c_exe2mem;
    logic [1:0] csr_we_exe2mem;

    exe m_exe(
        .clk            (clk_90M),
        .rst            (reset_of_clk90M),
        .exe_we         (exe_we),
        .empty          (exe_empty),
        .exe_ack        (exe_ack),

        .ex_en          (ex_en_id2exe),
        .alu_op_i       (alu_op_id2exe),
        .imm_type       (imm_type_id2exe),
        .imm            (imm_id2exe),
        .data_a         (data_a_id2exe),
        .data_b         (data_b_id2exe),
        .data_c         (data_c_id2exe),
        .use_rs1        (use_rs1_id2exe),
        .use_rs2        (use_rs2_id2exe),
        .use_csr_alu    (use_csr_alu),
        .use_csr_alu_imm(use_csr_alu_imm),
        .pc_i           (pc_id2exe),
        .mem_w_en_i     (mem_w_en_id2exe),
        .mem_r_en_i     (mem_r_en_id2exe),
        .inst_type_i    (inst_type_id2exe),
        .rf_wen_i       (rf_wen_id2exe),
        .rf_waddr_i     (rf_waddr_id2exe),
        .csr_waddr_a_i    (csr_waddr_a_id2exe),
        .csr_waddr_b_i    (csr_waddr_b_id2exe),
        .csr_waddr_c_i    (csr_waddr_c_id2exe),
        .csr_wdata_a_i    (csr_wdata_a_id2exe),
        .csr_wdata_b_i    (csr_wdata_b_id2exe),
        .csr_wdata_c_i    (csr_wdata_c_id2exe),
        .csr_we_i       (csr_we_id2exe),
        .mode_i         (mode_id2exe),

        .mode_o         (mode_exe2mem),
        .ex_data_o      (data_o_ex2mem),
        .mem_w_en_o     (mem_w_en_exe2mem),
        .mem_r_en_o     (mem_r_en_exe2mem),
        .inst_type_o    (inst_type_exe2mem),
        .rf_wen_o       (rf_wen_exe2mem),
        .rf_waddr_o     (rf_waddr_exe2mem),
        .data_b_o       (data_b_exe2mem),
        .pc_o           (pc_exe2mem),
        .csr_waddr_a_o    (csr_waddr_a_exe2mem),
        .csr_waddr_b_o    (csr_waddr_b_exe2mem),
        .csr_waddr_c_o    (csr_waddr_c_exe2mem),
        .csr_wdata_a_o    (csr_wdata_a_exe2mem),
        .csr_wdata_b_o    (csr_wdata_b_exe2mem),
        .csr_wdata_c_o    (csr_wdata_c_exe2mem),
        .csr_we_o       (csr_we_exe2mem),

        .alu_a  (alu_a),
        .alu_b  (alu_b),
        .alu_op (alu_op),
        .alu_y  (alu_y)
    );

    alu_new m_alu(
        .alu_a  (alu_a),
        .alu_b  (alu_b),
        .alu_op (alu_op),
        .alu_y  (alu_y)
    );

    logic [31:0] cache_addr_d;
    logic [31:0] cache_r_data_d;
    logic cache_r_we_d;
    logic cache_r_ack_d;
    logic [3:0] cache_sel_d;

    logic [31:0] cache_w_data_d;
    logic cache_w_we_d;
    logic cache_w_ack_d;

    logic cache_clear_d;
    logic clear_ack_d;

    logic        wbm_cyc_o_mem;
    logic        wbm_stb_o_mem;
    logic        wbm_ack_i_mem;
    logic [31:0] wbm_adr_o_mem;
    logic [31:0] wbm_dat_o_mem;
    logic [31:0] wbm_dat_i_mem;
    logic [ 3:0] wbm_sel_o_mem;
    logic        wbm_we_o_mem;

    cache d_cache (
        .clk        (clk_90M),
        .rst        (reset_of_clk90M),

        .r_addr         (cache_addr_d),
        .r_data         (cache_r_data_d),
        .r_we           (cache_r_we_d),
        .r_ack          (cache_r_ack_d),
        .r_sel          (cache_sel_d),
        
        .w_addr         (cache_addr_d),
        .w_data         (cache_w_data_d),
        .w_we           (cache_w_we_d),
        .w_ack          (cache_w_ack_d),
        .w_sel          (cache_sel_d),

        .clear          (cache_clear_d),
        .clear_ack      (clear_ack_d),

        .wb_cyc_o   (wbm_cyc_o_mem),
        .wb_stb_o   (wbm_stb_o_mem),
        .wb_ack_i   (wbm_ack_i_mem),
        .wb_adr_o   (wbm_adr_o_mem),
        .wb_dat_o   (wbm_dat_o_mem),
        .wb_dat_i   (wbm_dat_i_mem),
        .wb_sel_o   (wbm_sel_o_mem),
        .wb_we_o    (wbm_we_o_mem)
    );

    logic mem_we;
    logic mem_empty;
    logic mem_ack;
    
    logic rf_wen_mem2wb;
    logic [4:0] rf_waddr_mem2wb;
    logic [31:0] rf_wdata_mem2wb;
    logic [11:0] csr_waddr_a_mem2wb;
    logic signed [31:0] csr_wdata_a_mem2wb;
    logic [11:0] csr_waddr_b_mem2wb;
    logic signed [31:0] csr_wdata_b_mem2wb;
    logic [11:0] csr_waddr_c_mem2wb;
    logic signed [31:0] csr_wdata_c_mem2wb;
    logic [1:0] csr_we_mem2wb;

    logic [31:0] clint_raddr_a;
    logic signed [31:0] clint_rdata_a;
    logic [31:0] clint_waddr_a;
    logic signed [31:0] clint_wdata_a;
    logic clint_we;

    logic [31:0] pc_mem2wb;

    logic mmu_we_d;
    logic mmu_ack_d;
    logic [31:0] mmu_w_data_d;
    logic [31:0] mmu_addr_d;
    logic [3:0] mmu_sel_d;
    logic mmu_w_or_r_d;
    logic [31:0] mmu_data_i_d;
    logic [7:0] inst_type_mem2wb;

    mem m_mem(
        .clk            (clk_90M),
        .rst            (reset_of_clk90M),
        .mem_we         (mem_we),
        .empty          (mem_empty),
        .mem_ack        (mem_ack),

        .mem_w_en       (mem_w_en_exe2mem),
        .mem_r_en       (mem_r_en_exe2mem),
        .mem_w_data     (data_b_exe2mem),
        .ex_data_i      (data_o_ex2mem),
        .inst_type_i    (inst_type_exe2mem),
        .rf_wen_i       (rf_wen_exe2mem),
        .rf_waddr_i     (rf_waddr_exe2mem),
        .pc_i           (pc_exe2mem),
        .csr_waddr_a_i    (csr_waddr_a_exe2mem),
        .csr_waddr_b_i    (csr_waddr_b_exe2mem),
        .csr_waddr_c_i    (csr_waddr_c_exe2mem),
        .csr_wdata_a_i    (csr_wdata_a_exe2mem),
        .csr_wdata_b_i    (csr_wdata_b_exe2mem),
        .csr_wdata_c_i    (csr_wdata_c_exe2mem),
        .csr_we_i       (csr_we_exe2mem),

        .inst_type_o    (inst_type_mem2wb),
        .pc_o           (pc_mem2wb),
        .rf_wen_o       (rf_wen_mem2wb),
        .rf_waddr_o     (rf_waddr_mem2wb),
        .rf_wdata_o       (rf_wdata_mem2wb),
        .csr_waddr_a_o    (csr_waddr_a_mem2wb),
        .csr_waddr_b_o    (csr_waddr_b_mem2wb),
        .csr_waddr_c_o    (csr_waddr_c_mem2wb),
        .csr_wdata_a_o    (csr_wdata_a_mem2wb),
        .csr_wdata_b_o    (csr_wdata_b_mem2wb),
        .csr_wdata_c_o    (csr_wdata_c_mem2wb),
        .csr_we_o       (csr_we_mem2wb),
        
        .mmu_we         (mmu_we_d),
        .mmu_ack        (mmu_ack_d),
        .mmu_w_data     (mmu_w_data_d),
        .mmu_addr       (mmu_addr_d),
        .mmu_sel_o      (mmu_sel_d),
        .mmu_w_or_r     (mmu_w_or_r_d),
        .mmu_data_i     (mmu_data_i_d),

        .clint_raddr_a  (clint_raddr_a),
        .clint_rdata_a  (clint_rdata_a),
        .clint_waddr_a  (clint_waddr_a),
        .clint_wdata_a  (clint_wdata_a),
        .clint_we       (clint_we),

        .cache_clear    (cache_clear_d),
        .cache_clear_ack    (clear_ack_d),

        .mmu_clear      (mmu_clear_d)
    );

    logic mmu_clear_d;
    logic page_fault_mem;
    mem_mmu m_mmu_mem(
        .clk    (clk_90M),
        .rst    (reset_of_clk90M),

        .mmu_we (mmu_we_d),
        .mmu_ack(mmu_ack_d),

        .cpu_adr_i      (mmu_addr_d),
        .cpu_data_i     (mmu_w_data_d),
        .cpu_w_or_r     (mmu_w_or_r_d),
        .sel_i          (mmu_sel_d),
        .cpu_data_o     (mmu_data_i_d),

        .cache_we_w     (cache_w_we_d),
        .cache_we_r     (cache_r_we_d),    
        .cache_ack_w    (cache_w_ack_d),
        .cache_ack_r    (cache_r_ack_d),
        
        .cache_adr_o    (cache_addr_d),
        .cache_w_data_o (cache_w_data_d),
        .cache_data_i   (cache_r_data_d),
        .sel_o          (cache_sel_d),

        .mmu_clear      (mmu_clear_d),

        .satp           (satp),//读出来的satp寄存器值
        .mode           (mode_exe2mem),
        .page_fault     (page_fault_mem),

        .bram_addr      (bram_addra),
        .bram_data      (dina),
        .bram_we        (wea)
    );

    clint m_clint(
        .clk            (clk_90M),
        .rst            (reset_of_clk90M),

        .clint_raddr_a  (clint_raddr_a),
        .clint_rdata_a  (clint_rdata_a),
        .clint_waddr_a  (clint_waddr_a),
        .clint_wdata_a  (clint_wdata_a),
        .clint_we       (clint_we),

        .mtime_low      (mtime_low),
        .mtime_high     (mtime_high),
        .mtimecmp_low   (mtimecmp_low),
        .mtimecmp_high  (mtimecmp_high)
    );

    logic        wbm_cyc_o;
    logic        wbm_stb_o;
    logic        wbm_ack_i;
    logic [31:0] wbm_adr_o;
    logic [31:0] wbm_dat_o;
    logic [31:0] wbm_dat_i;
    logic [ 3:0] wbm_sel_o;
    logic        wbm_we_o;

    logic wb_we;
    logic wb_empty;
    logic wb_ack;

    logic [31:0] pc_wb2end;
    
    wb m_wb(
        .clk        (clk_90M),
        .rst        (reset_of_clk90M),
        .wb_we      (wb_we),
        .empty      (wb_empty),
        .wb_ack     (wb_ack),
        .pc_i       (pc_mem2wb),

        .rf_wen_i   (rf_wen_mem2wb),
        .rf_waddr_i (rf_waddr_mem2wb),
        .rf_wdata_i (rf_wdata_mem2wb),
        .csr_waddr_a_i    (csr_waddr_a_mem2wb),
        .csr_waddr_b_i    (csr_waddr_b_mem2wb),
        .csr_waddr_c_i    (csr_waddr_c_mem2wb),
        .csr_wdata_a_i    (csr_wdata_a_mem2wb),
        .csr_wdata_b_i    (csr_wdata_b_mem2wb),
        .csr_wdata_c_i    (csr_wdata_c_mem2wb),
        .csr_we_i       (csr_we_mem2wb),

        .pc_o       (pc_wb2end),
        .rf_waddr   (rf_waddr),
        .rf_wdata   (rf_wdata),
        .rf_we      (rf_we),

        .csr_waddr_a (csr_waddr_a),
        .csr_wdata_a (csr_wdata_a),
        .csr_waddr_b (csr_waddr_b),
        .csr_wdata_b (csr_wdata_b),
        .csr_waddr_c (csr_waddr_c),
        .csr_wdata_c (csr_wdata_c),
        .csr_we     (csr_we)
    );

    logic flash_we;
    logic flash_ack;

    cpu m_cpu(
        .clk        (clk_90M),
        .rst        (reset_of_clk90M),

        .pc_we      (pc_we),
        .pc_sel     (pc_sel),
        .pc_new     (pc_new), //id阶段跳转到的新pc
        .pc_jump    (pc_jump), //输出给pc_mux的跳转到的下一个pc
        .pc_save    (pc_if2id),

        .if_we      (if_we),
        .if_ack     (if_ack),
        .if_empty   (if_empty),

        .id_we      (id_we),
        .id_ack     (id_ack),
        .id_empty   (id_empty),
        .rs1        (rs1_id2exe),
        .rs2        (rs2_id2exe),
        .is_jump_if (is_jump_if), //if阶段传来的 是否跳转
        .is_jump_id (is_jump_id),//id阶段传来的 是否跳转 
        .inst_type_id(inst_type_id2exe),

        .exe_we     (exe_we),
        .exe_ack    (exe_ack),
        .exe_empty  (exe_empty),
        .cmp_res    (cmp_res_id2exe),

        .mem_we     (mem_we),
        .mem_ack    (mem_ack),
        .mem_empty  (mem_empty),

        .wb_we      (wb_we),
        .wb_ack     (wb_ack),
        .wb_empty   (wb_empty),

        .rd_0               (rf_waddr_exe2mem),
        .inst_type_exe2mem  (inst_type_exe2mem),
        .pl_we_2            (pl_we_2),
        .rf_wen_exe2mem     (rf_wen_exe2mem),

        .except_i   (except_cause),
        .except_o   (except_cause_cpu),
        .id_exception(id_exception),
        .pc_except  (data_c_id2exe),
        .pc_mepc    (pc_mepc),
        .pc_wb      (pc_wb2end),
        .pc_mem     (pc_mem2wb),
        .pc_exe     (pc_exe2mem),
        .pc_id      (pc_id2exe),
        .pc_if      (pc_if2id),
        .pc_pc      (pc_pc2if),

        .flash_we   (flash_we),//TODO:
        .flash_ack  (flash_ack)
    );

    logic wbs0_stb_o_flash;
    logic wbs0_cyc_o_flash;
    logic wbs0_ack_i_flash;
    logic [31:0] wbs0_adr_o_flash;
    logic [31:0] wbs0_dat_o_flash;
    flash m_flash(//TODO:
        .clk        (clk_90M),
        .rst        (reset_of_clk90M),

        .flash_we   (flash_we),
        .flash_ack  (flash_ack),

        .flash_a        (flash_a),//直接从flash读
        .flash_d        (flash_d),
        .flash_ce_n     (flash_ce_n),

        .wb_cyc_o       (wbs0_cyc_o_flash),
        .wb_stb_o       (wbs0_stb_o_flash),
        .wb_ack_i       (wbs0_ack_i_flash),
        .wb_adr_o       (wbs0_adr_o_flash),
        .wb_dat_o       (wbs0_dat_o_flash)
    );
    
    assign flash_rp_n = 1'b1;//复位无效
    assign flash_byte_n = 1'b1;//16bit模式
    assign flash_oe_n = 1'b0;//读使能（始终为读）
    assign flash_we_n = 1'b1;//写使能 （始终不写）
    assign flash_vpen = 1'b0;

    except_handler m_except_handler(
        .clk        (clk_90M),
        .rst        (reset_of_clk90M),
        .mode       (mode),
        .last_mode  (last_mode),
        .timeout    (timeout),
        .pc_i       (pc_pc2if),
        .inst_type_i_id(inst_type_id2exe),
        .inst_type_i_exe(inst_type_exe2mem),
        .inst_type_i_mem(inst_type_mem2wb),
        .ls_addr_i  (data_o_ex2mem),
        .cause_o    (except_cause),
        .page_fault_if(page_fault_if),
        .page_fault_mem(page_fault_mem)
    );

/* =========== if MUX begin =========== */
    logic wbs0_cyc_o_if;
    logic wbs0_stb_o_if;
    logic wbs0_ack_i_if;
    logic [31:0] wbs0_adr_o_if;
    logic [31:0] wbs0_dat_o_if;
    logic [31:0] wbs0_dat_i_if;
    logic [3:0] wbs0_sel_o_if;
    logic wbs0_we_o_if;

    logic wbs1_cyc_o_if;
    logic wbs1_stb_o_if;
    logic wbs1_ack_i_if;
    logic [31:0] wbs1_adr_o_if;
    logic [31:0] wbs1_dat_o_if;
    logic [31:0] wbs1_dat_i_if;
    logic [3:0] wbs1_sel_o_if;
    logic wbs1_we_o_if;

    wb_mux_2 wb_mux_if (
        .clk(clk_90M),
        .rst(reset_of_clk90M),

        // Master interface (to SRAM Tester)
        .wbm_adr_i(wbm_adr_o_if),
        .wbm_dat_i(wbm_dat_o_if),
        .wbm_dat_o(wbm_dat_i_if),
        .wbm_we_i (wbm_we_o_if),
        .wbm_sel_i(wbm_sel_o_if),
        .wbm_stb_i(wbm_stb_o_if),
        .wbm_ack_o(wbm_ack_i_if),
        .wbm_err_o(),
        .wbm_rty_o(),
        .wbm_cyc_i(wbm_cyc_o_if),

        // Slave interface 0 (to BaseRAM controller)
        // Address range: 0x8000_0000 ~ 0x803F_FFFF
        .wbs0_addr    (32'h8000_0000),
        .wbs0_addr_msk(32'hFFC0_0000),

        .wbs0_adr_o(wbs0_adr_o_if),
        .wbs0_dat_i(wbs0_dat_i_if),
        .wbs0_dat_o(wbs0_dat_o_if),
        .wbs0_we_o (wbs0_we_o_if),
        .wbs0_sel_o(wbs0_sel_o_if),
        .wbs0_stb_o(wbs0_stb_o_if),
        .wbs0_ack_i(wbs0_ack_i_if),
        .wbs0_err_i('0),
        .wbs0_rty_i('0),
        .wbs0_cyc_o(wbs0_cyc_o_if),

        // Slave interface 1 (to ExtRAM controller)
        // Address range: 0x8040_0000 ~ 0x807F_FFFF
        .wbs1_addr    (32'h8040_0000),
        .wbs1_addr_msk(32'hFFC0_0000),

        .wbs1_adr_o(wbs1_adr_o_if),
        .wbs1_dat_i(wbs1_dat_i_if),
        .wbs1_dat_o(wbs1_dat_o_if),
        .wbs1_we_o (wbs1_we_o_if),
        .wbs1_sel_o(wbs1_sel_o_if),
        .wbs1_stb_o(wbs1_stb_o_if),
        .wbs1_ack_i(wbs1_ack_i_if),
        .wbs1_err_i('0),
        .wbs1_rty_i('0),
        .wbs1_cyc_o(wbs1_cyc_o_if)
    );
/* =========== if MUX end =========== */

/* =========== mem MUX begin =========== */
    // Wishbone MUX (Masters) => bus slaves
    logic wbs0_cyc_o_mem;
    logic wbs0_stb_o_mem;
    logic wbs0_ack_i_mem;
    logic [31:0] wbs0_adr_o_mem;
    logic [31:0] wbs0_dat_o_mem;
    logic [31:0] wbs0_dat_i_mem;
    logic [3:0] wbs0_sel_o_mem;
    logic wbs0_we_o_mem;

    logic wbs1_cyc_o_mem;
    logic wbs1_stb_o_mem;
    logic wbs1_ack_i_mem;
    logic [31:0] wbs1_adr_o_mem;
    logic [31:0] wbs1_dat_o_mem;
    logic [31:0] wbs1_dat_i_mem;
    logic [3:0] wbs1_sel_o_mem;
    logic wbs1_we_o_mem;

    logic wbs2_cyc_o_mem;
    logic wbs2_stb_o_mem;
    logic wbs2_ack_i_mem;
    logic [31:0] wbs2_adr_o_mem;
    logic [31:0] wbs2_dat_o_mem;
    logic [31:0] wbs2_dat_i_mem;
    logic [3:0] wbs2_sel_o_mem;
    logic wbs2_we_o_mem;

    wb_mux_3 wb_mux_mem (
        .clk        (clk_90M),
        .rst        (reset_of_clk90M),

        // Master interface (to DM)
        .wbm_adr_i(wbm_adr_o_mem),
        .wbm_dat_i(wbm_dat_o_mem),
        .wbm_dat_o(wbm_dat_i_mem),
        .wbm_we_i (wbm_we_o_mem),
        .wbm_sel_i(wbm_sel_o_mem),
        .wbm_stb_i(wbm_stb_o_mem),
        .wbm_ack_o(wbm_ack_i_mem),
        .wbm_err_o(),
        .wbm_rty_o(),
        .wbm_cyc_i(wbm_cyc_o_mem),

        // Slave interface 0 (to BaseRAM controller)
        // Address range: 0x8000_0000 ~ 0x803F_FFFF
        .wbs0_addr    (32'h8000_0000),
        .wbs0_addr_msk(32'hFFC0_0000),

        .wbs0_adr_o(wbs0_adr_o_mem),
        .wbs0_dat_i(wbs0_dat_i_mem),
        .wbs0_dat_o(wbs0_dat_o_mem),
        .wbs0_we_o (wbs0_we_o_mem),
        .wbs0_sel_o(wbs0_sel_o_mem),
        .wbs0_stb_o(wbs0_stb_o_mem),
        .wbs0_ack_i(wbs0_ack_i_mem),
        .wbs0_err_i('0),
        .wbs0_rty_i('0),
        .wbs0_cyc_o(wbs0_cyc_o_mem),

        // Slave interface 1 (to ExtRAM controller)
        // Address range: 0x8040_0000 ~ 0x807F_FFFF
        .wbs1_addr    (32'h8040_0000),
        .wbs1_addr_msk(32'hFFC0_0000),

        .wbs1_adr_o(wbs1_adr_o_mem),
        .wbs1_dat_i(wbs1_dat_i_mem),
        .wbs1_dat_o(wbs1_dat_o_mem),
        .wbs1_we_o (wbs1_we_o_mem),
        .wbs1_sel_o(wbs1_sel_o_mem),
        .wbs1_stb_o(wbs1_stb_o_mem),
        .wbs1_ack_i(wbs1_ack_i_mem),
        .wbs1_err_i('0),
        .wbs1_rty_i('0),
        .wbs1_cyc_o(wbs1_cyc_o_mem),

        // Slave interface 2 (to UART controller)
        // Address range: 0x1000_0000 ~ 0x1000_FFFF
        .wbs2_addr    (32'h1000_0000),
        .wbs2_addr_msk(32'hFFFF_0000),

        .wbs2_adr_o(wbs2_adr_o_mem),
        .wbs2_dat_i(wbs2_dat_i_mem),
        .wbs2_dat_o(wbs2_dat_o_mem),
        .wbs2_we_o (wbs2_we_o_mem),
        .wbs2_sel_o(wbs2_sel_o_mem),
        .wbs2_stb_o(wbs2_stb_o_mem),
        .wbs2_ack_i(wbs2_ack_i_mem),
        .wbs2_err_i('0),
        .wbs2_rty_i('0),
        .wbs2_cyc_o(wbs2_cyc_o_mem)
  );
/* =========== mem MUX end =========== */

/* =========== flash arbiter begin =========== */
//TODO：
    logic wbf_base_ram_cyc_o;
    logic wbf_base_ram_stb_o;
    logic wbf_base_ram_ack_i;
    logic [31:0] wbf_base_ram_adr_o;
    logic [31:0] wbf_base_ram_dat_o;
    logic [31:0] wbf_base_ram_dat_i;
    logic [3:0] wbf_base_ram_sel_o;
    logic wbf_base_ram_we_o;
    wb_arbiter_2 m_wb_arbiter_flash(
        .clk            (clk_90M),
        .rst            (reset_of_clk90M),

        .wbm0_adr_i     (wbs0_adr_o_flash),//TODO：
        .wbm0_dat_i     (wbs0_dat_o_flash),
        .wbm0_dat_o     (),//只写所以不需要返回dat
        .wbm0_we_i      (1'b1),
        .wbm0_sel_i     (4'b1111),
        .wbm0_stb_i     (wbs0_stb_o_flash),
        .wbm0_ack_o     (wbs0_ack_i_flash),
        .wbm0_err_o     (),
        .wbm0_rty_o     (),
        .wbm0_cyc_i     (wbs0_cyc_o_flash),

        .wbm1_adr_i     (wbm_base_ram_adr_o),//TODO：
        .wbm1_dat_i     (wbm_base_ram_dat_o),
        .wbm1_dat_o     (wbm_base_ram_dat_i),
        .wbm1_we_i      (wbm_base_ram_we_o),
        .wbm1_sel_i     (wbm_base_ram_sel_o),
        .wbm1_stb_i     (wbm_base_ram_stb_o),
        .wbm1_ack_o     (wbm_base_ram_ack_i),
        .wbm1_err_o     (),
        .wbm1_rty_o     (),
        .wbm1_cyc_i     (wbm_base_ram_cyc_o),

        .wbs_adr_o      (wbf_base_ram_adr_o),//TODO：
        .wbs_dat_i      (wbf_base_ram_dat_i),//只写所以不需要返回dat
        .wbs_dat_o      (wbf_base_ram_dat_o),
        .wbs_we_o       (wbf_base_ram_we_o),
        .wbs_sel_o      (wbf_base_ram_sel_o),
        .wbs_stb_o      (wbf_base_ram_stb_o),
        .wbs_ack_i      (wbf_base_ram_ack_i),
        .wbs_err_i      ('0),
        .wbs_rty_i      ('0),
        .wbs_cyc_o      (wbf_base_ram_cyc_o)
    );
/* =========== flash arbiter end =========== */

/* =========== base_ram arbiter begin =========== */
    logic        wbm_base_ram_cyc_o;
    logic        wbm_base_ram_stb_o;
    logic        wbm_base_ram_ack_i;
    logic [31:0] wbm_base_ram_adr_o;
    logic [31:0] wbm_base_ram_dat_o;
    logic [31:0] wbm_base_ram_dat_i;
    logic [ 3:0] wbm_base_ram_sel_o;
    logic        wbm_base_ram_we_o;

    wb_arbiter_2 m_wb_arbiter_base_ram(
        .clk            (clk_90M),
        .rst            (reset_of_clk90M),

        .wbm0_adr_i     (wbs0_adr_o_if),
        .wbm0_dat_i     (wbs0_dat_o_if),
        .wbm0_dat_o     (wbs0_dat_i_if),
        .wbm0_we_i      (wbs0_we_o_if),
        .wbm0_sel_i     (wbs0_sel_o_if),
        .wbm0_stb_i     (wbs0_stb_o_if),
        .wbm0_ack_o     (wbs0_ack_i_if),
        .wbm0_err_o     (),
        .wbm0_rty_o     (),
        .wbm0_cyc_i     (wbs0_cyc_o_if),

        .wbm1_adr_i     (wbs0_adr_o_mem),
        .wbm1_dat_i     (wbs0_dat_o_mem),
        .wbm1_dat_o     (wbs0_dat_i_mem),
        .wbm1_we_i      (wbs0_we_o_mem),
        .wbm1_sel_i     (wbs0_sel_o_mem),
        .wbm1_stb_i     (wbs0_stb_o_mem),
        .wbm1_ack_o     (wbs0_ack_i_mem),
        .wbm1_err_o     (),
        .wbm1_rty_o     (),
        .wbm1_cyc_i     (wbs0_cyc_o_mem),

        .wbs_adr_o      (wbm_base_ram_adr_o),
        .wbs_dat_i      (wbm_base_ram_dat_i),
        .wbs_dat_o      (wbm_base_ram_dat_o),
        .wbs_we_o       (wbm_base_ram_we_o),
        .wbs_sel_o      (wbm_base_ram_sel_o),
        .wbs_stb_o      (wbm_base_ram_stb_o),
        .wbs_ack_i      (wbm_base_ram_ack_i),
        .wbs_err_i      ('0),
        .wbs_rty_i      ('0),
        .wbs_cyc_o      (wbm_base_ram_cyc_o)
    );
/* =========== base_ram arbiter end =========== */
/* =========== ext_ram arbiter end =========== */
    logic        wbm_ext_ram_cyc_o;
    logic        wbm_ext_ram_stb_o;
    logic        wbm_ext_ram_ack_i;
    logic [31:0] wbm_ext_ram_adr_o;
    logic [31:0] wbm_ext_ram_dat_o;
    logic [31:0] wbm_ext_ram_dat_i;
    logic [ 3:0] wbm_ext_ram_sel_o;
    logic        wbm_ext_ram_we_o;

    wb_arbiter_2 m_wb_arbiter_ext_ram(
        .clk            (clk_90M),
        .rst            (reset_of_clk90M),

        .wbm0_adr_i     (wbs1_adr_o_if),
        .wbm0_dat_i     (wbs1_dat_o_if),
        .wbm0_dat_o     (wbs1_dat_i_if),
        .wbm0_we_i      (wbs1_we_o_if),
        .wbm0_sel_i     (wbs1_sel_o_if),
        .wbm0_stb_i     (wbs1_stb_o_if),
        .wbm0_ack_o     (wbs1_ack_i_if),
        .wbm0_err_o     (),
        .wbm0_rty_o     (),
        .wbm0_cyc_i     (wbs1_cyc_o_if),

        .wbm1_adr_i     (wbs1_adr_o_mem),
        .wbm1_dat_i     (wbs1_dat_o_mem),
        .wbm1_dat_o     (wbs1_dat_i_mem),
        .wbm1_we_i      (wbs1_we_o_mem),
        .wbm1_sel_i     (wbs1_sel_o_mem),
        .wbm1_stb_i     (wbs1_stb_o_mem),
        .wbm1_ack_o     (wbs1_ack_i_mem),
        .wbm1_err_o     (),
        .wbm1_rty_o     (),
        .wbm1_cyc_i     (wbs1_cyc_o_mem),

        .wbs_adr_o     (wbm_ext_ram_adr_o),
        .wbs_dat_i      (wbm_ext_ram_dat_i),
        .wbs_dat_o      (wbm_ext_ram_dat_o),
        .wbs_we_o       (wbm_ext_ram_we_o),
        .wbs_sel_o      (wbm_ext_ram_sel_o),
        .wbs_stb_o      (wbm_ext_ram_stb_o),
        .wbs_ack_i      (wbm_ext_ram_ack_i),
        .wbs_err_i      ('0),
        .wbs_rty_i      ('0),
        .wbs_cyc_o      (wbm_ext_ram_cyc_o)
    );
/* =========== ext_ram arbiter end =========== */
/* =========== base ram Slaves begin =========== */
    sram_controller #(
        .SRAM_ADDR_WIDTH(20),
        .SRAM_DATA_WIDTH(32)
    ) sram_controller_base (
        .clk_i        (clk_90M),
        .rst_i        (reset_of_clk90M),

      // Wishbone slave (to MUX)
        .wb_cyc_i(wbf_base_ram_cyc_o),//TODO：
        .wb_stb_i(wbf_base_ram_stb_o),
        .wb_ack_o(wbf_base_ram_ack_i),
        .wb_adr_i(wbf_base_ram_adr_o),
        .wb_dat_i(wbf_base_ram_dat_o),
        .wb_dat_o(wbf_base_ram_dat_i),//只写所以不需要返回dat
        .wb_sel_i(wbf_base_ram_sel_o),
        .wb_we_i (wbf_base_ram_we_o),

        // To SRAM chip
        .sram_addr(base_ram_addr),
        .sram_data(base_ram_data),
        .sram_ce_n(base_ram_ce_n),
        .sram_oe_n(base_ram_oe_n),
        .sram_we_n(base_ram_we_n),
        .sram_be_n(base_ram_be_n)
    );
/* =========== base ram Slaves end =========== */
/* =========== ext ram Slaves begin =========== */
    sram_controller #(
        .SRAM_ADDR_WIDTH(20),
        .SRAM_DATA_WIDTH(32)
    ) sram_controller_ext (
        .clk_i        (clk_90M),
        .rst_i        (reset_of_clk90M),

        // Wishbone slave (to MUX)
        .wb_cyc_i(wbm_ext_ram_cyc_o),
        .wb_stb_i(wbm_ext_ram_stb_o),
        .wb_ack_o(wbm_ext_ram_ack_i),
        .wb_adr_i(wbm_ext_ram_adr_o),
        .wb_dat_i(wbm_ext_ram_dat_o),
        .wb_dat_o(wbm_ext_ram_dat_i),
        .wb_sel_i(wbm_ext_ram_sel_o),
        .wb_we_i (wbm_ext_ram_we_o),

        // To SRAM chip
        .sram_addr(ext_ram_addr),
        .sram_data(ext_ram_data),
        .sram_ce_n(ext_ram_ce_n),
        .sram_oe_n(ext_ram_oe_n),
        .sram_we_n(ext_ram_we_n),
        .sram_be_n(ext_ram_be_n)
    );
/* =========== ext ram Slaves begin =========== */

/* =========== uart ram Slaves begin =========== */
    uart_controller #(
        .CLK_FREQ(90_000_000),
        .BAUD    (115200)
    ) uart_controller (
        .clk_i        (clk_90M),
        .rst_i        (reset_of_clk90M),

        .wb_cyc_i(wbs2_cyc_o_mem),
        .wb_stb_i(wbs2_stb_o_mem),
        .wb_ack_o(wbs2_ack_i_mem),
        .wb_adr_i(wbs2_adr_o_mem),
        .wb_dat_i(wbs2_dat_o_mem),
        .wb_dat_o(wbs2_dat_i_mem),
        .wb_sel_i(wbs2_sel_o_mem),
        .wb_we_i (wbs2_we_o_mem),

        // to UART pins
        .uart_txd_o(txd),
        .uart_rxd_i(rxd)
    );
  assign uart_rdn = 1'b1;
  assign uart_wrn = 1'b1;
  /* =========== Lab5 Slaves end =========== */


//   // 数码管连接关系示意图，dpy1 同理
//   // p=dpy0[0] // ---a---
//   // c=dpy0[1] // |     |
//   // d=dpy0[2] // f     b
//   // e=dpy0[3] // |     |
//   // b=dpy0[4] // ---g---
//   // a=dpy0[5] // |     |
//   // f=dpy0[6] // e     c
//   // g=dpy0[7] // |     |
//   //           // ---d---  p

//   // 7 段数码管译码器演示，将 number 用 16 进制显示在数码管上面
//   logic [7:0] number;
//   SEG7_LUT segL (
//       .oSEG1(dpy0),
//       .iDIG (number[3:0])
//   );  // dpy0 是低位数码管
//   SEG7_LUT segH (
//       .oSEG1(dpy1),
//       .iDIG (number[7:4])
//   );  // dpy1 是高位数码管

//   logic [15:0] led_bits;
//   assign leds = led_bits;


//   // 直连串口接收发送演示，从直连串口收到的数据再发送出去
//   logic [7:0] ext_uart_rx;
//   logic [7:0] ext_uart_buffer, ext_uart_tx;
//   logic ext_uart_ready, ext_uart_clear, ext_uart_busy;
//   logic ext_uart_start, ext_uart_avai;

//   assign number = ext_uart_buffer;

//   // 接收模块，9600 无检验位
//   async_receiver #(
//       .ClkFrequency(50000000),
//       .Baud(9600)
//   ) ext_uart_r (
//       .clk           (clk_50M),         // 外部时钟信号
//       .RxD           (rxd),             // 外部串行信号输入
//       .RxD_data_ready(ext_uart_ready),  // 数据接收到标志
//       .RxD_clear     (ext_uart_clear),  // 清除接收标志
//       .RxD_data      (ext_uart_rx)      // 接收到的一字节数据
//   );

//   assign ext_uart_clear = ext_uart_ready; // 收到数据的同时，清除标志，因为数据已取到 ext_uart_buffer 中
//   always_ff @(posedge clk_50M) begin  // 接收到缓冲区 ext_uart_buffer
//     if (ext_uart_ready) begin
//       ext_uart_buffer <= ext_uart_rx;
//       ext_uart_avai   <= 1;
//     end else if (!ext_uart_busy && ext_uart_avai) begin
//       ext_uart_avai <= 0;
//     end
//   end
//   always_ff @(posedge clk_50M) begin  // 将缓冲区 ext_uart_buffer 发送出去
//     if (!ext_uart_busy && ext_uart_avai) begin
//       ext_uart_tx <= ext_uart_buffer;
//       ext_uart_start <= 1;
//     end else begin
//       ext_uart_start <= 0;
//     end
//   end

//   // 发送模块，9600 无检验位
//   async_transmitter #(
//       .ClkFrequency(50000000),
//       .Baud(9600)
//   ) ext_uart_t (
//       .clk      (clk_50M),         // 外部时钟信号
//       .TxD      (txd),             // 串行信号输出
//       .TxD_busy (ext_uart_busy),   // 发送器忙状态指示
//       .TxD_start(ext_uart_start),  // 开始发送信号
//       .TxD_data (ext_uart_tx)      // 待发送的数据
//   );

//   // 图像输出演示，分辨率 800x600@75Hz，像素时钟为 50MHz
  logic [11:0] hdata;
  logic [11:0] vdata;

  vga_color m_color(
    .clk        (clk_50M),
    .rst        (reset_of_clk50M),
    .video_red  (video_red),
    .video_green(video_green),
    .video_blue (video_blue),
    .video_clk  (video_clk),
    .hdata      (hdata),
    .vdata      (vdata),

    .bram_addr  (bram_addrb),
    .bram_data  (doutb)
  );
  vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) vga800x600at75 (
      .clk        (clk_50M),
      .rst        (reset_of_clk50M),
      .hdata      (hdata),        // 横坐标
      .vdata      (vdata),             // 纵坐标
      .hsync      (video_hsync),
      .vsync      (video_vsync),
      .data_enable(video_de)
  );
  /* =========== Demo code end =========== */
// assign leds = 16'b0;
// assign dpy0 = 8'b0;
// assign dpy1 = 8'b0;

endmodule
