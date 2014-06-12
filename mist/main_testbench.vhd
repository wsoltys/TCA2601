library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.all;

entity main_testbench is
end entity main_testbench;

architecture test of main_testbench is

	signal clk27 : std_logic := '0';
	signal SPI_SCK : std_logic := '0';
	signal SPI_DI : std_logic := '0';
	signal SPI_DO : std_logic := '0';
	signal CONF_DATA0 : std_logic := '0';
	signal red : std_logic_vector(5 downto 0) := (others => '0');
	signal grn : std_logic_vector(5 downto 0) := (others => '0');
	signal blu : std_logic_vector(5 downto 0) := (others => '0');
	signal nHSync : std_logic := '0';
	signal nVSync : std_logic := '0';
	signal sigmaL : std_logic := '0';
	signal sigmaR : std_logic := '0';

begin
	
	main_inst: entity main 
		port map(
			CLOCK_27(0) => clk27,
			SPI_SCK => SPI_SCK,
			SPI_DI => SPI_DI,
			SPI_DO => SPI_DO,
			CONF_DATA0 => CONF_DATA0,
			VGA_R => red,
			VGA_G => grn,
			VGA_B => blu,
			VGA_HS => nHSync,
			VGA_VS => nVSync,
			AUDIO_L => sigmaL,
			AUDIO_R => sigmaR
		);

	process
	begin
		-- 50 MHz clock
		while true loop
			wait for 20 ns; clk27 <= not clk27;
		end loop;

		-- show simulation end
		assert false report "no failure, simulation successful" severity failure;
		
	end process;
	

end architecture test;
