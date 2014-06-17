-- Port of the A2601 FPGA implementation for the Turbo Chameleon

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- -----------------------------------------------------------------------

entity main is
	port (
-- Clock
		CLOCK_27 : in std_logic_vector(1 downto 0);
		
-- SPI
		SPI_SCK : in std_logic;
		SPI_DI : in std_logic;
		SPI_DO : out std_logic;
    SPI_SS3 : in std_logic;
		CONF_DATA0 : in std_logic;
		
-- LED
		LED : out std_logic;

-- Video
		VGA_R : out std_logic_vector(5 downto 0);
		VGA_G : out std_logic_vector(5 downto 0);
		VGA_B : out std_logic_vector(5 downto 0);
		VGA_HS : out std_logic;
		VGA_VS : out std_logic;

-- Audio
    AUDIO_L : out std_logic;
    AUDIO_R : out std_logic;
    
-- SDRAM
    SDRAM_nCAS : out std_logic
	);
end entity;

-- -----------------------------------------------------------------------

architecture rtl of main is
	
-- System clocks
	signal vid_clk: std_logic := '0';
	signal sysclk : std_logic := '0';
  signal osd_clk : std_logic := '0';

	signal reset_button_n : std_logic := '0';
	
-- Global signals
	signal reset : std_logic := '0';
	
-- A2601
	signal audio: std_logic := '0';
  signal O_VSYNC: std_logic := '0';
  signal O_HSYNC: std_logic := '0';
	signal O_VIDEO_R: std_logic_vector(5 downto 0) := (others => '0');
	signal O_VIDEO_G: std_logic_vector(5 downto 0) := (others => '0');
	signal O_VIDEO_B: std_logic_vector(5 downto 0) := (others => '0');			
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
	signal p_start: std_logic := '0';
	signal p_select: std_logic := '0';
	signal next_cartridge: std_logic := '0';
--	signal p_bs: std_logic;
--	signal LED: std_logic_vector(2 downto 0);
--	signal I_SW : std_logic_vector(2 downto 0) := (others => '0');
--	signal JOYSTICK_GND: std_logic;
--	signal JOYSTICK2_GND: std_logic;

-- User IO
  signal switches : std_logic_vector(1 downto 0);
	signal buttons  : std_logic_vector(1 downto 0);
  signal joy0     : std_logic_vector(5 downto 0);
  signal joy1     : std_logic_vector(5 downto 0);

component user_io
	port (  SPI_CLK, SPI_SS_IO, SPI_MOSI :in std_logic;
          SPI_MISO : out std_logic;
          SWITCHES : out std_logic_vector(1 downto 0);
          BUTTONS : out std_logic_vector(1 downto 0);
          CORE_TYPE : in std_logic_vector(7 downto 0);
          JOY0 : out std_logic_vector(5 downto 0);
          JOY1 : out std_logic_vector(5 downto 0)
       );
  end component user_io;
  
component osd
  port (
          pclk, sck, ss, sdi, hs_in, vs_in : in std_logic;
          red_in, blue_in, green_in : in std_logic_vector(5 downto 0);
          red_out, blue_out, green_out : out std_logic_vector(5 downto 0);
          hs_out, vs_out : out std_logic
       );
end component osd;

begin

-- -----------------------------------------------------------------------
-- MiST
-- -----------------------------------------------------------------------

SDRAM_nCAS <= '1'; -- disable ram



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
          p_start => p_start,
          p_select => p_select,
          next_cartridge => '0', --next_cartridge,
          p_bs => open,
          LED => open,
          I_SW => "111",
          JOYSTICK_GND => open,
          JOYSTICK2_GND => open
		);

  -- A2601 -> OSD
  osd_inst : osd
      port map (
          pclk => osd_clk,
          sdi => SPI_DI,
          sck => SPI_SCK,
          ss => SPI_SS3,
          red_in => O_VIDEO_R,
          green_in => O_VIDEO_G,
          blue_in => O_VIDEO_B,
          hs_in => not O_HSYNC,
          vs_in => not O_VSYNC,
          red_out => VGA_R,
          green_out => VGA_G,
          blue_out => VGA_B,
          hs_out => VGA_HS,
          vs_out => VGA_VS
      );
      
  AUDIO_L <= audio;
  AUDIO_R <= audio;
			
	res <= '0';

	-- 9 pin d-sub joystick pinout:
	-- pin 1: up
	-- pin 2: down
	-- pin 3: left
	-- pin 4: right
	-- pin 6: fire
	
	-- Atari 2600, 6532 ports:
	-- PA0: right joystick, up
	-- PA1: right joystick, down
	-- PA2: right joystick, left
	-- PA3: right joystick, right
	-- PA4: left joystick, up
	-- PA5: left joystick, down
	-- PA6: left joystick, left
	-- PA7: left joystick, right
	-- PB0: start
	-- PB1: select
	-- PB3: B/W, color
	-- PB6: left difficulty
	-- PB7: right difficulty

	-- Atari 2600, TIA input:
	-- I5: right joystick, fire
	-- I6: left joystick, fire
	
	-- pinout docking station joystick 1/2:
	-- bit 0: up
	-- bit 1: down
	-- bit 2: left
	-- bit 3: right
	-- bit 4: fire
	p_l <= not joy0(1);
	p_r <= not joy0(0);
	p_a <= not joy0(4);
	p_u <= not joy0(3);
	p_d <= not joy0(2);

	p2_l <= not joy1(1);
	p2_r <= not joy1(0);
	p2_a <= not joy1(4);
	p2_u <= not joy1(3);
	p2_d <= not joy1(2);
	p_start <= not buttons(1);
	p_select <= not buttons(0);
	--next_cartridge <= reset_button_n;
--	p_s <= freeze_n;
	-- p_bs <= '1';
	-- LED: std_logic_vector(2 downto 0);
	-- I_SW <= '0'
	-- JOYSTICK_GND <= '0';
	-- JOYSTICK2_GND <= '0';

	
-- -----------------------------------------------------------------------
-- Clocks and PLL
-- -----------------------------------------------------------------------
  pllInstance : entity work.pll27
    port map (
      inclk0 => CLOCK_27(0),
      c0 => sysclk,
      c4 => vid_clk,
      locked => open
    );
    
  pllosd : entity work.clk_div
    generic map (
      scale_factor => 2
    )
    port map (
      clk_in => vid_clk,
      reset => '0',
      clk_out => osd_clk
    );

-- ------------------------------------------------------------------------
-- User IO
-- ------------------------------------------------------------------------

user_io_inst : user_io
	port map
	(
		SPI_CLK => SPI_SCK,
		SPI_SS_IO => CONF_DATA0,
		SPI_MOSI => SPI_DI,
		SPI_MISO => SPI_DO,
		SWITCHES => switches,
		BUTTONS  => buttons,
    JOY0 => joy0,
    JOY1 => joy1,
		CORE_TYPE => X"a4"
	);

end architecture;
