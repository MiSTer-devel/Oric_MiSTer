//============================================================================
//  Oric snapshot LOAD (.sna)
//
//  Triggered on the falling edge of ioctl_download with ioctl_index==4
//  (the F4 menu entry). Walks the Oricutron typed-block container from
//  the shared 192 KiB top-level filecache and applies the captured
//  state to RAM, the CPU, the AY chip and the VIA.
//
//  Block format and field-level mapping documented in
//  docs/sna_support.md. v1+v2 LOAD restores: 64 KiB main RAM, the 6502
//  register file (PC/A/X/Y/S/P), the 15-byte AY register file plus the
//  current-register select, and 12 of the 16 VIA registers (ORA, ORB,
//  DDRA, DDRB, T1L_L/H, T2L_L/H, SR, ACR, PCR, IER).
//
//  Out of scope (v3 candidates): live VIA timer counters, VIA shift-
//  register count, AY oscillator phase (tone/noise/envelope counters),
//  IFR direct restore.
//
//  Optional SNAP_DEBUG macro paints the captured CPU regs at row 10 of
//  the text screen for verification — `oric-build --snap-debug`.
//============================================================================

module snap_loader (
	input             clk_sys,
	input             reset,
	input             ioctl_download,
	input             ioctl_downlD,
	input             load_sna,           // ioctl_index == 4
	input             start,              // hotkey retrigger (snap_ss LOAD)
	input      [17:0] snap_end,
	output reg [17:0] snap_cache_addr,
	input       [7:0] snap_cache_q,

	output reg        active,             // halts CPU + selects loader's RAM-write path
	output reg [15:0] ram_addr,
	output reg  [7:0] ram_data,
	output reg        ram_we,

	output reg [63:0] cpu_regs_set,       // T65 register-set bus
	output reg        cpu_regs_set_we,

	output reg        via_snap_we,
	output reg  [3:0] via_snap_addr,
	output reg  [7:0] via_snap_data,

	// VIA timer internal state (T1C/T2C live counters + run flags).
	// Required for snapshots taken mid-frame on games that drive
	// music/animation off VIA T1 IRQs (e.g. Xenon3) — without these
	// the timer phase resets to the latch on restore and IRQ pacing
	// is wrong.
	output reg        via_snap_t1c_we,
	output reg [15:0] via_snap_t1c_data,
	output reg        via_snap_t2c_we,
	output reg [15:0] via_snap_t2c_data,
	output reg        via_snap_t_active_we,
	output reg        via_snap_t1_active,
	output reg        via_snap_t2_active,

	output reg        via_snap_ifr_we,
	output reg  [6:0] via_snap_ifr_data,

	output reg        ay_snap_we,
	output reg  [3:0] ay_snap_addr,
	output reg  [7:0] ay_snap_data,
	output reg        ay_snap_creg_we,
	output reg  [3:0] ay_snap_creg,

	output reg        ula_snap_mode_we,
	output reg  [2:0] ula_snap_mode
);

wire snap_trigger = (ioctl_downlD && ~ioctl_download && load_sna) || start;

localparam S_IDLE             = 5'd0,
           S_INIT             = 5'd1,
           S_HDR_TAG          = 5'd2,
           S_HDR_SIZE         = 5'd3,
           S_BLK_DATA_RAM     = 5'd4,
           S_BLK_CPU          = 5'd5,
           S_BLK_AY           = 5'd6,
           S_BLK_VIA          = 5'd7,
           S_SKIP             = 5'd8,
           S_APPLY_VIA        = 5'd9,
           S_APPLY_VIA_TIMERS = 5'd10,
           S_APPLY_AY         = 5'd11,
           S_APPLY_CPU        = 5'd12,
           S_DRAIN            = 5'd13,
           S_DONE             = 5'd14,
           S_DEBUG_PAINT      = 5'd15,
           S_BLK_OSN          = 5'd16;

reg  [4:0]  snap_state;
reg  [1:0]  hdr_byte_cnt;
reg  [31:0] blk_tag;
reg  [31:0] blk_size;
reg  [31:0] prev_tag;
reg  [16:0] blk_offset;

reg  [15:0] snap_pc;
reg  [7:0]  snap_a, snap_x, snap_y, snap_s, snap_p;
reg         snap_ula_mode_valid;

