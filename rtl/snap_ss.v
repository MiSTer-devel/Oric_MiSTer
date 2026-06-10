//============================================================================
//  Oric savestate DDR engine (MiSTer Main savestate framework)
//
//  Two mutually-exclusive state machines sharing one DDR channel:
//
//  SAVE (F1-F4): halts the CPU at an instruction boundary (save_halt /
//  cpu_halted handshake with oricatmos), latches VIA/CPU/ULA state in a
//  single cycle, walks the AY register file, then streams an
//  Oricutron-format .sna block container (OSN, DATA(RAM), CPU, AY, VIA,
//  PAD) into the DDR savestate slot. The 8-byte MiSTer header (change
//  counter + payload size in dwords) is written last; Main_MiSTer
//  detects the counter change and writes the slot to
//  savestates/Oric/<game>_<slot>.ss.
//
//  LOAD (F5-F8): validates the slot header, DMAs the payload into the
//  shared 192 KiB filecache and retriggers the existing snap_loader,
//  which applies the snapshot exactly like an OSD .sna load. The size
//  check is a range check (not exact-match) so Oricutron snapshots of
//  any size, converted with tools/ss-convert.py, load too.
//
//  Slot layout (DDR byte offset inside the core's 0x30000000 window),
//  matching conf_str "SS3E000000:200000":
//    0x0E000000 + slot*0x200000 : u32 LE change counter
//    +4                         : u32 LE payload size in dwords
//    +8                         : payload (big-endian Oricutron blocks)
//
//  Field-by-field format mapping: docs/sna_support.md.
//============================================================================

module snap_ss (
	input             clk_sys,
	input             reset,

	// requests (1-cycle strobes from savestate_hotkeys)
	input             save_req,
	input             load_req,
	input       [1:0] req_slot,
	input             allow,

	// CPU halt handshake (oricatmos): save_halt requests an
	// instruction-boundary stall; cpu_halted confirms it.
	output reg        save_halt,
	input             cpu_halted,

	// captured machine state
	input      [63:0] cpu_regs,      // T65 Regs: {PC, S[15:0], P, Y, X, A}
	input     [136:0] via_q,         // m6522 snap_q (see layout below)
	output reg  [3:0] ay_rd_addr,
	input       [7:0] ay_rd_q,
	input       [3:0] ay_creg_q,
	input       [3:0] ay_env_q,
	input       [2:0] ula_mode_q,
	input       [1:0] rom_sel_q,     // 0=Atmos 1=Oric-1 2=Pravetz 3=loadable

	// ULA mode write-back after SAVE: while the RAM dump hijacks the
	// shared RAM port, the ULA keeps scanning and interprets the dump
	// bytes as serial attributes — a stray $18-$1F byte latches a wrong
	// video mode that persists on games that only set their mode once.
	// Restore the captured mode during the drain, like snap_loader does.
	output reg        ula_mode_we,
	output      [2:0] ula_mode,

	// main RAM read through the Oric.sv spram mux (2-cycle latency)
	output            save_active,
	output     [15:0] save_ram_addr,
	input       [7:0] ram_q,

	// hotkey load -> filecache + snap_loader retrigger
	output reg        load_active,
	output reg [17:0] fc_addr,
	output reg  [7:0] fc_data,
	output reg        fc_we,
	output reg [17:0] snap_end_set,
	output reg        snap_end_we,
	output reg        loader_start,

	// DDR ch1 (rtl/ddram.sv)
	output     [27:1] ddr_addr,
	output reg [63:0] ddr_din,
	input      [63:0] ddr_dout,
	output reg        ddr_req,
	output reg        ddr_rnw,
	output      [7:0] ddr_be,
	input             ddr_ready,

	// OSD info toast (hps_io info mechanism, index into conf_str "I,...")
	output reg  [7:0] ss_info,
	output reg        ss_info_req
);

// via_q layout (from m6522 snap_q):
//   [7:0] IFR  [15:8] ORB  [23:16] ORA  [31:24] DDRA  [39:32] DDRB
//   [47:40] T1L_L  [55:48] T1L_H  [71:56] T1C  [79:72] T2L_L
//   [87:80] T2L_H  [103:88] T2C  [111:104] SR  [119:112] ACR
//   [127:120] PCR  [134:128] IER  [135] t1run  [136] t2run

