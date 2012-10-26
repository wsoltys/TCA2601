-- Port of the A2601 FPGA implementation for the Turbo Chameleon

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- -----------------------------------------------------------------------

entity main is
	port (
-- Clocks
		clk8 : in std_logic;
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
	signal vid_clk: std_logic := '0';
	signal sysclk : std_logic := '0';
	signal clk_locked : std_logic := '0';
	signal ena_1mhz : std_logic := '0';
	signal ena_1khz : std_logic := '0';

	signal reset_button_n : std_logic := '0';
	
-- Global signals
	signal reset : std_logic := '0';
	signal end_of_pixel : std_logic := '0';

-- RAM Test
	signal state : state_t := TEST_IDLE;
	signal noise_bits : unsigned(7 downto 0) := (others => '0');
	
-- MUX
	signal mux_clk_reg : std_logic := '0';
	signal mux_reg : unsigned(3 downto 0) := (others => '1');
	signal mux_d_reg : unsigned(3 downto 0) := (others => '1');

-- 4 Port joystick adapter
	signal video_joystick_shift_reg : std_logic := '0';

-- LEDs
	signal led_green : std_logic := '0';
	signal led_red : std_logic := '0';

-- VGA
	signal currentX : unsigned(11 downto 0) := (others => '0');
	signal currentY : unsigned(11 downto 0) := (others => '0');
	signal hsync : std_logic := '0';
	signal vsync : std_logic := '0';
	
	signal red_reg : unsigned(4 downto 0) := (others => '0');
	signal grn_reg : unsigned(4 downto 0) := (others => '0');
	signal blu_reg : unsigned(4 downto 0) := (others => '0');
	
-- Sound
	signal sigma_l : std_logic := '0';
	signal sigma_r : std_logic := '0';
	signal sigmaL_reg : std_logic := '0';
	signal sigmaR_reg : std_logic := '0';

-- Docking station
	signal docking_ena : std_logic := '0';
	signal docking_irq : std_logic := '0';
	signal irq_n : std_logic := '0';
	
	signal docking_joystick1 : unsigned(5 downto 0) := (others => '0');
	signal docking_joystick2 : unsigned(5 downto 0) := (others => '0');
	signal docking_joystick3 : unsigned(5 downto 0) := (others => '0');
	signal docking_joystick4 : unsigned(5 downto 0) := (others => '0');
	
-- A2601
	signal audio: std_logic := '0';
   signal O_VSYNC: std_logic := '0';
   signal O_HSYNC: std_logic := '0';
	signal O_VIDEO_R: std_logic_vector(3 downto 0) := (others => '0');
	signal O_VIDEO_G: std_logic_vector(3 downto 0) := (others => '0');
	signal O_VIDEO_B: std_logic_vector(3 downto 0) := (others => '0');			
	signal res: std_logic := '0';
	signal p_l: std_logic := '0';
	signal p_r: std_logic := '0';
	signal p_a: std_logic := '0';
	signal p_u: std_logic := '0';
	signal p_d: std_logic := '0';
	signal p2_l: std_logic := '0';
	signal p2_r: std_logic := '0';
	signal p2_a: std_logic := '0';
	signal p2_u: std_logic := '0';
	signal p2_d: std_logic := '0';
	signal p_s: std_logic := '0';
--	signal p_bs: std_logic;
--	signal LED: std_logic_vector(2 downto 0);
--	signal I_SW : std_logic_vector(2 downto 0) := (others => '0');
--	signal JOYSTICK_GND: std_logic;
--	signal JOYSTICK2_GND: std_logic;

	
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
         p_bs => open,
			LED => open,
			I_SW => "111",
         JOYSTICK_GND => open,
			JOYSTICK2_GND => open
		);

	process(red_reg, grn_reg, blu_reg, O_VIDEO_R, O_VIDEO_G, O_VIDEO_B, O_HSYNC, O_VSYNC, audio)
	begin
		if false then
			-- VGA test
			red <= red_reg;
			grn <= grn_reg;
			blu <= blu_reg;
			nHSync <= not hsync;
			nVSync <= not vsync;
			sigmaL <= sigmaL_reg;
			sigmaR <= sigmaR_reg;
		else
			-- A2601
			red <= unsigned(O_VIDEO_R) & "0";
			grn <= unsigned(O_VIDEO_G) & "0";
			blu <= unsigned(O_VIDEO_B) & "0";
			nHSync <= not O_HSYNC;
			nVSync <= not O_VSYNC;
			sigmaL <= audio;
			sigmaR <= audio;
		end if;
	end process;

	res <= clk_locked;
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
	-- p_bs <= '1';
	-- LED: std_logic_vector(2 downto 0);
	-- I_SW <= '0'
	-- JOYSTICK_GND <= '0';
	-- JOYSTICK2_GND <= '0';

	
-- -----------------------------------------------------------------------
-- Clocks and PLL
-- -----------------------------------------------------------------------
	pllInstance : entity work.pll8
		port map (
			inclk0 => clk8,
			c0 => sysclk,
			c1 => open, 
			c2 => open,
			c3 => open,
			c4 => vid_clk,
			locked => clk_locked
		);

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
				sigma_l <= not sigma_l;
				sigma_r <= not sigma_r;
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
			
			docking_station => '1',
			
			dotclock_n => dotclock_n,
			io_ef_n => ioef_n,
			rom_lh_n => romlh_n,
			irq_d => irq_n,
			irq_q => docking_irq,
			
			joystick1 => docking_joystick1,
			joystick2 => docking_joystick2,
			joystick3 => docking_joystick3,
			joystick4 => docking_joystick4,
			keys => open,
			restore_key_n => open,
			
			amiga_power_led => led_green,
			amiga_drive_led => led_red,
			amiga_reset_n => open,
			amiga_scancode => open
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
					mux_d_reg <= "1" & docking_irq & "11";
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
					mux_reg <= X"E";
					docking_ena <= '1';
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
	process(sysclk, currentX, currentY) is
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

			-- docking station
				if (abs(x - 96) < 7) and (abs(y - 192) < 7) then
					grn_reg <= (others => '1');
				elsif (abs(x - 96) = 7) and (abs(y - 192) < 7) then
					grn_reg <= (others => '1');
				elsif (abs(x - 96) < 7) and (abs(y - 192) = 7) then
					grn_reg <= (others => '1');
				end if;
				
			-- Draw joystick status
				if video_joystick_shift_reg = '1' then
					red_reg <= (others => '1');
					grn_reg <= (others => '1');
					blu_reg <= (others => '1');
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
