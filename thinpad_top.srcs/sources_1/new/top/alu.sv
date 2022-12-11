`default_nettype none

module alu_new(
    input wire signed [31:0] alu_a,
    input wire signed [31:0] alu_b,
    input wire [3:0] alu_op,
    output reg signed [31:0] alu_y
);

	logic [31:0] alu_a_unsigned;
	logic [31:0] alu_b_unsigned;

	assign alu_a_unsigned = alu_a;
	assign alu_b_unsigned = alu_b;
    always_comb begin
        case (alu_op)
            4'b0000: alu_y = alu_a + alu_b; // add
            4'b0010: alu_y = ~ alu_a ^ alu_b;//xnor 
            4'b0011: alu_y = alu_a >> alu_b[4:0]; //逻辑右移 srli
            4'b0100: alu_y = alu_a << alu_b[4:0]; //逻辑左移（b的低5位）slli
            4'b0101: alu_y = alu_a ^ alu_b; //按位异或 xor
            4'b0110: alu_y = alu_a | alu_b; //按位或 or           
            4'b0111: alu_y = (alu_a & alu_b); // and
            4'b1000: alu_y = (alu_a <= alu_b) ? alu_a : alu_b; //min求出最小值
            4'b1001: alu_y = alu_a[ 0] ? 0    : 
							 alu_a[ 1] ? 1    :
							 alu_a[ 2] ? 2    : 
							 alu_a[ 3] ? 3    :
							 alu_a[ 4] ? 4    : 
							 alu_a[ 5] ? 5    :
							 alu_a[ 6] ? 6    : 
							 alu_a[ 7] ? 7    :
							 alu_a[ 8] ? 8    : 
							 alu_a[ 9] ? 9    :
							 alu_a[10] ? 10   : 
							 alu_a[11] ? 11   :
							 alu_a[12] ? 12   : 
							 alu_a[13] ? 13   :
							 alu_a[14] ? 14   : 
							 alu_a[15] ? 15   :
							 alu_a[16] ? 16   : 
							 alu_a[17] ? 17   :
							 alu_a[18] ? 18   : 
							 alu_a[19] ? 19   :
							 alu_a[20] ? 20   : 
							 alu_a[21] ? 21   :
							 alu_a[22] ? 22   : 
							 alu_a[23] ? 23   :
							 alu_a[24] ? 24   : 
							 alu_a[25] ? 25   :
							 alu_a[26] ? 26   : 
			    			 alu_a[27] ? 27   :
							 alu_a[28] ? 28   : 
							 alu_a[29] ? 29   :
							 alu_a[30] ? 30   : 
							 alu_a[31] ? 31   : 32; // ctz
			4'b1010: alu_y = (alu_a_unsigned < alu_b_unsigned) ? 32'b1 : 32'b0; // SLTU
			4'b1011: alu_y = alu_b & (~alu_a);
			4'b1100: alu_y = (alu_a[31]) ? (32'hFFFFFFFF << (6'h20 - alu_b[4:0]) | alu_a >> alu_b[4:0]) : (alu_a >> alu_b[4:0]);
			4'b1101: alu_y = alu_a - alu_b;
			4'b1110: alu_y = (alu_a < alu_b) ? 32'b1 : 32'b0;
            default: alu_y = 32'b0;
        endcase
    end
endmodule