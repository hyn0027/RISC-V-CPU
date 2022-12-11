module flash(
    input wire clk,
    input wire rst,

    input wire flash_we,
    output reg flash_ack,

    //flash连线
    output reg [22:0] flash_a,//起始地址？？？
    inout wire [15:0] flash_d,//只等输入
    output reg flash_ce_n,

    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output reg [31:0] wb_adr_o,
    output reg [31:0] wb_dat_o
);
    typedef enum logic[2:0]{
        IDLE,
        READ_FLASH_LOW,
        READ_FLASH_HIGH,
        WRITE_BASERAM,
        DONE_ALL
    } state_t;

    state_t state;
    logic [2:0]wait_cycles;//记录读的等待周期
    logic [15:0] get_low_data;//读到的flash第一个16位

    //处理三态门
    assign flash_d = 16'bz;//不输出
    always @(posedge clk) begin
        if(rst)begin
            flash_a <= 23'h1000;//TODO：读flash的首地址 但是a0无效实际只有22位，d4194303=h3fffff
            flash_ack <= 1'b0;
            flash_ce_n <= 1'b1;//片选信号 无效

            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_adr_o <= 32'h8000_0000;//base_ram首位

            state <= IDLE;
        end else if(flash_we)begin//flash工作
            case(state)
                IDLE: begin //让flash工作去读flash （此时flash_a已经迭代好）
                    wait_cycles <= 3'b0;
                    flash_ce_n <= 1'b0;//片选信号有效
                    state <= READ_FLASH_LOW;         
                end
                READ_FLASH_LOW: begin //读低16位
                    if (wait_cycles == 3'd7) begin//等8个周期读到数据
                        wait_cycles <= 3'b0;
                        wb_dat_o[15:0] <= flash_d;//记录低16位
                        flash_a[22:1] <= flash_a[22:1] + 22'd1;//读后16bit（往下读2字节）迭代(a0无意义)
                        state <= READ_FLASH_HIGH;
                    end else begin
                        wait_cycles <= wait_cycles + 3'b1;
                    end
                end
                READ_FLASH_HIGH: begin //读到高16位并向baseram中写
                    if (wait_cycles == 3'd7) begin//等8个周期读到数据
                        wait_cycles <= 3'b0;
                        flash_ce_n <= 1'b1; //不用flash关片选信号

                        wb_cyc_o <= 1'b1;//用总线
                        wb_stb_o <= 1'b1;
                        wb_dat_o[31:16] <= flash_d;//高16位和低16位拼起来

                        state <= WRITE_BASERAM;
                    end else begin
                        wait_cycles <= wait_cycles + 3'd1;
                    end
                end
                WRITE_BASERAM: begin //写完到baseram
                    if(wb_ack_i)begin//收到ack说明写完了
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        wb_adr_o <= wb_adr_o + 32'd4;//base_ram下一位 （不断迭代）
                        if (flash_a[22:1] == 22'h0fffff) begin //读完flash数组中的东西 3ffffe
                            flash_ack <= 1'b1;
                            state <= DONE_ALL;
                        end else begin
                            flash_a[22:1] <= flash_a[22:1] + 22'd1;//向后继续读flash
                            state <= IDLE;  
                        end
                    end
                end
                DONE_ALL: begin//写完所有指令
                    flash_ack <= 1'b0;
                    state <= IDLE; 
                end
            endcase
        end
    end
endmodule