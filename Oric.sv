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
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0; 
 
assign LED_USER    = ioctl_download | fdd_busy | tape_adc_act;
assign LED_DISK    = led_disk;
assign LED_POWER   = 0;
assign BUTTONS     = 0; 
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

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
	"Oric;;",
	"F1,TAP,Load TAP file;",	
	"h0T[53],Rewind Tape;",
	"-;",
	"S0,DSK,Mount Drive A:;",
	"S1,DSK,Mount Drive B:;",
	"S2,DSK,Mount Drive C:;",
	"S3,DSK,Mount Drive D:;",
	"H2O[17],Drive A Write Protect,Off,On;",
	"h2-,Drive A is Write Protected;",
	"H3O[18],Drive B Write Protect,Off,On;",
	"h3-,Drive B is Write Protected;",
	"H4O[19],Drive C Write Protect,Off,On;",
	"h4-,Drive C is Write Protected;",
	"H5O[20],Drive D Write Protect,Off,On;",
	"h5-,Drive D is Write Protected;",
	"-;",
	"P1,Settings;",
	"P1O[6:5],FDD Controller,Auto,Off,On;",
	"P1FC2,ROM,Load Alternative Bios;",
	"P1-;",
	"P1O[51:50],Tape Audio,Mute,Low,High;",
	"P1O[52],Tape Input,File,ADC;",
	"P1-;",
	"P1O[55:54],Joystick Adapter,None,PASE,IJK;",
	"P1-;",
	"P1O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[12:10],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"P1O[16:15],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1O[9:8],Audio,Stereo,ABC (West Europe),ACB (East Europe);",
	"H1O[4:3],ROM,Oric Atmos,Oric 1;",
	"h1O[4:3],ROM,Oric Atmos,Oric 1,Loadable Bios;",
	
	"-;",
	"R0,Reset & Apply;",
	"J,Fire;",
	"V,v",`BUILD_DATE
};

wire [1:0] tapeVolume  = status[51:50];
wire       tapeUseADC = status[52];
wire       tapeRewind = status[53];
wire [1:0] joystick_adapter = status[55:54];

///////////////////////////////////////////////////

wire locked;
wire clk_sys;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(CLK_VIDEO),
	.locked(locked)
);

reg        reset = 0;
reg [16:0] clr_addr = 0;
always @(posedge clk_sys) begin

	if(~&clr_addr) clr_addr <= clr_addr + 1'd1;
	else reset <= 0;

	if(RESET | status[0] | buttons[1]) begin
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

wire         status_set;
wire  [31:0] status_out;

wire  [21:0] gamma_bus;
wire  [15:0] status_mask = {10'd0, img_wp, bios_loaded, tape_loaded & ~tapeUseADC & ~cas_relay};

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

wire key_strobe = old_keystb ^ ps2_key[10];
reg old_keystb = 0;
always @(posedge clk_sys) old_keystb <= ps2_key[10];


wire  [11:0] psg_a;
wire  [11:0] psg_b;
wire  [11:0] psg_c;
wire  [13:0] psg_out;

wire  [1:0] stereo = status [9:8];

wire        r, g, b; 
wire        hs, vs, HBlank, VBlank;
wire        clk_pix;
wire        tape_in, tape_out;

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
	.key_pressed      (ps2_key[9]),
	.key_code         (ps2_key[7:0]),
	.key_extended     (ps2_key[8]),
	.key_strobe       (key_strobe),
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
	.rom              ({rom[1] & bios_loaded, rom[0]}),
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
	.sd_din_strobe    (0)
);



reg [1:0] rom = 0;
always @(posedge clk_sys) if(reset) rom <= status[4:3];

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

wire        load_tape = ioctl_index==1;
reg  [15:0] tape_end;
reg         tape_loaded = 1'b0;
reg         ioctl_downlD;

wire [15:0] tape_addr;
wire [7:0]  tape_data;

spram #(.address_width(16)) tapecache (
  .clock(clk_sys),

  .address((ioctl_index == 1 && ioctl_download) ? ioctl_addr: tape_addr),
  .data(ioctl_dout),
  .wren(ioctl_wr && load_tape),
  .q(tape_data)
);


always @(posedge clk_sys) begin
 if (load_tape) tape_end <= ioctl_addr[15:0];
end

always @(posedge clk_sys) begin
	ioctl_downlD <= ioctl_download;
	if(ioctl_downlD && ~ioctl_download && load_tape) tape_loaded <= 1'b1;
	if(ioctl_downlD && ~ioctl_download && load_alt_bios) bios_loaded <= 1'b1;
end

cassette cassette (
  .clk(clk_sys),
  .reset(reset),
  .rewind(tapeRewind | (load_tape && ioctl_download)),
  .en(cas_relay && tape_loaded && ~tapeUseADC), 
  .tape_addr(tape_addr),
  .tape_data(tape_data),

  .tape_end(tape_end),
  .data(casdout)
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
