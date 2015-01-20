library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity pid is
		port(
			u_out:out std_logic_vector(11 downto 0);
			e_in:in std_logic_vector(11 downto 0);
			clk:in std_logic;
			reset:in std_logic;
			inc_dec:in std_logic
		);
end pid;

architecture Behavioral of pid is

begin
	process(reset, e_in)
		variable u1: std_logic_vector(11 downto 0) := (OTHERS => '0');
		variable u_prev : std_logic_vector(11 downto 0) := (OTHERS => '0');
		constant kp: std_logic_vector(6 downto 0):="0000010";
		--constant k1: std_logic_vector( 6 downto 0 ):="1101011";
		--constant k2:std_logic_vector( 6 downto 0):="1101000";
		--constant k3: std_logic_vector( 6 downto 0) :="0000010";
	begin
	   if reset ='1' then
			u_prev := (OTHERS => '0');
		elsif (clk'event and clk = '1') then
				if (inc_dec = '0') then
					u1 := u_prev + (kp*e_in);
				else 
					u1 := u_prev - (kp*e_in);
				end if;
				u_prev := u1;
		end if;
		u_out <= u1;
	end process;
end Behavioral;