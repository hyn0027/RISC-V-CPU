`default_nettype none

module cache(
    input wire clk,
    input wire rst,

    input wire [31:0] r_addr,
    output reg [31:0] r_data,
    input wire r_we,
    output reg r_ack,
    input wire [3:0] r_sel,
    
    input wire [31:0] w_addr,
    input wire [31:0] w_data,
    input wire w_we,
    output reg w_ack,
    input wire [3:0] w_sel,

    input wire clear,
    output reg clear_ack,

    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output reg [31:0] wb_adr_o,
    output reg [31:0] wb_dat_o,
    input wire [31:0] wb_dat_i,
    output reg [3:0] wb_sel_o,
    output reg wb_we_o
);
    typedef enum logic [2:0] {
        IDLE,
        WAIT_ACTION,
        WRITE_ACTION,
        WAIT_WRITE,
        WAIT,
        FINISH,
        READ_ACTION
    } state_t;

    state_t state;

    logic [31:0] cache_data [0:31];
    logic [31:0] cache_addr [0:31];
    logic cache_empty [0:31];
    logic cache_dirty [0:31];

    logic [5:0] idx_r;
    logic [5:0] idx_w;
    logic [4:0] idx_replace;
    logic [5:0] idx_dirty;

    logic [29:0] r_addr_reg;
    logic [3:0] sel_reg;
    logic [31:0] write_data_reg;
    logic [31:0] write_addr_reg;

    always_comb begin
        idx_r = 6'd33;
        for (int i = 0; i < 32; i++) begin
            if (cache_empty[i] == 1'b0 && cache_addr[i][31:2] == r_addr[31:2]) begin
                idx_r = i;
                break;
            end
        end

        idx_w = 6'd33;
        for (int i = 0; i < 32; i++) begin
            if (cache_empty[i] == 1'b0 && cache_addr[i][31:2] == w_addr[31:2]) begin
                idx_w = i;
                break;
            end
        end

        idx_dirty = 6'd33;
        for (int i = 0; i < 32; i++) begin
            if (cache_empty[i] == 1'b0 && cache_dirty[i] == 1'b1) begin
                idx_dirty = i;
                break;
            end
        end
    end
    
    always @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                cache_empty[i] <= 1'b1;
                cache_dirty[i] <= 1'b0;
            end
            idx_replace <= 5'b0;
            
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;

            r_ack <= 1'b0;
            w_ack <= 1'b0;
            clear_ack <= 1'b0;
            state <= IDLE;
        end else if (clear == 1'b1) begin
            case (state) 
                IDLE: begin
                    if (idx_dirty == 6'd33) begin
                        clear_ack <= 1'b0;
                        state <= FINISH;
                    end else begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= cache_addr[idx_dirty[4:0]];
                        wb_dat_o <= cache_data[idx_dirty[4:0]];
                        wb_sel_o <= 4'b1111;
                        wb_we_o <= 1'b1;
                        clear_ack <= 1'b0;
                        cache_dirty[idx_dirty[4:0]] <= 1'b0;
                        state <= WAIT_WRITE;
                    end
                end
                WAIT_WRITE: begin
                    if (wb_ack_i == 1'b1) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        state <= IDLE;
                    end
                end
                FINISH: begin
                    for (int i = 0; i < 32; i++) begin
                        cache_empty[i] <= 1'b1;
                        cache_dirty[i] <= 1'b0;
                    end
                    idx_replace <= 5'b0;
                    clear_ack <= 1'b1;
                    state <= WAIT;
                end
                WAIT: begin
                    clear_ack <= 1'b0;
                    state <= IDLE;
                end
            endcase
            r_ack <= 1'b0;
            w_ack <= 1'b0;
        end else if (w_we == 1'b1) begin
            case (state) 
                IDLE: begin
                    if (w_addr < 32'h8000_0000 || w_addr > 32'h807F_FFFF) begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= w_addr;
                        wb_dat_o <= w_data;
                        wb_sel_o <= w_sel;
                        wb_we_o <= 1'b1;
                        w_ack <= 1'b0;
                        state <= WAIT_WRITE;
                    end else if (idx_w == 6'd33 && cache_dirty[idx_replace] == 1'b1) begin
                        if (w_sel != 4'b1111) begin
                            wb_cyc_o <= 1'b1;
                            wb_stb_o <= 1'b1;
                            wb_adr_o <= {w_addr[31:2], 2'b0};
                            wb_sel_o <= 4'b1111;
                            wb_we_o <= 1'b0;
                            sel_reg <= w_sel;
                            write_data_reg <= cache_data[idx_replace];
                            write_addr_reg <= cache_addr[idx_replace];
                            state <= READ_ACTION;
                        end else begin
                            wb_cyc_o <= 1'b1;
                            wb_stb_o <= 1'b1;
                            wb_adr_o <= cache_addr[idx_replace];
                            wb_dat_o <= cache_data[idx_replace];
                            wb_sel_o <= 4'b1111;
                            wb_we_o <= 1'b1;
                            w_ack <= 1'b0;
                            state <= WAIT_WRITE;
                            if (idx_replace == 5'd31)  idx_replace <= 5'd0;
                            else idx_replace <= idx_replace + 5'd1;
                        end
                        w_ack <= 1'b0;
                        if (w_sel == 4'b1111)   cache_data[idx_replace] <= w_data;
                        else if (w_sel == 4'b0001) cache_data[idx_replace] <= w_data;
                        else if (w_sel == 4'b0010) cache_data[idx_replace] <= {w_data[23:0], 8'b0};
                        else if (w_sel == 4'b0100) cache_data[idx_replace] <= {w_data[15:0], 16'b0};
                        else if (w_sel == 4'b1000) cache_data[idx_replace] <= {w_data[7:0], 24'b0};
                        else if (w_sel == 4'b0011) cache_data[idx_replace] <= w_data;
                        else if (w_sel == 4'b1100) cache_data[idx_replace] <= {w_data[15:0], 15'b0};
                        cache_addr[idx_replace] <= {w_addr[31:2], 2'b0};
                        cache_empty[idx_replace] <= 1'b0;
                        cache_dirty[idx_replace] <= 1'b1;
                    end else if (idx_w == 6'd33) begin
                        if (w_sel != 4'b1111) begin
                            wb_cyc_o <= 1'b1;
                            wb_stb_o <= 1'b1;
                            wb_adr_o <= {w_addr[31:2], 2'b0};
                            wb_sel_o <= 4'b1111;
                            wb_we_o <= 1'b0;
                            sel_reg <= w_sel;
                            write_data_reg <= 32'b0;
                            write_addr_reg <= 32'b0;
                            state <= READ_ACTION;
                            w_ack <= 1'b0;
                        end else begin
                            idx_replace <= idx_replace + 5'd1;
                            w_ack <= 1'b1;
                            state <= WAIT;
                        end
                        if (w_sel == 4'b1111)   cache_data[idx_replace] <= w_data;
                        else if (w_sel == 4'b0001) cache_data[idx_replace] <= w_data;
                        else if (w_sel == 4'b0010) cache_data[idx_replace] <= {w_data[23:0], 8'b0};
                        else if (w_sel == 4'b0100) cache_data[idx_replace] <= {w_data[15:0], 16'b0};
                        else if (w_sel == 4'b1000) cache_data[idx_replace] <= {w_data[7:0], 24'b0};
                        else if (w_sel == 4'b0011) cache_data[idx_replace] <= w_data;
                        else if (w_sel == 4'b1100) cache_data[idx_replace] <= {w_data[15:0], 15'b0};
                        cache_addr[idx_replace] <= {w_addr[31:2], 2'b0};
                        cache_empty[idx_replace] <= 1'b0;
                        cache_dirty[idx_replace] <= 1'b1;
                    end else begin
                        if (w_sel == 4'b1111) begin
                            cache_data[idx_w[4:0]] <= w_data;
                        end else if (w_sel == 4'b0001) begin
                            cache_data[idx_w[4:0]][7:0] <= w_data[7:0];
                        end else if (w_sel == 4'b0010) begin
                            cache_data[idx_w[4:0]][15:8] <= w_data[7:0];
                        end else if (w_sel == 4'b0100) begin
                            cache_data[idx_w[4:0]][23:16] <= w_data[7:0];
                        end else if (w_sel == 4'b1000) begin
                            cache_data[idx_w[4:0]][31:24] <= w_data[7:0];
                        end else if (w_sel == 4'b0011) begin
                            cache_data[idx_w[4:0]][15:0] <= w_data[15:0];
                        end else if (w_sel == 4'b1100) begin
                            cache_data[idx_w[4:0]][31:16] <= w_data[15:0];
                        end
                        cache_dirty[idx_w[4:0]] <= 1'b1;
                        w_ack <= 1'b1;
                        state <= WAIT;
                    end
                end
                WAIT_WRITE: begin
                    if (wb_ack_i == 1'b1) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        w_ack <= 1'b1;
                        state <= WAIT;
                    end
                end
                READ_ACTION: begin
                    if (wb_ack_i == 1'b1) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        if (sel_reg == 4'b0001) begin
                            cache_data[idx_replace][31:8] <= wb_dat_i[31:8];
                        end else if (sel_reg == 4'b0010) begin
                            cache_data[idx_replace][31:16] <= wb_dat_i[31:16];
                            cache_data[idx_replace][7:0] <= wb_dat_i[7:0];
                        end else if (sel_reg == 4'b0100) begin
                            cache_data[idx_replace][31:24] <= wb_dat_i[31:24];
                            cache_data[idx_replace][15:0] <= wb_dat_i[15:0];
                        end else if (sel_reg == 4'b1000) begin
                            cache_data[idx_replace][23:0] <= wb_dat_i[23:0];
                        end else if (sel_reg == 4'b0011) begin
                            cache_data[idx_replace][31:16] <= wb_dat_i[31:16];
                        end else if (sel_reg == 4'b1100) begin
                            cache_data[idx_replace][15:0] <= wb_dat_i[15:0];
                        end                 
                        if (idx_replace == 5'd31)  idx_replace <= 5'd0;
                        else idx_replace <= idx_replace + 5'd1;
                        if (write_addr_reg != 32'b0) begin
                            state <= WRITE_ACTION;
                        end else begin
                            w_ack <= 1'b1;
                            state <= WAIT;
                        end
                    end
                end
                WRITE_ACTION: begin
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    wb_adr_o <= write_addr_reg;
                    wb_dat_o <= write_data_reg;
                    wb_sel_o <= 4'b1111;
                    wb_we_o <= 1'b1;
                    state <= WAIT_WRITE;
                end
                WAIT: begin
                    w_ack <= 1'b0;
                    state <= IDLE;
                end
            endcase
            r_ack <= 1'b0;
            clear_ack <= 1'b0;
        end else if (r_we == 1'b1) begin
            case (state) 
                IDLE: begin
                    if (r_addr < 32'h8000_0000 || r_addr > 32'h807F_FFFF) begin
                        r_ack <= 1'b0;
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= r_addr;
                        wb_sel_o <= r_sel;
                        wb_we_o <= 1'b0;
                        sel_reg <= r_sel;
                        state <= READ_ACTION;
                    end else if (idx_r == 6'd33) begin
                        r_addr_reg <= r_addr[31:2];
                        sel_reg <= r_sel;
                        r_ack <= 1'b0;
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= {r_addr[31:2], 2'b0};
                        wb_sel_o <= 4'b1111;
                        wb_we_o <= 1'b0;
                        state <= WAIT_ACTION;
                    end else begin
                        r_ack <= 1'b1;
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        if (r_sel == 4'b1111) begin
                            r_data <= cache_data[idx_r[4:0]];
                        end else if (r_sel == 4'b0001) begin
                            r_data <= {24'b0, cache_data[idx_r[4:0]][7:0]};
                        end else if (r_sel == 4'b0010) begin
                            r_data <= {24'b0, cache_data[idx_r[4:0]][15:8]};
                        end else if (r_sel == 4'b0100) begin
                            r_data <= {24'b0, cache_data[idx_r[4:0]][23:16]};
                        end else if (r_sel == 4'b1000) begin
                            r_data <= {24'b0, cache_data[idx_r[4:0]][31:24]};
                        end else if (r_sel == 4'b0011) begin
                            r_data <= {16'b0, cache_data[idx_r[4:0]][15:0]};
                        end else if (r_sel == 4'b1100) begin 
                            r_data <= {16'b0, cache_data[idx_r[4:0]][31:16]};
                        end
                        state <= WAIT;
                    end
                end
                WAIT_ACTION: begin
                    if (wb_ack_i == 1'b1) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        if (sel_reg == 4'b1111) begin
                            r_data <= wb_dat_i;
                        end else if (sel_reg == 4'b0001) begin
                            r_data <= {24'b0, wb_dat_i[7:0]};
                        end else if (sel_reg == 4'b0010) begin
                            r_data <= {24'b0, wb_dat_i[15:8]};
                        end else if (sel_reg == 4'b0100) begin
                            r_data <= {24'b0, wb_dat_i[23:16]};
                        end else if (sel_reg == 4'b1000) begin
                            r_data <= {24'b0, wb_dat_i[31:24]};
                        end else if (sel_reg == 4'b0011) begin
                            r_data <= {16'b0, wb_dat_i[15:0]};
                        end else if (sel_reg == 4'b1100) begin 
                            r_data <= {16'b0, wb_dat_i[31:16]};
                        end
                        if (cache_empty[idx_replace] == 1'b0 && cache_dirty[idx_replace] == 1'b1) begin
                            state <= WRITE_ACTION;
                            write_data_reg <= cache_data[idx_replace];
                            write_addr_reg <= cache_addr[idx_replace];
                        end else begin
                            r_ack <= 1'b1;
                            state <= WAIT;
                        end
                        cache_data[idx_replace] <= wb_dat_i;
                        cache_addr[idx_replace] <= {r_addr_reg, 2'b0};
                        cache_empty[idx_replace] <= 1'b0;
                        cache_dirty[idx_replace] <= 1'b0;
                        if (idx_replace == 5'd31)  idx_replace <= 5'd0;
                        else idx_replace <= idx_replace + 5'd1;
                    end
                end
                WRITE_ACTION: begin
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    wb_adr_o <= write_addr_reg;
                    wb_dat_o <= write_data_reg;
                    wb_sel_o <= 4'b1111;
                    wb_we_o <= 1'b1;
                    state <= WAIT_WRITE;
                end
                WAIT_WRITE: begin
                    if (wb_ack_i == 1'b1) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        r_ack <= 1'b1;
                        state <= WAIT;
                    end
                end
                READ_ACTION: begin
                    if (wb_ack_i == 1'b1) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        if (sel_reg == 4'b1111) begin
                            r_data <= wb_dat_i;
                        end else if (sel_reg == 4'b0001) begin
                            r_data <= {24'b0, wb_dat_i[7:0]};
                        end else if (sel_reg == 4'b0010) begin
                            r_data <= {24'b0, wb_dat_i[15:8]};
                        end else if (sel_reg == 4'b0100) begin
                            r_data <= {24'b0, wb_dat_i[23:16]};
                        end else if (sel_reg == 4'b1000) begin
                            r_data <= {24'b0, wb_dat_i[31:24]};
                        end else if (sel_reg == 4'b0011) begin
                            r_data <= {16'b0, wb_dat_i[15:0]};
                        end else if (sel_reg == 4'b1100) begin 
                            r_data <= {16'b0, wb_dat_i[31:16]};
                        end
                        r_ack <= 1'b1;
                        state <= WAIT;
                    end
                end
                WAIT: begin
                    r_ack <= 1'b0;
                    state <= IDLE;
                end
            endcase
            w_ack <= 1'b0;
            clear_ack <= 1'b0;
        end else begin
            r_ack <= 1'b0;
            w_ack <= 1'b0;
            clear_ack <= 1'b0;
            state <= IDLE;
        end
    end

endmodule