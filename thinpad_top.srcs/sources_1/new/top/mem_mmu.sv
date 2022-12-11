module mem_mmu(
    input wire clk,
    input wire rst,
    
    input wire mmu_we,//是否工作
    output reg mmu_ack, //是否工作完成（找完物理地址）

    input wire [31:0] cpu_adr_i,//虚拟地址(来自cpu)
    input wire [31:0] cpu_data_i, //写入内存的数据（来自cpu）
    input wire cpu_w_or_r,//读内存或者写内存
    input wire [3:0]sel_i, //cpu给的sel
    output reg [31:0] cpu_data_o,//输出给cpu真正的data

    output reg cache_we_w,//是否让cache工作 
    output reg cache_we_r,//是否让cache工作 
    input wire cache_ack_w, //cache是否写完 
    input wire cache_ack_r,//cache是否读完

    output reg [31:0] cache_adr_o,//给cache的让其查找表项的地址
    output reg [31:0] cache_w_data_o,//写进内存的data
    input wire [31:0] cache_data_i,//从cache得到的数据
    output reg [3:0] sel_o,//给cache的sel字节使能
    
    input wire mmu_clear,

    //读csr寄存器
    // output reg [11:0] csr_raddr_a,//读satp寄存器 
    input wire [31:0] satp, //读到的32位的satp
    input wire [1:0] mode,
    output reg page_fault,

    output reg [18:0] bram_addr,
    output reg [7:0] bram_data,
    // output reg bram_en,
    output reg [0:0] bram_we
);
    //虚拟地址转换成物理地址 if 和 mem
    //tlb

    reg [19:0] tlb_vpn [0:31];//32项
    reg [21:0] tlb_ppn [0:31];
    reg [8:0] tlb_asid [0:31];
    reg tlb_empty [0:31];

    reg [5:0] idx_tlb;//更新的
    reg [4:0] idx_update_tlb;//踢走的tlb表项
    always_comb begin

        idx_tlb = 6'd33; 
        for (int i = 0; i < 32; i++) begin
            if (tlb_empty[i] == 1'b0 && tlb_vpn[i][19:0] == cpu_adr_i[31:12] && tlb_asid[i][8:0] == satp[30:22]) begin//进程号asid和虚拟地址在快表中找到
                idx_tlb = i;
                break;
            end
        end
    end

    //page table walker
    // logic [9:0] vpn1, vpn0;//10位一级页号和二级页号
    // logic [11:0] v_offset;//12位虚拟地址offset

    // logic [21:0] satp_ppn;//1级页表的ppn
    // logic satp_mode;//用户态u还是balabala
    // logic [8:0] satp_asid;//进程号
    // always_comb begin
        // vpn1 = cpu_adr_i[31:22];
        // vpn0 = cpu_adr_i[21:12];
        // v_offset = cpu_adr_i[11:0];

        // csr_raddr_a = 12'h180;//satp寄存器编号
        // satp_ppn = satp[21:0];
        // satp_asid = satp[30:22];
        // satp_mode = satp[31];
    // end

    typedef enum logic [2:0] {
        IDLE,
        FIRST_PTE,
        SECOND_PTE,
        RETURN_DATA,
        PAGE_FAULT,
        WAIT,
        DONE
    } state_t;
    state_t state;
    
    always @(posedge clk) begin
        if (rst == 1'b1) begin
            //初始化mmu
            // bram_en <= 1'b0;
            bram_we <= 1'b0;
            mmu_ack <= 1'b0;
            sel_o <= 4'b0;//字节使能全为0
            cpu_data_o <= 0;
            cache_we_r <= 1'b0;
            cache_we_w <= 1'b0;
            page_fault <= 0;

            for (int i = 0; i < 32; i++) begin
                tlb_vpn[i] <= 20'b0;
                tlb_ppn[i] <= 22'b0;
                tlb_asid[i] <= 9'b0;
                tlb_empty[i] <= 1'b1;
            end
            idx_update_tlb <= 5'b0;
            state <= IDLE;
        end else if (mmu_clear == 1'b1) begin//清空tlb
            // bram_en <= 1'b0;
            bram_we <= 1'b0;
            for (int i = 0; i < 32; i++) begin
                tlb_vpn[i] <= 20'b0;
                tlb_ppn[i] <= 22'b0;
                tlb_asid[i] <= 9'b0;
                tlb_empty[i] <= 1'b1;
            end
            idx_update_tlb <= 5'b0;
            mmu_ack <= 1'b0;
            page_fault <= 0;
            cache_we_w <= 1'b0;
            cache_we_r <= 1'b0;
            state <= IDLE;  
        end else if (mmu_we == 1'b1 && (cpu_adr_i >= 32'h0100_0000 && cpu_adr_i <= 32'h01FF_FFFF)) begin
            case(state)
                IDLE: begin
                    // bram_en <= 1'b1;
                    bram_we <= 1'b1;
                    bram_addr <= cpu_adr_i[18:0];
                    bram_data <= cpu_data_i[7:0];
                    mmu_ack <= 1'b0;
                    cache_we_w <= 1'b0;
                    cache_we_r <= 1'b0;
                    page_fault <= 1'b0;
                    mmu_ack <= 1'b0;
                    state <= WAIT;
                end
                WAIT: begin
                    mmu_ack <= 1'b1;
                end
                DONE: begin
                    mmu_ack <= 1'b0;
                    // bram_en <= 1'b0;
                    bram_we <= 1'b0;
                end
            endcase
        end else if (mmu_we == 1'b1 && ((cpu_adr_i >= 32'h1000_0000 && cpu_adr_i <= 32'h1000_FFFF) || mode == 2'b11 || satp[31] == 1'b0)) begin //工作 不启动分页模式
            case(state)
                IDLE: begin
                    // bram_en <= 1'b0;
                    bram_we <= 1'b0;
                    mmu_ack <= 1'b0;//降ack？
                    sel_o <= sel_i;//物理地址直接给sel
                    cache_adr_o <= cpu_adr_i;//此时cpu的地址就是真实的物理地址
                    if (cpu_w_or_r == 1'b0) begin//读
                        cache_we_r <= 1'b1;//让cache读
                        cache_we_w <= 1'b0;
                    end else if (cpu_w_or_r == 1'b1) begin //写
                        cache_w_data_o <= cpu_data_i;
                        cache_we_w <= 1'b1;//让cache写
                        cache_we_r <= 1'b0;
                    end
                    state <= RETURN_DATA;
                end
                RETURN_DATA: begin
                    if (cache_ack_r == 1'b1) begin //读完
                        cpu_data_o <= cache_data_i;//返回cpu
                        mmu_ack <= 1'b1; //工作完成
                        cache_we_r <= 1'b0;
                        cache_we_w <= 1'b0;
                        state <= DONE;
                    end else if(cache_ack_w == 1'b1) begin //写完
                        mmu_ack <= 1'b1; //工作完成
                        cache_we_w <= 1'b0;
                        cache_we_r <= 1'b0;
                        state <= DONE;
                    end
                end
                DONE: begin
                    mmu_ack <= 1'b0; //降mmu_ack
                    state <= IDLE; 
                end
            endcase        
        end else if (mmu_we == 1'b1) begin//mmu要开始工作 且有页表
            case (state)
                IDLE: begin
                    // bram_en <= 1'b0;
                    bram_we <= 1'b0;
                    mmu_ack <= 1'b0;//降ack？
                    if (idx_tlb != 6'd33) begin //tlb （如果cpu_adr_i在tlb中）直接用物理地址 state<=RETURN_DATA
                        cache_adr_o <= {tlb_ppn[idx_tlb][19:0], cpu_adr_i[11:0]}; 
                        sel_o <= sel_i;
                        if(cpu_w_or_r == 1'b0) begin//读    
                            cache_we_r <= 1'b1;//cache读
                            cache_we_w <= 1'b0;
                        end else if (cpu_w_or_r == 1'b1) begin //写
                            cache_we_r <= 1'b0;
                            cache_we_w <= 1'b1;//cache写
                            cache_w_data_o <= cpu_data_i;
                        end
                        state <= RETURN_DATA;
                    end else if(idx_tlb == 6'd33) begin //tlb中没有命中
                        sel_o <= 4'b1111;
                        cache_adr_o <= (satp[21:0] << 12) + (cpu_adr_i[31:22] << 2);//给cache找的一级表项地址
                        if (((satp[21:0] << 12) + (cpu_adr_i[31:22] << 2)) < 32'h8000_0000 || ((satp[21:0] << 12) + (cpu_adr_i[31:22] << 2)) > 32'h807f_ffff) begin
                            page_fault <= 1'b1;
                            cache_we_r <= 1'b0;
                            cache_we_w <= 1'b0;
                            state <= IDLE;
                        end
                        else begin
                            state <= FIRST_PTE;
                            cache_we_r <= 1'b1;//让cache读
                            cache_we_w <= 1'b0;
                        end
                    end
                end
                FIRST_PTE: begin //获取一级页表项
                    if (cache_ack_r == 1'b1) begin//获取到了一级页表项
                    //触发page fault ：cache_data_i[0] == 0 || (cache_data_i[1] == 0 && cache_data_i[2] == 1)    
                     //                        pte.v 为0                    pte.r为0同时pte.w为1             
                        if(cache_data_i[0] == 0 || (cache_data_i[1] == 0 && cache_data_i[2] == 1)) begin
                            //触发 page fault
                            page_fault <= 1'b1;
                            cache_we_r <= 1'b0;
                            state <= IDLE;
                        end else begin
                            cache_adr_o <= (cache_data_i[31:10] << 12) + (cpu_adr_i[21:12] << 2);//给cache找的二级表项地址
                            state <= SECOND_PTE;
                        end
                    end
                end
                SECOND_PTE: begin //获取二级页表项
                    if (cache_ack_r == 1'b1) begin//获取到了二级页表项
                    //触发page fault ：cache_data_i[0] == 0 || (cache_data_i[1] == 0 && cache_data_i[2] == 1) || (cache_data_i[1] == 0 && cache_data_i[2] == 0 && cache_data_i[3] == 0) || mode不匹配等 (当前模式为mode，cache_data_i[4]表示页表项的mode)
                            //                   pte.v 为0              pte.r为0同时pte.w为1                              pte.r pte.w pte.x同时为0（表示是一个指针不是叶结点所以触发异常）     pte.u=0时，Umode不能访问 Smode可以；pte.u=1时，Umode可以 Smode不可以(目前没有smode所以简单判断为pte.u=0就为pagefault)
                        if(cache_data_i[0] == 0 || (cache_data_i[1] == 0 && cache_data_i[2] == 1) || (cache_data_i[1] == 0 && cache_data_i[2] == 0 && cache_data_i[3] == 0) || (cache_data_i[4] == 0 && mode == 2'b0)) begin
                            //触发 page fault
                            page_fault <= 1'b1;
                            mmu_ack <= 1'b0;
                            cache_we_r <= 1'b0;
                            cache_we_w <= 1'b0;
                            state <= IDLE;
                        end else begin//找到了虚拟地址对应的物理地址
                            //记录到tlb
                            tlb_empty[idx_update_tlb] <= 1'b0;
                            tlb_vpn[idx_update_tlb] <= cpu_adr_i[31:12];
                            tlb_ppn[idx_update_tlb] <= cache_data_i[31:10];
                            tlb_asid[idx_update_tlb] <= satp[30:22];
                            if (idx_update_tlb == 5'd31) begin
                                idx_update_tlb <= 5'd0;
                            end else begin
                                idx_update_tlb <= idx_update_tlb + 5'd1;
                            end

                            cache_adr_o <= {cache_data_i[29:10], cpu_adr_i[11:0]};//找到的物理地址
                            sel_o <= sel_i;//针对物理地址
                            //给其写入数据
                            if (cpu_w_or_r == 1'b0) begin //读
                                cache_we_r <= 1'b1;//cache读
                                cache_we_w <= 1'b0;
                            end else if(cpu_w_or_r == 1'b1) begin//写
                                cache_we_r <= 1'b0;
                                cache_we_w <= 1'b1;//让cache写
                                cache_w_data_o <= cpu_data_i;
                            end
                            state <= RETURN_DATA;
                        end
                    end
                end
                RETURN_DATA: begin 
                    if (cache_ack_r == 1'b1) begin //读完了
                        cpu_data_o <= cache_data_i;//读到的data给cpu
                        mmu_ack <= 1'b1; //工作完成
                        cache_we_r <= 1'b0;
                        cache_we_w <= 1'b0;
                        state <= DONE;
                    end else if(cache_ack_w == 1'b1) begin //写完了
                        mmu_ack <= 1'b1; //工作完成
                        cache_we_w <= 1'b0;
                        cache_we_r <= 1'b0;
                        state <= DONE;
                    end
                end
                DONE: begin
                    mmu_ack <= 1'b0; //降mmu_ack
                    // sel_o <= 4'b0;
                    // cache_we_w <= 1'b0;
                    // cache_we_r <= 1'b0;
                    state <= IDLE; 
                end
            endcase
        end else begin
            // bram_en <= 1'b0;
            bram_we <= 1'b0;
            mmu_ack <= 1'b0;
            page_fault <= 0;
            cache_we_w <= 1'b0;
            cache_we_r <= 1'b0;
            state <= IDLE;  
        end
    end
endmodule