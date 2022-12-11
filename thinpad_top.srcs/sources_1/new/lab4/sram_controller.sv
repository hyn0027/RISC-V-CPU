module sram_controller #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 32,

  parameter SRAM_ADDR_WIDTH = 20,
  parameter SRAM_DATA_WIDTH = 32,

  localparam SRAM_BYTES = SRAM_DATA_WIDTH / 8,
  localparam SRAM_BYTE_WIDTH = $clog2(SRAM_BYTES)
) (
  // clk and reset
  input wire clk_i,
  input wire rst_i,

  // wishbone slave interface
  input wire wb_cyc_i,
  input wire wb_stb_i,
  output reg wb_ack_o,
  input wire [ADDR_WIDTH-1:0] wb_adr_i,
  input wire [DATA_WIDTH-1:0] wb_dat_i,
  output reg [DATA_WIDTH-1:0] wb_dat_o,
  input wire [DATA_WIDTH/8-1:0] wb_sel_i,
  input wire wb_we_i,

  // sram interface
  output reg [SRAM_ADDR_WIDTH-1:0] sram_addr,
  inout wire [SRAM_DATA_WIDTH-1:0] sram_data,
  output reg sram_ce_n,
  output reg sram_oe_n,
  output reg sram_we_n,
  output reg [SRAM_BYTES-1:0] sram_be_n
);


  wire [31:0] sram_data_i_comb;
  reg [31:0] sram_data_o_comb;
  reg sram_data_t_comb;
  
  assign sram_data = sram_data_t_comb ? 32'bz : sram_data_o_comb;
  assign sram_data_i_comb = sram_data;

  typedef enum logic[2:0] {
    ST_IDLE,
    ST_READ_2,
    ST_WRITE_2,
    ST_WRITE_3
  } state_t;

  state_t state;

  reg wb_ack_o_reg;
  reg sram_we_n_reg;

  always_comb begin
    wb_ack_o = wb_ack_o_reg;
    wb_dat_o = sram_data_i_comb;
    sram_addr = (wb_adr_i >> 2);
    sram_data_t_comb = !wb_we_i;
    sram_data_o_comb = wb_dat_i;
    sram_ce_n = !wb_cyc_i;
    sram_oe_n = !(wb_cyc_i & (!wb_we_i));
    sram_we_n = sram_we_n_reg;
    sram_be_n = ~wb_sel_i;
  end

  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      wb_ack_o_reg <= 1'b0;
      sram_we_n_reg <= 1'b1;
      state <= ST_IDLE;
    end else begin
      case (state)
        ST_IDLE: begin
          if (wb_stb_i && wb_cyc_i) begin
            if (wb_we_i) begin
                
              sram_we_n_reg <= 1'b0;
              wb_ack_o_reg <= 1'b0;
              state <= ST_WRITE_2;
            end else begin
                
              wb_ack_o_reg <= 1'b1;
              state <= ST_READ_2;
            end
          end else begin
            wb_ack_o_reg <= 1'b0;
          end
        end
        ST_READ_2: begin
          wb_ack_o_reg <= 1'b0;
          state <= ST_IDLE;
        end
        ST_WRITE_2: begin
          sram_we_n_reg <= 1'b1;
          state <= ST_WRITE_3;
          wb_ack_o_reg <= 1'b1;
        end
        ST_WRITE_3: begin
          wb_ack_o_reg <= 1'b0;
          state <= ST_IDLE;
        end
      endcase
    end
  end

endmodule
