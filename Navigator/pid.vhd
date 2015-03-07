library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.NUMERIC_STD.all;

entity pid is
		port(
			u_out:out std_logic_vector(11 downto 0);
			e_in:in signed(11 downto 0);
			integral: in signed(11 downto 0);
			clk:in std_logic;
			reset:in std_logic
		);
end pid;

architecture Behavioral of pid is

begin
	process(reset, e_in)
		variable u1: signed(11 downto 0) := (OTHERS => '0');
		variable u_prev : signed(11 downto 0) := (OTHERS => '0');
		constant k_pro: signed(6 downto 0):="0000001";
		constant k_integral: signed( 6 downto 0 ):="0000001";
		--constant k2:std_logic_vector( 6 downto 0):="1101000";
		--constant k3: std_logic_vector( 6 downto 0) :="0000010";
	begin
	   if reset ='1' then
			u_prev := (OTHERS => '0');
		elsif (clk'event and clk = '1') then
				u1 := u_prev + (k_pro*(e_in)) ; --+ (k_integral*integral)
				u_prev := u1;
		end if;
		u_out <= std_logic_vector(u1);
	end process;
end Behavioral;