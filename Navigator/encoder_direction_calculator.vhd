----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:51:53 11/10/2014 
-- Design Name: 
-- Module Name:    encoder_direction_calculator - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity encoder_direction_calculator is
    Port ( channels_R : in  STD_LOGIC_VECTOR(1 DOWNTO 0);
			  channels_L : in  STD_LOGIC_VECTOR(1 DOWNTO 0);
			  on_off : in STD_LOGIC; -- switch sw0
			  left_right_enc : in STD_LOGIC; -- switch sw1
			  reset : in STD_LOGIC;
			  clk : in STD_LOGIC;
			  anodes : out STD_LOGIC_VECTOR (3 DOWNTO 0);
			  sseg : out STD_LOGIC_VECTOR (7 DOWNTO 0));
end encoder_direction_calculator;

architecture SpeedCalculator of encoder_direction_calculator is
signal anode_r : STD_LOGIC_VECTOR (1 DOWNTO 0) := (others => '0');
signal counter_R : STD_LOGIC_VECTOR (15 DOWNTO 0) := (others => '0');
signal counter_L : STD_LOGIC_VECTOR (15 DOWNTO 0) := (others => '0');
constant prescaler: STD_LOGIC_VECTOR (16 downto 0) := "11000011010100000";
signal prescaler_counter: STD_LOGIC_VECTOR (16 downto 0) := (others => '0');
procedure ssg_decode(signal hexcode : in STD_LOGIC_VECTOR (3 DOWNTO 0);
							signal ssg_out : out STD_LOGIC_VECTOR (7 DOWNTO 0)) is
	variable temp : STD_LOGIC_VECTOR (7 DOWNTO 0);
	begin
		case hexcode is
			when "0000" => temp(6 DOWNTO 0) := "0111111"; -- Zero
			when "0001" => temp(6 DOWNTO 0) := "0000110"; -- One
			when "0010" => temp(6 DOWNTO 0) := "1011011"; -- Two
			when "0011" => temp(6 DOWNTO 0) := "1001111"; -- Three
			when "0100" => temp(6 DOWNTO 0) := "1100110"; -- Four
			when "0101" => temp(6 DOWNTO 0) := "1101101"; -- Five
			when "0110" => temp(6 DOWNTO 0) := "1111101"; -- Six
			when "0111" => temp(6 DOWNTO 0) := "0000111"; -- Seven
			when "1000" => temp(6 DOWNTO 0) := "1111111"; -- Eight
			when "1001" => temp(6 DOWNTO 0) := "1101111"; -- Nine
			when "1010" => temp(6 DOWNTO 0) := "1110111"; -- A
			when "1011" => temp(6 DOWNTO 0) := "1111100"; -- B
			when "1100" => temp(6 DOWNTO 0) := "0111001"; -- C
			when "1101" => temp(6 DOWNTO 0) := "1011110"; -- D
			when "1110" => temp(6 DOWNTO 0) := "1111001"; -- E
			when "1111" => temp(6 DOWNTO 0) := "1110001"; -- F
			when others =>
		end case;
	ssg_out <= not temp;
	ssg_out(7) <= '1'; -- Disable dot
end ssg_decode;

component QuadratureCountsPerSec
  		Port (
     			clock     : in    std_logic;
				reset     : in    std_logic;
     			QuadA     : in    std_logic;
     			QuadB     : in    std_logic;
				CountsPerSec : out std_logic_vector(15 downto 0)
				);
end component;

	begin
		--instanciate the decoder
		LMotorSpeed: TicksPerSecCounter 
		port map	(
		   reset => reset,
 			clock => clk,
	   	QuadA => channels_R(0),
 	   	QuadB => channels_R(1),
    		CountsPerSec => counter_R
		);
		
		RMotorSpeed: TicksPerSecCounter 
		port map	(
		   reset => reset,
 			clock => clk,
	   	QuadA => channels_L(0),
 	   	QuadB => channels_L(1),
    		CountsPerSec => counter_L
		);
		
		process (clk, on_off)
			begin
				-- sseg on/off by switch sw0
				if on_off = '1' then
					if (clk'event and clk = '1') then
						prescaler_counter <= prescaler_counter + 1;
						if(prescaler_counter = prescaler) then
							if left_right_enc = '1' then
								case anode_r is
									when "00" =>
										ssg_decode(hexcode => counter_R(3 DOWNTO 0), ssg_out => sseg);
										anodes <= "1110";
										anode_r <= "01";
									when "01" =>
										ssg_decode(hexcode => counter_R(7 DOWNTO 4), ssg_out => sseg);
										anodes <= "1101";
										anode_r <= "10";
									when "10" =>
										ssg_decode(hexcode => counter_R(11 DOWNTO 8), ssg_out => sseg);
										anodes <= "1011";
										anode_r <= "11";
									when "11" =>
										ssg_decode(hexcode => counter_R(15 DOWNTO 12), ssg_out => sseg);
										anodes <= "0111";
										anode_r <= "00";
									when others =>
								end case;
							else
								case anode_r is
									when "00" =>
										ssg_decode(hexcode => counter_L(3 DOWNTO 0), ssg_out => sseg);
										anodes <= "1110";
										anode_r <= "01";
									when "01" =>
										ssg_decode(hexcode => counter_L(7 DOWNTO 4), ssg_out => sseg);
										anodes <= "1101";
										anode_r <= "10";
									when "10" =>
										ssg_decode(hexcode => counter_L(11 DOWNTO 8), ssg_out => sseg);
										anodes <= "1011";
										anode_r <= "11";
									when "11" =>
										ssg_decode(hexcode => counter_L(15 DOWNTO 12), ssg_out => sseg);
										anodes <= "0111";
										anode_r <= "00";
									when others =>
								end case;
							end if;
							prescaler_counter <= (others => '0');
						end if;
					end if;
				else
					anodes <= "1111";
				end if;
		end process;
end SpeedCalculator;

