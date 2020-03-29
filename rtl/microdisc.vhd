-- Cumulus CPLD Core
-- Top Level Entity
-- Copyright 2010 Retromaster
--
-- This file is part of Cumulus CPLD Core.
--
-- Cumulus CPLD Core is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License,
-- or any later version.
--
-- Cumulus CPLD Core is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Cumulus CPLD Core. If not, see .
--

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY Microdisc IS

	PORT 
	(
		CLK_SYS         : IN std_logic; -- 24 Mhz input clock
		
		-- Oric Expansion Port Signals
		DI              : IN std_logic_vector(7 DOWNTO 0); -- 6502 Data Bus
		DO              : OUT std_logic_vector(7 DOWNTO 0); -- 6502 Data Bus
 
		A               : IN std_logic_vector(15 DOWNTO 0); -- 6502 Address Bus
		RnW             : IN std_logic; -- 6502 Read-/Write
		nIRQ            : OUT std_logic; -- 6502 /IRQ
		PH2             : IN std_logic; -- 6502 PH2
		nROMDIS         : OUT std_logic; -- Oric ROM Disable
		nMAP            : OUT std_logic; -- Oric MAP
		IO              : IN std_logic; -- Oric I/O
		IOCTRL          : OUT std_logic; -- Oric I/O Control 
		nHOSTRST        : OUT std_logic; -- Oric RESET
 
		-- Data Bus Buffer Control Signals
		nOE             : OUT std_logic; -- Output Enable
		DIR             : OUT std_logic; -- Direction
 

		-- Additional MCU Interface Lines
		nRESET          : IN std_logic; -- RESET from MCU
--		DSEL            : OUT std_logic_vector(1 DOWNTO 0); -- Drive Select
--		SSEL            : OUT  std_logic; -- Side Select
 
		-- EEPROM Control Lines.
		nECE            : OUT std_logic; -- Chip Enable
		nEOE            : OUT std_logic; -- Output Enable
		ENA             : IN std_logic;
 
		img_mounted     : IN std_logic;
		img_wp          : IN std_logic;
		img_size        : IN std_logic_vector (31 DOWNTO 0);
		sd_lba          : OUT std_logic_vector (31 DOWNTO 0);
		sd_rd           : OUT std_logic;
		sd_wr           : OUT std_logic;
		sd_ack          : IN std_logic;
		sd_buff_addr    : IN std_logic_vector (8 DOWNTO 0);
		sd_dout         : IN std_logic_vector (7 DOWNTO 0);
		sd_din          : OUT std_logic_vector (7 DOWNTO 0);
		sd_dout_strobe  : IN std_logic;
		sd_din_strobe   : IN std_logic;
 
		fdd_ready       : IN std_logic;
		fdd_busy        : BUFFER std_logic;
		fdd_reset       : IN std_logic;
		fdd_layout      : IN std_logic;
		fd_led          : OUT std_logic
	);
END Microdisc;

