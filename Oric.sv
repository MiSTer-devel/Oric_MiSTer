//============================================================================
//  Oric-1 and Oric Atmos
//  Copyright (C) rampa
//
//  Port to MiSTer by Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
// DDRAM is used as the MiSTer Main savestate buffer (see snap_ss below)
assign DDRAM_CLK = clk_sys;

assign LED_USER    = ioctl_download | fdd_busy | tape_adc_act | led_user_pokeable;
assign LED_DISK    = led_disk;
assign LED_POWER   = 0;
assign BUTTONS     = 0; 
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S   = 0;
assign AUDIO_MIX = 0;

wire [1:0] ar = status[122:121];
video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),

	.ARX((!ar) ? 12'd4 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd3 : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[16:15])
);

`include "build_id.v"
localparam CONF_STR = {
	"Oric;SS3E000000:200000;",
	"FS1,TAP,Load TAP file;",
	"FS4,SNA,Load Snapshot;",
	"h0T[53],Rewind Tape;",
	"-,F1-F4 Save / F5-F8 Restore State;",
	"-;",
	"h6S0,NIBDSKDO ,Mount Drive A:;",
	"h6S1,NIBDSKDO ,Mount Drive B:;",
	"H6S0,DSK,Mount Drive A:;",
	"H6S1,DSK,Mount Drive B:;",
	"H6S2,DSK,Mount Drive C:;",
	"H6S3,DSK,Mount Drive D:;",
	"H2O[17],Drive A Write Protect,Off,On;",
	"h2-,Drive A is Write Protected;",
	"H3O[18],Drive B Write Protect,Off,On;",
	"h3-,Drive B is Write Protected;",
	"H6H4O[19],Drive C Write Protect,Off,On;",
	"H6h4-,Drive C is Write Protected;",
	"H6H5O[20],Drive D Write Protect,Off,On;",
	"H6h5-,Drive D is Write Protected;",
	"-;",
	"P1,Settings;",
	"P1O[6:5],FDD Controller,Auto,Off,On;",
	"P1FC2,ROM,Load Alternative Bios;",
	"P1-;",
	"P1O[51:50],Tape Audio,Mute,Low,High;",
	"P1O[52],Tape Input,File,ADC;",
	"P1O[59:58],Tape Load,Fast,Ultra,Off;",
	"P1O[57],Autoload TAP,On,Off;",
	"P1O[60],Named CLOAD Rewind,On,Off;",
	"P1-;",
	"P1O[55:54],Joystick Adapter,None,PASE,IJK;",
	"P1-;",
	"P1O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[12:10],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"P1O[16:15],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1O[9:8],Audio,Stereo,ABC (West Europe),ACB (East Europe);",
	"H1O[4:3],ROM,Pravetz 8D,Oric Atmos,Oric 1;",
	"h1O[4:3],ROM,Pravetz 8D,Oric Atmos,Oric 1,Loadable Bios;",
	
	"-;",
	"R0,Reset & Apply;",
	"J,Fire;",
	"I,",
	"Saved state 1,",
	"Saved state 2,",
	"Saved state 3,",
	"Saved state 4,",
	"Restored state 1,",
	"Restored state 2,",
	"Restored state 3,",
	"Restored state 4,",
	"Slot is empty;",
	"V,v",`BUILD_DATE
};