// AY register file (15 regs) + currently-selected register
reg  [7:0]  snap_ay_regs [0:14];
reg  [3:0]  snap_ay_creg;

// VIA register file (12 we restore — see comment in S_BLK_VIA below)
reg  [7:0]  snap_via_regs [0:11];

// VIA timer internals captured from snapshot: T1C lo/hi + T2C lo/hi
// + t1run + t2run (Oricutron VIA block offsets 11/12/15/16/30/31).
reg  [15:0] snap_via_t1c;
reg  [15:0] snap_via_t2c;
reg         snap_via_t1run;
reg         snap_via_t2run;
reg  [7:0]  snap_via_ifr;     // Oricutron VIA block offset 0

reg  [3:0]  snap_apply_cnt;
reg  [9:0]  snap_drain_cnt;

`ifdef SNAP_DEBUG
reg  [5:0]  snap_paint_idx;
function automatic [7:0] snap_hex_digit(input [3:0] n);
    snap_hex_digit = (n < 4'd10) ? (8'h30 + n) : (8'h37 + n);
endfunction
`endif

// Use explicit hex literals — Verilog string-escape semantics don't
// handle "\x00" the way SystemVerilog does, so building tag constants
// from string literals containing NUL was matching nothing.
localparam [31:0] TAG_OSN  = 32'h4F534E00; // "OSN\0"
localparam [31:0] TAG_DATA = 32'h44415441; // "DATA"
localparam [31:0] TAG_CPU  = 32'h43505500; // "CPU\0"
localparam [31:0] TAG_AY   = 32'h41590000; // "AY\0\0"
localparam [31:0] TAG_VIA  = 32'h56494100; // "VIA\0"

