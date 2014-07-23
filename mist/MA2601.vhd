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
  signal p_u: std_logic := '0';
  signal p_d: std_logic := '0';
  signal p2_l: std_logic := '0';
  signal p2_r: std_logic := '0';
  signal p2_a: std_logic := '0';
  signal p2_u: std_logic := '0';
  signal p2_d: std_logic := '0';
  signal p_start: std_logic := '1';
  signal p_select: std_logic := '1';
  signal p_color: std_logic := '1';
  signal pal: std_logic := '0';
  signal p_dif: std_logic_vector(1 downto 0) := (others => '0');

-- User IO
  signal switches   : std_logic_vector(1 downto 0);
  signal buttons    : std_logic_vector(1 downto 0);
  signal joy0       : std_logic_vector(5 downto 0);
  signal joy1       : std_logic_vector(5 downto 0);
  signal status     : std_logic_vector(7 downto 0);
  signal ascii_new  : std_logic;
  signal ascii_code : STD_LOGIC_VECTOR(6 DOWNTO 0);
  signal clk12k     : std_logic;
  signal ps2Clk     : std_logic;
  signal ps2Data    : std_logic;
  signal ps2_scancode : std_logic_vector(7 downto 0);

  component user_io_w
    port (
      SPI_CLK, SPI_SS_IO, SPI_MOSI :in std_logic;
      SPI_MISO : out std_logic;
      SWITCHES : out std_logic_vector(1 downto 0);
      BUTTONS : out std_logic_vector(1 downto 0);
      JOY0 : out std_logic_vector(5 downto 0);
      JOY1 : out std_logic_vector(5 downto 0);
      status : out std_logic_vector(7 downto 0);
      clk : in std_logic;
      ps2_clk : out std_logic;
      ps2_data : out std_logic
    );
  end component user_io_w;

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
  res <= status(0);
  p_color <= not status(2);
  pal <= status(1);
  p_dif(0) <= status(3);
  p_dif(1) <= status(4);

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
      p_color => p_color,
      next_cartridge => '0', --next_cartridge,
      p_bs => open,
      LED => open,
      I_SW => "111",
      JOYSTICK_GND => open,
      JOYSTICK2_GND => open,
      sdi => SPI_DI,
      sck => SPI_SCK,
      ss2 => SPI_SS2,
      pal => pal,
      p_dif => p_dif
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


-- -----------------------------------------------------------------------
-- Clocks and PLL
-- -----------------------------------------------------------------------
  pllInstance : entity work.pll27
    port map (
      inclk0 => CLOCK_27(0),
      c0 => vid_clk,
      c1 => clk12k,
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

  user_io_inst : user_io_w
    port map (
      SPI_CLK => SPI_SCK,
      SPI_SS_IO => CONF_DATA0,
      SPI_MOSI => SPI_DI,
      SPI_MISO => SPI_DO,
      SWITCHES => switches,
      BUTTONS  => buttons,
      JOY0 => joy0,
      JOY1 => joy1,
      status => status,
      clk => clk12k,
      ps2_clk => ps2Clk,
      ps2_data => ps2Data
    );

  keyboard : entity work.ps2Keyboard
    port map (vid_clk, '0', ps2Clk, ps2data, ps2_scancode);

  
  p_start <= '0' when (ps2_scancode = X"01" or buttons(1) = '1') else '1'; -- F9 or MiST right button
  p_select <= '0' when (ps2_scancode = X"09") else '1'; -- F10

  LED <= not p_color; -- yellow led is bright when color mode is selected

end architecture;
