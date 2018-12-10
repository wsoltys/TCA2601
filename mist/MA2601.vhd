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
  signal vid_clk: std_logic := '0'; -- 28 MHz
  signal clk : std_logic; -- 3.5 MHz

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
  signal sc: std_logic := '0';
  signal pal: std_logic := '0';
  signal p_dif: std_logic_vector(1 downto 0) := (others => '0');

-- User IO
  signal switches   : std_logic_vector(1 downto 0);
  signal buttons    : std_logic_vector(1 downto 0);
  signal joy0       : std_logic_vector(7 downto 0);
  signal joy1       : std_logic_vector(7 downto 0);
  signal joy_a_0    : std_logic_vector(15 downto 0);
  signal joy_a_1    : std_logic_vector(15 downto 0);
  signal status     : std_logic_vector(31 downto 0);
  signal ascii_new  : std_logic;
  signal ascii_code : STD_LOGIC_VECTOR(6 DOWNTO 0);
  signal ps2Clk     : std_logic;
  signal ps2Data    : std_logic;
  signal ps2_scancode : std_logic_vector(7 downto 0);
  signal scandoubler_disable : std_logic;
  signal ypbpr      : std_logic;

-- Data IO
  signal downl      : std_logic;
  signal index      : std_logic_vector(7 downto 0);
  signal rom_a      : std_logic_vector(14 downto 0);
  signal rom_do     : std_logic_vector(7 downto 0);
  signal rom_size   : std_logic_vector(15 downto 0);

-- Video 
  signal sd_r         : std_logic_vector(5 downto 0);
  signal sd_g         : std_logic_vector(5 downto 0);
  signal sd_b         : std_logic_vector(5 downto 0);
  signal sd_hs        : std_logic;
  signal sd_vs        : std_logic;

  signal osd_red_i    : std_logic_vector(5 downto 0);
  signal osd_green_i  : std_logic_vector(5 downto 0);
  signal osd_blue_i   : std_logic_vector(5 downto 0);
  signal osd_vs_i     : std_logic;
  signal osd_hs_i     : std_logic;
  signal osd_red_o    : std_logic_vector(5 downto 0);
  signal osd_green_o  : std_logic_vector(5 downto 0);
  signal osd_blue_o   : std_logic_vector(5 downto 0);
  signal vga_y_o      : std_logic_vector(5 downto 0);
  signal vga_pb_o     : std_logic_vector(5 downto 0);
  signal vga_pr_o     : std_logic_vector(5 downto 0);
  signal vga_vsync_i  : std_logic;
  signal vga_hsync_i  : std_logic;

  -- config string used by the io controller to fill the OSD
  constant CONF_STR : string :=
    "MA2601;A26BIN;"&
    "F,A26BIN,Load SuperChip;"&
    "O1,Video standard,NTSC,PAL;"&
    "O2,Video mode,Color,B&W;"&
    "O3,Difficulty P1,A,B;"&
    "O4,Difficulty P2,A,B;"&
    "O5,Controller,Joystick,Paddle;"&
    "O67,Scanlines,Off,25%,50%,75%;";

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
      ypbpr : out std_logic;
      joystick_0 : out std_logic_vector(7 downto 0);
      joystick_1 : out std_logic_vector(7 downto 0);
      joystick_analog_0 : out std_logic_vector(15 downto 0);
      joystick_analog_1 : out std_logic_vector(15 downto 0);
      status : out std_logic_vector(31 downto 0);
      sd_sdhc : in std_logic;
      ps2_kbd_clk : out std_logic;
      ps2_kbd_data : out std_logic
    );
  end component user_io;

  component data_io is
    port(sck: in std_logic;
        ss: in std_logic;
        sdi: in std_logic;
        downloading: out std_logic;
        size: out std_logic_vector(15 downto 0);
        index: out std_logic_vector(7 downto 0);
        clk: in std_logic;
        we: in std_logic;
        a: in std_logic_vector(14 downto 0);
        din: in std_logic_vector(7 downto 0);
        dout: out std_logic_vector(7 downto 0));
    end component;

  component scandoubler
    port (
            clk_sys     : in std_logic;
            scanlines   : in std_logic_vector(1 downto 0);

            hs_in       : in std_logic;
            vs_in       : in std_logic;
            r_in        : in std_logic_vector(5 downto 0);
            g_in        : in std_logic_vector(5 downto 0);
            b_in        : in std_logic_vector(5 downto 0);
      
            hs_out      : out std_logic;
            vs_out      : out std_logic;
            r_out       : out std_logic_vector(5 downto 0);
            g_out       : out std_logic_vector(5 downto 0);
            b_out       : out std_logic_vector(5 downto 0)
        );
  end component scandoubler;

  component osd
         generic ( OSD_COLOR : integer := 1 );  -- blue
    port (  clk_sys     : in std_logic;
        
            R_in        : in std_logic_vector(5 downto 0);
            G_in        : in std_logic_vector(5 downto 0);
            B_in        : in std_logic_vector(5 downto 0);
            HSync       : in std_logic;
            VSync       : in std_logic;

            R_out       : out std_logic_vector(5 downto 0);
            G_out       : out std_logic_vector(5 downto 0);
            B_out       : out std_logic_vector(5 downto 0);
        
            SPI_SCK     : in std_logic;
            SPI_SS3     : in std_logic;
            SPI_DI      : in std_logic
        );
    end component osd;
        
  COMPONENT rgb2ypbpr
        PORT
        (
        red     :        IN std_logic_vector(5 DOWNTO 0);
        green   :        IN std_logic_vector(5 DOWNTO 0);
        blue    :        IN std_logic_vector(5 DOWNTO 0);
        y       :        OUT std_logic_vector(5 DOWNTO 0);
        pb      :        OUT std_logic_vector(5 DOWNTO 0);
        pr      :        OUT std_logic_vector(5 DOWNTO 0)
        );
  END COMPONENT;

