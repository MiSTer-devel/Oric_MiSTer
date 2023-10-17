// Dave Wood 2019
// Updated by Vincent Bénony in 2023

module keyboard
(
	input			   clk_sys,
	input			   reset,
	input          key_pressed,  // 1-make (pressed), 0-break (released)
	input          key_extended, // extended code
	input          key_strobe,   // strobe
	input  [7:0]   key_code,     // key scan code
	input  [2:0]	col,         // column index used by the mutiplexer
	input [7:0] row_mask,        // row mask as prepared by the PSG
	output reg kbd_int,
	output reg swrst,
	output reg swnmi
);

reg sw0 = 1'b0;
reg sw1 = 1'b0;
reg sw2 = 1'b0;
reg sw3 = 1'b0;
reg sw4 = 1'b0;
reg sw5 = 1'b0;
reg sw6 = 1'b0;
reg sw7 = 1'b0;
reg sw8 = 1'b0;
reg sw9 = 1'b0;
reg swa = 1'b0;
reg swb = 1'b0;
reg swc = 1'b0;
reg swd = 1'b0;
reg swe = 1'b0;
reg swf = 1'b0;
reg swg = 1'b0;
reg swh = 1'b0;
reg swi = 1'b0;
reg swj = 1'b0;
reg swk = 1'b0;
reg swl = 1'b0;
reg swm = 1'b0;
reg swn = 1'b0;
reg swo = 1'b0;
reg swp = 1'b0;
reg swq = 1'b0;
reg swr = 1'b0;
reg sws = 1'b0;
reg swt = 1'b0;
reg swu = 1'b0;
reg swv = 1'b0;
reg sww = 1'b0;
reg swx = 1'b0;
reg swy = 1'b0;
reg swz = 1'b0;

reg swU = 1'b0;	// up
reg swD = 1'b0;	// down 
reg swL = 1'b0;	// left 
reg swR = 1'b0;	// right

reg swrs = 1'b0;		// right shift
reg swls = 1'b0;		// left shift
reg swsp = 1'b0;		// space
reg swcom = 1'b0;	// ,
reg swdot = 1'b0;	// .
reg swret = 1'b0;	// return
reg swfs = 1'b0;		// forward slash
reg sweq = 1'b0;		// =
reg swfcn = 1'b0;	// FCN - ALT
reg swdel = 1'b0;	// delete
reg swrsb = 1'b0;	// ]
reg swlsb = 1'b0;	// [
reg swbs = 1'b0;		// back slash
reg swdsh = 1'b0;	// -
reg swsq = 1'b0; 	// '
reg swsc = 1'b0;		// ;
reg swesc = 1'b0;	// escape
reg swctl = 1'b0;	// left ctrl
	
always @(posedge clk_sys) begin
	if(key_strobe) begin
		case(key_code)
			'h045: sw0      			<= key_pressed; // 0
			'h016: sw1       			<= key_pressed; // 1
			'h01e: sw2   				<= key_pressed; // 2
			'h026: sw3  				<= key_pressed; // 3
			'h025: sw4   				<= key_pressed; // 4
			'h02e: sw5   				<= key_pressed; // 5
			'h036: sw6      			<= key_pressed; // 6
			'h03d: sw7      			<= key_pressed; // 7
			'h03e: sw8		   		<= key_pressed; // 8
			'h046: sw9      			<= key_pressed; // 9
			'h01c: swa       			<= key_pressed; // a
			'h032: swb   				<= key_pressed; // b
			'h021: swc  				<= key_pressed; // c
			'h023: swd   				<= key_pressed; // d
			'h024: swe   				<= key_pressed; // e
			'h02b: swf      			<= key_pressed; // f
			'h034: swg		   		<= key_pressed; // g
			'h033: swh					<= key_pressed; // h
			'h043: swi					<= key_pressed; // i
			'h03b: swj					<= key_pressed; // j
			'h042: swk					<= key_pressed; // k
			'h04b: swl   				<= key_pressed; // l
			'h03a: swm      			<= key_pressed; // m
			'h031: swn					<= key_pressed; // n
			'h044: swo					<= key_pressed; // o
			'h04d: swp   				<= key_pressed; // p
			'h015: swq					<= key_pressed; // q
			'h02d: swr   				<= key_pressed; // r
			'h01b: sws  				<= key_pressed; // s
			'h02c: swt					<= key_pressed; // t
			'h03c: swu					<= key_pressed; // u
			'h02a: swv					<= key_pressed; // v
			'h01d: sww					<= key_pressed; // w
			'h022: swx					<= key_pressed; // x
			'h035: swy					<= key_pressed; // y
			'h01a: swz					<= key_pressed; // z
	
			'h075: swU           	<= key_pressed; // up
			'h072: swD		        	<= key_pressed; // down
			'h06b: swL					<= key_pressed; // left
			'h074: swR					<= key_pressed; // right
			'h059: swrs					<= key_pressed; // right shift
			'h012: swls					<= key_pressed; // left shift
			'h029: swsp					<= key_pressed; // space
			'h041: swcom				<= key_pressed; // comma
			'h049: swdot				<= key_pressed; // full stop
			'h05a: swret				<= key_pressed; // return
			'h04a: swfs					<= key_pressed; // forward slash
			'h055: sweq					<= key_pressed; // equals
			'h011: swfcn				<= key_pressed; // ALT
			'h066: swdel				<= key_pressed; // delete
			'h071: swdel				<= key_pressed; // delete
			'h05b: swrsb				<= key_pressed; // right sq bracket
			'h054: swlsb				<= key_pressed; // left sq bracket
			'h05d: swbs					<= key_pressed; // back slash h05d
			'h04e: swdsh				<= key_pressed; // dash
			'h052: swsq					<= key_pressed; // single quote
			'h04c: swsc					<= key_pressed; // semi colon
			'h076: swesc				<= key_pressed; // escape
			'h014: swctl				<= key_pressed; // left control
			'h078: swrst            <= key_pressed; // F11 reset 
			'h009: swnmi      		<= key_pressed; // F10 break		
		endcase
	end