localparam [27:0] SLOT0_BASE  = 28'hE000000;  // 0x3E000000 in DDR
localparam [27:0] SLOT_STRIDE = 28'h0200000;  // 2 MiB per slot
localparam [17:0] TOTAL_BYTES = 18'd82204;         // payload, dword-aligned
localparam [31:0] SIZE_DWORDS = 32'd20551;         // TOTAL_BYTES / 4
localparam [17:0] FC_BYTES    = 18'd196608;        // filecache capacity

localparam [4:0] S_IDLE      = 5'd0,
                 SV_RDHDR    = 5'd1,
                 SV_RDHDR_W  = 5'd2,
                 SV_HALT     = 5'd3,
                 SV_CAPTURE  = 5'd4,
                 SV_AYRD     = 5'd5,
                 SV_EMIT     = 5'd6,
                 SV_WR       = 5'd7,
                 SV_WRHDR    = 5'd8,
                 SV_WRHDR_W  = 5'd9,
                 SV_DRAIN    = 5'd10,
                 LD_RDHDR    = 5'd11,
                 LD_RDHDR_W  = 5'd12,
                 LD_RD       = 5'd13,
                 LD_RD_W     = 5'd14,
                 LD_FC       = 5'd15,
                 LD_FIN      = 5'd16;

reg  [4:0]  state = S_IDLE;
reg  [1:0]  slot;
reg  [27:0] slot_base;
reg  [27:0] ddr_byte_addr;
reg  [31:0] counter_old;

assign ddr_addr = ddr_byte_addr[27:1];
assign ddr_be   = 8'hFF;

// ---------------- captured state ----------------

reg [136:0] c_via;
reg  [15:0] c_pc;
reg  [7:0]  c_a, c_x, c_y, c_sp, c_p;
reg  [2:0]  c_mode;
reg  [7:0]  c_type;
reg  [3:0]  c_creg;
reg  [3:0]  c_env;
reg  [7:0]  c_ay [0:14];

