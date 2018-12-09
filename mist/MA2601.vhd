--
-- MA2601.vhd
--
-- Atari VCS 2600 toplevel for the MiST board
-- https://github.com/wsoltys/tca2601
--
-- Copyright (c) 2014 W. Soltys <wsoltys@gmail.com>
--
-- This source file is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This source file is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- -----------------------------------------------------------------------

entity MA2601 is
    port (
    
-- Clock
      CLOCK_27 : in std_logic_vector(1 downto 0);

-- SPI
      SPI_SCK : in std_logic;
      SPI_DI : in std_logic;
      SPI_DO : out std_logic;
      SPI_SS2 : in std_logic;
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

architecture rtl of MA2601 is

-- System clocks
  signal vid_clk: std_logic := '0';
  signal osd_clk : std_logic := '0';

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
  signal p_b: std_logic := '0';
  signal p_u: std_logic := '0';
  signal p_d: std_logic := '0';
  signal p2_l: std_logic := '0';
  signal p2_r: std_logic := '0';
  signal p2_a: std_logic := '0';
  signal p2_b: std_logic := '0';
  signal p2_u: std_logic := '0';
  signal p2_d: std_logic := '0';
  signal p_start: std_logic := '1';
  signal p_select: std_logic := '1';
  signal p_color: std_logic := '1';
  signal pal: std_logic := '0';
  signal p_dif: std_logic_vector(1 downto 0) := (others => '0');
  signal tv15khz: std_logic := '0';

-- User IO
  signal switches   : std_logic_vector(1 downto 0);
  signal buttons    : std_logic_vector(1 downto 0);
  signal joy0       : std_logic_vector(7 downto 0);
  signal joy1       : std_logic_vector(7 downto 0);
  signal joy_a_0    : std_logic_vector(15 downto 0);
  signal joy_a_1    : std_logic_vector(15 downto 0);
  signal status     : std_logic_vector(7 downto 0);
  signal ascii_new  : std_logic;
  signal ascii_code : STD_LOGIC_VECTOR(6 DOWNTO 0);
  signal ps2Clk     : std_logic;
  signal ps2Data    : std_logic;
  signal ps2_scancode : std_logic_vector(7 downto 0);
  signal scandoubler_disable : std_logic;

  signal vga_vsync_i : std_logic;
  signal vga_hsync_i : std_logic;

  
  -- config string used by the io controller to fill the OSD
  constant CONF_STR : string := "MA2601;A26BIN;O1,Video standard,NTSC,PAL;O2,Video mode,Color,B&W;O3,Difficulty P1,A,B;O4,Difficulty P2,A,B;O5,Controller,Joystick,Paddle;O6,Enable Scanlines,no,yes;";

  function to_slv(s: string) return std_logic_vector is
    constant ss: string(1 to s'length) := s;
    variable rval: std_logic_vector(1 to 8 * s'length);
    variable p: integer;
    variable c: integer;
  
  begin  
    for i in ss'range loop
      p := 8 * i;
      c := character'pos(ss(i));
      rval(p - 7 to p) := std_logic_vector(to_unsigned(c,8));
    end loop;
    return rval;

  end function;
  
  component user_io
	 generic ( STRLEN : integer := 0 );
    port (
      clk_sys: in std_logic;
      SPI_CLK, SPI_SS_IO, SPI_MOSI :in std_logic;
      SPI_MISO : out std_logic;
      conf_str : in std_logic_vector(8*STRLEN-1 downto 0);
      switches : out std_logic_vector(1 downto 0);
      buttons : out std_logic_vector(1 downto 0);
      scandoubler_disable : out std_logic;
      joystick_0 : out std_logic_vector(7 downto 0);
      joystick_1 : out std_logic_vector(7 downto 0);
      joystick_analog_0 : out std_logic_vector(15 downto 0);
      joystick_analog_1 : out std_logic_vector(15 downto 0);
      status : out std_logic_vector(7 downto 0);
      sd_sdhc : in std_logic;
      ps2_kbd_clk : out std_logic;
      ps2_kbd_data : out std_logic
    );
  end component user_io;

  component osd
    port (
      pclk, sck, ss, sdi, hs_in, vs_in, scanline_ena_h : in std_logic;
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
  res <= status(0);
  p_color <= not status(2);
  pal <= status(1);
  p_dif(0) <= not status(3);
  p_dif(1) <= not status(4);

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
      p_b => p_b,
      p_u => p_u,
      p_d => p_d,
      p2_l => p2_l,
      p2_r => p2_r,
      p2_a => p2_a,
      p2_b => p2_b,
      p2_u => p2_u,
      p2_d => p2_d,
      paddle_0 => joy_a_0(15 downto 8),
      paddle_1 => joy_a_0(7 downto 0),
      paddle_2 => joy_a_1(15 downto 8),
      paddle_3 => joy_a_1(7 downto 0),
      paddle_ena => status(5),
      p_start => p_start,
      p_select => p_select,
      p_color => p_color,
      sdi => SPI_DI,
      sck => SPI_SCK,
      ss2 => SPI_SS2,
      pal => pal,
      p_dif => p_dif,
      tv15khz => tv15khz
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
      scanline_ena_h => status(6),
      red_out => VGA_R,
      green_out => VGA_G,
      blue_out => VGA_B,
      hs_out => vga_hsync_i,
      vs_out => vga_vsync_i
    );

  AUDIO_L <= audio;
  AUDIO_R <= audio;

  -- Create composite sync and high vsync if using tv15khz.
  VGA_HS <= not (vga_hsync_i xor vga_vsync_i) when tv15khz='1' else vga_hsync_i;
  VGA_VS <= '1' when tv15khz='1' else vga_vsync_i;

	 

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
  -- bit 5: 2nd fire (required for paddle emulation)
  p_l <= not joy0(1);
  p_r <= not joy0(0);
  p_a <= not joy0(4);
  p_b <= not joy0(5);
  p_u <= not joy0(3);
  p_d <= not joy0(2);

  p2_l <= not joy1(1);
  p2_r <= not joy1(0);
  p2_a <= not joy1(4);
  p2_b <= not joy1(5);
  p2_u <= not joy1(3);
  p2_d <= not joy1(2);


-- -----------------------------------------------------------------------
-- Clocks and PLL
-- -----------------------------------------------------------------------
  pllInstance : entity work.pll27
    port map (
      inclk0 => CLOCK_27(0),
      c0 => vid_clk,
      locked => open
    );

  pllosd : entity work.clk_div
    generic map (
      DIVISOR => 4
    )
    port map (
      clk    => vid_clk,
      reset  => '0',
      clk_en => osd_clk
    );

-- ------------------------------------------------------------------------
-- User IO
-- ------------------------------------------------------------------------

  user_io_inst : user_io
 	generic map (STRLEN => CONF_STR'length)
   port map (
      clk_sys => vid_clk,
      SPI_CLK => SPI_SCK,
      SPI_SS_IO => CONF_DATA0,
      SPI_MOSI => SPI_DI,
      SPI_MISO => SPI_DO,
		conf_str => to_slv(CONF_STR),
      switches => switches,
      buttons  => buttons,
		scandoubler_disable => tv15khz,
      joystick_1 => joy0,
      joystick_0 => joy1,
      joystick_analog_1 => joy_a_0,
      joystick_analog_0 => joy_a_1,
      status => status,
      sd_sdhc => '1',
      ps2_kbd_clk => ps2Clk,
      ps2_kbd_data => ps2Data
    );

  keyboard : entity work.ps2Keyboard
    port map (vid_clk, '0', ps2Clk, ps2data, ps2_scancode);

  -- if a gamepad has 4 buttons then buttons 3 and 4 are mapped to start and select
  p_start <= '0' when (ps2_scancode = X"01" or buttons(1) = '1' or joy0(7) = '1' or joy1(7) = '1' ) else '1'; -- F9 or MiST right button
  p_select <= '0' when (ps2_scancode = X"09" or joy0(6) = '1' or joy1(6) = '1' ) else '1'; -- F10

  LED <= not p_color; -- yellow led is bright when color mode is selected

end architecture;
