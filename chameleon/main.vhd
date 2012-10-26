-- Port of the A2601 FPGA implementation for the Turbo Chameleon

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- -----------------------------------------------------------------------

entity main is
	port (
-- Clocks
		clk8 : in std_logic;
		phi2_n : in std_logic;
		dotclock_n : in std_logic;

-- Bus
		romlh_n : in std_logic;
		ioef_n : in std_logic;

-- Buttons
		freeze_n : in std_logic;

-- MMC/SPI
		spi_miso : in std_logic;
		mmc_cd_n : in std_logic;
		mmc_wp : in std_logic;

-- MUX CPLD
		mux_clk : out std_logic;
		mux : out unsigned(3 downto 0);
		mux_d : out unsigned(3 downto 0);
		mux_q : in unsigned(3 downto 0);

-- USART
		usart_tx : in std_logic;
		usart_clk : in std_logic;
		usart_rts : in std_logic;
		usart_cts : in std_logic;

-- SDRam
		sd_clk : out std_logic;
		sd_data : inout unsigned(15 downto 0);
		sd_addr : out unsigned(12 downto 0);
		sd_we_n : out std_logic;
		sd_ras_n : out std_logic;
		sd_cas_n : out std_logic;
		sd_ba_0 : out std_logic;
		sd_ba_1 : out std_logic;
		sd_ldqm : out std_logic;
		sd_udqm : out std_logic;

-- Video
		red : out unsigned(4 downto 0);
		grn : out unsigned(4 downto 0);
		blu : out unsigned(4 downto 0);
		nHSync : out std_logic;
		nVSync : out std_logic;

-- Audio
		sigmaL : out std_logic;
		sigmaR : out std_logic
	);
end entity;

-- -----------------------------------------------------------------------

architecture rtl of main is
	type state_t is (TEST_IDLE, TEST_FILL, TEST_FILL_W, TEST_CHECK, TEST_CHECK_W, TEST_ERROR);
	
-- System clocks
	signal vid_clk: std_logic;
	signal sysclk : std_logic;
	signal clk_150 : std_logic;
	signal sd_clk_loc : std_logic;
	signal clk_locked : std_logic;
	signal ena_1mhz : std_logic;
	signal ena_1khz : std_logic;
	signal phi2 : std_logic;
	signal no_clock : std_logic;

	signal reset_button_n : std_logic;
	
-- Global signals
	signal reset : std_logic;
	signal end_of_pixel : std_logic;

-- RAM Test
	signal state : state_t := TEST_IDLE;
	signal noise_bits : unsigned(7 downto 0);
	
-- MUX
	signal mux_clk_reg : std_logic := '0';
	signal mux_reg : unsigned(3 downto 0) := (others => '1');
	signal mux_d_reg : unsigned(3 downto 0) := (others => '1');

-- 4 Port joystick adapter
	signal video_joystick_shift_reg : std_logic;

-- C64 keyboard (on joystick adapter)
	signal video_keyboard_reg : std_logic;
	
-- LEDs
	signal led_green : std_logic;
	signal led_red : std_logic;

-- IR
	signal ir : std_logic := '1';

-- PS/2 Keyboard
	signal ps2_keyboard_clk_in : std_logic;
	signal ps2_keyboard_dat_in : std_logic;
	signal ps2_keyboard_clk_out : std_logic;
	signal ps2_keyboard_dat_out : std_logic;

	signal keyboard_trigger : std_logic;
	signal keyboard_scancode : unsigned(7 downto 0);

