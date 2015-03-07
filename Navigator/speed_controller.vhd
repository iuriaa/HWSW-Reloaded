----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    20:20:37 01/18/2015 
-- Design Name: 
-- Module Name:    speed_controller - Behavioral 
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
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;
--use IEEE.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity speed_controller is
    Port ( 
	        clk : in  STD_LOGIC;
	        reset : in  STD_LOGIC;
	        desired_speed : in  STD_LOGIC_VECTOR (11 downto 0);
           desired_bias : in  STD_LOGIC_VECTOR (11 downto 0);
			  desired_state_R : in  STD_LOGIC_VECTOR (1 downto 0);
           desired_state_L : in  STD_LOGIC_VECTOR (1 downto 0);
           actual_speed_R : in  STD_LOGIC_VECTOR (11 downto 0);
           actual_speed_L : in  STD_LOGIC_VECTOR (11 downto 0);
           pwm_command_R : out  STD_LOGIC_VECTOR (11 downto 0);
           pwm_command_L : out  STD_LOGIC_VECTOR (11 downto 0));
end speed_controller;

architecture Behavioral of speed_controller is
SIGNAL error_L, error_R, integral_sig, integral_L, integral_R: signed(11 downto 0):= (OTHERS => '0');

SIGNAL pwm_command_L_sig, pwm_command_R_sig: STD_LOGIC_VECTOR(11 downto 0):= (OTHERS => '0');
SIGNAL inc_dec_L, inc_dec_R: STD_LOGIC := '0';

SIGNAL prescaledClk : STD_LOGIC := '0';
SIGNAL prevPrescaledClk : STD_LOGIC := '0';
SIGNAL prescaleCounter: signed(25 DOWNTO 0) := (OTHERS =>'0');
CONSTANT prescalerSecond: signed(25 DOWNTO 0) := "00000000000000000000000010"; --3_125_000 (62.5millisec)

component pid
		port(
			u_out:out std_logic_vector(11 downto 0);
			e_in:in signed(11 downto 0);
			integral: in signed(11 downto 0);
			clk:in std_logic;
			reset:in std_logic
		);
end component;

--	component pid_controller
--      Port (
--		     reset : in  STD_LOGIC;
--		     e : in  STD_LOGIC_VECTOR (7 downto 0);
--           PWM : out  STD_LOGIC_VECTOR (11 downto 0));
--   end component;
begin
   pid_controller_R:pid
		port map(
			u_out => pwm_command_R_sig,
			e_in => error_R,
			integral => integral_R,
			clk => prescaledClk,
			reset => reset
		);
		
	pid_controller_L:pid
		port map(
			u_out => pwm_command_L_sig,
			e_in => error_L,
			integral => integral_L,
			clk => prescaledClk,
			reset => reset
		);
--   pid_controller_R: pid_controller		
--		port map (  reset => reset,
--						e => error_R,
--						PWM => pwm_command_R
--			      );
--			
--	pid_controller_L: pid_controller		
--		port map (  reset => reset,
--						e => error_L,
--						PWM => pwm_command_L
--			      );
	process(clk)
	begin
		if (clk'event and clk = '1') then
			prescaleCounter <= prescaleCounter + 1;
			if (prescaleCounter = PrescalerSecond) then
				prescaledClk <= not(prescaledClk);
				prescaleCounter<= (OTHERS => '0');
			end if;
		end if;
	end process;
	
	process(actual_speed_R, actual_speed_L, reset, clk)--actual_speed_R, actual_speed_L)
	begin
	  if(reset = '1') then
		  error_R <= (OTHERS => '0');
		  error_L <= (OTHERS => '0');
	  elsif (clk'event and clk = '1') then
		  prevPrescaledClk <= prescaledClk;
		  if (prevPrescaledClk /= prescaledClk and prescaledClk = '1') then
		         integral_sig <= integral_sig + signed(actual_speed_L) + signed(desired_bias) - signed(actual_speed_R);
					if (desired_state_R = "00" and desired_state_L = "00") then
						error_R <= signed(desired_speed) - signed(actual_speed_R);
						error_L <= signed(desired_speed) - signed(actual_speed_L);
					elsif (desired_state_R = "01" and desired_state_L = "01") then
						error_R <= signed(desired_speed) - signed(actual_speed_R);
						error_L <= signed(desired_speed) - signed(actual_speed_L);
					elsif(desired_state_R = "10" and desired_state_L = "10") then
						error_R <= signed(actual_speed_R) - signed(desired_speed);
						error_L <=  signed(actual_speed_L) - signed(desired_speed);
					end if;
					integral_R <= integral_sig;
					integral_L <= -1 * integral_sig;
		  end if;
	  end if;
	end process;
	pwm_command_R <= pwm_command_R_sig;
	pwm_command_L <= pwm_command_L_sig;
end Behavioral;

