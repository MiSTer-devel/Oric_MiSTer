// Vincent Bénony 2023

module joystick
(
	input			   clk_sys,
	input  [7:0]   joystick_0,
	input  [7:0]	joystick_1,
	input	 [1:0]	adapter,
	input          via_strobe,
	input  [7:0]   via_pa_in,

	output [7:0]	joy_mask,
	output [7:0]	joy_value
);

reg [7:0] mask;
reg [7:0] value;

always @(posedge clk_sys) begin

	mask[7:0]  = 8'b00000000;
	value[7:0] = 8'b00000000;
	
	case (adapter)
		// PASE
		1:
			if (via_pa_in[7] == 1) begin	         // Joystick 0 selected
				mask[0] = joystick_0[1];            // Left
				mask[1] = joystick_0[0];            // Right
				mask[3] = joystick_0[2];            // Down
				mask[4] = joystick_0[3];            // Up
				mask[5] = joystick_0[4];            // Fire
			end else if (via_pa_in[6] == 1) begin	// Joystick 1 selected
				mask[0] = joystick_1[1];            // Left
				mask[1] = joystick_1[0];            // Right
				mask[3] = joystick_1[2];            // Down
				mask[4] = joystick_1[3];            // Up
				mask[5] = joystick_1[4];            // Fire
			end

		// IJK
		2:
			if (via_strobe == 0) begin	// Respond only when the printer stobe is active (low)
				joy_mask[5] = 1'b1;     // Signal that the IJK interface is present
				
				if (via_pa_in[6] == 1) begin				// Joystick 0 selected
					mask[0] = joystick_0[0];            // Right
					mask[1] = joystick_0[1];            // Left
					mask[2] = joystick_0[4];            // Fire
					mask[3] = joystick_0[2];            // Down
					mask[4] = joystick_0[3];            // Up
				end else if (via_pa_in[7] == 1) begin	// Joystick 1 selected
					mask[0] = joystick_1[0];            // Right
					mask[1] = joystick_1[1];            // Left
					mask[2] = joystick_1[4];            // Fire
					mask[3] = joystick_1[2];            // Down
					mask[4] = joystick_1[3];            // Up
				end
			end
	endcase
	
	joy_mask[7:0]  <= mask[7:0];
	joy_value[7:0] <= value[7:0];
end

endmodule
