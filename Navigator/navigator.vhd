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
--use IEEE.std_logic_unsigned.all;

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
	SIGNAL pwm_command_out_L, pwm_command_out_R: STD_LOGIC_VECTOR(11 downto 0):= (OTHERS => '0');
	CONSTANT MAX_SPEED : STD_LOGIC_VECTOR(11 downto 0):= x"7FF";
	SIGNAL state_left_wheel, state_right_wheel : STD_LOGIC_VECTOR(1 downto 0):= (OTHERS => '0');
	SIGNAL trigger_cmd_vel : STD_LOGIC:= '0';
	SIGNAL anodes : STD_LOGIC_VECTOR (3 DOWNTO 0);
	SIGNAL sseg : STD_LOGIC_VECTOR (7 DOWNTO 0);
	SIGNAL valueToDisplay : STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0');
	SIGNAL counter_L, counter_R : STD_LOGIC_VECTOR (11 DOWNTO 0) := (OTHERS => '0');
	SIGNAL desired_speed_in: STD_LOGIC_VECTOR (11 DOWNTO 0):= x"000";
	SIGNAL desired_bias_in: STD_LOGIC_VECTOR (11 DOWNTO 0):= x"000";
	SIGNAL cmd_vel_busy: STD_LOGIC;
	
	SIGNAL prescaledClk : STD_LOGIC := '0';
	SIGNAL prevPrescaledClk : STD_LOGIC := '0';
	SIGNAL prescaleCounter: STD_LOGIC_VECTOR (25 DOWNTO 0) := (OTHERS =>'0');
--	CONSTANT prescalerSecond: STD_LOGIC_VECTOR (25 DOWNTO 0) := "00000010111110101111000010"; --781_250 (15.625millisec)
--	CONSTANT prescalerSecond: STD_LOGIC_VECTOR (25 DOWNTO 0) := "00000101111101011110000100"; --1_562_500 (31.25millisec)
	CONSTANT prescalerSecond: STD_LOGIC_VECTOR (25 DOWNTO 0) := "00001011111010111100001000"; --3_125_000 (62.5millisec)

	
	component speed_controller
    Port ( clk : in  STD_LOGIC;
	        reset : in  STD_LOGIC;
	        desired_speed : in  STD_LOGIC_VECTOR (11 downto 0);
           desired_bias : in  STD_LOGIC_VECTOR (11 downto 0);
           actual_speed_R : in  STD_LOGIC_VECTOR (11 downto 0);
           actual_speed_L : in  STD_LOGIC_VECTOR (11 downto 0);
           pwm_command_R : out  STD_LOGIC_VECTOR (11 downto 0);
           pwm_command_L : out  STD_LOGIC_VECTOR (11 downto 0));
   end component;

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
						 R_fw_bw	  : IN	  STD_LOGIC_VECTOR(1 DOWNTO 0);
						 cmd_vel_busy : OUT 	  STD_LOGIC
						);
	end component;
	
	component TicksPerSecCounter
			Port (
					clock     : in    std_logic;		 
					prescaledClk : in std_logic;
					reset     : in    std_logic;
					QuadA     : in    std_logic;
					QuadB     : in    std_logic;
					CountsPerSec : out std_logic_vector(11 downto 0)
					);
	end component;

	component display
			Port (
					on_off : in STD_LOGIC; -- switch sw0
					valueToDisplay : in STD_LOGIC_VECTOR (15 DOWNTO 0);
					dotsOnOff : in STD_LOGIC_VECTOR (3 DOWNTO 0);
					reset : in STD_LOGIC;
					clk : in STD_LOGIC;
					anodes : out STD_LOGIC_VECTOR (3 DOWNTO 0);
					sseg : out STD_LOGIC_VECTOR (7 DOWNTO 0)
					);
	end component;
	
