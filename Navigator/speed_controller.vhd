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
use ieee.numeric_std.all;

entity speed_controller is
    Port ( 
	        clk : in  STD_LOGIC;
	        reset : in  STD_LOGIC;
	        desired_speed : in  SIGNED (12 downto 0);
           desired_bias : in  SIGNED (12 downto 0);
			  desired_state_R : in  STD_LOGIC_VECTOR (1 downto 0);
           desired_state_L : in  STD_LOGIC_VECTOR (1 downto 0);
           actual_speed_R : in  SIGNED (12 downto 0);
           actual_speed_L : in  SIGNED (12 downto 0);
           pwm_command_R : out  STD_LOGIC_VECTOR (11 downto 0);
           pwm_command_L : out  STD_LOGIC_VECTOR (11 downto 0));
end speed_controller;

architecture Behavioral of speed_controller is
SIGNAL error_L, error_R, integral_sig, integral_L, integral_R: signed(12 downto 0):= (OTHERS => '0');

SIGNAL pwm_command_L_sig, pwm_command_R_sig: SIGNED(12 downto 0):= (OTHERS => '0');
SIGNAL inc_dec_L, inc_dec_R: STD_LOGIC := '0';

SIGNAL prescaledClk : STD_LOGIC := '0';
SIGNAL prevPrescaledClk : STD_LOGIC := '0';
SIGNAL prescaleCounter: signed(25 DOWNTO 0) := (OTHERS =>'0');
CONSTANT prescalerSecond: signed(25 DOWNTO 0) := "00000000000000000000000001"; --3_125_000 (62.5millisec)

component pid
		port(
			u_out:out signed(12 downto 0);
			e_in:in signed(12 downto 0);
			integral: in signed(12 downto 0);
			clk:in std_logic;
			reset:in std_logic
		);
end component;

begin
   pid_controller_R:pid
		port map(
			u_out => pwm_command_R_sig,
			e_in => error_R,
			integral => integral_R,
			clk => clk,
			reset => reset
		);
		
	pid_controller_L:pid
		port map(
			u_out => pwm_command_L_sig,
			e_in => error_L,
			integral => integral_L,
			clk => clk,
			reset => reset
		);
		
	process(actual_speed_R, actual_speed_L, reset, clk)--actual_speed_R, actual_speed_L)
	begin
	  if(reset = '1') then
		   error_R <= (OTHERS => '0');
		   error_L <= (OTHERS => '0');
	  elsif (clk'event and clk = '1') then
--			if (abs(actual_speed_L) /= abs(actual_speed_R)) then
				integral_sig <= abs(actual_speed_L) - abs(actual_speed_R) + abs(desired_bias);
--			else
--				integral_sig <= (OTHERS => '0');
--			end if;
			error_R <= abs(desired_speed) - abs(actual_speed_R);
			error_L <= abs(desired_speed) - abs(actual_speed_L);
			integral_R <= integral_sig;
			integral_L <= -1 * integral_sig;
	  end if;
	end process;
	pwm_command_R <= STD_LOGIC_VECTOR(abs(pwm_command_R_sig));
	pwm_command_L <= STD_LOGIC_VECTOR(abs(pwm_command_L_sig));
end Behavioral;