end
					
always @(posedge clk_sys) begin
		if (col == 7) begin
			kbd_int <= (sweq  & ~row_mask[7])
			         | (swret & ~row_mask[5])
			         | (swrs  & ~row_mask[4])
			         | (swfs  & ~row_mask[3])
			         | (sw0   & ~row_mask[2])
			         | (swl   & ~row_mask[1])
			         | (sw8   & ~row_mask[0]);
		end
		else if (col == 6) begin
			kbd_int <= (sww & ~row_mask[7])
			         | (sws & ~row_mask[6])
			         | (swa & ~row_mask[5])
			         | (swe & ~row_mask[3])
			         | (swg & ~row_mask[2])
			         | (swh & ~row_mask[1])
			         | (swy & ~row_mask[0]);
		end
		else if (col == 5) begin
			kbd_int <= (swlsb & ~row_mask[7])
			         | (swrsb & ~row_mask[6])
			         | (swdel & ~row_mask[5])
			         | (swfcn & ~row_mask[4])
			         | (swp   & ~row_mask[3])
			         | (swo   & ~row_mask[2])
			         | (swi   & ~row_mask[1])
			         | (swu   & ~row_mask[0]);
		end
		else if (col == 4) begin
			kbd_int <= (swR   & ~row_mask[7])
			         | (swD   & ~row_mask[6])
			         | (swL   & ~row_mask[5])
			         | (swls  & ~row_mask[4])
			         | (swU   & ~row_mask[3])
			         | (swdot & ~row_mask[2])
			         | (swcom & ~row_mask[1])
			         | (swsp  & ~row_mask[0]);
		end
		else if (col == 3) begin
			kbd_int <= (swsq  & ~row_mask[7])
			         | (swbs  & ~row_mask[6])
			         | (swdsh & ~row_mask[3])
			         | (swsc  & ~row_mask[2])
			         | (sw9   & ~row_mask[1])
			         | (swk   & ~row_mask[0]);
		end
		else if (col == 2) begin
			kbd_int <= (swc   & ~row_mask[7])
			         | (sw2   & ~row_mask[6])
			         | (swz   & ~row_mask[5])
			         | (swctl & ~row_mask[4])
			         | (sw4   & ~row_mask[3])
			         | (swb   & ~row_mask[2])
			         | (sw6   & ~row_mask[1])
			         | (swm   & ~row_mask[0]);
		end
		else if (col == 1) begin
			kbd_int <= (swd   & ~row_mask[7])
			         | (swq   & ~row_mask[6])
			         | (swesc & ~row_mask[5])
			         | (swf   & ~row_mask[3])
			         | (swr   & ~row_mask[2])
			         | (swt   & ~row_mask[1])
			         | (swj   & ~row_mask[0]);
		end
		else if (col == 0) begin
			kbd_int <= (sw3 & ~row_mask[7])
			         | (swx & ~row_mask[6])
			         | (sw1 & ~row_mask[5])
			         | (swv & ~row_mask[3])
			         | (sw5 & ~row_mask[2])
			         | (swn & ~row_mask[1])
			         | (sw7 & ~row_mask[0]);
		end
end
endmodule

