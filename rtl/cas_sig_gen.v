module cas_sig_gen(
  input clk,
  input reset,
  input start,
  input gap,
  input [7:0] din,
  output reg done,
  output dout
);


//At 24Mhz, pulse sizes for each bit is as follows:
//0: 6000 Low, 9500 High
//1: 3500 Low, 5000 High

reg [13:0] div;
reg [3:0] nbit;
reg [3:0] parity;
reg [13:0] data;
reg [7:0] gap_bit_cnt;
reg en, tape_bit;
wire emit_bit;

wire pulse;

initial begin
  en = 0;
  nbit = 0;
  div = 0;
end


assign dout = en ? (data[0] ? (div >=0 && div < 4354  ? 1'b0 : 1'b1) : (div >=0 && div < 6530 ? 1'b0 : 1'b1)) : 1'b0;

assign emit_bit = (nbit == 4'd9 && ~gap) ? parity[0] : data[0];

always @(posedge clk or posedge start) begin
	if (start) div <= 14'd0;
	else if (en) begin
		if((emit_bit && div == 8707) || (~emit_bit && div == 15238)) div <= 14'd0;
		else div <= div + 1'b1;
	end
end

always @(posedge clk or posedge start or posedge reset) begin
	if(reset) begin
		en <= 1'b0;
		done <= 1'b0;
		parity <= 4'd1;
		parity <= 4'd1;
		nbit <= 4'd0;
		data <= 14'd0;
		gap_bit_cnt <= 8'h00;
	end
	
	else begin
		if(start) begin
			en <= 1'b1;
			done <= 1'b0;
			parity <= 4'd1;
			nbit <= 4'd0;
			data <= gap ? 14'h3FFF : { 5'b11111, din, 1'b0};
			gap_bit_cnt <= 8'h00;
		end
		else if (en) begin
			if((emit_bit && div == 8707) || (~emit_bit && div == 15238)) begin
				if(gap) begin
					gap_bit_cnt <= gap_bit_cnt + 1'b1;
					data[0] <= 1'b1;
				end
				else begin
					nbit <= nbit + 4'd1;
					if(nbit >= 4'd1 && nbit <= 4'd8) parity <= parity + data[0];
					data <= { 1'b0, data[13:1] };
				end
				if (nbit == 4'd13 || (gap_bit_cnt == 8'd100)) begin
				  en <= 1'b0;
				  done <= 1'b1;
				end
			end
		end
	end
end

endmodule