always @(posedge clk_sys) begin
	if (reset) begin
		snap_state           <= S_IDLE;
		active               <= 1'b0;
		ram_we               <= 1'b0;
		cpu_regs_set_we      <= 1'b0;
		via_snap_we          <= 1'b0;
		via_snap_t1c_we      <= 1'b0;
		via_snap_t2c_we      <= 1'b0;
		via_snap_t_active_we <= 1'b0;
		via_snap_ifr_we      <= 1'b0;
		ay_snap_we           <= 1'b0;
		ay_snap_creg_we      <= 1'b0;
		ula_snap_mode_we     <= 1'b0;
	end
	else begin
		ram_we               <= 1'b0;
		cpu_regs_set_we      <= 1'b0;
		via_snap_we          <= 1'b0;
		via_snap_t1c_we      <= 1'b0;
		via_snap_t2c_we      <= 1'b0;
		via_snap_t_active_we <= 1'b0;
		via_snap_ifr_we      <= 1'b0;
		ay_snap_we           <= 1'b0;
		ay_snap_creg_we      <= 1'b0;
		ula_snap_mode_we     <= 1'b0;

		case (snap_state)
			S_IDLE: begin
				if (snap_trigger) begin
					active          <= 1'b1;
					snap_cache_addr <= 18'd0;
					hdr_byte_cnt    <= 2'd0;
					blk_offset      <= 17'd0;
					prev_tag        <= 32'd0;
					// Defaults if a CPU block isn't found
					snap_pc <= 16'h0000;
					snap_a  <= 8'h00;
					snap_x  <= 8'h00;
					snap_y  <= 8'h00;
					snap_s  <= 8'hFF;
					snap_p  <= 8'h24; // I=1, undefined-bit-5=1, others 0
					ula_snap_mode       <= 3'b000;
					snap_ula_mode_valid <= 1'b0;
					snap_state <= S_INIT;
				end
			end

			// Prime filecache read pipeline. After this cycle, snap_cache_q
			// at S_HDR_TAG will reflect mem[0].
			S_INIT: begin
				snap_cache_addr <= 18'd1;
				hdr_byte_cnt    <= 2'd0;
				snap_state      <= S_HDR_TAG;
			end

			// Read 4 tag bytes. End-of-file detected when we'd read past snap_end.
			S_HDR_TAG: begin
				if ({1'b0, snap_cache_addr} > {1'b0, snap_end} + 1'b1) begin
`ifdef SNAP_DEBUG
					snap_paint_idx <= 6'd0;
					snap_state     <= S_DEBUG_PAINT;
`else
					snap_apply_cnt <= 4'd0;
					snap_state     <= S_APPLY_VIA;
`endif
				end
				else begin
					case (hdr_byte_cnt)
						2'd0: blk_tag[31:24] <= snap_cache_q;
						2'd1: blk_tag[23:16] <= snap_cache_q;
						2'd2: blk_tag[15:8]  <= snap_cache_q;
						2'd3: blk_tag[7:0]   <= snap_cache_q;
					endcase
					snap_cache_addr <= snap_cache_addr + 18'd1;
					if (hdr_byte_cnt == 2'd3) begin
						hdr_byte_cnt <= 2'd0;
						snap_state   <= S_HDR_SIZE;
					end
					else hdr_byte_cnt <= hdr_byte_cnt + 2'd1;
				end
			end

			// Read 4 size bytes (BE), then dispatch on blk_tag.
			S_HDR_SIZE: begin
				case (hdr_byte_cnt)
					2'd0: blk_size[31:24] <= snap_cache_q;
					2'd1: blk_size[23:16] <= snap_cache_q;
					2'd2: blk_size[15:8]  <= snap_cache_q;
					2'd3: blk_size[7:0]   <= snap_cache_q;
				endcase
				snap_cache_addr <= snap_cache_addr + 18'd1;
				if (hdr_byte_cnt == 2'd3) begin
					hdr_byte_cnt <= 2'd0;
					blk_offset   <= 17'd0;
					case (blk_tag)
						TAG_OSN:  snap_state <= S_BLK_OSN;
						TAG_CPU:  snap_state <= S_BLK_CPU;
						TAG_AY:   snap_state <= S_BLK_AY;
						TAG_VIA:  snap_state <= S_BLK_VIA;
						TAG_DATA: snap_state <= (prev_tag == TAG_OSN) ? S_BLK_DATA_RAM : S_SKIP;
						default:  snap_state <= S_SKIP;
					endcase
					if (blk_tag != TAG_DATA) prev_tag <= blk_tag;
				end
				else hdr_byte_cnt <= hdr_byte_cnt + 2'd1;
			end

			// OSN machine-config block: capture the ULA video mode at
			// offset 16. Oricutron stores hires/text and 50/60 Hz here;
			// RAM contents alone are not enough when a snapshot resumes
			// mid-screen before the next mode attribute is scanned.
			S_BLK_OSN: begin
				if (blk_offset[7:0] == 8'd16) begin
					ula_snap_mode       <= snap_cache_q[2:0];
					snap_ula_mode_valid <= 1'b1;
				end
				snap_cache_addr <= snap_cache_addr + 18'd1;
				blk_offset      <= blk_offset + 17'd1;
				if (blk_offset == blk_size[16:0] - 17'd1) begin
					blk_offset   <= 17'd0;
					hdr_byte_cnt <= 2'd0;
					snap_state   <= S_HDR_TAG;
				end
			end

			// DATA payload following OSN: stream first 64 KiB into main RAM.
			S_BLK_DATA_RAM: begin
				if (blk_offset < 17'h10000) begin
					ram_addr <= blk_offset[15:0];
					ram_data <= snap_cache_q;
					ram_we   <= 1'b1;
				end
				snap_cache_addr <= snap_cache_addr + 18'd1;
				blk_offset      <= blk_offset + 17'd1;
				if (blk_offset == blk_size[16:0] - 17'd1) begin
					blk_offset   <= 17'd0;
					hdr_byte_cnt <= 2'd0;
					snap_state   <= S_HDR_TAG;
				end
			end

			// CPU block: capture only the fields we use (PC at 4-5, A/X/Y/S/P at 13-17).
			S_BLK_CPU: begin
				case (blk_offset[7:0])
					8'd4:  snap_pc[15:8] <= snap_cache_q;
					8'd5:  snap_pc[7:0]  <= snap_cache_q;
					8'd13: snap_a <= snap_cache_q;
					8'd14: snap_x <= snap_cache_q;
					8'd15: snap_y <= snap_cache_q;
					8'd16: snap_s <= snap_cache_q;
					8'd17: snap_p <= snap_cache_q;
					default: ;
				endcase
				snap_cache_addr <= snap_cache_addr + 18'd1;
				blk_offset      <= blk_offset + 17'd1;
				if (blk_offset == blk_size[16:0] - 17'd1) begin
					blk_offset   <= 17'd0;
					hdr_byte_cnt <= 2'd0;
					snap_state   <= S_HDR_TAG;
				end
			end

			// AY block: capture creg (offset 1) + 15-byte register file (2..16).
			// Other Oricutron AY fields (keystates, derived counters etc.) skipped
			// for v2 — register file is enough to make audio resume.
			S_BLK_AY: begin
				case (blk_offset[7:0])
					8'd1:  snap_ay_creg     <= snap_cache_q[3:0];
					8'd2:  snap_ay_regs[0]  <= snap_cache_q;
					8'd3:  snap_ay_regs[1]  <= snap_cache_q;
					8'd4:  snap_ay_regs[2]  <= snap_cache_q;
					8'd5:  snap_ay_regs[3]  <= snap_cache_q;
					8'd6:  snap_ay_regs[4]  <= snap_cache_q;
					8'd7:  snap_ay_regs[5]  <= snap_cache_q;
					8'd8:  snap_ay_regs[6]  <= snap_cache_q;
					8'd9:  snap_ay_regs[7]  <= snap_cache_q;
					8'd10: snap_ay_regs[8]  <= snap_cache_q;
					8'd11: snap_ay_regs[9]  <= snap_cache_q;
					8'd12: snap_ay_regs[10] <= snap_cache_q;
					8'd13: snap_ay_regs[11] <= snap_cache_q;
					8'd14: snap_ay_regs[12] <= snap_cache_q;
					8'd15: snap_ay_regs[13] <= snap_cache_q;
					8'd16: snap_ay_regs[14] <= snap_cache_q;
					default: ;
				endcase
				snap_cache_addr <= snap_cache_addr + 18'd1;
				blk_offset      <= blk_offset + 17'd1;
				if (blk_offset == blk_size[16:0] - 17'd1) begin
					blk_offset   <= 17'd0;
					hdr_byte_cnt <= 2'd0;
					snap_state   <= S_HDR_TAG;
				end
			end

			// VIA block: capture the 12 registers we restore plus timer
			// internals (T1C/T2C live counters + t1run/t2run flags).
			// Skipped fields: IFR (computed from source IRQ flags),
			// IRB/IRBL/IRA/IRAL (input shadows), CA/CB line states,
			// srcount/srtime/srtrigger, ca2pulse/cb2pulse, irqbit.
			S_BLK_VIA: begin
				case (blk_offset[7:0])
					8'd0:  snap_via_ifr      <= snap_cache_q; // IFR
					8'd2:  snap_via_regs[0]  <= snap_cache_q; // ORB
					8'd5:  snap_via_regs[1]  <= snap_cache_q; // ORA
					8'd7:  snap_via_regs[2]  <= snap_cache_q; // DDRA
					8'd8:  snap_via_regs[3]  <= snap_cache_q; // DDRB
					8'd9:  snap_via_regs[4]  <= snap_cache_q; // T1L_L
					8'd10: snap_via_regs[5]  <= snap_cache_q; // T1L_H
					8'd11: snap_via_t1c[15:8] <= snap_cache_q; // T1C hi (BE)
					8'd12: snap_via_t1c[7:0]  <= snap_cache_q; // T1C lo
					8'd13: snap_via_regs[6]  <= snap_cache_q; // T2L_L
					8'd14: snap_via_regs[7]  <= snap_cache_q; // T2L_H
					8'd15: snap_via_t2c[15:8] <= snap_cache_q; // T2C hi (BE)
					8'd16: snap_via_t2c[7:0]  <= snap_cache_q; // T2C lo
					8'd17: snap_via_regs[8]  <= snap_cache_q; // SR
					8'd18: snap_via_regs[9]  <= snap_cache_q; // ACR
					8'd19: snap_via_regs[10] <= snap_cache_q; // PCR
					8'd20: snap_via_regs[11] <= snap_cache_q; // IER
					8'd30: snap_via_t1run    <= snap_cache_q[0]; // t1run flag
					8'd31: snap_via_t2run    <= snap_cache_q[0]; // t2run flag
					default: ;
				endcase
				snap_cache_addr <= snap_cache_addr + 18'd1;
				blk_offset      <= blk_offset + 17'd1;
				if (blk_offset == blk_size[16:0] - 17'd1) begin
					blk_offset   <= 17'd0;
					hdr_byte_cnt <= 2'd0;
					snap_state   <= S_HDR_TAG;
				end
			end

			// Unknown / not-yet-handled block: advance past the payload.
			S_SKIP: begin
				snap_cache_addr <= snap_cache_addr + 18'd1;
				blk_offset      <= blk_offset + 17'd1;
				if (blk_offset == blk_size[16:0] - 17'd1) begin
					blk_offset   <= 17'd0;
					hdr_byte_cnt <= 2'd0;
					snap_state   <= S_HDR_TAG;
				end
			end

`ifdef SNAP_DEBUG
			// Debug-only: paint captured CPU regs to row 10 of the text
			// screen so we can verify the snapshot decode survived even
			// if the CPU misbehaves on resume. Compile in via the
			// SNAP_DEBUG Verilog macro (`oric-build --snap-debug`).
			S_DEBUG_PAINT: begin
				ram_we   <= 1'b1;
				// Row 10: $BB80 + 10*40 = $BD10
				ram_addr <= 16'hBD10 + {10'd0, snap_paint_idx};
				case (snap_paint_idx)
					6'd0:  ram_data <= 8'h07;
					6'd1:  ram_data <= "S";
					6'd2:  ram_data <= "N";
					6'd3:  ram_data <= "A";
					6'd4:  ram_data <= "P";
					6'd5:  ram_data <= " ";
					6'd6:  ram_data <= "P";
					6'd7:  ram_data <= "C";
					6'd8:  ram_data <= "=";
					6'd9:  ram_data <= "$";
					6'd10: ram_data <= snap_hex_digit(snap_pc[15:12]);
					6'd11: ram_data <= snap_hex_digit(snap_pc[11:8]);
					6'd12: ram_data <= snap_hex_digit(snap_pc[7:4]);
					6'd13: ram_data <= snap_hex_digit(snap_pc[3:0]);
					6'd14: ram_data <= " ";
					6'd15: ram_data <= "A";
					6'd16: ram_data <= "=";
					6'd17: ram_data <= "$";
					6'd18: ram_data <= snap_hex_digit(snap_a[7:4]);
					6'd19: ram_data <= snap_hex_digit(snap_a[3:0]);
					6'd20: ram_data <= " ";
					6'd21: ram_data <= "X";
					6'd22: ram_data <= "=";
					6'd23: ram_data <= "$";
					6'd24: ram_data <= snap_hex_digit(snap_x[7:4]);
					6'd25: ram_data <= snap_hex_digit(snap_x[3:0]);
					6'd26: ram_data <= " ";
					6'd27: ram_data <= "Y";
					6'd28: ram_data <= "=";
					6'd29: ram_data <= "$";
					6'd30: ram_data <= snap_hex_digit(snap_y[7:4]);
					6'd31: ram_data <= snap_hex_digit(snap_y[3:0]);
					6'd32: ram_data <= " ";
					6'd33: ram_data <= "S";
					6'd34: ram_data <= "=";
					6'd35: ram_data <= "$";
					6'd36: ram_data <= snap_hex_digit(snap_s[7:4]);
					6'd37: ram_data <= snap_hex_digit(snap_s[3:0]);
					default: ram_data <= " ";
				endcase
				if (snap_paint_idx == 6'd39) begin
					snap_apply_cnt <= 4'd0;
					snap_state     <= S_APPLY_VIA;
				end
				else snap_paint_idx <= snap_paint_idx + 6'd1;
			end
`endif

			// Walk through 12 captured VIA registers and pulse via_snap_we for
			// each — the chip's snap branch writes the register file directly,
			// bypassing the chip-select / phi2 protocol. snap_apply_cnt selects.
			S_APPLY_VIA: begin
				via_snap_we <= 1'b1;
				case (snap_apply_cnt)
					4'd0:  begin via_snap_addr <= 4'h0; via_snap_data <= snap_via_regs[0];  end // ORB
					4'd1:  begin via_snap_addr <= 4'h1; via_snap_data <= snap_via_regs[1];  end // ORA
					4'd2:  begin via_snap_addr <= 4'h3; via_snap_data <= snap_via_regs[2];  end // DDRA
					4'd3:  begin via_snap_addr <= 4'h2; via_snap_data <= snap_via_regs[3];  end // DDRB
					4'd4:  begin via_snap_addr <= 4'h4; via_snap_data <= snap_via_regs[4];  end // T1L_L
					4'd5:  begin via_snap_addr <= 4'h5; via_snap_data <= snap_via_regs[5];  end // T1L_H
					4'd6:  begin via_snap_addr <= 4'h8; via_snap_data <= snap_via_regs[6];  end // T2L_L
					4'd7:  begin via_snap_addr <= 4'h9; via_snap_data <= snap_via_regs[7];  end // T2L_H
					4'd8:  begin via_snap_addr <= 4'hA; via_snap_data <= snap_via_regs[8];  end // SR
					4'd9:  begin via_snap_addr <= 4'hB; via_snap_data <= snap_via_regs[9];  end // ACR
					4'd10: begin via_snap_addr <= 4'hC; via_snap_data <= snap_via_regs[10]; end // PCR
					4'd11: begin via_snap_addr <= 4'hE; via_snap_data <= snap_via_regs[11]; end // IER
					default: via_snap_we <= 1'b0;
				endcase
				snap_apply_cnt <= snap_apply_cnt + 4'd1;
				if (snap_apply_cnt == 4'd11) begin
					snap_apply_cnt <= 4'd0;
					snap_state     <= S_APPLY_VIA_TIMERS;
				end
			end

			// VIA timer + IFR internal-state apply: pulse the dedicated
			// strobes that override t1c/t2c/active flags / per-source
			// IRQ flags inside the VIA processes. One cycle each.
			S_APPLY_VIA_TIMERS: begin
				case (snap_apply_cnt)
					4'd0: begin
						via_snap_t1c_we   <= 1'b1;
						via_snap_t1c_data <= snap_via_t1c;
					end
					4'd1: begin
						via_snap_t2c_we   <= 1'b1;
						via_snap_t2c_data <= snap_via_t2c;
					end
					4'd2: begin
						via_snap_t_active_we <= 1'b1;
						via_snap_t1_active   <= snap_via_t1run;
						via_snap_t2_active   <= snap_via_t2run;
					end
					4'd3: begin
						via_snap_ifr_we   <= 1'b1;
						via_snap_ifr_data <= snap_via_ifr[6:0];
					end
					default: ;
				endcase
				snap_apply_cnt <= snap_apply_cnt + 4'd1;
				if (snap_apply_cnt == 4'd3) begin
					snap_apply_cnt <= 4'd0;
					snap_state     <= S_APPLY_AY;
				end
			end

			// Walk through 15 captured AY registers, then write the captured
			// current-register-select. Each pulse is one clk_sys cycle.
			S_APPLY_AY: begin
				if (snap_apply_cnt < 4'd15) begin
					ay_snap_we   <= 1'b1;
					ay_snap_addr <= snap_apply_cnt;
					ay_snap_data <= snap_ay_regs[snap_apply_cnt];
				end
				else begin
					ay_snap_creg_we <= 1'b1;
					ay_snap_creg    <= snap_ay_creg;
				end
				snap_apply_cnt <= snap_apply_cnt + 4'd1;
				if (snap_apply_cnt == 4'd15) begin
					snap_apply_cnt <= 4'd0;
					snap_state     <= S_APPLY_CPU;
				end
			end

			// Drive Regs_set + we to T65 for a handful of cycles so the
			// register-load process latches cleanly.
			S_APPLY_CPU: begin
				cpu_regs_set    <= {snap_pc, 8'h00, snap_s, snap_p, snap_y, snap_x, snap_a};
				cpu_regs_set_we <= 1'b1;
				snap_apply_cnt  <= snap_apply_cnt + 4'd1;
				if (snap_apply_cnt == 4'd15) begin
					snap_drain_cnt <= 10'd0;
					snap_state     <= S_DRAIN;
				end
			end

			// Hold active long enough to span at least one full phi2
			// cycle (24 clk_sys cycles per phi2 half) so cpu_di settles to
			// mem[loaded_PC] before we let T65 fetch its first opcode.
			S_DRAIN: begin
				ram_addr         <= snap_pc;
				ram_we           <= 1'b0;
				ula_snap_mode_we <= snap_ula_mode_valid;
				snap_drain_cnt   <= snap_drain_cnt + 10'd1;
				if (snap_drain_cnt == 10'd1023) snap_state <= S_DONE;
			end

			S_DONE: begin
				active     <= 1'b0;
				snap_state <= S_IDLE;
			end

			default: snap_state <= S_IDLE;
		endcase
	end
end

endmodule