ARCHITECTURE Behavioral OF Microdisc IS
	COMPONENT wd1793
		GENERIC 
		(
			RWMODE          : INTEGER := 1;
			EDSK            : INTEGER := 0
		);
		PORT 
		(
			clk_sys       : IN std_logic;
			ce            : IN std_logic;
 
			reset         : IN std_logic;
			io_en         : IN std_logic;
			rd            : IN std_logic;
			wr            : IN std_logic;
			addr          : IN std_logic_vector (1 DOWNTO 0);
			din           : IN std_logic_vector (7 DOWNTO 0);
			dout          : OUT std_logic_vector (7 DOWNTO 0);
 
			intrq         : OUT std_logic;
			drq           : OUT std_logic;
 
			busy          : OUT std_logic;
			ready         : IN std_logic;
			layout        : IN std_logic;
			side          : IN std_logic;
 
			img_mounted   : IN std_logic;
 
			wp            : IN std_logic;
			img_size      : IN std_logic_vector (19 DOWNTO 0);
			sd_lba        : OUT std_logic_vector (31 DOWNTO 0);
			sd_rd         : OUT std_logic;
			sd_wr         : OUT std_logic;
			sd_ack        : IN std_logic;
			sd_buff_addr  : IN std_logic_vector (8 DOWNTO 0);
			sd_buff_dout  : IN std_logic_vector (7 DOWNTO 0);
			sd_buff_din   : OUT std_logic_vector (7 DOWNTO 0);
			sd_buff_wr    : IN std_logic;
 
			prepare       : OUT std_logic;
			size_code     : IN std_logic_vector (2 DOWNTO 0); 
			
			input_active  : IN std_logic;
	      input_addr    : IN std_logic_vector (19 DOWNTO 0);
	      input_data    : IN std_logic_vector (7 DOWNTO 0);
	      input_wr      : IN std_logic;
	      buff_addr     : OUT std_logic_vector (19 DOWNTO 0);	  
	      buff_read     : OUT std_logic;	  
	      buff_din      : IN std_logic_vector (7 DOWNTO 0)
 
		);
	END COMPONENT;
 


	-- Status
 
 

 
	SIGNAL fdc_nCS : std_logic; 
	SIGNAL nCS     : std_logic;
	SIGNAL fdc_nRE : std_logic; 
	SIGNAL fdc_nWE : std_logic; 
	SIGNAL fdc_CLK_en : std_logic; 
	SIGNAL fdc_A : std_logic_vector(1 DOWNTO 0); 
	SIGNAL fdc_DALin : std_logic_vector(7 DOWNTO 0);
	SIGNAL fdc_DALout : std_logic_vector(7 DOWNTO 0); 
	SIGNAL fdc_DRQ : std_logic; 
	SIGNAL fdc_IRQ : std_logic; 
 
	SIGNAL sel : std_logic; 
	SIGNAL u16k : std_logic;
	SIGNAL inECE : std_logic;
	SIGNAL inROMDIS : std_logic;
	SIGNAL iDIR : std_logic;

	SIGNAL DSEL : std_logic_vector(1 DOWNTO 0); -- Drive Select
	SIGNAL SSEL : std_logic; -- Side Select
 
	-- Control Register
	SIGNAL nROMEN : std_logic; -- ROM Enable
	SIGNAL IRQEN : std_logic; -- IRQ Enable
 
	SIGNAL inMCRQ : std_logic;

