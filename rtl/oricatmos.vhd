--
-- A simulation model of ORIC ATMOS hardware
-- Copyright (c) SEILEBOST - March 2006
-- 
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
-- The latest version of this file can be found at: passionoric.free.fr
--
-- Email seilebost@free.fr
--
--

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.all;
ENTITY oricatmos IS
	PORT (
		CLK_IN : IN STD_LOGIC;
		RESET : IN STD_LOGIC;
		key_pressed : IN STD_LOGIC;
		key_extended : IN STD_LOGIC;
		key_code : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		key_strobe : IN STD_LOGIC;
		pravetz_layout : IN STD_LOGIC := '0';
		K7_TAPEIN : IN STD_LOGIC;
		K7_TAPEOUT : OUT STD_LOGIC;
		K7_REMOTE : OUT STD_LOGIC;

		PSG_OUT_A : OUT UNSIGNED(11 DOWNTO 0);
		PSG_OUT_B : OUT UNSIGNED(11 DOWNTO 0);
		PSG_OUT_C : OUT UNSIGNED(11 DOWNTO 0);
      PSG_OUT   : OUT UNSIGNED(13 DOWNTO 0);
		
		VIDEO_CLK : OUT STD_LOGIC;
		VIDEO_R : OUT STD_LOGIC;
		VIDEO_G : OUT STD_LOGIC;
		VIDEO_B : OUT STD_LOGIC;
		VIDEO_HBLANK : OUT STD_LOGIC;
		VIDEO_VBLANK : OUT STD_LOGIC;
		VIDEO_HSYNC : OUT STD_LOGIC;
		VIDEO_VSYNC : OUT STD_LOGIC;
		VIDEO_SYNC : OUT STD_LOGIC;
		ram_ad : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		ram_d : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		ram_q : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		ram_cs : OUT STD_LOGIC;
		ram_oe : OUT STD_LOGIC;
		ram_we : OUT STD_LOGIC;
		phi2 : OUT STD_LOGIC;
		fd_led : OUT STD_LOGIC;
		fdd_ready : IN STD_LOGIC;
		fdd_busy : OUT STD_LOGIC;
		fdd_reset : IN STD_LOGIC;
		fdd_layout : IN STD_LOGIC;
		joystick_adapter : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		joystick_0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		joystick_1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		pll_locked : IN STD_LOGIC;
		disk_enable : IN STD_LOGIC;
		rom : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		bios_addr : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
		bios_din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);

		img_mounted : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		img_wp : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		img_size : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		sd_lba_fd0 : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		sd_lba_fd1 : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		sd_lba_fd2 : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		sd_lba_fd3 : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		sd_rd : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
		sd_wr : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
		sd_ack : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		sd_buff_addr : IN STD_LOGIC_VECTOR (8 DOWNTO 0);
		sd_dout : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		sd_din_fd0 : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		sd_din_fd1 : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		sd_din_fd2 : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		sd_din_fd3 : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		sd_dout_strobe : IN STD_LOGIC;
		sd_din_strobe : IN STD_LOGIC;
		cpu_halt : IN STD_LOGIC;
		cpu_regs_set    : IN STD_LOGIC_VECTOR(63 DOWNTO 0) := (OTHERS => '0');
		cpu_regs_set_we : IN STD_LOGIC := '0';
		via_snap_we     : IN STD_LOGIC := '0';
		via_snap_addr   : IN STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
		via_snap_data   : IN STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
		via_snap_t1c_we      : IN STD_LOGIC := '0';
		via_snap_t1c_data    : IN STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
		via_snap_t2c_we      : IN STD_LOGIC := '0';
		via_snap_t2c_data    : IN STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
		via_snap_t_active_we : IN STD_LOGIC := '0';
		via_snap_t1_active   : IN STD_LOGIC := '0';
		via_snap_t2_active   : IN STD_LOGIC := '0';
		via_snap_ifr_we      : IN STD_LOGIC := '0';
		via_snap_ifr_data    : IN STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0');
		ay_snap_we      : IN STD_LOGIC := '0';
		ay_snap_addr    : IN STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
		ay_snap_data    : IN STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
		ay_snap_creg_we : IN STD_LOGIC := '0';
		ay_snap_creg    : IN STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
		ula_snap_mode_we : IN STD_LOGIC := '0';
		ula_snap_mode   : IN STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');

		-- Snapshot SAVE support (consumed by Oric.sv snap_ss engine):
		-- save_halt requests a CPU stall at the next instruction
		-- boundary (T65 Sync); save_halted confirms it. The readout
		-- ports expose live CPU/VIA/AY/ULA state for capture.
		save_halt       : IN  STD_LOGIC := '0';
		save_halted     : OUT STD_LOGIC;
		cpu_regs_q      : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
		via_snap_q      : OUT STD_LOGIC_VECTOR(136 DOWNTO 0);
		ay_snap_rd_addr : IN  STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
		ay_snap_rd_q    : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		ay_snap_creg_q  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
		ay_snap_env_q   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
		ula_snap_mode_q : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);

		-- Tape-load live ROM patch: when patch_active='1', the CPU
		-- reads patch_data instead of the selected ROM source.
		patch_active    : IN  STD_LOGIC := '0';
		patch_data      : IN  STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');

		-- Host LED mailbox snoop: c000_we pulses when the CPU writes
		-- to $C000; c000_data carries the byte being written. Driven
		-- to the MiSTer USER LED in Oric.sv.
		c000_we         : OUT STD_LOGIC;
		c000_data       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

		-- CLOAD filename snoop: pulses when the ROM argument parser
		-- writes the first non-zero requested filename byte to $027F.
		named_cload_we  : OUT STD_LOGIC;

		-- Fast TAP byte streamer. The patched GETTAPEBYTE routine
		-- embeds the current TAP byte as an immediate operand at
		-- $E6CE; this strobe advances the prefetcher after that byte
		-- has been fetched. The patched SYNCTAPE entry at $E735
		-- notifies the streamer before the ROM starts raw byte reads.
		tape_byte_enable : IN  STD_LOGIC := '0';
		tap_sync_request : OUT STD_LOGIC;
		tap_byte_consume : OUT STD_LOGIC
	);
