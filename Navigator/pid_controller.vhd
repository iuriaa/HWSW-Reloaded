----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:04:32 01/13/2015 
-- Design Name: 
-- Module Name:    pid_controller - Behavioral 
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

--use IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use IEEE.std_logic_signed.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity pid_controller is
      Port ( reset : in  STD_LOGIC;
		     e : in  STD_LOGIC_VECTOR (7 downto 0);
           PWM : out  STD_LOGIC_VECTOR (11 downto 0));
end pid_controller;

architecture Behavioral of pid_controller is

signal eInt : integer := 0;
signal PWMInt : integer := 0;

--min/max
signal borne : integer := 255;

--Gain
signal Kp : integer := 1;

--saturation
--component saturation is
--    Port ( entier : in  integer;
--           borne : in  integer;
--           sotie : out  STD_LOGIC_VECTOR (8 downto 0));
--end component;

begin
    process(reset, e)
    begin
	   if reset = '1' then
			PWMInt <= 0;
		else
			eInt <= conv_integer(e);
			PWMInt <= (Kp * eInt);
		end if;
	 end process;

	 PWM <= conv_std_logic_vector(PWMInt, 12);--(OTHERS => '0');
end Behavioral;