-- PS/2 Mouse
	signal ps2_mouse_clk_in: std_logic;
	signal ps2_mouse_dat_in: std_logic;
	signal ps2_mouse_clk_out: std_logic;
	signal ps2_mouse_dat_out: std_logic;

	signal mouse_present : std_logic;
	signal mouse_active : std_logic;
	signal mouse_trigger : std_logic;
	signal mouse_left_button : std_logic;
	signal mouse_middle_button : std_logic;
	signal mouse_right_button : std_logic;
	signal mouse_delta_x : signed(8 downto 0);
	signal mouse_delta_y : signed(8 downto 0);
	
	signal cursor_x : signed(11 downto 0) := to_signed(0, 12);
	signal cursor_y : signed(11 downto 0) := to_signed(0, 12);
	
	signal sdram_req : std_logic := '0';
	signal sdram_ack : std_logic;
	signal sdram_we : std_logic := '0';
	signal sdram_a : unsigned(24 downto 0) := (others => '0');
	signal sdram_d : unsigned(7 downto 0);
	signal sdram_q : unsigned(7 downto 0);

-- VGA
	signal currentX : unsigned(11 downto 0);
	signal currentY : unsigned(11 downto 0);
	signal hsync : std_logic;
	signal vsync : std_logic;
	
	signal iec_cnt : unsigned(2 downto 0);
	signal iec_reg : unsigned(3 downto 0);
	signal iec_result : unsigned(23 downto 0);
	signal vga_id : unsigned(3 downto 0);
	
	signal video_amiga : std_logic := '0';

	signal red_reg : unsigned(4 downto 0);
	signal grn_reg : unsigned(4 downto 0);
	signal blu_reg : unsigned(4 downto 0);
	
-- Sound
	signal sigma_l : std_logic := '0';
	signal sigma_r : std_logic := '0';
	signal sigmaL_reg : std_logic := '0';
	signal sigmaR_reg : std_logic := '0';

-- Docking station
	signal docking_station : std_logic;
	signal docking_ena : std_logic;
	signal docking_keys : unsigned(63 downto 0);
	signal docking_restore_n : std_logic;
	signal docking_irq : std_logic;
	signal irq_n : std_logic;
	
	signal docking_joystick1 : unsigned(5 downto 0);
	signal docking_joystick2 : unsigned(5 downto 0);
	signal docking_joystick3 : unsigned(5 downto 0);
	signal docking_joystick4 : unsigned(5 downto 0);
	signal docking_amiga_reset_n : std_logic;
	signal docking_amiga_scancode : unsigned(7 downto 0);
	
-- A2601
	signal audio: std_logic;
   signal O_VSYNC: std_logic;
   signal O_HSYNC: std_logic;
	signal O_VIDEO_R: std_logic_vector(3 downto 0);
	signal O_VIDEO_G: std_logic_vector(3 downto 0);
	signal O_VIDEO_B: std_logic_vector(3 downto 0);			
	signal res: std_logic;
	signal p_l: std_logic;
	signal p_r: std_logic;
	signal p_a: std_logic;
	signal p_u: std_logic;
	signal p_d: std_logic;
	signal p2_l: std_logic;
	signal p2_r: std_logic;
	signal p2_a: std_logic;
	signal p2_u: std_logic;
	signal p2_d: std_logic;
	signal p_s: std_logic;
	signal p_bs: std_logic;			
	signal LED: std_logic_vector(2 downto 0);
	signal I_SW : std_logic_vector(2 downto 0);
	signal JOYSTICK_GND: std_logic;
	signal JOYSTICK2_GND: std_logic;

	
	procedure box(signal video : inout std_logic; x : signed; y : signed; xpos : integer; ypos : integer; value : std_logic) is
	begin
		if (abs(x - xpos) < 5) and (abs(y - ypos) < 5) and (value = '1') then
			video <= '1';
		elsif (abs(x - xpos) = 5) and (abs(y - ypos) < 5) then
			video <= '1';
		elsif (abs(x - xpos) < 5) and (abs(y - ypos) = 5) then
			video <= '1';
		end if;		
	end procedure;
begin

