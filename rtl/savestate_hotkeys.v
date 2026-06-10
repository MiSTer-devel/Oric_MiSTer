//============================================================================
//  Savestate hotkeys (PS/2)
//
//  F1-F4 save to slot 1-4, F5-F8 restore from slot 1-4. Strobes are one
//  clk cycle. The Oric keyboard map only uses F10 (NMI) and F11 (reset),
//  so F1-F8 never reach the emulated machine.
//============================================================================

module savestate_hotkeys (
	input            clk,
	input     [10:0] ps2_key,
	input            allow,
	output reg       ss_save,
	output reg       ss_load,
	output reg [1:0] ss_slot
);

reg old_state = 0;

always @(posedge clk) begin
	old_state <= ps2_key[10];

	ss_save <= 1'b0;
	ss_load <= 1'b0;

	// ps2_key: [10] toggle strobe, [9] pressed, [8] extended, [7:0] code
	if (allow && old_state != ps2_key[10] && ps2_key[9] && !ps2_key[8]) begin
		case (ps2_key[7:0])
			8'h05: begin ss_save <= 1'b1; ss_slot <= 2'd0; end // F1
			8'h06: begin ss_save <= 1'b1; ss_slot <= 2'd1; end // F2
			8'h04: begin ss_save <= 1'b1; ss_slot <= 2'd2; end // F3
			8'h0C: begin ss_save <= 1'b1; ss_slot <= 2'd3; end // F4
			8'h03: begin ss_load <= 1'b1; ss_slot <= 2'd0; end // F5
			8'h0B: begin ss_load <= 1'b1; ss_slot <= 2'd1; end // F6
			8'h83: begin ss_load <= 1'b1; ss_slot <= 2'd2; end // F7
			8'h0A: begin ss_load <= 1'b1; ss_slot <= 2'd3; end // F8
			default: ;
		endcase
	end
end

endmodule
