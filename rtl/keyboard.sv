// Dave Wood 2019


module keyboard
(
	input			   clk_sys,
	input			   reset,
	input          key_pressed,  // 1-make (pressed), 0-break (released)
	input          key_extended, // extended code
	input          key_strobe,   // strobe
	input  [7:0]   key_code,     // key scan code
	input  [2:0]	col,
	input	 [7:0]	row,
	output [7:0]	ROWbit,
	output			swrst,
	output         swnmi
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


//reg swrst = 0;
reg swf1 = 1'b0;
reg swf2 = 1'b0;
reg swf3 = 1'b0;
reg swf4 = 1'b0;
reg swf5 = 1'b0;
reg swf6 = 1'b0;


	
always @(posedge clk_sys) begin
	
	if(key_strobe) begin
		casex(key_code)
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
	
			'hX75: swU           	<= key_pressed; // up
			'hX72: swD		        	<= key_pressed; // down
			'hx6b: swL					<= key_pressed; // left
			'hx74: swR					<= key_pressed; // right
			'h059: swrs					<= key_pressed; // right shift
			'h012: swls					<= key_pressed; // left shift
			'h029: swsp					<= key_pressed; // space
			'h041: swcom				<= key_pressed; // comma
			'h049: swdot				<= key_pressed; // full stop
			'h05a: swret				<= key_pressed; // return
			'h04a: swfs					<= key_pressed; // forward slash
			'h055: sweq					<= key_pressed; // equals
			'h011: swfcn				<= key_pressed; // ALT
			'hx66: swdel				<= key_pressed; // delete
			'hx71: swdel				<= key_pressed; // delete
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
			'h005: swf1	      		<= key_pressed; // f1
			'h006: swf2	      		<= key_pressed; // f2
			'h004: swf3	      		<= key_pressed; // f3
			'h00c: swf4	      		<= key_pressed; // f4
			'h003: swf5	      		<= key_pressed; // f5
			'h00b: swf6	      		<= key_pressed; // f6
			
		endcase
	end
end
					
always @(posedge clk_sys) begin
		if (col == 3'b111) begin
			ROWbit[7] <= sweq;
			ROWbit[6] <= swf1;
			ROWbit[5] <= swret;
			ROWbit[4] <= swrs;
			ROWbit[3] <= swfs;
			ROWbit[2] <= sw0;
			ROWbit[1] <= swl;
			ROWbit[0] <= sw8;
		end
		else if (col == 3'b110) begin
			ROWbit[7] <= sww;
			ROWbit[6] <= sws;
			ROWbit[5] <= swa;
			ROWbit[4] <= swf2;
			ROWbit[3] <= swe;
			ROWbit[2] <= swg;
			ROWbit[1] <= swh;
			ROWbit[0] <= swy;
		end
		else if (col == 3'b101) begin
			ROWbit[7] <= swlsb;
			ROWbit[6] <= swrsb;
			ROWbit[5] <= swdel;
			ROWbit[4] <= swfcn;
			ROWbit[3] <= swp;
			ROWbit[2] <= swo;
			ROWbit[1] <= swi;
			ROWbit[0] <= swu;
		end
		else if (col == 3'b100) begin
			ROWbit[7] <= swR;
			ROWbit[6] <= swD;
			ROWbit[5] <= swL;
			ROWbit[4] <= swls;
			ROWbit[3] <= swU;
			ROWbit[2] <= swdot;
			ROWbit[1] <= swcom;
			ROWbit[0] <= swsp;
		end
		else if (col == 3'b011) begin
			ROWbit[7] <= swsq;
			ROWbit[6] <= swbs;
			ROWbit[5] <= swf3;
			ROWbit[4] <= swf4;
			ROWbit[3] <= swdsh;
			ROWbit[2] <= swsc;
			ROWbit[1] <= sw9;
			ROWbit[0] <= swk;
		end
		else if (col == 3'b010) begin
			ROWbit[7] <= swc;
			ROWbit[6] <= sw2;
			ROWbit[5] <= swz;
			ROWbit[4] <= swctl;
			ROWbit[3] <= sw4;
			ROWbit[2] <= swb;
			ROWbit[1] <= sw6;
			ROWbit[0] <= swm;
		end
		else if (col == 3'b001) begin
			ROWbit[7] <= swd;
			ROWbit[6] <= swq;
			ROWbit[5] <= swesc;
			ROWbit[4] <= swf5;
			ROWbit[3] <= swf;
			ROWbit[2] <= swr;
			ROWbit[1] <= swt;
			ROWbit[0] <= swj;
		end
		else if (col == 3'b000) begin
			ROWbit[7] <= sw3;
			ROWbit[6] <= swx;
			ROWbit[5] <= sw1;
			ROWbit[4] <= swf6;
			ROWbit[3] <= swv;
			ROWbit[2] <= sw5;
			ROWbit[1] <= swn;
			ROWbit[0] <= sw7;
		end
end
endmodule

