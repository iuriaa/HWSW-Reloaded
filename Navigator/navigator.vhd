----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    18:27:14 12/15/2014 
-- Design Name: 
-- Module Name:    navigator - Behavioral 
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
use IEEE.std_logic_signed.all;
use IEEE.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity navigator is
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
			  sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
			  scl       : INOUT  STD_LOGIC;                    --serial clock output of i2c bus
           state_selector : in  STD_LOGIC_VECTOR (2 downto 0);
           speed_prescalar : in  STD_LOGIC_VECTOR (3 downto 0);
			  left_right_encoder : in  STD_LOGIC;
			  channels_L : in STD_LOGIC_VECTOR (1 DOWNTO 0);
			  channels_R : in STD_LOGIC_VECTOR (1 DOWNTO 0);
			  ext_anodes : out STD_LOGIC_VECTOR (3 DOWNTO 0);
			  ext_sseg : out STD_LOGIC_VECTOR (7 DOWNTO 0)
			  );
end navigator;

architecture Behavioral of navigator is
	TYPE state_type IS (stop, forward, backward, rotate_R, rotate_L); -- declaring enumeration
	SIGNAL state, next_state, current_state: state_type;
	SIGNAL speed_l, speed_r: STD_LOGIC_VECTOR(11 downto 0):= (OTHERS => '0');
	CONSTANT MAX_SPEED : STD_LOGIC_VECTOR(11 downto 0):= x"7FF";
	SIGNAL state_left_wheel, state_right_wheel : STD_LOGIC_VECTOR(1 downto 0):= (OTHERS => '0');
	SIGNAL trigger_cmd_vel : STD_LOGIC:= '0';
	SIGNAL anodes : STD_LOGIC_VECTOR (3 DOWNTO 0);
	SIGNAL sseg : STD_LOGIC_VECTOR (7 DOWNTO 0);

	component cmd_velocity_i2c
				Port (
						 clk       : IN     STD_LOGIC;                    --system clock
						 reset  	  : IN     STD_LOGIC;                    --active low reset
						 sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
						 scl       : INOUT  STD_LOGIC;                    --serial clock output of i2c bus
						 trigger	  : IN	  STD_LOGIC;
						 speed_L	  : IN	  STD_LOGIC_VECTOR (11 DOWNTO 0);
						 speed_R	  : IN	  STD_LOGIC_VECTOR (11 DOWNTO 0);
						 L_fw_bw	  : IN	  STD_LOGIC_VECTOR(1 DOWNTO 0);
						 R_fw_bw	  : IN	  STD_LOGIC_VECTOR(1 DOWNTO 0)
						);
	end component;
	
	component encoder_direction_calculator
				Port ( 
						 channels_R : in  STD_LOGIC_VECTOR(1 DOWNTO 0);
						 channels_L : in  STD_LOGIC_VECTOR(1 DOWNTO 0);
						 on_off : in STD_LOGIC; -- switch sw0
						 left_right_enc : in STD_LOGIC; -- switch sw1
						 reset : in STD_LOGIC;
						 clk : in STD_LOGIC;
						 anodes : out STD_LOGIC_VECTOR (3 DOWNTO 0);
						 sseg : out STD_LOGIC_VECTOR (7 DOWNTO 0)
						);
	end component;

begin
		--instanciate the encoder component
		iEncoderCounter : encoder_direction_calculator
		port map (
						 channels_R => channels_R,
						 channels_L => channels_L,
						 on_off => '1', -- switch sw0
						 left_right_enc => left_right_encoder, -- switch sw1
						 reset => reset,
						 clk => clk,
						 anodes => anodes,
						 sseg => sseg
					 );
		
		--instanciate the i2c
		cmdvelocityi2c: cmd_velocity_i2c 
		port map	(
						 clk       => clk,
						 reset  	  => reset,
						 sda       => sda,
						 scl       => scl,
						 trigger	  => trigger_cmd_vel,
						 speed_L	  => speed_l,
						 speed_R	  => speed_r,
						 L_fw_bw	  => state_left_wheel,
						 R_fw_bw	  => state_right_wheel
					);

   current_state_logic : PROCESS(reset, clk)
		begin
			if reset = '1' then
				  current_state <= stop;
				  trigger_cmd_vel <= '0';
			elsif clk'event and clk = '1' then
				  current_state <= next_state;
				  if (current_state /= next_state) then
						trigger_cmd_vel <= '1';
				  else 
						trigger_cmd_vel <= '0';
				  end if;
			end if;
	end process;
	
	ext_anodes <= anodes;
	ext_sseg <= sseg;
	
   next_state_logic : PROCESS(reset, clk)
		begin
			if reset = '1' then
				  next_state <= stop;
			elsif clk'event and clk = '1' then
				CASE state_selector IS
					when "100" => 
						next_state <= backward;
					when "101" => 
						next_state <= forward;
					when "110" => 
						next_state <= rotate_R;
					when "111" => 
						next_state <= rotate_L;
					when OTHERS => 
						next_state <= stop;
				end case;
			end if;
	end process;
	
	states : process(reset, current_state)
		begin
			if reset = '1' then
				speed_l <= (OTHERS => '0');
				speed_r <= (OTHERS => '0');
				state_left_wheel <= "00";
				state_right_wheel <= "00";
			else
				speed_l <= (OTHERS => '0');
				speed_r <= (OTHERS => '0');
				case current_state is
					when stop =>
						state_left_wheel <= "00";
						state_right_wheel <= "00";
					when forward =>
						state_left_wheel <= "01";
						state_right_wheel <= "01";
						speed_l(11 DOWNTO 8) <= speed_prescalar;
						speed_r(11 DOWNTO 8) <= speed_prescalar;
						speed_l(7 DOWNTO 0) <= x"FF";
						speed_r(7 DOWNTO 0) <= x"FF";
					when backward =>
						state_left_wheel <= "10";
						state_right_wheel <= "10";
						speed_l <= MAX_SPEED;
						speed_r <= MAX_SPEED;
					when rotate_R =>
						state_left_wheel <= "01";
						state_right_wheel <= "10";
						speed_l <= MAX_SPEED;
						speed_r <= MAX_SPEED;
					when rotate_L =>
						state_left_wheel <= "10";
						state_right_wheel <= "01";
						speed_l <= MAX_SPEED;
						speed_r <= MAX_SPEED;
				end case;
			 end if;
	end process;
end Behavioral;