wire [7:0] osn_type = (rom_sel_q == 2'd1) ? 8'd0 :   // Oric-1
                      (rom_sel_q == 2'd2) ? 8'd4 :   // Pravetz 8D
                                            8'd2;    // Atmos / loadable BIOS

// Oricutron derived AY fields (8912.c): toneper = period*8,
// noiseper = period*8, envper = period*16, tonebit/noisebit from reg 7,
// vol = voltab[level or envelope level].
wire [31:0] toneper0 = {20'd0, c_ay[1][3:0], c_ay[0]} << 3;
wire [31:0] toneper1 = {20'd0, c_ay[3][3:0], c_ay[2]} << 3;
wire [31:0] toneper2 = {20'd0, c_ay[5][3:0], c_ay[4]} << 3;
wire [31:0] noiseper = {27'd0, c_ay[6][4:0]} << 3;
wire [31:0] envper   = {16'd0, c_ay[12], c_ay[11]} << 4;

// Oricutron voltab/4 (8912.c:61), C integer truncation
function [15:0] voltab(input [3:0] v);
	case (v)
		4'd0:  voltab = 16'd0;     4'd1:  voltab = 16'd128;
		4'd2:  voltab = 16'd207;   4'd3:  voltab = 16'd309;
		4'd4:  voltab = 16'd480;   4'd5:  voltab = 16'd809;
		4'd6:  voltab = 16'd1231;  4'd7:  voltab = 16'd2277;
		4'd8:  voltab = 16'd2586;  4'd9:  voltab = 16'd4469;
		4'd10: voltab = 16'd6170;  4'd11: voltab = 16'd7610;
		4'd12: voltab = 16'd9711;  4'd13: voltab = 16'd11817;
		4'd14: voltab = 16'd14100; 4'd15: voltab = 16'd16383;
	endcase
endfunction

wire [15:0] vol0 = voltab(c_ay[8][4]  ? c_env : c_ay[8][3:0]);
wire [15:0] vol1 = voltab(c_ay[9][4]  ? c_env : c_ay[9][3:0]);
wire [15:0] vol2 = voltab(c_ay[10][4] ? c_env : c_ay[10][3:0]);

assign ula_mode = c_mode;

// ---------------- byte emitter ----------------
//
// The payload is emitted as 8 sections; sec_off counts within the
// current section and includes the 8-byte block envelope.

reg  [17:0] byte_idx;
reg  [2:0]  section;
reg  [16:0] sec_off;
reg  [1:0]  phase;
reg  [2:0]  pack_cnt;
reg         saving;            // claims the spram read mux

assign save_active   = saving;
assign save_ram_addr = sec_off[15:0];   // only consumed in the RAM section

wire [16:0] sec_len = (section == 3'd0) ? 17'd29    :  // "OSN\0" + 21
                      (section == 3'd1) ? 17'd8     :  // "DATA" envelope
                      (section == 3'd2) ? 17'd65536 :  // RAM $0000-$FFFF
                      (section == 3'd3) ? 17'd16384 :  // overlay area, zeros
                      (section == 3'd4) ? 17'd29    :  // "CPU\0" + 21
                      (section == 3'd5) ? 17'd161   :  // "AY\0\0" + 153
                      (section == 3'd6) ? 17'd47    :  // "VIA\0" + 39
                                          17'd10;      // "PAD\0" + 2

reg [7:0] emit_byte;
always @(*) begin
	emit_byte = 8'h00;
	case (section)
		// "OSN\0" size 21: machine config
		3'd0: case (sec_off[4:0])
			5'd0:  emit_byte = 8'h4F;          // 'O'
			5'd1:  emit_byte = 8'h53;          // 'S'
			5'd2:  emit_byte = 8'h4E;          // 'N'
			5'd7:  emit_byte = 8'd21;          // size
			5'd8:  emit_byte = c_type;         // machine type
			5'd12: emit_byte = 8'd1;           // overclock mult = 1 (u32 BE)
			5'd17: emit_byte = 8'h01;          // vsync = 272 (u16 BE)
			5'd18: emit_byte = 8'h10;
			5'd20: emit_byte = 8'd1;           // romon = 1
			5'd24: emit_byte = {5'd0, c_mode}; // vid_mode
			default: ;
		endcase

		// "DATA" envelope, size 81920 = 0x14000 (64K RAM + 16K overlay pad)
		3'd1: case (sec_off[2:0])
			3'd0: emit_byte = 8'h44;           // 'D'
			3'd1: emit_byte = 8'h41;           // 'A'
			3'd2: emit_byte = 8'h54;           // 'T'
			3'd3: emit_byte = 8'h41;           // 'A'
			3'd5: emit_byte = 8'h01;           // size 0x00014000
			3'd6: emit_byte = 8'h40;
			default: ;
		endcase

		3'd2: emit_byte = ram_q;               // RAM image
		3'd3: emit_byte = 8'h00;               // disk-overlay area

		// "CPU\0" size 21
		3'd4: case (sec_off[4:0])
			5'd0:  emit_byte = 8'h43;          // 'C'
			5'd1:  emit_byte = 8'h50;          // 'P'
			5'd2:  emit_byte = 8'h55;          // 'U'
			5'd7:  emit_byte = 8'd21;          // size
			5'd12: emit_byte = c_pc[15:8];     // PC (BE)
			5'd13: emit_byte = c_pc[7:0];
			5'd14: emit_byte = c_pc[15:8];     // lastpc = PC
			5'd15: emit_byte = c_pc[7:0];
			5'd16: emit_byte = c_pc[15:8];     // calcpc = PC
			5'd17: emit_byte = c_pc[7:0];
			5'd21: emit_byte = c_a;
			5'd22: emit_byte = c_x;
			5'd23: emit_byte = c_y;
			5'd24: emit_byte = c_sp;
			5'd25: emit_byte = c_p;            // flags (bit 5 forced 1)
			5'd26: emit_byte = {7'd0, c_via[7]}; // irq pending = IFR bit 7
			default: ;
		endcase

		// "AY\0\0" size 153
		3'd5: begin
			if (sec_off >= 17'd10 && sec_off <= 17'd24)
				emit_byte = c_ay[sec_off - 17'd10];           // eregs[0..14]
			else case (sec_off[7:0])
				8'd0:  emit_byte = 8'h41;       // 'A'
				8'd1:  emit_byte = 8'h59;       // 'Y'
				8'd7:  emit_byte = 8'd153;      // size
				8'd9:  emit_byte = {4'd0, c_creg};
				// derived tone/noise/envelope periods (u32 BE each)
				8'd33: emit_byte = toneper0[31:24];
				8'd34: emit_byte = toneper0[23:16];
				8'd35: emit_byte = toneper0[15:8];
				8'd36: emit_byte = toneper0[7:0];
				8'd37: emit_byte = toneper1[31:24];
				8'd38: emit_byte = toneper1[23:16];
				8'd39: emit_byte = toneper1[15:8];
				8'd40: emit_byte = toneper1[7:0];
				8'd41: emit_byte = toneper2[31:24];
				8'd42: emit_byte = toneper2[23:16];
				8'd43: emit_byte = toneper2[15:8];
				8'd44: emit_byte = toneper2[7:0];
				8'd45: emit_byte = noiseper[31:24];
				8'd46: emit_byte = noiseper[23:16];
				8'd47: emit_byte = noiseper[15:8];
				8'd48: emit_byte = noiseper[7:0];
				8'd49: emit_byte = envper[31:24];
				8'd50: emit_byte = envper[23:16];
				8'd51: emit_byte = envper[15:8];
				8'd52: emit_byte = envper[7:0];
				// per channel i: tonebit[i], noisebit[i], vol[i] (u16 BE each,
				// interleaved — snapshot.c:261-266)
				8'd54: emit_byte = {7'd0, c_ay[7][0]};
				8'd56: emit_byte = {7'd0, c_ay[7][3]};
				8'd57: emit_byte = vol0[15:8];
				8'd58: emit_byte = vol0[7:0];
				8'd60: emit_byte = {7'd0, c_ay[7][1]};
				8'd62: emit_byte = {7'd0, c_ay[7][4]};
				8'd63: emit_byte = vol1[15:8];
				8'd64: emit_byte = vol1[7:0];
				8'd66: emit_byte = {7'd0, c_ay[7][2]};
				8'd68: emit_byte = {7'd0, c_ay[7][5]};
				8'd69: emit_byte = vol2[15:8];
				8'd70: emit_byte = vol2[7:0];
				// dynamic counters/phases (ct, ctn, cte, envpos, LFSR...)
				// intentionally zero — same class our LOAD skips as [v4]
				default: ;
			endcase
		end

		// "VIA\0" size 39
		3'd6: case (sec_off[5:0])
			6'd0:  emit_byte = 8'h56;          // 'V'
			6'd1:  emit_byte = 8'h49;          // 'I'
			6'd2:  emit_byte = 8'h41;          // 'A'
			6'd7:  emit_byte = 8'd39;          // size
			6'd8:  emit_byte = c_via[7:0];     // IFR
			6'd10: emit_byte = c_via[15:8];    // ORB    (IRB=0 at 9)
			6'd13: emit_byte = c_via[23:16];   // ORA    (IRBL/IRA=0)
			6'd15: emit_byte = c_via[31:24];   // DDRA   (IRAL=0 at 14)
			6'd16: emit_byte = c_via[39:32];   // DDRB
			6'd17: emit_byte = c_via[47:40];   // T1L_L
			6'd18: emit_byte = c_via[55:48];   // T1L_H
			6'd19: emit_byte = c_via[71:64];   // T1C hi (BE)
			6'd20: emit_byte = c_via[63:56];   // T1C lo
			6'd21: emit_byte = c_via[79:72];   // T2L_L
			6'd22: emit_byte = c_via[87:80];   // T2L_H
			6'd23: emit_byte = c_via[103:96];  // T2C hi (BE)
			6'd24: emit_byte = c_via[95:88];   // T2C lo
			6'd25: emit_byte = c_via[111:104]; // SR
			6'd26: emit_byte = c_via[119:112]; // ACR
			6'd27: emit_byte = c_via[127:120]; // PCR
			6'd28: emit_byte = {1'b0, c_via[134:128]}; // IER
			// CA1/CA2/CB1/CB2 line states (29-32), srcount, t1/t2reload,
			// srtime: zero — same approximation our LOAD applies
			6'd38: emit_byte = {7'd0, c_via[135]};     // t1run
			6'd39: emit_byte = {7'd0, c_via[136]};     // t2run
			// ca2pulse/cb2pulse/srtrigger (40-42): zero
			6'd46: emit_byte = 8'd1;           // irqbit = IRQF_VIA (u32 BE)
			default: ;
		endcase

		// "PAD\0" size 2: dword alignment as a real block — Oricutron
		// rejects bare trailing bytes but skips unknown tags cleanly.
		3'd7: case (sec_off[3:0])
			4'd0: emit_byte = 8'h50;           // 'P'
			4'd1: emit_byte = 8'h41;           // 'A'
			4'd2: emit_byte = 8'h44;           // 'D'
			4'd7: emit_byte = 8'd2;            // size
			default: ;
		endcase

		default: ;
	endcase
end

// ---------------- load-side counters ----------------

reg [17:0] ld_total;     // payload bytes to copy (size_dw * 4)
reg [17:0] ld_done;      // bytes copied so far
reg [2:0]  ld_sub;       // byte lane within the current 64-bit beat
reg [63:0] ld_beat;

reg [3:0]  ay_idx;
reg [10:0] drain_cnt;

// ---------------- main FSM ----------------

always @(posedge clk_sys) begin
	if (reset) begin
		state        <= S_IDLE;
		save_halt    <= 1'b0;
		saving       <= 1'b0;
		load_active  <= 1'b0;
		ddr_req      <= 1'b0;
		fc_we        <= 1'b0;
		snap_end_we  <= 1'b0;
		loader_start <= 1'b0;
		ss_info_req  <= 1'b0;
		ula_mode_we  <= 1'b0;
	end
	else begin
		ddr_req      <= 1'b0;
		fc_we        <= 1'b0;
		snap_end_we  <= 1'b0;
		loader_start <= 1'b0;
		ss_info_req  <= 1'b0;
		ula_mode_we  <= 1'b0;

		case (state)
			S_IDLE: begin
				save_halt   <= 1'b0;
				saving      <= 1'b0;
				load_active <= 1'b0;
				if (allow && (save_req || load_req)) begin
					slot          <= req_slot;
					slot_base     <= SLOT0_BASE + ({26'd0, req_slot} * SLOT_STRIDE);
					ddr_byte_addr <= SLOT0_BASE + ({26'd0, req_slot} * SLOT_STRIDE);
					ddr_rnw       <= 1'b1;
					ddr_req       <= 1'b1;
					state         <= save_req ? SV_RDHDR_W : LD_RDHDR_W;
				end
			end

			// ---------------- SAVE ----------------

			// header read: pick up the current change counter so the
			// increment is robust against a Main-preloaded .ss file
			SV_RDHDR_W: if (ddr_ready) begin
				counter_old <= ddr_dout[31:0];
				save_halt   <= 1'b1;
				state       <= SV_HALT;
			end

			// wait for the instruction-boundary stall (worst case a few
			// hundred clk_sys cycles — longest 6502 instruction)
			SV_HALT: if (cpu_halted) state <= SV_CAPTURE;

			// one-cycle atomic latch of everything that ticks
			SV_CAPTURE: begin
				c_via  <= via_q;
				c_pc   <= cpu_regs[63:48];
				c_sp   <= cpu_regs[39:32];
				c_p    <= cpu_regs[31:24] | 8'h20;  // bit 5 always set
				c_y    <= cpu_regs[23:16];
				c_x    <= cpu_regs[15:8];
				c_a    <= cpu_regs[7:0];
				c_mode <= ula_mode_q;
				c_type <= osn_type;
				c_creg <= ay_creg_q;
				c_env  <= ay_env_q;
				saving <= 1'b1;                      // claim the spram mux
				ay_idx <= 4'd0;
				ay_rd_addr <= 4'd0;
				phase  <= 2'd0;
				state  <= SV_AYRD;
			end

			// walk AY registers 0..14 (static while the CPU is halted);
			// 3 cycles per register to cover the combinational path
			SV_AYRD: begin
				if (phase != 2'd2) phase <= phase + 2'd1;
				else begin
					c_ay[ay_idx] <= ay_rd_q;
					phase        <= 2'd0;
					if (ay_idx == 4'd14) begin
						byte_idx      <= 18'd0;
						section       <= 3'd0;
						sec_off       <= 17'd0;
						pack_cnt      <= 3'd0;
						ddr_byte_addr <= slot_base + 28'd8;
						ddr_rnw       <= 1'b0;
						state         <= SV_EMIT;
					end
					else begin
						ay_idx     <= ay_idx + 4'd1;
						ay_rd_addr <= ay_idx + 4'd1;
					end
				end
			end

			// emit one payload byte per 3 cycles (covers the registered
			// spram mux + BRAM output: ram_q valid 2 cycles after
			// save_ram_addr) and pack 8 bytes per DDR beat
			SV_EMIT: begin
				if (phase != 2'd2) phase <= phase + 2'd1;
				else begin
					phase <= 2'd0;
					ddr_din[{pack_cnt, 3'b000} +: 8] <= emit_byte;
					pack_cnt <= pack_cnt + 3'd1;
					byte_idx <= byte_idx + 18'd1;
					if (sec_off == sec_len - 17'd1) begin
						sec_off <= 17'd0;
						section <= section + 3'd1;
					end
					else sec_off <= sec_off + 17'd1;
					// flush full beats, and the 4-byte tail at the end
					if (pack_cnt == 3'd7 || byte_idx == TOTAL_BYTES - 18'd1) begin
						ddr_req  <= 1'b1;
						pack_cnt <= 3'd0;
						state    <= SV_WR;
					end
				end
			end

			SV_WR: if (ddr_ready) begin
				ddr_byte_addr <= ddr_byte_addr + 28'd8;
				if (byte_idx == TOTAL_BYTES) begin
					// header last: Main only sees the counter change
					// once the payload is complete
					ddr_byte_addr <= slot_base;
					ddr_din       <= {SIZE_DWORDS, counter_old + 32'd1};
					ddr_req       <= 1'b1;
					state         <= SV_WRHDR_W;
				end
				else state <= SV_EMIT;
			end

			SV_WRHDR_W: if (ddr_ready) begin
				saving    <= 1'b0;        // mux returns to CPU/ULA
				drain_cnt <= 11'd0;
				state     <= SV_DRAIN;
			end

			// keep the CPU stalled while ram_q/cpu_di settle back to
			// mem[PC] — same margin as snap_loader S_DRAIN. Also write
			// the captured video mode back into the ULA: the dump bytes
			// it scanned during the save may have latched a wrong mode.
			SV_DRAIN: begin
				ula_mode_we <= 1'b1;
				drain_cnt <= drain_cnt + 11'd1;
				if (drain_cnt == 11'd1023) begin
					save_halt   <= 1'b0;
					ss_info     <= 8'd1 + {6'd0, slot};   // "Saved state N"
					ss_info_req <= 1'b1;
					state       <= S_IDLE;
				end
			end

			// ---------------- LOAD ----------------

			LD_RDHDR_W: if (ddr_ready) begin
				// dword[1] = payload size in dwords; range check only so
				// converted Oricutron snapshots of any size load too
				if (ddr_dout[63:32] != 32'd0 && ddr_dout[63:32] <= 32'd49152) begin
					ld_total      <= {ddr_dout[47:32], 2'b00};
					load_active   <= 1'b1;
					ld_done       <= 18'd0;
					ddr_byte_addr <= slot_base + 28'd8;
					ddr_req       <= 1'b1;
					state         <= LD_RD_W;
				end
				else begin
					ss_info     <= 8'd9;                  // "Slot is empty"
					ss_info_req <= 1'b1;
					state       <= S_IDLE;
				end
			end

			LD_RD_W: if (ddr_ready) begin
				ld_beat <= ddr_dout;
				ld_sub  <= 3'd0;
				state   <= LD_FC;
			end

			// unpack the beat byte-wise into the filecache (DDR is
			// little-endian: byte j of the file is dout[8j +: 8])
			LD_FC: begin
				fc_addr <= ld_done[17:0];
				fc_data <= ld_beat[{ld_sub, 3'b000} +: 8];
				fc_we   <= 1'b1;
				ld_done <= ld_done + 18'd1;
				if (ld_done == ld_total - 18'd1) state <= LD_FIN;
				else if (ld_sub == 3'd7) begin
					ddr_byte_addr <= ddr_byte_addr + 28'd8;
					ddr_req       <= 1'b1;
					state         <= LD_RD_W;
				end
				else ld_sub <= ld_sub + 3'd1;
			end

			LD_FIN: begin
				load_active  <= 1'b0;
				snap_end_set <= ld_total - 18'd1;
				snap_end_we  <= 1'b1;
				loader_start <= 1'b1;     // snap_loader applies the snapshot
				ss_info      <= 8'd5 + {6'd0, slot};      // "Restored state N"
				ss_info_req  <= 1'b1;
				state        <= S_IDLE;
			end

			default: state <= S_IDLE;
		endcase
	end
end

endmodule
