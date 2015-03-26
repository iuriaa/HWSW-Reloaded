library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.NUMERIC_STD.all;

entity pid is
		port(
			u_out:out signed(12 downto 0);
			e_in:in signed(12 downto 0);
			integral: in signed(12 downto 0);
			kp_in : in  STD_LOGIC_VECTOR (6 downto 0);
			ki_in : in  STD_LOGIC_VECTOR (6 downto 0);
			clk:in std_logic;
			reset:in std_logic
		);
end pid;

architecture Behavioral of pid is

begin
	process(reset, e_in)
	   variable error_temp: signed(12 downto 0) := (OTHERS => '0');
		variable integral_temp: signed(12 downto 0) := (OTHERS => '0');
		variable u1: signed(12 downto 0) := (OTHERS => '0');
		variable u_prev : signed(12 downto 0) := (OTHERS => '0');
		variable k_pro: signed(6 downto 0):="0000010";
		variable k_integral: signed( 6 downto 0 ):="0000001";
	begin
		k_pro := signed(kp_in);
		k_integral := signed(ki_in);
	   if reset ='1' then
			u_prev := (OTHERS => '0');
			integral_temp := (OTHERS => '0');
			error_temp := (OTHERS => '0');
		elsif (clk'event and clk = '1') then
		   if(integral >= 0) then
				integral_temp := (abs(integral) srl 2);
			else
				integral_temp := -1*(abs(integral) srl 2);
			end if;

			if(e_in >= 0) then
				error_temp := (abs(e_in) srl 2);
			else
				error_temp := -1*(abs(e_in) srl 2);
			end if;
			u1 := u_prev + (k_pro*(error_temp)) + (k_integral*integral_temp);
			u_prev := u1;
		end if;
		u_out <= u1;
	end process;
end Behavioral;