begin

-- -----------------------------------------------------------------------
-- MiST
-- -----------------------------------------------------------------------

  SDRAM_nCAS <= '1'; -- disable ram
  res <= status(0) or buttons(1) or downl;
  p_color <= not status(2);
  pal <= status(1);
  p_dif(0) <= not status(3);
  p_dif(1) <= not status(4);
  sc <= index(1); -- 2nd menu index - load with SuperChip support
-- -----------------------------------------------------------------------
-- A2601 core
-- -----------------------------------------------------------------------
  a2601Instance : entity work.A2601NoFlash
    port map (
      vid_clk => vid_clk,
      clk => clk,
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
      sc => sc,
      rom_a => rom_a,
      rom_do => rom_do,
      rom_size => rom_size,
      pal => pal,
      p_dif => p_dif,
      tv15khz => '1'
    );

  scandoubler_inst: scandoubler
    port map (
        clk_sys     => vid_clk,
        scanlines   => status(7 downto 6),

        hs_in       => not O_HSYNC,
        vs_in       => not O_VSYNC,
        r_in        => O_VIDEO_R,
        g_in        => O_VIDEO_G,
        b_in        => O_VIDEO_B,
    
        hs_out      => sd_hs,
        vs_out      => sd_vs,
        r_out       => sd_r,
        g_out       => sd_g,
        b_out       => sd_b
    );

  osd_inst: osd
    port map (
        clk_sys     => vid_clk,
  
        SPI_SCK     => SPI_SCK,
        SPI_SS3     => SPI_SS3,
        SPI_DI      => SPI_DI,
      
        R_in        => osd_red_i,
        G_in        => osd_green_i,
        B_in        => osd_blue_i,
        HSync       => osd_hs_i,
        VSync       => osd_vs_i,
      
        R_out       => osd_red_o,
        G_out       => osd_green_o,
        B_out       => osd_blue_o
    );

--
  rgb2component: component rgb2ypbpr
        port map
        (
           red => osd_red_o,
           green => osd_green_o,
           blue => osd_blue_o,
           y => vga_y_o,
           pb => vga_pb_o,
           pr => vga_pr_o
        );


  AUDIO_L <= audio;
  AUDIO_R <= audio;

  -- Create composite sync and high vsync if using tv15khz.
  osd_red_i   <= O_VIDEO_R when scandoubler_disable = '1' else sd_r;
  osd_green_i <= O_VIDEO_G when scandoubler_disable = '1' else sd_g;
  osd_blue_i  <= O_VIDEO_B when scandoubler_disable = '1' else sd_b;
  osd_hs_i    <= O_HSYNC when scandoubler_disable = '1' else sd_hs;
  osd_vs_i    <= O_VSYNC when scandoubler_disable = '1' else sd_vs;

  -- If 15kHz Video - composite sync to VGA_HS and VGA_VS high for MiST RGB cable
  VGA_HS <= not (O_HSYNC xor O_VSYNC) when scandoubler_disable='1' else not (sd_hs xor sd_vs) when ypbpr='1' else sd_hs;
  VGA_VS <= '1' when scandoubler_disable='1' or ypbpr='1' else sd_vs;
  VGA_R <= vga_pr_o when ypbpr='1' else osd_red_o;
  VGA_G <= vga_y_o  when ypbpr='1' else osd_green_o;
  VGA_B <= vga_pb_o when ypbpr='1' else osd_blue_o;

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
      c1 => clk,
      locked => open
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
      scandoubler_disable => scandoubler_disable,
      ypbpr => ypbpr,
      joystick_1 => joy0,
      joystick_0 => joy1,
      joystick_analog_1 => joy_a_0,
      joystick_analog_0 => joy_a_1,
      status => status,
      sd_sdhc => '1',
      ps2_kbd_clk => ps2Clk,
      ps2_kbd_data => ps2Data
    );

  data_io_inst: data_io
        port map(SPI_SCK, SPI_SS2, SPI_DI, downl, rom_size, index, vid_clk, '0', rom_a, (others=>'0'), rom_do);

  keyboard : entity work.ps2Keyboard
    port map (vid_clk, '0', ps2Clk, ps2data, ps2_scancode);

  -- if a gamepad has 4 buttons then buttons 3 and 4 are mapped to start and select
  p_start <= '0' when (ps2_scancode = X"01" or buttons(1) = '1' or joy0(7) = '1' or joy1(7) = '1' ) else '1'; -- F9 or MiST right button
  p_select <= '0' when (ps2_scancode = X"09" or joy0(6) = '1' or joy1(6) = '1' ) else '1'; -- F10

  LED <= not p_color; -- yellow led is bright when color mode is selected

end architecture;
