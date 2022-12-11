`default_nettype none

module vga_color (
    input wire clk,
    input wire rst,

    output wire [2:0] video_red,
    output wire [2:0] video_green,
    output wire [1:0] video_blue,
    output reg video_clk,
    
    input wire [11:0] hdata,
    input wire [11:0] vdata,

    output reg [18:0] bram_addr,
    input wire [7:0] bram_data
);
    assign video_red = bram_data[7:5];
    assign video_green = bram_data[4:2];
    assign video_blue = bram_data[1:0];

    logic [11:0] m_hdata;
    logic [11:0] m_vdata;
    always_comb begin
        video_clk = clk;
        if (hdata >= 12'd800) begin
            m_hdata = 12'd799;
        end else begin
            m_hdata = hdata;
        end
        if (vdata >= 12'd600) begin
            m_vdata = 12'd599;
        end else begin
            m_vdata = vdata;
        end
    end
    always @(posedge clk) begin
        if(rst) begin
            bram_addr <= 19'b0;
            // state <= IDLE;
        end else begin
            if (m_hdata * 12'd600 + m_vdata == 19'd479999)  bram_addr <= 12'd0;
            else    bram_addr <= m_hdata * 12'd600 + m_vdata + 1;
        end
    end

endmodule