-- -----------------------------------------------------------------------
-- A2601 core
-- -----------------------------------------------------------------------
	a2601Instance : entity work.A2601NoFlash
		port map (
			vid_clk => vid_clk,
			audio => audio,
         O_VSYNC => O_VSYNC,
         O_HSYNC => O_HSYNC,
			O_VIDEO_R => O_VIDEO_R,
			O_VIDEO_G => O_VIDEO_G,
			O_VIDEO_B => O_VIDEO_B,
         res => res,
         p_l => p_l,
         p_r => p_r,
         p_a => p_a,
         p_u => p_u,
         p_d => p_d,
         p2_l => p2_l,
         p2_r => p2_r,
         p2_a => p2_a,
         p2_u => p2_u,
         p2_d => p2_d,
         p_s => p_s,
         p_bs => p_bs,
			LED => LED,
			I_SW => I_SW,
         JOYSTICK_GND => JOYSTICK_GND,
			JOYSTICK2_GND => JOYSTICK2_GND
		);

	process(red_reg, grn_reg, blu_reg)
	begin
		if true then
			red <= red_reg;
			grn <= grn_reg;
			blu <= blu_reg;
			nHSync <= not hsync;
			nVSync <= not vsync;
			sigmaL <= sigmaL_reg;
			sigmaR <= sigmaR_reg;
		else
			red <= unsigned(O_VIDEO_R) & "0";
			grn <= unsigned(O_VIDEO_G) & "0";
			blu <= unsigned(O_VIDEO_B) & "0";
			nHSync <= not hsync;
			nVSync <= not vsync;
			nHSync <= not O_HSYNC;
			nVSync <= not O_VSYNC;
			sigmaL <= audio;
			sigmaR <= audio;
		end if;
	end process;

	res <= '1';
	p_l <= docking_joystick1(0);
	p_r <= docking_joystick1(1);
	p_a <= docking_joystick1(2);
	p_u <= docking_joystick1(3);
	p_d <= docking_joystick1(4);
	p2_l <= docking_joystick2(0);
	p2_r <= docking_joystick2(1);
	p2_a <= docking_joystick2(2);
	p2_u <= docking_joystick2(3);
	p2_d <= docking_joystick2(4);
	p_s <= '1';
	p_bs <= '1';
	-- LED: std_logic_vector(2 downto 0);
	-- I_SW : std_logic_vector(2 downto 0);
	JOYSTICK_GND <= '0';
	JOYSTICK2_GND <= '0';

	
-- -----------------------------------------------------------------------
-- Clocks and PLL
-- -----------------------------------------------------------------------
	pllInstance : entity work.pll8
		port map (
			inclk0 => clk8,
			c0 => sysclk,
			c1 => open, 
			c2 => clk_150,
			c3 => sd_clk_loc,
			c4 => vid_clk,
			locked => clk_locked
		);
	sd_clk <= sd_clk_loc;

-- -----------------------------------------------------------------------
-- 1 Mhz and 1 Khz clocks
-- -----------------------------------------------------------------------
	my1Mhz : entity work.chameleon_1mhz
		generic map (
			clk_ticks_per_usec => 100
		)
		port map (
			clk => sysclk,
			ena_1mhz => ena_1mhz,
			ena_1mhz_2 => open
		);

	my1Khz : entity work.chameleon_1khz
		port map (
			clk => sysclk,
			ena_1mhz => ena_1mhz,
			ena_1khz => ena_1khz
		);


-- -----------------------------------------------------------------------
-- Sound test
-- -----------------------------------------------------------------------
	process(sysclk)
	begin
		if rising_edge(sysclk) then
			if ena_1khz = '1' then
				if (mouse_left_button = '1') or (usart_cts = '0') then
					sigma_l <= not sigma_l;
				end if;
				if (mouse_right_button = '1') or (reset_button_n = '0') then
					sigma_r <= not sigma_r;
				end if;
			end if;
		end if;
	end process;
	sigmaL_reg <= sigma_l;
	sigmaR_reg <= sigma_r;

	
