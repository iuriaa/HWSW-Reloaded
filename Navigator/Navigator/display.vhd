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

entity display is
    Port ( 
			  on_off : in STD_LOGIC; -- switch sw0
			  valueToDisplay : in STD_LOGIC_VECTOR (15 DOWNTO 0);
			  dotsOnOff : in STD_LOGIC_VECTOR (3 DOWNTO 0);
			  reset : in STD_LOGIC;
			  clk : in STD_LOGIC;
			  anodes : out STD_LOGIC_VECTOR (3 DOWNTO 0);
			  sseg : out STD_LOGIC_VECTOR (7 DOWNTO 0)
			 );
end display;

architecture Displayer of display is
signal anode_r : STD_LOGIC_VECTOR (1 DOWNTO 0) := (others => '0');
constant prescaler: STD_LOGIC_VECTOR (16 downto 0) := "11000011010100000";
signal prescaler_counter: STD_LOGIC_VECTOR (16 downto 0) := (others => '0');

procedure ssg_decode(signal hexcode : in STD_LOGIC_VECTOR (3 DOWNTO 0);
							signal ssg_out : out STD_LOGIC_VECTOR (7 DOWNTO 0);
							signal dot_on_off : in STD_LOGIC) is
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
	ssg_out(7) <= not(dot_on_off); -- Disable dot
end ssg_decode;

	begin
		
		process (clk, on_off)
			begin
				-- sseg on/off by switch sw0
				if on_off = '1' then
					if (clk'event and clk = '1') then
						prescaler_counter <= prescaler_counter + 1;
						if(prescaler_counter = prescaler) then
								case anode_r is
									when "00" =>
										ssg_decode(hexcode => valueToDisplay(3 DOWNTO 0), ssg_out => sseg, dot_on_off => dotsOnOff(0));
										anodes <= "1110";
										anode_r <= "01";
									when "01" =>
										ssg_decode(hexcode => valueToDisplay(7 DOWNTO 4), ssg_out => sseg, dot_on_off => dotsOnOff(1));
										anodes <= "1101";
										anode_r <= "10";
									when "10" =>
										ssg_decode(hexcode => valueToDisplay(11 DOWNTO 8), ssg_out => sseg, dot_on_off => dotsOnOff(2));
										anodes <= "1011";
										anode_r <= "11";
									when "11" =>
										ssg_decode(hexcode => valueToDisplay(15 DOWNTO 12), ssg_out => sseg, dot_on_off => dotsOnOff(3));
										anodes <= "0111";
										anode_r <= "00";
									when others =>
								end case;
							prescaler_counter <= (others => '0');
						end if;
					end if;
				else
					anodes <= "1111";
				end if;
		end process;
end Displayer;