wire [1:0] tapeVolume  = status[51:50];
wire       tapeUseADC = status[52];
wire       tapeRewind = status[53];
wire [1:0] joystick_adapter = status[55:54];
wire       tap_autorun_en   = ~status[57];  // menu shows On (default) / Off
wire [1:0] tape_load_mode   = status[59:58];
wire       tape_mode_fast   = (tape_load_mode == 2'd0);
wire       tape_mode_ultra  = (tape_load_mode == 2'd1);
wire       tape_mode_off    = (tape_load_mode >= 2'd2);
wire       named_cload_rewind_en = ~status[60]; // menu shows On (default) / Off

///////////////////////////////////////////////////

wire locked;
wire clk_sys;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(CLK_VIDEO),
	.outclk_2(),
	.locked(locked)
);

reg        reset = 0;
reg [16:0] clr_addr = 0;
wire       tap_autorun_reset_req;
wire       manual_reset_req = RESET | status[0] | buttons[1];
always @(posedge clk_sys) begin

	if(~&clr_addr) clr_addr <= clr_addr + 1'd1;
	else reset <= 0;

	if(manual_reset_req | tap_autorun_reset_req) begin
		clr_addr <= 0;
		reset <= 1;
	end
	
end

wire tape_clk;
always @(posedge clk_sys) begin
	if (reset)
    	tape_clk <= 1'b0;
	else
    	tape_clk <= ~tape_clk;	
end

///////////////////////////////////////////////////

wire  [10:0] ps2_key;

wire  [15:0] joystick_0;
wire  [15:0] joystick_1;
wire   [1:0] buttons;
wire         forced_scandoubler;
wire [127:0] status;
wire         freeze_sync;

wire  [31:0] sd_lba[4];
wire   [3:0] sd_rd;
wire   [3:0] sd_wr;
wire   [3:0] sd_ack;
wire   [8:0] sd_buff_addr;
wire   [7:0] sd_buff_dout;
wire   [7:0] sd_buff_din[4];
wire         sd_buff_wr;

wire   [3:0] img_mounted;
wire  [31:0] img_size;
wire         img_readonly;

wire         ioctl_wr;
wire  [24:0] ioctl_addr;
wire   [7:0] ioctl_dout;
wire         ioctl_download;
wire   [7:0] ioctl_index;
wire         load_tape = ioctl_index==1;
wire         load_sna  = ioctl_index==4;
reg          ioctl_downlD;

wire         status_set;
wire  [31:0] status_out;

wire  [21:0] gamma_bus;
wire         pravetz_layout;
wire  [15:0] status_mask = {9'd0, pravetz_layout, img_wp, bios_loaded, tape_loaded & ~tapeUseADC & ~cas_relay};

hps_io #(.CONF_STR(CONF_STR), .VDNUM(4)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.ps2_key(ps2_key),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.status(status),
	.status_menumask(status_mask),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_readonly(img_readonly),

	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),

	.info_req(ss_info_req),
	.info(ss_info),

	.gamma_bus(gamma_bus)
);


///////////////////////////////////////////////////

reg    [3:0] img_mountedD;
reg    [3:0] img_wp;

always @(posedge clk_sys)
begin
	img_mountedD <= img_mounted;
	if(~|img_mountedD && |img_mounted) begin
		if(img_mounted[0]) img_wp[0] <= img_readonly & |img_size;
		else if(img_mounted[1]) img_wp[1] <= img_readonly & |img_size;
		else if(img_mounted[2]) img_wp[2] <= img_readonly & |img_size;
		else if(img_mounted[3]) img_wp[3] <= img_readonly & |img_size;
	end
end
///////////////////////////////////////////////////

wire        tap_load_pulse = ioctl_downlD && ~ioctl_download && load_tape;
wire        tap_autorun_active;
wire [10:0] tap_autorun_ps2_key;
wire [10:0] kbd_ps2_key = tap_autorun_active ? tap_autorun_ps2_key : ps2_key;
wire        hps_key_strobe;
wire        tap_autorun_key_strobe;

tap_autorun_keys tap_autorun_keys (
	.clk_sys    (clk_sys),
	.hard_reset (manual_reset_req),
	.start      (tap_load_pulse && tap_autorun_en),
	.oric_reset (reset),
	.pravetz_layout (pravetz_layout),
	.reset_req  (tap_autorun_reset_req),
	.active     (tap_autorun_active),
	.ps2_key    (tap_autorun_ps2_key)
);

reg  tap_start_rewind = 1'b0;
wire tap_start_rewind_ack;
always @(posedge clk_sys) begin
	if (tap_load_pulse || ((manual_reset_req || tap_autorun_reset_req) && tape_loaded))
		tap_start_rewind <= 1'b1;
	else if (tap_start_rewind_ack)
		tap_start_rewind <= 1'b0;
end

wire key_strobe = tap_autorun_active ? tap_autorun_key_strobe : hps_key_strobe;
reg old_keystb = 0;
reg old_tap_autorun_keystb = 0;
always @(posedge clk_sys) begin
	old_keystb <= ps2_key[10];
	old_tap_autorun_keystb <= tap_autorun_ps2_key[10];
end
assign hps_key_strobe = old_keystb ^ ps2_key[10];
assign tap_autorun_key_strobe = old_tap_autorun_keystb ^ tap_autorun_ps2_key[10];


wire  [11:0] psg_a;
wire  [11:0] psg_b;
wire  [11:0] psg_c;
wire  [13:0] psg_out;

wire  [1:0] stereo = status [9:8];

wire        r, g, b; 
wire        hs, vs, HBlank, VBlank;
wire        clk_pix;
wire        tape_in, tape_out;
localparam FILE_CACHE_ADDR_WIDTH = 18;
localparam FILE_CACHE_NUMWORDS   = 196608; // 192 KiB, shared by TAP and SNA loads.
localparam TAP_CACHE_NUMWORDS    = 163840; // 160 KiB TAP limit.
localparam [FILE_CACHE_ADDR_WIDTH-1:0] FILE_CACHE_LAST = FILE_CACHE_NUMWORDS - 1;
localparam [FILE_CACHE_ADDR_WIDTH-1:0] TAP_CACHE_LAST  = TAP_CACHE_NUMWORDS - 1;

wire        tap_byte_consume;
wire        tap_byte_active;
wire [FILE_CACHE_ADDR_WIDTH-1:0] tap_byte_cache_addr;
wire  [7:0] tap_byte_data;

wire        snap_active;
wire [FILE_CACHE_ADDR_WIDTH-1:0] snap_cache_addr;

wire [15:0] ram_ad;
wire [15:0] spram_addr;
wire  [7:0] ram_d;
wire  [7:0] spram_d;
wire        ram_we;
wire        spram_we;
reg   [7:0] ram_q;

always @(posedge clk_sys) begin
	if(reset) begin
		spram_d <= 1;
		spram_addr <= clr_addr[15:0];
		spram_we <= 1'b1;
	end
	else if (snap_active) begin
		spram_d <= snap_ram_data;
		spram_addr <= snap_ram_addr;
		spram_we <= snap_ram_we;
	end
	else if (ss_save_active) begin
		// savestate SAVE: read-only RAM dump (CPU is halted)
		spram_d <= 8'h00;
		spram_addr <= ss_save_ram_addr;
		spram_we <= 1'b0;
	end
	else if (tap_active) begin
		spram_d <= tap_ram_data;
		spram_addr <= tap_ram_addr;
		spram_we <= tap_ram_we;
	end
	else begin
		spram_d <= ram_d;
		spram_addr <= ram_ad;
		spram_we <= ram_we;
	end
end

spram #(.address_width(16)) ram (
  .clock(clk_sys),

  .address(spram_addr),
  .data(spram_d),
  .wren(spram_we),
  .q(ram_q)
);