-- -----------------------------------------------------------------------
-- Docking station
-- -----------------------------------------------------------------------
	myDockingStation : entity work.chameleon_docking_station
		port map (
			clk => sysclk,
			ena_1mhz => ena_1mhz,
			enable => docking_ena,
			
			docking_station => docking_station,
			
			dotclock_n => dotclock_n,
			io_ef_n => ioef_n,
			rom_lh_n => romlh_n,
			irq_d => irq_n,
			irq_q => docking_irq,
			
			joystick1 => docking_joystick1,
			joystick2 => docking_joystick2,
			joystick3 => docking_joystick3,
			joystick4 => docking_joystick4,
			keys => docking_keys,
			restore_key_n => docking_restore_n,
			
			amiga_power_led => led_green,
			amiga_drive_led => led_red,
			amiga_reset_n => docking_amiga_reset_n,
			amiga_scancode => docking_amiga_scancode
		);

-- -----------------------------------------------------------------------
-- MUX CPLD
-- -----------------------------------------------------------------------
	-- MUX clock
	process(sysclk)
	begin
		if rising_edge(sysclk) then
			mux_clk_reg <= not mux_clk_reg;
		end if;
	end process;

	-- MUX read
	process(sysclk)
	begin
		if rising_edge(sysclk) then
			if mux_clk_reg = '1' then
				case mux_reg is
				when X"6" =>
					irq_n <= mux_q(2);
				when X"B" =>
					reset_button_n <= mux_q(1);
					ir <= mux_q(3);
				when X"A" =>
					vga_id <= mux_q;
				when X"E" =>
					ps2_keyboard_dat_in <= mux_q(0);
					ps2_keyboard_clk_in <= mux_q(1);
					ps2_mouse_dat_in <= mux_q(2);
					ps2_mouse_clk_in <= mux_q(3);
				when others =>
					null;
				end case;
			end if;
		end if;
	end process;

	-- MUX write
	process(sysclk)
	begin
		if rising_edge(sysclk) then
			docking_ena <= '0';
			if mux_clk_reg = '1' then
				case mux_reg is
				when X"7" =>
					mux_d_reg <= "1111";
					if docking_station = '1' then
						mux_d_reg <= "1" & docking_irq & "11";
					end if;
					mux_reg <= X"6";
				when X"6" =>
					mux_d_reg <= "1111";
					mux_reg <= X"8";
				when X"8" =>
					mux_d_reg <= "1111";
					mux_reg <= X"A";
				when X"A" =>
					mux_d_reg <= "10" & led_green & led_red;
					mux_reg <= X"B";
				when X"B" =>
					mux_d_reg <= iec_reg;
					mux_reg <= X"D";
					docking_ena <= '1';
				when X"D" =>
					mux_d_reg(0) <= ps2_keyboard_dat_out;
					mux_d_reg(1) <= ps2_keyboard_clk_out;
					mux_d_reg(2) <= ps2_mouse_dat_out;
					mux_d_reg(3) <= ps2_mouse_clk_out;
					mux_reg <= X"E";
				when X"E" =>
					mux_d_reg <= "1111";
					mux_reg <= X"7";
				when others =>
					mux_reg <= X"B";
					mux_d_reg <= "10" & led_green & led_red;
				end case;
			end if;
		end if;
	end process;
	
	mux_clk <= mux_clk_reg;
	mux_d <= mux_d_reg;
	mux <= mux_reg;

-- -----------------------------------------------------------------------
-- LEDs
-- -----------------------------------------------------------------------
	myGreenLed : entity work.chameleon_led
		port map (
			clk => sysclk,
			clk_1khz => ena_1khz,
			led_on => '0',
			led_blink => '1',
			led => led_red,
			led_1hz => led_green
		);

