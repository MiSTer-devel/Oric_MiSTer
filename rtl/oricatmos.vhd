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
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;
ENTITY oricatmos IS
	PORT (
		CLK_IN : IN STD_LOGIC;
		RESET : IN STD_LOGIC;
		key_pressed : IN STD_LOGIC;
		key_extended : IN STD_LOGIC;
		key_code : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		key_strobe : IN STD_LOGIC;
		K7_TAPEIN : IN STD_LOGIC;
		K7_TAPEOUT : OUT STD_LOGIC;
		K7_REMOTE : OUT STD_LOGIC;

		PSG_OUT_A : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		PSG_OUT_B : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		PSG_OUT_C : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      PSG_OUT   : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
		
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
		joystick_0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		joystick_1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		pll_locked : IN STD_LOGIC;
		disk_enable : IN STD_LOGIC;
		rom : IN STD_LOGIC;
		img_mounted : IN STD_LOGIC;
		img_wp : IN STD_LOGIC;
		img_size : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		sd_lba : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		sd_rd : OUT STD_LOGIC;
		sd_wr : OUT STD_LOGIC;
		sd_ack : IN STD_LOGIC;
		sd_buff_addr : IN STD_LOGIC_VECTOR (8 DOWNTO 0);
		sd_dout : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		sd_din : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
		sd_dout_strobe : IN STD_LOGIC;
		sd_din_strobe : IN STD_LOGIC
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
	SIGNAL KEYB_RESETn : STD_LOGIC;
	SIGNAL KEYB_NMIn : STD_LOGIC;

	-- PSG
	SIGNAL psg_bdir : STD_LOGIC;
	SIGNAL psg_bc1 : STD_LOGIC;
	SIGNAL ym_o_ioa : STD_LOGIC_VECTOR (7 DOWNTO 0);
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
	SIGNAL ROM_MD_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);

	--- Printer port
	SIGNAL PRN_STROBE : STD_LOGIC;
	SIGNAL PRN_DATA : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL SRAM_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);

	SIGNAL swnmi : STD_LOGIC;
	SIGNAL swrst : STD_LOGIC;

	-- Disk controller
	SIGNAL cont_MAPn : STD_LOGIC := '1';
	SIGNAL cont_ROMDISn : STD_LOGIC := '1';
	SIGNAL cont_D_OUT : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL cont_IOCONTROLn : STD_LOGIC := '1';
	SIGNAL cont_ECE : STD_LOGIC;
	SIGNAL cont_RESETn : STD_LOGIC;
	SIGNAL cont_nOE : STD_LOGIC;
	SIGNAL cont_irq : STD_LOGIC;

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
			col : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
			row : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			ROWbit : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			swnmi : OUT STD_LOGIC;
			swrst : OUT STD_LOGIC
		);
	END COMPONENT;


	COMPONENT jt49_bus
		PORT (
			clk : IN STD_LOGIC;
			clk_en : IN STD_LOGIC;
			rst_n : IN STD_LOGIC;
			bdir : IN STD_LOGIC;
			bc1 : IN STD_LOGIC;
			sel : IN STD_LOGIC;
			din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			sound : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
			A : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			B : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			C : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			sample : OUT STD_LOGIC;
			IOA_In : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			IOA_Out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			IOB_In : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			IOB_Out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
		);
	END COMPONENT;