wire        led_disk;
reg         fdd_busy;

oricatmos oricatmos
(
	.clk_in           (clk_sys),
	.RESET            (reset),
	.key_pressed      (kbd_ps2_key[9]),
	.key_code         (kbd_ps2_key[7:0]),
	.key_extended     (kbd_ps2_key[8]),
	.key_strobe       (key_strobe),
	.pravetz_layout   (pravetz_layout),
	.PSG_OUT_A        (psg_a),
	.PSG_OUT_B        (psg_b),
	.PSG_OUT_C        (psg_c),
	.PSG_OUT          (psg_out),
	.VIDEO_CLK			(clk_pix),
	.VIDEO_R				(r),
	.VIDEO_G				(g),
	.VIDEO_B				(b),
	.VIDEO_HSYNC		(hs),
	.VIDEO_VSYNC		(vs),
	.VIDEO_HBLANK		(HBlank),
	.VIDEO_VBLANK		(VBlank),
	.K7_TAPEIN			(tape_in),
	.K7_TAPEOUT			(tape_out),
	.K7_REMOTE			(cas_relay),
	.ram_ad           (ram_ad),
	.ram_d            (ram_d),
	.ram_q            (ram_q),
	.ram_oe           (),
	.ram_we           (ram_we),
	.joystick_adapter (joystick_adapter),
	.joystick_0       (joystick_0),
	.joystick_1       (joystick_1),
	.fd_led           (led_disk),
	.fdd_ready        (fdd_ready),
	.fdd_busy         (fdd_busy),
	.fdd_reset        (0),
	.fdd_layout       (0),
	.phi2             (),
	.pll_locked       (locked),
	.disk_enable      ((!status[6:5]) ? ~fdd_ready : status[5]),
	.rom              (rom_sel),
	.bios_addr        (bios_addr),
	.bios_din         (bios_din),

	.img_mounted      (img_mounted),
	.img_size         (img_size),

	.img_wp           (status[20:17] | img_wp),
	.sd_lba_fd0       (sd_lba[0]),
	.sd_lba_fd1       (sd_lba[1]),
	.sd_lba_fd2       (sd_lba[2]),
	.sd_lba_fd3       (sd_lba[3]),
	.sd_rd            (sd_rd),
	.sd_wr            (sd_wr),
	.sd_ack           (sd_ack),
	.sd_buff_addr     (sd_buff_addr),
	.sd_dout          (sd_buff_dout),
	.sd_din_fd0       (sd_buff_din[0]),
	.sd_din_fd1       (sd_buff_din[1]),
	.sd_din_fd2       (sd_buff_din[2]),
	.sd_din_fd3       (sd_buff_din[3]),
	.sd_dout_strobe   (sd_buff_wr),
	.sd_din_strobe    (0),
	.cpu_halt         (snap_active | tap_active | tap_byte_active),
	.cpu_regs_set     (cpu_regs_set),
	.cpu_regs_set_we  (cpu_regs_set_we),
	.via_snap_we      (via_snap_we),
	.via_snap_addr    (via_snap_addr),
	.via_snap_data    (via_snap_data),
	.via_snap_t1c_we      (via_snap_t1c_we),
	.via_snap_t1c_data    (via_snap_t1c_data),
	.via_snap_t2c_we      (via_snap_t2c_we),
	.via_snap_t2c_data    (via_snap_t2c_data),
	.via_snap_t_active_we (via_snap_t_active_we),
	.via_snap_t1_active   (via_snap_t1_active),
	.via_snap_t2_active   (via_snap_t2_active),
	.via_snap_ifr_we      (via_snap_ifr_we),
	.via_snap_ifr_data    (via_snap_ifr_data),
	.ay_snap_we       (ay_snap_we),
	.ay_snap_addr     (ay_snap_addr),
	.ay_snap_data     (ay_snap_data),
	.ay_snap_creg_we  (ay_snap_creg_we),
	.ay_snap_creg     (ay_snap_creg),
	// mode write-back is shared by the loader (after restore) and the
	// save engine (after the RAM dump) — never active simultaneously
	.ula_snap_mode_we (ula_snap_mode_we | ss_ula_mode_we),
	.ula_snap_mode    (ula_snap_mode_we ? ula_snap_mode : ss_ula_mode),
	.save_halt        (ss_save_halt),
	.save_halted      (ss_save_halted),
	.cpu_regs_q       (cpu_regs_q),
	.via_snap_q       (via_snap_q),
	.ay_snap_rd_addr  (ay_snap_rd_addr),
	.ay_snap_rd_q     (ay_snap_rd_q),
	.ay_snap_creg_q   (ay_snap_creg_q),
	.ay_snap_env_q    (ay_snap_env_q),
	.ula_snap_mode_q  (ula_snap_mode_q),
	.patch_active     (cload_patch_active),
	.patch_data       (cload_patch_data),
	.c000_we          (c000_we),
	.c000_data        (c000_data),
	.named_cload_we   (named_cload_we),
	.tape_byte_enable (tape_mode_fast),
	.tap_sync_request (tap_sync_request),
	.tap_byte_consume (tap_byte_consume)
);



