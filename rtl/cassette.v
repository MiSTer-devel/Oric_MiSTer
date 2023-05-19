
module cassette(

  input clk,
  input reset,
  input rewind,
  input en,
  
  output reg [15:0] tape_addr,
  input [7:0] tape_data,

  input [15:0] tape_end,
  output data

);

wire [7:0] r_tape_data;


assign r_tape_data = tape_data;

reg old_en;
reg ffrewind;

reg [7:0] ibyte;
reg [2:0] state;
reg sq_start;
reg [1:0] eof;
reg [8:0] sync_count;
reg [15:0] bot_seg; //Beginning of TAP segment
reg [15:0] data_start_addr;  //The Start Address of the Data, as derived from the Header
reg [15:0] data_end_addr;    //The End Address of the Data, as derived from the Header
reg [15:0] data_size;        //The Data size (data_end_addr - data_start_addr + 1)
reg [15:0] file_boh_ptr; //Current file's beginning of header pointer (right after end of sync marker h24)
reg [119:0] currentFileName; //Store the name of program in current TAP segment (may be null).  Not needed ATM - Possible future use
reg [23:0] wait_counter; //Half a second (half the clock pulses) pause between segments.
reg name;
reg eoh, eos;
reg gap, gap_sent;
wire done;

parameter
  IDLE      = 3'h0,
  NEXT      = 3'h1,
  READ1     = 3'h2,
  READ2     = 3'h3,
  READ3     = 3'h4,
  WAIT      = 3'h5,
  SEND_GAP  = 3'h6;

always @(posedge clk) begin

	ffrewind <= rewind;

	if(reset || (ffrewind ^ rewind)) begin
		state <= IDLE;
		eoh <= 1'b0;
		eos <= 1'b0;
		eof <= 2'b00;
		gap <= 1'b0;
		gap_sent <= 1'b0;
		tape_addr <= 16'd0;
		bot_seg <= 16'd0;
		data_start_addr <= 16'd0;
		data_end_addr <= 16'd0;
		data_size <= 16'd0;
		sync_count <= 9'h000;
		currentFileName <= 120'd0;
		wait_counter <= 24'd12000000;
	end
	else begin
			
		 old_en <= en;
		 if (old_en ^ en) begin
			state <= state == IDLE ? WAIT : IDLE;
		 end

		 case (state)
		 WAIT: begin
			if(|wait_counter) wait_counter <= wait_counter - 1'b1;
			else state <= NEXT;
		 end
			
		 NEXT: begin
			state <= READ1;
//			sdram_rd <= 1'b0;
			if (tape_addr == tape_end) begin
			  eof<=2'd2;
			end
			if (~en) begin
			  state <= IDLE;
			end
		 end

		 READ1: begin
			if(bot_seg == 16'd0 && sync_count == 9'h000) begin     //Beginning of TAP segment.
				eoh <= 1'b0;               //Make sure End of Header flag is reset
				eos <= 1'b0;               //Make sure End of Sync flag is reset
				if(r_tape_data != 8'h16) begin   //Check first byte of data to be sure it's a sync byte, if not
					eof<=2'd2;             //  set End of Tape marker
					state <= IDLE;         //  and go back to IDLE state
				end
			end
			if(~eos && r_tape_data == 8'h24) begin //Look for End of Sync marker till we find it
				eos <= 1'b1;                        //Raise the End of Sync flag so we can stop looking for it
				bot_seg <= tape_addr + 1'b1;        //Set the Beginning of Tape Segment address to the first byte of the Header (current address + 1)
			end
			if(tape_addr == bot_seg + 8'd4) data_end_addr[15:8] = r_tape_data;
			if(tape_addr == bot_seg + 8'd5) data_end_addr[7:0] = r_tape_data;
			if(tape_addr == bot_seg + 8'd6) data_start_addr[15:8] = r_tape_data;
			if(tape_addr == bot_seg + 8'd7) data_start_addr[7:0] = r_tape_data;
			if(tape_addr == bot_seg + 8'd8) data_size <= (data_end_addr - data_start_addr) + 16'd2;
			if(tape_addr >= bot_seg + 8'd9 && ~eoh) begin                              //Starting with 9 bytes after the BoT segment,
				if(r_tape_data == 8'h00) begin                                          //look for the terminating 'h0 of the FileName
					eoh <= 1'b1;                                                         //Raise the End of Header flag
					gap_sent <= 1'b0;                                                    //Reset the Gap Sent Flag
					gap <= 1'b0;                                                         //Reset the Gap request Flag
				end
				else currentFileName <= {currentFileName[110:0],r_tape_data};
			end
			ibyte <= r_tape_data;

			state <= READ2;
			sq_start <= 1'b1;
		 end
		 READ2: begin
			sq_start <= 1'b0;
			//If current byte has finished being sent/emitted...
			//Have we reached the End of Header?  If so, have we sent the gap?  If not, set the State to SEND_GAP, otherwise continue on to READ3
			//If we are still processing the current byte, then just loop back around
			state <= done ? (eoh && ~gap_sent ? SEND_GAP : READ3 ) : READ2;
		 end
		 READ3: begin
			if(~eos && sync_count != 9'h1FF)	begin              //Repeat the first byte of file (should be 16h) at least 16 times before incrementing cache address
				sync_count <= sync_count + 1'b1;
			end
			else begin
				tape_addr <= tape_addr + 1'd1;                   //Advance the tape cache address by 1
				if(eoh) begin
					if(data_size) data_size <= data_size - 1'b1;  //Decrement Data Size till we hit 0
					else begin
						bot_seg <= 16'd0;                          //Reset the Beginning of TAP segment address in case there is another segment on tape
						sync_count <= 9'h000;                      //Reset the Sync Marker count
						wait_counter <= 24'd12000000;
					end
				end
			end
			state <= eof == 2'd2 ? IDLE : NEXT;  //If we haven't reached end of file/tape, read the next byte if there is still data to be sent or go to WAIT state to pause a bit before next segment/file
		 end
		 
		 SEND_GAP: begin
			if(~gap_sent && ~gap) begin
				ibyte <= 8'hFF;         //This value is not used, but we set it to all hFF just because
				gap <= 1'b1;
				sq_start <= 1'b1;
			end
			else if(done) begin
				gap_sent <= 1'b1;
				gap <= 1'b0;
				state <= READ3;
			end
			else begin
				sq_start <= 1'b0;
			end
		 end
			
		 endcase


	 end
end

cas_sig_gen csg(
  .clk(clk),
  .reset(reset),
  .start(sq_start),
  .gap(gap),
  .din(ibyte),
  .done(done),
  .dout (data)
);


endmodule