begin

      speed_control:speed_controller
		port map( 
		        clk => prescaledClk,
		        reset => reset,
		        desired_speed => desired_speed_in,
				  desired_bias => desired_bias_in,
				  actual_speed_R => counter_R(11 DOWNTO 0),
				  actual_speed_L => counter_L(11 DOWNTO 0),
				  pwm_command_R => speed_r,
				  pwm_command_L => speed_l
		);
	
		displayer: display		
		port map (
						on_off => '1',
						valueToDisplay => valueToDisplay,
						dotsOnOff => "0100",
						reset => reset,
						clk => clk,
						anodes => anodes,
						sseg => sseg
		);

		--instanciate the decoder
		RMotorSpeed: TicksPerSecCounter 
		port map	(
						reset => reset,
						clock => clk,
						prescaledClk => prescaledClk,
						QuadA => channels_R(0),
						QuadB => channels_R(1),
						CountsPerSec => counter_R
		);
		
		LMotorSpeed: TicksPerSecCounter
		port map	(
						reset => reset,
						clock => clk,
						prescaledClk => prescaledClk,
						QuadA => channels_L(0),
						QuadB => channels_L(1),
						CountsPerSec => counter_L
		);
		
		-- speed controller which takes in desired motor level speed(8 bit digit),bias(8 bit) couter_R(16 bits), couter_L(bits)
      --	and outputs speed_l(12 bits) and speed_r(12 bits)
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
						 R_fw_bw	  => state_right_wheel,
						 cmd_vel_busy  => cmd_vel_busy
					);

   current_state_logic : PROCESS(reset, clk)
		begin
			if reset = '1' then
				  current_state <= stop;
				  trigger_cmd_vel <= '0';
			elsif clk'event and clk = '1' then
				  prescaleCounter<= prescaleCounter+ 1;
				  current_state <= next_state;
				  prevPrescaledClk <= prescaledClk;
				  if (prescaleCounter = PrescalerSecond) then
						prescaledClk <= not(prescaledClk);
						prescaleCounter<= (OTHERS => '0');
				  end if;
				  if (current_state /= next_state) then
						trigger_cmd_vel <= '1';
				  elsif (prevPrescaledClk /= prescaledClk and prescaledClk = '1') then
						trigger_cmd_vel <= '1';
				  else
					   trigger_cmd_vel <= '0';
              end if;
			end if;
	end process;
	
	ext_anodes <= anodes;
	ext_sseg <= sseg;
--	valueToDisplay(15 DOWNTO 12) <= (OTHERS => '0');
--	valueToDisplay(11 DOWNTO 0) <= counter_R(11 DOWNTO 0);
	valueToDisplay(7 DOWNTO 0) <= counter_R(7 DOWNTO 0);
	valueToDisplay(15 DOWNTO 8) <= counter_L(7 DOWNTO 0);
	
   next_state_logic : PROCESS(reset, clk)
		begin
			if reset = '1' then
				  next_state <= stop;
			elsif clk'event and clk = '1' then
				CASE state_selector IS
					when "100" => 
						next_state <= forward;
					when "101" => 
						next_state <= backward;
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
--				speed_l <= (OTHERS => '0');
--				speed_r <= (OTHERS => '0');
				state_left_wheel <= "00";
				state_right_wheel <= "00";
			else
--				speed_l <= (OTHERS => '0');
--				speed_r <= (OTHERS => '0');
				case current_state is
					when stop =>
						state_left_wheel <= "00";
						state_right_wheel <= "00";
						desired_speed_in <= x"000";
					when forward =>
						state_left_wheel <= "01";
						state_right_wheel <= "01";
--						speed_l(11 DOWNTO 8) <= speed_prescalar;
--						speed_r(11 DOWNTO 8) <= speed_prescalar;
--						speed_l(7 DOWNTO 0) <= x"FF";
--						speed_r(7 DOWNTO 0) <= x"FF";
                  desired_speed_in <= x"0C0";
					when backward =>
						state_left_wheel <= "10";
						state_right_wheel <= "10";
--						speed_l(11 DOWNTO 8) <= speed_prescalar;
--						speed_r(11 DOWNTO 8) <= speed_prescalar;
--						speed_l(7 DOWNTO 0) <= x"FF";
--						speed_r(7 DOWNTO 0) <= x"FF";
						desired_speed_in <= x"0C0";
					when rotate_R =>
						state_left_wheel <= "01";
						state_right_wheel <= "10";
--						speed_l(11 DOWNTO 8) <= speed_prescalar;
--						speed_r(11 DOWNTO 8) <= speed_prescalar;
--						speed_l(7 DOWNTO 0) <= x"FF";
--						speed_r(7 DOWNTO 0) <= x"FF";
						desired_speed_in <= x"0C0";
					when rotate_L =>
						state_left_wheel <= "10";
						state_right_wheel <= "01";
--						speed_l(11 DOWNTO 8) <= speed_prescalar;
--						speed_r(11 DOWNTO 8) <= speed_prescalar;
--						speed_l(7 DOWNTO 0) <= x"FF";
--						speed_r(7 DOWNTO 0) <= x"FF";
						desired_speed_in <= x"0C0";
				end case;
			 end if;
	end process;
end Behavioral;