reg [1:0] rom = 0;
always @(posedge clk_sys) if(reset) rom <= status[4:3];
wire [1:0] rom_sel =
	(rom == 2'd0) ? 2'd2 :
	(rom == 2'd1) ? 2'd0 :
	(rom == 2'd2) ? 2'd1 :
	(bios_loaded ? 2'd3 : 2'd0);
assign pravetz_layout = (rom_sel == 2'd2);

reg fdd_ready = 0;
always @(posedge clk_sys) if(img_mounted) fdd_ready <= |img_size;

///////////////////////////////////////////////////

reg clk_pix2;
always @(posedge clk_sys) clk_pix2 <= clk_pix;

reg ce_pix;
always @(posedge CLK_VIDEO) begin
	reg old_clk;
	
	old_clk <= clk_pix2;
	ce_pix <= ~old_clk & clk_pix2;
end

reg HSync, VSync;
always @(posedge CLK_VIDEO) begin
	if(ce_pix) begin
		HSync <= ~hs;
		if(~HSync & ~hs) VSync <= ~vs;
	end
end

wire [2:0] scale = status[12:10];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = scale || forced_scandoubler;

assign VGA_F1 = 0;
assign VGA_SL = sl[1:0];

video_mixer #(.LINE_LENGTH(250), .HALF_DEPTH(1), .GAMMA(1)) video_mixer
(
	.*,
	.R({4{r}}),
	.G({4{g}}),
	.B({4{b}}),
	.hq2x(scale==1)
);

///////////////////////////////////////////////////
wire        load_alt_bios = ioctl_index==2;
reg         bios_loaded = 1'b0;

wire [15:0] bios_addr;
wire [7:0]  bios_din;

spram #(.address_width(14)) altbios (
  .clock(clk_sys),

  .address((load_alt_bios && ioctl_download) ? ioctl_addr: bios_addr),
  .data(ioctl_dout),
  .wren(ioctl_wr && load_alt_bios),
  .q(bios_din)
);

// Tape live ROM patches. Ultra mode patches CLOAD into the instant
// segment loader. Fast mode patches ROM cassette sync/byte routines
// into the byte streamer. Off mode leaves the ROM untouched.
wire        cload_patch_active;
wire  [7:0] cload_patch_data;
cload_patch_rom cload_patch_rom (
	.ultra_enable(tape_mode_ultra),
	.fast_enable (tape_mode_fast),
	.fast_byte_data(tap_byte_data),
	.rom_addr    (bios_addr[13:0]),
	.patch_active(cload_patch_active),
	.patch_data  (cload_patch_data)
);

///////////////////////////////////////////////////

wire [10:0] tapeAudio;
assign tapeAudio = {|tapeVolume ? (tapeVolume == 2'd1 ? {1'b0,tape_in} : {tape_in,1'b0} ) : 2'b00,9'b00};

wire [15:0] psg_ab = {2'b0,psg_a+psg_b+tapeAudio,1'b0};
wire [15:0] psg_ac = {2'b0,psg_a+psg_c+tapeAudio,1'b0};
wire [15:0] psg_bc = {2'b0,psg_b+psg_c+tapeAudio,1'b0};

assign AUDIO_L = (stereo == 2'b00) ? {1'b0,psg_out+tapeAudio,1'b0} : (stereo == 2'b01) ? psg_ab: psg_ac;
assign AUDIO_R = (stereo == 2'b00) ? {1'b0,psg_out+tapeAudio,1'b0} : (stereo == 2'b01) ? psg_bc: psg_bc;



wire casdout;
wire cas_relay;

reg  [FILE_CACHE_ADDR_WIDTH-1:0] tape_end;
reg         tape_loaded = 1'b0;
reg  [FILE_CACHE_ADDR_WIDTH-1:0] snap_end;

wire [FILE_CACHE_ADDR_WIDTH-1:0] tape_addr;
wire [7:0]  filecache_q;
wire [7:0]  tape_data = filecache_q;
wire [7:0]  snap_cache_q = filecache_q;

wire file_download_active   = ioctl_download && (load_tape || load_sna);
wire file_download_in_range = load_tape ? (ioctl_addr < TAP_CACHE_NUMWORDS) :
                              load_sna  ? (ioctl_addr < FILE_CACHE_NUMWORDS) :
                                          1'b0;
wire [FILE_CACHE_ADDR_WIDTH-1:0] file_download_last =
  load_tape ? TAP_CACHE_LAST : FILE_CACHE_LAST;
wire [FILE_CACHE_ADDR_WIDTH-1:0] file_download_addr =
  file_download_in_range ? ioctl_addr[FILE_CACHE_ADDR_WIDTH-1:0] : file_download_last;

wire [FILE_CACHE_ADDR_WIDTH-1:0] file_selected_addr =
  file_download_active ? file_download_addr :
  ss_load_active       ? ss_fc_addr :
  snap_active          ? snap_cache_addr :
  tap_active           ? tap_cache_addr :
  tap_byte_active      ? tap_byte_cache_addr :
                         tape_addr;
wire [FILE_CACHE_ADDR_WIDTH-1:0] filecache_addr =
  (file_selected_addr > FILE_CACHE_LAST) ? FILE_CACHE_LAST : file_selected_addr;

// Savestate hotkey LOAD DMAs the DDR slot into this cache before
// retriggering snap_loader — same clobber semantics as an OSD .sna load.
wire [7:0] filecache_write_data = ss_load_active ? ss_fc_data : ioctl_dout;
wire       filecache_write_we   = (ioctl_wr && (load_tape || load_sna) && file_download_in_range)
                                | ss_fc_we;

spram #(.address_width(FILE_CACHE_ADDR_WIDTH), .numwords(FILE_CACHE_NUMWORDS)) filecache (
  .clock(clk_sys),

  .address(filecache_addr),
  .data(filecache_write_data),
  .wren(filecache_write_we),
  .q(filecache_q)
);


always @(posedge clk_sys) begin
	if (load_tape && ioctl_download) tape_end <= file_download_addr;
	if (load_sna && ioctl_download) snap_end <= file_download_addr;
	else if (ss_snap_end_we) snap_end <= ss_snap_end_set;
end

always @(posedge clk_sys) begin
	ioctl_downlD <= ioctl_download;
	if(ioctl_downlD && ~ioctl_download && load_tape) tape_loaded <= 1'b1;
	if(ioctl_downlD && ~ioctl_download && load_sna) sna_loaded <= 1'b1;
	if(ioctl_downlD && ~ioctl_download && load_alt_bios) bios_loaded <= 1'b1;
end

cassette cassette (
  .clk(clk_sys),
  .reset(reset),
  .rewind(tapeRewind | (load_tape && ioctl_download)),
  .en(cas_relay && tape_loaded && ~tapeUseADC && tape_mode_off),
  .tape_addr(tape_addr),
  .tape_data(tape_data),

  .tape_end(tape_end),
  .data(casdout)
);

// ---- Multi-stage TAP segment loader (rtl/tap_segment_loader.v) ----
// Triggered by the patched BASIC CLOAD doing `LDA #$01 / STA $C000`.
// Pulls one segment per trigger from the shared file cache into RAM, populates
// the BASIC-state side effects (start/end pointers, autorun, type,
// TXTTAB/TXTEND), then releases CPU. Status-row paint at $BB80 is
// left to the ROM ($E651) so HIRES programs that use that area as
// their own data aren't disturbed. Lets multi-segment .tap files
// load in stages so inter-segment BASIC code runs between calls.
wire        tap_active;
wire [15:0] tap_ram_addr;
wire  [7:0] tap_ram_data;
wire        tap_ram_we;
wire [FILE_CACHE_ADDR_WIDTH-1:0] tap_cache_addr;
tap_segment_loader tap_seg (
	.clk_sys        (clk_sys),
	.reset          (reset),
	.trigger        (c000_we && c000_data == 8'd1 && tape_mode_ultra && tape_loaded),
	.tape_load_pulse(tap_load_pulse),
	.tape_end       (tape_end),
	.tape_data      (tape_data),
	.cache_addr     (tap_cache_addr),
	.active         (tap_active),
	.ram_addr       (tap_ram_addr),
	.ram_data       (tap_ram_data),
	.ram_we         (tap_ram_we)
);

// ---- Fast TAP byte streamer (rtl/tap_byte_streamer.v) ----
// Used by Tape Load = Fast. The patched ROM GETTAPEBYTE routine
// embeds tap_byte_data as an immediate operand; each operand fetch
// consumes one byte and prefetches the next one.
wire named_cload_rewind = named_cload_we && tape_mode_fast &&
                          tape_loaded && named_cload_rewind_en;
tap_byte_streamer tap_byte_streamer (
	.clk_sys        (clk_sys),
	.reset          (reset),
	.consume        (tap_byte_consume && tape_mode_fast && tape_loaded),
	.sync_request   (tap_sync_request && tape_mode_fast && tape_loaded),
	.named_rewind   (named_cload_rewind),
	.start_rewind   (tap_start_rewind && tape_mode_fast && tape_loaded),
	.tape_load_pulse(tap_load_pulse),
	.rewind         (tapeRewind),
	.tape_end       (tape_end),
	.tape_data      (tape_data),
	.cache_addr     (tap_byte_cache_addr),
	.active         (tap_byte_active),
	.start_rewind_ack(tap_start_rewind_ack),
	.byte_data      (tap_byte_data)
);

// Host LED mailbox: oricatmos.vhd snoops CPU writes to $C000 and
// emits c000_we (1-cycle strobe) + c000_data (the byte being
// written). led_user_pokeable latches the bit: data==1 sets,
// data==0 clears, anything else holds. Driven into the MiSTer USER
// LED below (OR'd with the existing activity sources).
wire        c000_we;
wire  [7:0] c000_data;
wire        named_cload_we;
wire        tap_sync_request;
reg         led_user_pokeable = 1'b0;
always @(posedge clk_sys) begin
	if (reset) led_user_pokeable <= 1'b0;
	else if (c000_we) begin
		if (c000_data == 8'd1) led_user_pokeable <= 1'b1;
		else if (c000_data == 8'd0) led_user_pokeable <= 1'b0;
	end
end

// ---- Snapshot LOAD .sna (rtl/snap_loader.v) ----
// Block format and field-level mapping in docs/sna_support.md.
// The shared filecache spram is owned by this top level; snap_loader
// reads it while applying RAM/CPU/AY/VIA restore outputs.
wire [15:0] snap_ram_addr;
wire  [7:0] snap_ram_data;
wire        snap_ram_we;
wire [63:0] cpu_regs_set;
wire        cpu_regs_set_we;
wire        via_snap_we;
wire  [3:0] via_snap_addr;
wire  [7:0] via_snap_data;
wire        via_snap_t1c_we;
wire [15:0] via_snap_t1c_data;
wire        via_snap_t2c_we;
wire [15:0] via_snap_t2c_data;
wire        via_snap_t_active_we;
wire        via_snap_t1_active;
wire        via_snap_t2_active;
wire        via_snap_ifr_we;
wire  [6:0] via_snap_ifr_data;
wire        ay_snap_we;
wire  [3:0] ay_snap_addr;
wire  [7:0] ay_snap_data;
wire        ay_snap_creg_we;
wire  [3:0] ay_snap_creg;
wire        ula_snap_mode_we;
wire  [2:0] ula_snap_mode;

snap_loader snap_loader (
	.clk_sys         (clk_sys),
	.reset           (reset),
	.ioctl_download  (ioctl_download),
	.ioctl_downlD    (ioctl_downlD),
	.load_sna        (load_sna),
	.start           (ss_loader_start),
	.snap_end        (snap_end),
	.snap_cache_addr (snap_cache_addr),
	.snap_cache_q    (snap_cache_q),
	.active          (snap_active),
	.ram_addr        (snap_ram_addr),
	.ram_data        (snap_ram_data),
	.ram_we          (snap_ram_we),
	.cpu_regs_set    (cpu_regs_set),
	.cpu_regs_set_we (cpu_regs_set_we),
	.via_snap_we     (via_snap_we),
	.via_snap_addr   (via_snap_addr),
	.via_snap_data   (via_snap_data),
	.via_snap_t1c_we      (via_snap_t1c_we),
	.via_snap_t1c_data    (via_snap_t1c_data),
	.via_snap_t2c_we      (via_snap_t2c_we),
	.via_snap_t2c_data    (via_snap_t2c_data),
	.via_snap_t_active_we (via_snap_t_active_we),
	.via_snap_t1_active   (via_snap_t1_active),
	.via_snap_t2_active   (via_snap_t2_active),
	.via_snap_ifr_we      (via_snap_ifr_we),
	.via_snap_ifr_data    (via_snap_ifr_data),
	.ay_snap_we      (ay_snap_we),
	.ay_snap_addr    (ay_snap_addr),
	.ay_snap_data    (ay_snap_data),
	.ay_snap_creg_we (ay_snap_creg_we),
	.ay_snap_creg    (ay_snap_creg),
	.ula_snap_mode_we (ula_snap_mode_we),
	.ula_snap_mode   (ula_snap_mode)
);

// ---- Savestates (rtl/snap_ss.v, docs/sna_support.md) ----
// F1-F4 save to / F5-F8 restore from MiSTer Main savestate slots
// (conf_str "SS3E000000:200000"; Main writes/reads
// savestates/Oric/<game>_<slot>.ss). SAVE halts the CPU at an
// instruction boundary and streams an Oricutron-format snapshot into
// DDR; LOAD copies the slot into the filecache and reruns snap_loader.
reg          sna_loaded = 1'b0;
wire         allow_ss = (tape_loaded | sna_loaded | fdd_ready)
                      & ~ioctl_download & ~reset
                      & ~snap_active & ~tap_active & ~tap_byte_active;

wire         ss_save_key, ss_load_key;
wire   [1:0] ss_slot;
wire         ss_save_halt, ss_save_halted;
wire  [63:0] cpu_regs_q;
wire [136:0] via_snap_q;
wire   [3:0] ay_snap_rd_addr;
wire   [7:0] ay_snap_rd_q;
wire   [3:0] ay_snap_creg_q;
wire   [3:0] ay_snap_env_q;
wire   [2:0] ula_snap_mode_q;
wire         ss_save_active;
wire  [15:0] ss_save_ram_addr;
wire         ss_load_active;
wire  [17:0] ss_fc_addr;
wire   [7:0] ss_fc_data;
wire         ss_fc_we;
wire  [17:0] ss_snap_end_set;
wire         ss_snap_end_we;
wire         ss_loader_start;
wire  [27:1] ss_ddr_addr;
wire  [63:0] ss_ddr_din, ss_ddr_dout;
wire         ss_ddr_req, ss_ddr_rnw, ss_ddr_ready;
wire   [7:0] ss_ddr_be;
wire   [7:0] ss_info;
wire         ss_info_req;
wire         ss_ula_mode_we;
wire   [2:0] ss_ula_mode;

savestate_hotkeys savestate_hotkeys (
	.clk     (clk_sys),
	.ps2_key (ps2_key),
	.allow   (allow_ss),
	.ss_save (ss_save_key),
	.ss_load (ss_load_key),
	.ss_slot (ss_slot)
);

snap_ss snap_ss (
	.clk_sys       (clk_sys),
	.reset         (reset),
	.save_req      (ss_save_key),
	.load_req      (ss_load_key),
	.req_slot      (ss_slot),
	.allow         (allow_ss),
	.save_halt     (ss_save_halt),
	.cpu_halted    (ss_save_halted),
	.cpu_regs      (cpu_regs_q),
	.via_q         (via_snap_q),
	.ay_rd_addr    (ay_snap_rd_addr),
	.ay_rd_q       (ay_snap_rd_q),
	.ay_creg_q     (ay_snap_creg_q),
	.ay_env_q      (ay_snap_env_q),
	.ula_mode_q    (ula_snap_mode_q),
	.rom_sel_q     (rom_sel),
	.ula_mode_we   (ss_ula_mode_we),
	.ula_mode      (ss_ula_mode),
	.save_active   (ss_save_active),
	.save_ram_addr (ss_save_ram_addr),
	.ram_q         (ram_q),
	.load_active   (ss_load_active),
	.fc_addr       (ss_fc_addr),
	.fc_data       (ss_fc_data),
	.fc_we         (ss_fc_we),
	.snap_end_set  (ss_snap_end_set),
	.snap_end_we   (ss_snap_end_we),
	.loader_start  (ss_loader_start),
	.ddr_addr      (ss_ddr_addr),
	.ddr_din       (ss_ddr_din),
	.ddr_dout      (ss_ddr_dout),
	.ddr_req       (ss_ddr_req),
	.ddr_rnw       (ss_ddr_rnw),
	.ddr_be        (ss_ddr_be),
	.ddr_ready     (ss_ddr_ready),
	.ss_info       (ss_info),
	.ss_info_req   (ss_info_req)
);

ddram ddram (
	.DDRAM_CLK        (clk_sys),
	.DDRAM_BUSY       (DDRAM_BUSY),
	.DDRAM_BURSTCNT   (DDRAM_BURSTCNT),
	.DDRAM_ADDR       (DDRAM_ADDR),
	.DDRAM_DOUT       (DDRAM_DOUT),
	.DDRAM_DOUT_READY (DDRAM_DOUT_READY),
	.DDRAM_RD         (DDRAM_RD),
	.DDRAM_DIN        (DDRAM_DIN),
	.DDRAM_BE         (DDRAM_BE),
	.DDRAM_WE         (DDRAM_WE),

	.ch1_addr         (ss_ddr_addr),
	.ch1_dout         (ss_ddr_dout),
	.ch1_din          (ss_ddr_din),
	.ch1_req          (ss_ddr_req),
	.ch1_rnw          (ss_ddr_rnw),
	.ch1_be           (ss_ddr_be),
	.ch1_ready        (ss_ddr_ready)
);

///////////////////////////////////////////////////
wire tape_adc, tape_adc_act;
ltc2308_tape ltc2308_tape
(
	.clk(CLK_50M),
	.ADC_BUS(ADC_BUS),
	.dout(tape_adc),
	.active(tape_adc_act)
);

assign tape_in = tapeUseADC ? tape_adc : casdout;

endmodule