END;

ARCHITECTURE RTL OF oricatmos IS

	-- Gestion des resets
	SIGNAL RESETn : STD_LOGIC;
	SIGNAL reset_dll_h : STD_LOGIC;
	SIGNAL delay_count : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL clk_cnt : STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";

	-- cpu
	SIGNAL cpu_ad : STD_LOGIC_VECTOR(23 DOWNTO 0);
	SIGNAL cpu_di : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL cpu_do : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL cpu_rw : STD_LOGIC;
	SIGNAL cpu_irq : STD_LOGIC;

	-- VIA
	SIGNAL via_pa_out_oe : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL via_pa_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL via_pa_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL via_pa_in_from_psg : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL via_cb1_out : STD_LOGIC;
	SIGNAL via_cb1_oe_l : STD_LOGIC;
	SIGNAL via_cb2_out : STD_LOGIC;
	SIGNAL via_cb2_oe_l : STD_LOGIC;
	SIGNAL via_pb_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL via_pb_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL via_pb_oe_l : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL VIA_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);
	-- Clavier : émulation par port PS2
	SIGNAL KEY_ROW : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL kbd_int : STD_LOGIC;
	SIGNAL KEYB_RESETn : STD_LOGIC;
	SIGNAL KEYB_NMIn : STD_LOGIC;

	-- Joystick
	SIGNAL via_pa_joy_value : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL via_pa_joy_mask : STD_LOGIC_VECTOR(7 DOWNTO 0);
	
	-- PSG
	SIGNAL psg_bdir : STD_LOGIC;
	SIGNAL psg_bc1 : STD_LOGIC;
	SIGNAL psg_ioa_out : STD_LOGIC_VECTOR (7 DOWNTO 0);
	SIGNAL psg_iob_out : STD_LOGIC_VECTOR (7 DOWNTO 0);
	SIGNAL psg_sample_ok : STD_LOGIC;
	-- ULA    
	SIGNAL ula_phi2 : STD_LOGIC;
	SIGNAL ula_CSIOn : STD_LOGIC;
	SIGNAL ula_CSROMn : STD_LOGIC;
	SIGNAL ula_CSRAMn : STD_LOGIC;
	SIGNAL ula_AD_SRAM : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL ula_CE_SRAM : STD_LOGIC;
	SIGNAL ula_OE_SRAM : STD_LOGIC;
	SIGNAL ula_WE_SRAM : STD_LOGIC;
	SIGNAL ula_LATCH_SRAM : STD_LOGIC;
	SIGNAL ula_CLK_4 : STD_LOGIC;
	SIGNAL ula_CLK_4_en : STD_LOGIC;
	SIGNAL ula_MUX : STD_LOGIC;
	SIGNAL ula_RW_RAM : STD_LOGIC;
	SIGNAL ula_VIDEO_R : STD_LOGIC;
	SIGNAL ula_VIDEO_G : STD_LOGIC;
	SIGNAL ula_VIDEO_B : STD_LOGIC;
	--	 signal lSRAM_D            : std_logic_vector(7 downto 0);
	SIGNAL ENA_1MHZ : STD_LOGIC;
	SIGNAL ROM_ATMOS_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ROM_1_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ROM_PRAVETZ_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ROM_MD_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ROM_PRAVETZ_BANK_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);

	--- Printer port
	SIGNAL PRN_STROBE : STD_LOGIC;
	SIGNAL PRN_DATA : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL SRAM_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);

	SIGNAL swnmi : STD_LOGIC;
	SIGNAL swrst : STD_LOGIC;

	-- Snapshot SAVE: instruction-boundary CPU stall
	SIGNAL cpu_sync : STD_LOGIC;
	SIGNAL save_halted_i : STD_LOGIC := '0';

	-- Disk controller
	SIGNAL cont_MAPn : STD_LOGIC := '1';
	SIGNAL cont_ROMDISn : STD_LOGIC := '1';
	SIGNAL cont_IOCONTROLn : STD_LOGIC := '1';
	SIGNAL cont_ECE : STD_LOGIC;
	SIGNAL cont_RESETn : STD_LOGIC;
	SIGNAL cont_nOE : STD_LOGIC;
	SIGNAL cont_irq : STD_LOGIC;
	SIGNAL md_MAPn : STD_LOGIC := '1';
	SIGNAL md_ROMDISn : STD_LOGIC := '1';
	SIGNAL md_IOCONTROLn : STD_LOGIC := '1';
	SIGNAL md_ECE : STD_LOGIC := '1';
	SIGNAL md_RESETn : STD_LOGIC := '1';
	SIGNAL md_nOE : STD_LOGIC := '1';
	SIGNAL md_irq : STD_LOGIC := '1';
	SIGNAL md_D_OUT : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL md_sd_lba_fd0 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL md_sd_lba_fd1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL md_sd_lba_fd2 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL md_sd_lba_fd3 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL md_sd_rd : STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL md_sd_wr : STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL md_sd_din_fd0 : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL md_sd_din_fd1 : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL md_sd_din_fd2 : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL md_sd_din_fd3 : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL md_fdd_busy : STD_LOGIC;
	SIGNAL md_fd_led : STD_LOGIC;
	SIGNAL pravetz_mode : STD_LOGIC;
	SIGNAL pravetz_bank : STD_LOGIC := '0';
	SIGNAL pravetz_shadow : STD_LOGIC := '0';
	SIGNAL pravetz_extension_window : STD_LOGIC;
	SIGNAL pravetz_bank_window : STD_LOGIC;
	SIGNAL pravetz_fdc_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL pravetz_fdc_select : STD_LOGIC;
	SIGNAL pravetz_sd_lba_fd0 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL pravetz_sd_lba_fd1 : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL pravetz_sd_rd : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL pravetz_sd_wr : STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL pravetz_sd_din_fd0 : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL pravetz_sd_din_fd1 : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL pravetz_fdd_busy : STD_LOGIC;
	SIGNAL pravetz_fd_led : STD_LOGIC;


	-- Controller derived clocks
	SIGNAL PH2_1 : STD_LOGIC;
	SIGNAL PH2_2 : STD_LOGIC;
	SIGNAL PH2_3 : STD_LOGIC;
	SIGNAL PH2_old : STD_LOGIC_VECTOR(3 DOWNTO 0);
	SIGNAL PH2_cntr : STD_LOGIC_VECTOR(4 DOWNTO 0);

	COMPONENT keyboard
		PORT (
			clk_sys : IN STD_LOGIC;
			reset : IN STD_LOGIC;
			key_pressed : IN STD_LOGIC;
			key_extended : IN STD_LOGIC;
			key_strobe : IN STD_LOGIC;
			key_code : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			pravetz_layout : IN STD_LOGIC;
			col : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			row_mask : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			kbd_int : OUT STD_LOGIC;
			swnmi : OUT STD_LOGIC;
			swrst : OUT STD_LOGIC
		);
	END COMPONENT;

	COMPONENT joystick
		PORT (
			clk_sys : IN STD_LOGIC;
			joystick_0 : STD_LOGIC_VECTOR(7 DOWNTO 0);
			joystick_1 : STD_LOGIC_VECTOR(7 DOWNTO 0);
			adapter : STD_LOGIC_VECTOR(1 DOWNTO 0);
			via_strobe : IN STD_LOGIC;
			via_pa_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			joy_value : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			joy_mask : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
		);
	END COMPONENT;

