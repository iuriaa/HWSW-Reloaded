----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:25:20 03/25/2015 
-- Design Name: 
-- Module Name:    navigator_control - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity navigator_control is
	Port (  clk : in  STD_LOGIC;
			  sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
			  scl       : INOUT  STD_LOGIC;                    --serial clock output of i2c bus
           switches : in STD_LOGIC_VECTOR (7 DOWNTO 0);
			  leds : out STD_LOGIC_VECTOR (7 DOWNTO 0);
			  channels_L : in STD_LOGIC_VECTOR (1 DOWNTO 0);
			  channels_R : in STD_LOGIC_VECTOR (1 DOWNTO 0);
			  push_buttons : in STD_LOGIC_VECTOR (3 DOWNTO 0);
			  ext_anodes : out STD_LOGIC_VECTOR (3 DOWNTO 0);
			  ext_sseg : out STD_LOGIC_VECTOR (7 DOWNTO 0)
			  );
end navigator_control;

architecture Behavioral of navigator_control is
	signal run_stop: STD_LOGIC := '0';
	signal push_buttons_prev: STD_LOGIC_VECTOR(3 downto 0):= (OTHERS=> '0');
	signal reset: STD_LOGIC;
	signal speed_prescalar, desired_bias: STD_LOGIC_VECTOR(6 downto 0):= (OTHERS=> '0');
	signal kp_in: STD_LOGIC_VECTOR(6 downto 0):= "0000010";
	signal ki_in: STD_LOGIC_VECTOR(6 downto 0):= "0000001";
	
   component navigator is
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
			  sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
			  scl       : INOUT  STD_LOGIC;                    --serial clock output of i2c bus
           run_stop : in  STD_LOGIC;
           speed_prescalar : in  STD_LOGIC_VECTOR (6 downto 0);
			  desired_bias : in  STD_LOGIC_VECTOR (6 downto 0);
			  kp_in : in  STD_LOGIC_VECTOR (6 downto 0);
			  ki_in : in  STD_LOGIC_VECTOR (6 downto 0);
			  channels_L : in STD_LOGIC_VECTOR (1 DOWNTO 0);
			  channels_R : in STD_LOGIC_VECTOR (1 DOWNTO 0);
			  ext_anodes : out STD_LOGIC_VECTOR (3 DOWNTO 0);
			  ext_sseg : out STD_LOGIC_VECTOR (7 DOWNTO 0)
			  );
   end component;
begin
   navigator_process : navigator
		port map( 
		        clk => clk,
		        reset => reset,
		        sda => sda,
				  scl => scl,
				  run_stop => run_stop, 
				  kp_in => kp_in,
				  ki_in => ki_in,
				  speed_prescalar => speed_prescalar,
				  desired_bias => desired_bias,
				  channels_L => channels_L,
				  channels_R => channels_R,
				  ext_anodes => ext_anodes,
				  ext_sseg => ext_sseg
		);
	reset <= push_buttons(0);
	leds(7 downto 4) <= push_buttons;
	leds(3) <= '0';
	leds(0) <= run_stop;
	
	process (clk)
		begin
			if(clk'event and clk = '1') then
				if (switches(0) = '1') then
					--stop
					run_stop <= '0';
				end if;
				
				if (push_buttons_prev /= push_buttons and push_buttons(0) = '1') then
					leds(2 downto 1) <= "00";
					kp_in <= "0000010";
					ki_in <= "0000001";
				elsif (push_buttons_prev /= push_buttons and push_buttons(1) = '1') then
					if (switches(0) = '0') then
							--run
							run_stop <= '1';
					end if;
				elsif (push_buttons_prev /= push_buttons and push_buttons(2) = '1') then  --desired velocity/bias button
						if (switches(0) = '0') then
							--set velocity
							leds(1) <= '1';
							speed_prescalar <= switches(7 downto 1);
						else
							--set bias
							leds(2) <= '1';
							desired_bias <= switches(7 downto 1);
						end if;
				elsif (push_buttons_prev /= push_buttons and push_buttons(3) = '1') then  --desired Kp/Ki button
						if (switches(0) = '0') then
							--set Kp
							kp_in <= switches(7 downto 1);
						else
							--set Ki
							ki_in <= switches(7 downto 1);
						end if;
				end if;
				push_buttons_prev <= push_buttons;
			end if;
	end process;
end Behavioral;