BEGIN

	RESETn <= (NOT RESET AND KEYB_RESETn);
	inst_cpu : ENTITY work.T65
		PORT MAP(
			Mode => "00",
			Res_n => cont_RESETn,
			Enable => ENA_1MHZ,
			Clk => CLK_IN,
			Rdy => '1',
			Abort_n => '1',
			IRQ_n => cpu_irq AND cont_irq, -- Via and disk controller
			NMI_n => KEYB_NMIn,
			SO_n => '1',
			R_W_n => cpu_rw,
			A => cpu_ad,
			DI => cpu_di,
			DO => cpu_do
		);

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
			CLK => CLK_IN
		);

	inst_psg : jt49_bus
	PORT MAP(
		clk => CLK_IN,
		clk_en => ENA_1MHZ,
		sel => '1',
		rst_n => RESETn AND KEYB_RESETn,
		bc1 => psg_bdir,
		bdir => via_cb2_out,
		din => via_pa_out,
		dout => via_pa_in_from_psg,
		sample => psg_sample_ok,
		sound => PSG_OUT,
		A => PSG_OUT_A,
		B => PSG_OUT_B,
		C => PSG_OUT_C,
		IOA_In => (OTHERS => '0'),
		IOA_Out => ym_o_ioa,
		IOB_In => (OTHERS => '0')
	);

	inst_key : keyboard
	PORT MAP(
		clk_sys => CLK_IN,
		reset => NOT RESETn, --not RESETn,
		key_pressed => key_pressed,
		key_extended => key_extended,
		key_strobe => key_strobe,
		key_code => key_code,
		row => ym_o_ioa,
		col => via_pb_out (2 DOWNTO 0),
		ROWbit => KEY_ROW,
		swnmi => swnmi,
		swrst => swrst
	);

	KEYB_NMIn <= NOT swnmi;
	KEYB_RESETn <= NOT swrst;

	inst_microdisc : work.Microdisc
	PORT MAP(
		CLK_SYS => CLK_IN,
		-- Oric Expansion Port Signals
		DI => cpu_do, -- 6502 Data Bus
		DO => cont_D_OUT, -- 6502 Data Bus			 
		A => cpu_ad (15 DOWNTO 0), -- 6502 Address Bus
		RnW => cpu_rw, -- 6502 Read-/Write
		nIRQ => cont_irq, -- 6502 /IRQ
		PH2 => ula_PHI2, -- 6502 PH2 
		nROMDIS => cont_ROMDISn, -- Oric ROM Disable
		nMAP => cont_MAPn, -- Oric MAP 
		IO => ula_CSIOn, -- Oric I/O 
		IOCTRL => cont_IOCONTROLn, -- Oric I/O Control           
		nHOSTRST => cont_RESETn, -- Oric RESET 
		-- Additional MCU Interface Lines
		nRESET => RESETn AND pll_locked, -- RESET from MCU
		--DSEL      => cont_DSEL,                           -- Drive Select
		--SSEL      => cont_SSEL,                           -- Side Select

		-- EEPROM Control Lines.
		nECE => cont_ECE, -- Chip Enable

		ENA => disk_enable,

		nOE => cont_nOE,

		img_mounted => img_mounted,
		img_wp => img_wp,
		img_size => img_size,
		sd_lba => sd_lba,
		sd_rd => sd_rd,
		sd_wr => sd_wr,
		sd_ack => sd_ack,
		sd_buff_addr => sd_buff_addr,
		sd_dout => sd_dout,
		sd_din => sd_din,
		sd_dout_strobe => sd_dout_strobe,
		sd_din_strobe => sd_din_strobe,
		fdd_ready => fdd_ready,
		fdd_busy => fdd_busy,
		fdd_reset => fdd_reset,
		fdd_layout => fdd_layout,
		fd_led => fd_led

	);

	via_pa_in <= (via_pa_out AND NOT via_pa_out_oe) OR (via_pa_in_from_psg AND via_pa_out_oe);
	via_pb_in(2 DOWNTO 0) <= via_pb_out(2 DOWNTO 0);
	via_pb_in(3) <= '0' WHEN ((KEY_ROW AND (ym_o_ioa XOR x"FF"))) = x"00" ELSE
	'1';
	via_pb_in(4) <= via_pb_out(4);
	via_pb_in(5) <= 'Z';
	via_pb_in(6) <= via_pb_out(6);
	via_pb_in(7) <= via_pb_out(7);

	
	K7_TAPEOUT <= via_pb_out(7);
	K7_REMOTE <= via_pb_out(6);
	PRN_STROBE <= via_pb_out(4);
	PRN_DATA <= via_pa_out;


	PROCESS BEGIN

		WAIT UNTIL rising_edge(clk_in);
	
		-- expansion port
		IF    cpu_rw = '1' AND ula_PHI2 = '1' AND ula_CSIOn = '0' AND cont_IOCONTROLn = '0' THEN
			cpu_di <= cont_D_OUT;
			-- VIA
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND ula_CSIOn = '0' AND cont_IOCONTROLn = '1' THEN
			cpu_di <= VIA_DO;
			-- ROM Atmos	
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND ula_CSIOn = '1' AND ula_CSROMn = '0' AND cont_MAPn = '1' AND cont_ROMDISn = '1' AND rom = '1' THEN
			cpu_di <= ROM_ATMOS_DO;
			-- ROM Oric 1	
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND ula_CSIOn = '1' AND ula_CSROMn = '0' AND cont_MAPn = '1' AND cont_ROMDISn = '1' AND rom = '0' THEN
			cpu_di <= ROM_1_DO;
			--ROM Microdisc
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND cont_ECE = '0' AND cont_ROMDISn = '0' AND cont_MAPn = '1' THEN
			cpu_di <= ROM_MD_DO;
			-- RAM	
		ELSIF cpu_rw = '1' AND ula_phi2 = '1' AND ula_CSRAMn = '0' AND ula_LATCH_SRAM = '0' THEN
			cpu_di <= SRAM_DO;
		END IF;
	END PROCESS;

END RTL;