COMPONENT psg
 PORT (
			clock : IN STD_LOGIC;
			ce    : IN STD_LOGIC;
			reset : IN STD_LOGIC;
			bdir : IN STD_LOGIC;
			bc1 : IN STD_LOGIC;
			sel : IN STD_LOGIC;
			d   : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			q   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

			ioad : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	      ioaq : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			iobd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			iobq : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

			MIX : OUT UNSIGNED (13 DOWNTO 0);
			A   : OUT UNSIGNED (11 DOWNTO 0);
			B   : OUT UNSIGNED(11 DOWNTO 0);
			C   : OUT UNSIGNED(11 DOWNTO 0);
			snap_we      : IN STD_LOGIC;
			snap_addr    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			snap_data    : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			snap_creg_we : IN STD_LOGIC;
			snap_creg    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			snap_rd_addr : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
			snap_rd_q    : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			snap_creg_q  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
			snap_env_q   : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
);
END COMPONENT;


BEGIN

	RESETn <= (NOT RESET AND KEYB_RESETn);
	pravetz_mode <= '1' WHEN rom = "10" ELSE '0';
	pravetz_extension_window <= '1' WHEN pravetz_mode = '1'
	                                  AND cpu_ad(15 DOWNTO 8) = X"03"
	                                  AND unsigned(cpu_ad(7 DOWNTO 0)) >= TO_UNSIGNED(16#10#, 8)
	                             ELSE '0';
	pravetz_bank_window <= '1' WHEN pravetz_mode = '1'
	                         AND cpu_ad(15 DOWNTO 8) = X"03"
	                         AND unsigned(cpu_ad(7 DOWNTO 0)) >= TO_UNSIGNED(16#20#, 8)
	                    ELSE '0';

	cont_MAPn <= '0' WHEN pravetz_mode = '1'
	                      AND pravetz_shadow = '1'
	                      AND cpu_ad(15 DOWNTO 14) = "11" ELSE
	             '1' WHEN pravetz_mode = '1' ELSE
	             md_MAPn;
	cont_ROMDISn <= '0' WHEN pravetz_mode = '1' AND pravetz_shadow = '1' ELSE
	                '1' WHEN pravetz_mode = '1' ELSE
	                md_ROMDISn;
	cont_IOCONTROLn <= '0' WHEN pravetz_extension_window = '1' ELSE
	                   '1' WHEN pravetz_mode = '1' ELSE
	                   md_IOCONTROLn;
	cont_ECE <= '1' WHEN pravetz_mode = '1' ELSE md_ECE;
	cont_RESETn <= md_RESETn;
	cont_nOE <= '1' WHEN pravetz_mode = '1' ELSE md_nOE;
	cont_irq <= '1' WHEN pravetz_mode = '1' ELSE md_irq;
	sd_lba_fd0 <= pravetz_sd_lba_fd0 WHEN pravetz_mode = '1' ELSE md_sd_lba_fd0;
	sd_lba_fd1 <= pravetz_sd_lba_fd1 WHEN pravetz_mode = '1' ELSE md_sd_lba_fd1;
	sd_lba_fd2 <= (OTHERS => '0') WHEN pravetz_mode = '1' ELSE md_sd_lba_fd2;
	sd_lba_fd3 <= (OTHERS => '0') WHEN pravetz_mode = '1' ELSE md_sd_lba_fd3;
	sd_rd <= "00" & pravetz_sd_rd WHEN pravetz_mode = '1' ELSE md_sd_rd;
	sd_wr <= "00" & pravetz_sd_wr WHEN pravetz_mode = '1' ELSE md_sd_wr;
	sd_din_fd0 <= pravetz_sd_din_fd0 WHEN pravetz_mode = '1' ELSE md_sd_din_fd0;
	sd_din_fd1 <= pravetz_sd_din_fd1 WHEN pravetz_mode = '1' ELSE md_sd_din_fd1;
	sd_din_fd2 <= (OTHERS => '0') WHEN pravetz_mode = '1' ELSE md_sd_din_fd2;
	sd_din_fd3 <= (OTHERS => '0') WHEN pravetz_mode = '1' ELSE md_sd_din_fd3;
	fdd_busy <= pravetz_fdd_busy WHEN pravetz_mode = '1' ELSE md_fdd_busy;
	fd_led <= pravetz_fd_led WHEN pravetz_mode = '1' ELSE md_fd_led;

	inst_cpu : ENTITY work.T65
		PORT MAP(
			Mode => "00",
			Res_n => cont_RESETn,
			Enable => ENA_1MHZ,
			Clk => CLK_IN,
			Rdy => NOT (cpu_halt OR save_halted_i),
			Abort_n => '1',
			IRQ_n => cpu_irq AND cont_irq, -- Via and disk controller
			NMI_n => KEYB_NMIn,
			SO_n => '1',
			R_W_n => cpu_rw,
			A => cpu_ad,
			DI => cpu_di,
			DO => cpu_do,
			Sync => cpu_sync,
			Regs => cpu_regs_q,
			Regs_set => cpu_regs_set,
			Regs_set_we => cpu_regs_set_we
		);

	-- Snapshot SAVE halt: engage the Rdy stall only while T65 is parked
	-- at an opcode fetch (Sync='1', MCycle 000) and not on the very edge
	-- that completes the fetch (ENA_1MHZ='1'), so the captured PC is the
	-- exact resume address. Releasing save_halt drops the stall.
	p_save_halt : PROCESS (CLK_IN)
	BEGIN
		IF rising_edge(CLK_IN) THEN
			IF save_halt = '0' THEN
				save_halted_i <= '0';
			ELSIF cpu_sync = '1' AND ENA_1MHZ = '0' THEN
				save_halted_i <= '1';
			END IF;
		END IF;
	END PROCESS;
	save_halted <= save_halted_i;

	ram_ad <= ula_AD_SRAM WHEN (ula_PHI2 = '0') ELSE
		cpu_ad(15 DOWNTO 0);
	ram_d <= cpu_do;
	SRAM_DO <= ram_q;
	ram_cs <= '0' WHEN RESETn = '0' ELSE
		ula_CE_SRAM;
	ram_oe <= '0' WHEN RESETn = '0' ELSE
		ula_OE_SRAM;
	ram_we <= '0' WHEN RESETn = '0' ELSE
		ula_WE_SRAM;
	phi2 <= ula_PHI2;

	bios_addr <= cpu_ad(13 DOWNTO 0);
	
	inst_rom0 : ENTITY work.BASIC11A -- Oric Atmos ROM
		PORT MAP(
			clk => CLK_IN,
			addr => cpu_ad(13 DOWNTO 0),
			data => ROM_ATMOS_DO
		);

	inst_rom1 : ENTITY work.BASIC10 -- Oric 1 ROM
		PORT MAP(
			clk => CLK_IN,
			addr => cpu_ad(13 DOWNTO 0),
			data => ROM_1_DO
		);

	inst_rom_pravetz : ENTITY work.PRAVETZ8D -- Pravetz 8D ROM
		PORT MAP(
			clk => CLK_IN,
			addr => cpu_ad(13 DOWNTO 0),
			data => ROM_PRAVETZ_DO
		);

	inst_rom_pravetz_fdc : ENTITY work.PRAVETZ8D_FDC -- Pravetz 8D FDC bank ROM
		PORT MAP(
			clk => CLK_IN,
			bank => pravetz_bank,
			addr => cpu_ad(7 DOWNTO 0),
			data => ROM_PRAVETZ_BANK_DO
		);

	inst_rom2 : ENTITY work.ORICDOS06 -- Microdisc ROM
		PORT MAP(
			clk => CLK_IN,
			addr => cpu_ad(12 DOWNTO 0),
			data => ROM_MD_DO
		);
	inst_ula : ENTITY work.ULA
		PORT MAP(
			CLK => CLK_IN,
			PHI2 => ula_phi2,
			PHI2_EN => ENA_1MHZ,
			CLK_4 => ula_CLK_4,
			CLK_4_EN => ula_CLK_4_en,
			RW => cpu_rw,
			RESETn => pll_locked, --RESETn,
			MAPn => cont_MAPn,
			DB => SRAM_DO,
			ADDR => cpu_ad(15 DOWNTO 0),
			SRAM_AD => ula_AD_SRAM,
			SRAM_OE => ula_OE_SRAM,
			SRAM_CE => ula_CE_SRAM,
			SRAM_WE => ula_WE_SRAM,
			LATCH_SRAM => ula_LATCH_SRAM,
			CSIOn => ula_CSIOn,
			CSROMn => ula_CSROMn,
			CSRAMn => ula_CSRAMn,
			SNAP_MODE_WE => ula_snap_mode_we,
			SNAP_MODE => ula_snap_mode,
			SNAP_MODE_Q => ula_snap_mode_q,
			R => VIDEO_R,
			G => VIDEO_G,
			B => VIDEO_B,
			CLK_PIX => VIDEO_CLK,
			HBLANK => VIDEO_HBLANK,
			VBLANK => VIDEO_VBLANK,
			SYNC => VIDEO_SYNC,
			HSYNC => VIDEO_HSYNC,
			VSYNC => VIDEO_VSYNC
		);

	inst_via : ENTITY work.M6522
		PORT MAP(
			I_RS => cpu_ad(3 DOWNTO 0),
			I_DATA => cpu_do(7 DOWNTO 0),
			O_DATA => VIA_DO,
			I_RW_L => cpu_rw,
			I_CS1 => cont_IOCONTROLn,
			I_CS2_L => ula_CSIOn,

			O_IRQ_L => cpu_irq,

			--PORT A		
			I_CA1 => '1', -- PRT_ACK
			I_CA2 => '1', -- psg_bdir
			O_CA2 => psg_bdir,
			O_CA2_OE_L => OPEN,

			I_PA => via_pa_in,
			O_PA => via_pa_out,
			O_PA_OE_L => via_pa_out_oe,

			-- PORT B
			I_CB1 => K7_TAPEIN,
			O_CB1 => via_cb1_out,
			O_CB1_OE_L => via_cb1_oe_l,

			I_CB2 => '1',
			O_CB2 => via_cb2_out,
			O_CB2_OE_L => via_cb2_oe_l,

			I_PB => via_pb_in,
			O_PB => via_pb_out,
			RESET_L => RESETn,
			I_P2_H => ula_phi2,
			ENA_4 => ula_CLK_4_en,
			CLK => CLK_IN,
			snap_we => via_snap_we,
			snap_addr => via_snap_addr,
			snap_data => via_snap_data,
			snap_t1c_we      => via_snap_t1c_we,
			snap_t1c_data    => via_snap_t1c_data,
			snap_t2c_we      => via_snap_t2c_we,
			snap_t2c_data    => via_snap_t2c_data,
			snap_t_active_we => via_snap_t_active_we,
			snap_t1_active   => via_snap_t1_active,
			snap_t2_active   => via_snap_t2_active,
			snap_ifr_we      => via_snap_ifr_we,
			snap_ifr_data    => via_snap_ifr_data,
			snap_q           => via_snap_q
		);



  psg_a: psg
  port map (
      clock       => CLK_IN,
      ce          => ENA_1MHZ,
      reset       => RESETn AND KEYB_RESETn,
      bdir        => via_cb2_out,
      bc1         => psg_bdir,
      d           => via_pa_out,
      q           => via_pa_in_from_psg,
      a           => PSG_OUT_A,
      b           => PSG_OUT_B,
      c           => PSG_OUT_C,
      mix         => PSG_OUT,

      ioad        => "ZZZZZZZZ",
      ioaq        => psg_ioa_out,
      iobd        => "ZZZZZZZZ",
      iobq        => psg_iob_out,

      sel         => '1',

      snap_we      => ay_snap_we,
      snap_addr    => ay_snap_addr,
      snap_data    => ay_snap_data,
      snap_creg_we => ay_snap_creg_we,
      snap_creg    => ay_snap_creg,
      snap_rd_addr => ay_snap_rd_addr,
      snap_rd_q    => ay_snap_rd_q,
      snap_creg_q  => ay_snap_creg_q,
      snap_env_q   => ay_snap_env_q
    );

	
	inst_key : keyboard
	PORT MAP(
		clk_sys => CLK_IN,
		reset => NOT RESETn, --not RESETn,
		key_pressed => key_pressed,
		key_extended => key_extended,
		key_strobe => key_strobe,
		key_code => key_code,
		pravetz_layout => pravetz_layout,
		col => via_pb_out (2 DOWNTO 0),
		kbd_int => kbd_int,
		row_mask => psg_ioa_out,
		swnmi => swnmi,
		swrst => swrst
	);
	
	inst_joy : joystick
	PORT MAP(
		clk_sys => CLK_IN,
		joystick_0 => joystick_0,
		joystick_1 => joystick_1,
		adapter => joystick_adapter,
		via_strobe => via_pb_out(4),
		via_pa_in => via_pa_out,
		joy_mask => via_pa_joy_mask,
		joy_value => via_pa_joy_value
	);

	KEYB_NMIn <= NOT swnmi;
	KEYB_RESETn <= NOT swrst;

	inst_pravetz_fdc : ENTITY work.PRAVETZ8D_FDC_CTRL
	PORT MAP(
		clk_sys => CLK_IN,
		reset => NOT RESETn,
		phi2 => ula_PHI2,
		A => cpu_ad(15 DOWNTO 0),
		DI => cpu_do,
		DO => pravetz_fdc_DO,
		fdc_select => pravetz_fdc_select,
		img_mounted => img_mounted,
		img_wp => img_wp,
		img_size => img_size,
		sd_lba_fd0 => pravetz_sd_lba_fd0,
		sd_lba_fd1 => pravetz_sd_lba_fd1,
		sd_rd => pravetz_sd_rd,
		sd_wr => pravetz_sd_wr,
		sd_ack => sd_ack(1 DOWNTO 0),
		sd_buff_addr => sd_buff_addr,
		sd_dout => sd_dout,
		sd_din_fd0 => pravetz_sd_din_fd0,
		sd_din_fd1 => pravetz_sd_din_fd1,
		sd_dout_strobe => sd_dout_strobe,
		fdd_busy => pravetz_fdd_busy,
		fd_led => pravetz_fd_led
	);

	inst_microdisc : work.Microdisc
	PORT MAP(
		CLK_SYS => CLK_IN,
		-- Oric Expansion Port Signals
		DI => cpu_do, -- 6502 Data Bus
		DO => md_D_OUT, -- 6502 Data Bus
		A => cpu_ad (15 DOWNTO 0), -- 6502 Address Bus
		RnW => cpu_rw, -- 6502 Read-/Write
		nIRQ => md_irq, -- 6502 /IRQ
		PH2 => ula_PHI2, -- 6502 PH2 
		nROMDIS => md_ROMDISn, -- Oric ROM Disable
		nMAP => md_MAPn, -- Oric MAP 
		IO => ula_CSIOn, -- Oric I/O 
		IOCTRL => md_IOCONTROLn, -- Oric I/O Control           
		nHOSTRST => md_RESETn, -- Oric RESET 
		-- Additional MCU Interface Lines
		nRESET => RESETn AND pll_locked, -- RESET from MCU
		--DSEL      => cont_DSEL,                           -- Drive Select
		--SSEL      => cont_SSEL,                           -- Side Select

		-- EEPROM Control Lines.
		nECE => md_ECE, -- Chip Enable

		ENA => disk_enable,

		nOE => md_nOE,

		img_mounted => img_mounted,
		img_wp => img_wp,
		img_size => img_size,
		sd_lba_fd0 => md_sd_lba_fd0,
		sd_lba_fd1 => md_sd_lba_fd1,
		sd_lba_fd2 => md_sd_lba_fd2,
		sd_lba_fd3 => md_sd_lba_fd3,
		sd_rd => md_sd_rd,
		sd_wr => md_sd_wr,
		sd_ack => sd_ack,
		sd_buff_addr => sd_buff_addr,
		sd_dout => sd_dout,
		sd_din_fd0 => md_sd_din_fd0,
		sd_din_fd1 => md_sd_din_fd1,
		sd_din_fd2 => md_sd_din_fd2,
		sd_din_fd3 => md_sd_din_fd3,
		sd_dout_strobe => sd_dout_strobe,
		sd_din_strobe => sd_din_strobe,
		fdd_ready => fdd_ready,
		fdd_busy => md_fdd_busy,
		fdd_reset => fdd_reset,
		fdd_layout => fdd_layout,
		fd_led => md_fd_led

	);


	via_pa_in <= (((via_pa_joy_value AND via_pa_joy_mask) OR (via_pa_out_oe AND NOT via_pa_joy_mask) OR (via_pa_out AND NOT via_pa_out_oe AND NOT via_pa_joy_mask))) WHEN (via_cb2_out='0' AND psg_bdir='0') ELSE
	             (((via_pa_joy_value AND via_pa_joy_mask) OR (via_pa_in_from_psg AND via_pa_out_oe AND NOT via_pa_joy_mask) OR (via_pa_out AND NOT via_pa_out_oe AND NOT via_pa_joy_mask)));
	via_pb_in(2 DOWNTO 0) <= via_pb_out(2 DOWNTO 0);
	via_pb_in(3) <= kbd_int;
	via_pb_in(4) <= via_pb_out(4);
	via_pb_in(5) <= 'Z';
	via_pb_in(6) <= via_pb_out(6);
	via_pb_in(7) <= via_pb_out(7);

	
	K7_TAPEOUT <= via_pb_out(7);
	K7_REMOTE <= via_pb_out(6);
	PRN_STROBE <= via_pb_out(4);
	PRN_DATA <= via_pa_out;

	-- Host LED mailbox: snoop CPU writes to $C000. $C000 is in the
	-- ROM read-window (read returns the ROM byte $4C, untouched);
	-- the write side is a side-channel — POKE/STA reaches the bus
	-- regardless of ROM, and Oric.sv latches the value.
	c000_we <= '1' WHEN ula_phi2 = '1'
	                AND cpu_rw = '0'
	                AND cpu_ad(15 DOWNTO 0) = X"C000"
	           ELSE '0';
	c000_data <= cpu_do;
	named_cload_we <= '1' WHEN ula_phi2 = '1'
	                       AND cpu_rw = '0'
	                       AND cpu_do /= X"00"
	                       AND cpu_ad(15 DOWNTO 0) = X"027F"
	                  ELSE '0';
	tap_sync_request <= '1' WHEN ula_phi2 = '1'
	                          AND cpu_rw = '1'
	                          AND tape_byte_enable = '1'
	                          AND ula_CSROMn = '0'
	                          AND cont_MAPn = '1'
	                          AND cont_ROMDISn = '1'
	                          AND cpu_ad(13 DOWNTO 0) = STD_LOGIC_VECTOR(TO_UNSIGNED(16#2735#, 14))
	                     ELSE '0';
	tap_byte_consume <= '1' WHEN ula_phi2 = '1'
	                         AND cpu_rw = '1'
	                         AND tape_byte_enable = '1'
	                         AND ula_CSROMn = '0'
	                         AND cont_MAPn = '1'
	                         AND cont_ROMDISn = '1'
	                         AND cpu_ad(13 DOWNTO 0) = STD_LOGIC_VECTOR(TO_UNSIGNED(16#26CE#, 14))
	                    ELSE '0';

	PROCESS (CLK_IN)
	BEGIN
		IF rising_edge(CLK_IN) THEN
			IF RESETn = '0' OR pravetz_mode = '0' THEN
				pravetz_bank <= '0';
				pravetz_shadow <= '0';
			ELSIF ula_phi2 = '1'
			      AND cpu_rw = '0'
			      AND cpu_ad(15 DOWNTO 8) = X"03"
			      AND cpu_ad(7 DOWNTO 2) = "100000" THEN
				pravetz_bank <= cpu_ad(1);
				pravetz_shadow <= cpu_ad(0);
			END IF;
		END IF;
	END PROCESS;


	PROCESS BEGIN

		WAIT UNTIL rising_edge(clk_in);
	
		-- Tape-load live ROM patch — wins over every ROM source.
		-- Gate on ula_CSROMn='0' so we only override during reads
		-- inside the ROM window ($C000-$FFFF). Without this gate the
		-- override fires for any low-RAM read whose low 14 bits land
		-- in the patch range — e.g. cold-boot RAM detection writing/
		-- reading $285F sees our patch byte instead of RAM, mistakes
		-- it for end-of-RAM, and reports a tiny BYTES FREE.
		IF cpu_rw = '1' AND ula_phi2 = '1' AND patch_active = '1'
		      AND ula_CSROMn = '0' AND cont_MAPn = '1' AND cont_ROMDISn = '1' THEN
			cpu_di <= patch_data;
			-- Pravetz 8D Disk II-style FDC softswitches ($0310-$031F).
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND pravetz_mode = '1' AND pravetz_fdc_select = '1' THEN
			cpu_di <= pravetz_fdc_DO;
			-- Pravetz 8D POC page-3 bank ROM ($0320-$03FF).
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND pravetz_bank_window = '1' THEN
			cpu_di <= ROM_PRAVETZ_BANK_DO;
			-- expansion port
		ELSIF cpu_rw = '1' AND ula_PHI2 = '1' AND ula_CSIOn = '0' AND cont_IOCONTROLn = '0' THEN
			cpu_di <= md_D_OUT;
			-- VIA
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND ula_CSIOn = '0' AND cont_IOCONTROLn = '1' THEN
			cpu_di <= VIA_DO;
			-- ROM Atmos	
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND ula_CSIOn = '1' AND ula_CSROMn = '0' AND cont_MAPn = '1' AND cont_ROMDISn = '1' AND rom = "00" THEN
			cpu_di <= ROM_ATMOS_DO;
			-- ROM Oric 1	
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND ula_CSIOn = '1' AND ula_CSROMn = '0' AND cont_MAPn = '1' AND cont_ROMDISn = '1' AND rom = "01" THEN
			cpu_di <= ROM_1_DO;
			-- ROM Pravetz 8D
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND ula_CSIOn = '1' AND ula_CSROMn = '0' AND cont_MAPn = '1' AND cont_ROMDISn = '1' AND rom = "10" THEN
			cpu_di <= ROM_PRAVETZ_DO;
			-- Loadable ROM
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND ula_CSIOn = '1' AND ula_CSROMn = '0' AND cont_MAPn = '1' AND cont_ROMDISn = '1' AND rom = "11" THEN
			cpu_di <= bios_din;
			--ROM Microdisc
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND cont_ECE = '0' AND cont_ROMDISn = '0' AND cont_MAPn = '1' THEN
			cpu_di <= ROM_MD_DO;
			-- RAM	
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND ula_CSRAMn = '0' AND ula_LATCH_SRAM = '0' THEN
			cpu_di <= SRAM_DO;
		END IF;
	END PROCESS;

END RTL;