BEGIN
	fdc1 : wd1793
		GENERIC MAP
		(
		EDSK => 1, 
		RWMODE => 1
		)
		PORT MAP
		(
			clk_sys       => clk_sys, 
			ce            => fdc_CLK_en, 
 
			reset         => NOT nRESET, 
			io_en         => NOT fdc_nCS, 
			rd            => NOT fdc_nRE,
			wr            => NOT fdc_nWE,
			addr          => fdc_A, 
			din           => fdc_DALin, 
			dout          => fdc_DALout, 
 
			intrq         => fdc_IRQ, 
			drq           => fdc_DRQ, 
 
			ready         => fdd_ready, 
			--busy          => fdd_busy, 
 
			layout        => fdd_layout , --fdd_layout, 
			size_code     => "001", 
			side          => SSEL, 
			prepare       => fdd_busy,
			img_mounted   => img_mounted, 
			wp            => img_wp, 
			img_size      => img_size (19 DOWNTO 0), 
			sd_lba        => sd_lba, 
			sd_rd         => sd_rd, 
			sd_wr         => sd_wr, 
			sd_ack        => sd_ack, 
			sd_buff_addr  => sd_buff_addr, 
			sd_buff_dout  => sd_dout, 
			sd_buff_din   => sd_din,
			sd_buff_wr    => sd_dout_strobe,
		
	      input_active  => '0',
		   input_addr    => (others => '0'),	
			input_data    => (others => '0'),
			input_wr      => '0',
			buff_din      => (others => '0')
			
			); 
 

			-- Reset
			nHOSTRST <= '0' WHEN nRESET = '0'   ELSE '1';
			
			-- Select signal (Address Range 031-)
			sel <= '1' WHEN A(7 DOWNTO 4) = "0001" AND IO = '0' AND A(3 DOWNTO 2) /= "11" ELSE '0';

			-- WD1793 Signals
			fdc_A <= A(1 DOWNTO 0);
			fdc_nCS <= '0' WHEN sel = '1' AND A(3 DOWNTO 2) = "00" ELSE '1';
			
			fdc_nRE <= IO OR NOT RnW;
			fdc_nWE <= IO OR RnW;
			fdc_DALin <= DI;
			
			
			-- DEBUG led
 
			fd_led <= fdd_busy; 
			-- ORIC Expansion Port Signals
			IOCTRL <= '0' WHEN sel = '1' ELSE '1';
			nROMDIS <= '0' WHEN inROMDIS = '0' ELSE '1';
			nIRQ <= '0' WHEN fdc_IRQ = '1' AND IRQEN = '1' ELSE '1'; 
			-- EEPROM Control Signals
			nEOE <= PH2 OR NOT RnW;
			u16k <= '1' WHEN (inROMDIS = '0') AND (A(14) = '1') AND (A(15) = '1') ELSE '0';
			inECE <= NOT (A(13) AND u16k AND NOT nROMEN);
			nECE <= inECE;
			nMAP <= '0' WHEN (PH2 AND inECE AND u16k) = '1' ELSE '1'; 
 
			--nMCRQ <= inMCRQ; 
 
			DIR <= iDIR;
			iDIR <= RnW; 
 
			-- Data Bus Control.
			PROCESS (iDIR, fdc_DALout, fdc_DRQ, fdc_IRQ, fdc_nRE, A, fdc_nCS )
			BEGIN
				IF iDIR = '1' THEN 
					IF A(3 DOWNTO 2) = "10" THEN
						DO <= (NOT fdc_DRQ) & "-------";
						ELSIF A(3 DOWNTO 2) = "01" THEN
							DO <= (NOT fdc_IRQ) & "-------";
						ELSIF fdc_nRE = '0' AND fdc_nCS = '0' THEN
							DO <= fdc_DALout; 
					ELSE
						DO <= "--------"; 
						END IF;
				ELSE
					DO <= "ZZZZZZZZ"; 
				END IF;
			END PROCESS; 
 
         

			
			nOE <= '0' WHEN sel = '1' AND PH2 = '1' ELSE '1';
 
			-- Control Register.
			PROCESS (CLK_SYS)
				BEGIN
					IF rising_edge(CLK_SYS) THEN
						IF nRESET = '0' THEN
							nROMEN <= '0';
							DSEL <= "00";
							SSEL <= '0';
							IF ENA = '0' THEN
								inROMDIS <= '0';
							ELSE
								inROMDIS <= '1';
							END IF;
							IRQEN <= '0'; 
						ELSE
							IF sel = '1' AND A(3 DOWNTO 2) = "01" AND RnW = '0' THEN
								nROMEN <= DI(7);
								DSEL <= DI(6 DOWNTO 5);
								SSEL <= DI(4);
								inROMDIS <= DI(1);
								IRQEN <= DI(0);
							END IF;
						END IF;
					END IF;
				END PROCESS;

			-- FDC clock enable: 24/6 = 4MHz
			PROCESS (nRESET, CLK_SYS)
				VARIABLE count: integer range 0 to 5;
				BEGIN
					IF nRESET = '0' THEN
						count := 0;
						fdc_CLK_en <= '0';
					ELSIF rising_edge(CLK_SYS) THEN
						fdc_CLK_en <= '0';
						if count = 0 then
							fdc_CLK_en <= '1';
						end if;
						count := count + 1;
					END IF;
				END PROCESS;

END Behavioral;