-- -----------------------------------------------------------------------
-- VGA timing configured for 640x480
-- -----------------------------------------------------------------------
	myVgaMaster : entity work.video_vga_master
		generic map (
			clkDivBits => 4
		)
		port map (
			clk => sysclk,
			-- 100 Mhz / (3+1) = 25 Mhz
			clkDiv => X"3",

			hSync => hSync,
			vSync => vSync,

			endOfPixel => end_of_pixel,
			endOfLine => open,
			endOfFrame => open,
			currentX => currentX,
			currentY => currentY,

			-- Setup 640x480@60hz needs ~25 Mhz
			hSyncPol => '0',
			vSyncPol => '0',
			xSize => to_unsigned(800, 12),
			ySize => to_unsigned(525, 12),
			xSyncFr => to_unsigned(656, 12), -- Sync pulse 96
			xSyncTo => to_unsigned(752, 12),
			ySyncFr => to_unsigned(500, 12), -- Sync pulse 2
			ySyncTo => to_unsigned(502, 12)
		);

-- -----------------------------------------------------------------------
-- Show state of joysticks on docking-station
-- -----------------------------------------------------------------------
	process(sysclk) is
		variable x : signed(11 downto 0);
		variable y : signed(11 downto 0);
		variable joysticks : unsigned(23 downto 0);
	begin
		x := signed(currentX);
		y := signed(currentY);
		if rising_edge(sysclk) then
			joysticks := docking_joystick4 & docking_joystick3 & docking_joystick2 & docking_joystick1;
			video_joystick_shift_reg <= '0';
			for i in 0 to 23 loop
				if (abs(x - (144 + (i+i/6)*16)) < 5) and (abs(y - 320) < 5) and (joysticks(23-i) = '1') then
					video_joystick_shift_reg <= '1';
				elsif (abs(x - (144 + (i+i/6)*16)) = 5) and (abs(y - 320) < 5) then
					video_joystick_shift_reg <= '1';
				elsif (abs(x - (144 + (i+i/6)*16)) < 5) and (abs(y - 320) = 5) then
					video_joystick_shift_reg <= '1';
				end if;
			end loop;
		end if;
	end process;

-- -----------------------------------------------------------------------
-- VGA colors
-- -----------------------------------------------------------------------
	process(sysclk)
		variable x : signed(11 downto 0);
		variable y : signed(11 downto 0);
	begin
		x := signed(currentX);
		y := signed(currentY);
		if rising_edge(sysclk) then
			if end_of_pixel = '1' then
				red_reg <= (others => '0');
				grn_reg <= (others => '0');
				blu_reg <= (others => '0');
				if currentY < 256 then
					case currentX(11 downto 7) is
					when "00001" =>
						red_reg <= currentX(6 downto 2);
					when "00010" =>
						grn_reg <= currentX(6 downto 2);
					when "00011" =>
						blu_reg <= currentX(6 downto 2);
					when "00100" =>
						red_reg <= currentX(6 downto 2);
						grn_reg <= currentX(6 downto 2);
						blu_reg <= currentX(6 downto 2);
					when others =>
						null;
					end case;
				end if;
				
			-- Draw 3 push button tests
				if (abs(x - 64) < 7) and (abs(y - 64) < 7) and (usart_cts = '0') then
					blu_reg <= (others => '1');
				elsif (abs(x - 64) = 7) and (abs(y - 64) < 7) then
					blu_reg <= (others => '1');
				elsif (abs(x - 64) < 7) and (abs(y - 64) = 7) then
					blu_reg <= (others => '1');
				end if;

				if (abs(x - 96) < 7) and (abs(y - 64) < 7) and (freeze_n = '0') then
					blu_reg <= (others => '1');
				elsif (abs(x - 96) = 7) and (abs(y - 64) < 7) then
					blu_reg <= (others => '1');
				elsif (abs(x - 96) < 7) and (abs(y - 64) = 7) then
					blu_reg <= (others => '1');
				end if;

				if (abs(x - 128) < 7) and (abs(y - 64) < 7) and (reset_button_n = '0') then
					blu_reg <= (others => '1');
				elsif (abs(x - 128) = 7) and (abs(y - 64) < 7) then
					blu_reg <= (others => '1');
				elsif (abs(x - 128) < 7) and (abs(y - 64) = 7) then
					blu_reg <= (others => '1');
				end if;

			-- Draw mouse button tests
				if (abs(x - 64) < 7) and (abs(y - 128) < 7) and (mouse_left_button = '1') then
					red_reg <= (others => '1');
					grn_reg <= (others => '1');
				elsif (abs(x - 64) = 7) and (abs(y - 128) < 7) then
					red_reg <= (others => '1');
					grn_reg <= (others => '1');
				elsif (abs(x - 64) < 7) and (abs(y - 128) = 7) then
					red_reg <= (others => '1');
					grn_reg <= (others => '1');
				end if;

				if (abs(x - 96) < 7) and (abs(y - 128) < 7) and (mouse_middle_button = '1') then
					red_reg <= (others => '1');
					grn_reg <= (others => '1');
				elsif (abs(x - 96) = 7) and (abs(y - 128) < 7) then
					red_reg <= (others => '1');
					grn_reg <= (others => '1');
				elsif (abs(x - 96) < 7) and (abs(y - 128) = 7) then
					red_reg <= (others => '1');
					grn_reg <= (others => '1');
				end if;

				if (abs(x - 128) < 7) and (abs(y - 128) < 7) and (mouse_right_button = '1') then
					red_reg <= (others => '1');
					grn_reg <= (others => '1');
				elsif (abs(x - 128) = 7) and (abs(y - 128) < 7) then
					red_reg <= (others => '1');
					grn_reg <= (others => '1');
				elsif (abs(x - 128) < 7) and (abs(y - 128) = 7) then
					red_reg <= (others => '1');
					grn_reg <= (others => '1');
				end if;
			
			-- clock
				if (abs(x - 64) < 7) and (abs(y - 192) < 7) and (no_clock = '0') then
					grn_reg <= (others => '1');
				elsif (abs(x - 64) = 7) and (abs(y - 192) < 7) then
					grn_reg <= (others => '1');
				elsif (abs(x - 64) < 7) and (abs(y - 192) = 7) then
					grn_reg <= (others => '1');
				end if;

			-- docking station
				if (abs(x - 96) < 7) and (abs(y - 192) < 7) and (docking_station = '1') then
					grn_reg <= (others => '1');
				elsif (abs(x - 96) = 7) and (abs(y - 192) < 7) then
					grn_reg <= (others => '1');
				elsif (abs(x - 96) < 7) and (abs(y - 192) = 7) then
					grn_reg <= (others => '1');
				end if;
				
			-- Draw joystick status
				if docking_station = '1' then
					if video_joystick_shift_reg = '1'
					or video_keyboard_reg = '1'
					or video_amiga = '1' then
						red_reg <= (others => '1');
						grn_reg <= (others => '1');
						blu_reg <= (others => '1');
					end if;
				end if;
				
			-- Draw mouse cursor
				if mouse_present = '1' then
					if (abs(x - cursor_x) < 5) and (abs(y - cursor_y) < 5) then
						red_reg <= (others => '1');
						grn_reg <= (others => '1');
						blu_reg <= (others => '0');
					end if;
				end if;

			--
			-- One pixel border around the screen
				if (currentX = 0) or (currentX = 639) or (currentY =0) or (currentY = 479) then
					red_reg <= (others => '1');
					grn_reg <= (others => '1');
					blu_reg <= (others => '1');
				end if;
			--
			-- Never draw pixels outside the visual area
				if (currentX >= 640) or (currentY >= 480) then
					red_reg <= (others => '0');
					grn_reg <= (others => '0');
					blu_reg <= (others => '0');
				end if;
			end if;
		end if;
	end process;

end architecture;
