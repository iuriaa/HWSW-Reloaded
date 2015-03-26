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
end navigator;

architecture Behavioral of navigator is
	TYPE state_type IS (stop, forward, backward, rotate_R, rotate_L); -- declaring enumeration
	SIGNAL state, next_state, current_state: state_type;
	SIGNAL pwm_speed_l, pwm_speed_r: STD_LOGIC_VECTOR(11 downto 0):= (OTHERS => '0');
	SIGNAL pwm_command_out_L, pwm_command_out_R: STD_LOGIC_VECTOR(11 downto 0):= (OTHERS => '0');
	CONSTANT MAX_SPEED : STD_LOGIC_VECTOR(11 downto 0):= x"7FF";
	SIGNAL state_left_wheel, state_right_wheel : STD_LOGIC_VECTOR(1 downto 0):= (OTHERS => '0');
	SIGNAL trigger_cmd_vel : STD_LOGIC:= '0';
	SIGNAL runstop_prev :  STD_LOGIC:= '0';
	SIGNAL anodes : STD_LOGIC_VECTOR (3 DOWNTO 0);
	SIGNAL sseg : STD_LOGIC_VECTOR (7 DOWNTO 0);
	SIGNAL valueToDisplay : STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0');
	SIGNAL counter_L, counter_R : SIGNED(12 DOWNTO 0) := (OTHERS => '0');
	SIGNAL desired_speed_in: SIGNED(12 DOWNTO 0):= (OTHERS => '0');
	SIGNAL desired_bias_in: SIGNED(12 DOWNTO 0):= (OTHERS => '0');
	SIGNAL integral_sum: SIGNED(12 DOWNTO 0):= (OTHERS => '0');
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
	        desired_speed : in  SIGNED (12 downto 0);
           desired_bias : in  SIGNED (12 downto 0);
			  desired_state_R : out  STD_LOGIC_VECTOR (1 downto 0);
           desired_state_L : out  STD_LOGIC_VECTOR (1 downto 0);
			  kp_in : in  STD_LOGIC_VECTOR (6 downto 0);
			  ki_in : in  STD_LOGIC_VECTOR (6 downto 0);
           actual_speed_R : in  SIGNED (12 downto 0);
           actual_speed_L : in  SIGNED (12 downto 0);
			  integral_sum : out  SIGNED(12 downto 0);
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
					CountsPerSec : out signed(12 downto 0)
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
		        clk => prescaledClk,--16Hz
		        reset => reset,
		        desired_speed => desired_speed_in,
				  desired_bias => desired_bias_in,
				  desired_state_R => state_right_wheel, 
				  desired_state_L => state_left_wheel,
				  kp_in => kp_in,
				  ki_in => ki_in,
				  actual_speed_R => counter_R,
				  actual_speed_L => counter_L,
				  integral_sum => integral_sum,
				  pwm_command_R => pwm_speed_r,
				  pwm_command_L => pwm_speed_l
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
      --	and outputs pwm_speed_l(12 bits) and pwm_speed_r(12 bits)
		--instanciate the i2c
		cmdvelocityi2c: cmd_velocity_i2c 
		port map	(
						 clk       => clk,
						 reset  	  => reset,
						 sda       => sda,
						 scl       => scl,
						 trigger	  => trigger_cmd_vel,
						 speed_L	  => pwm_speed_l,
						 speed_R	  => pwm_speed_r,
						 L_fw_bw	  => state_left_wheel,
						 R_fw_bw	  => state_right_wheel,
						 cmd_vel_busy  => cmd_vel_busy
					);

   current_state_logic : PROCESS(reset, clk)
	   variable desired_bias_temp: signed(6 downto 0) := (OTHERS => '0');
		begin
			if reset = '1' then
				desired_speed_in <= (OTHERS => '0');
				desired_bias_in <= (OTHERS => '0');
			elsif clk'event and clk = '1' then
				prescaleCounter<= prescaleCounter+ 1;
				runstop_prev <= run_stop;
				prevPrescaledClk <= prescaledClk;
				if (prescaleCounter = PrescalerSecond) then
					prescaledClk <= not(prescaledClk);
					prescaleCounter<= (OTHERS => '0');
				end if;
				  
				if (runstop_prev /= run_stop) then
					trigger_cmd_vel <= '1';
					case run_stop is
						when '0' =>
							desired_speed_in <= (OTHERS => '0');
							desired_bias_in <= (OTHERS => '0');
						when '1' =>
							desired_speed_in(12 DOWNTO 6) <= signed(speed_prescalar);
							desired_speed_in(5 DOWNTO 0) <= "111111";
							desired_bias_temp := signed(desired_bias);
							desired_bias_in(12) <= desired_bias_temp(6);
							desired_bias_in(11 DOWNTO 6) <= "000000";
							desired_bias_in(5 DOWNTO 0) <= desired_bias_temp(5 DOWNTO 0);
						when others => NULL;
					end case;
				elsif (prevPrescaledClk /= prescaledClk and prescaledClk = '1') then
					trigger_cmd_vel <= '1';
				else
					trigger_cmd_vel <= '0';
				end if;
			end if;
	end process;
	
	ext_anodes <= anodes;
	ext_sseg <= sseg;
	
	process(counter_R, counter_L)
	   variable display_temp: STD_LOGIC_VECTOR(12 downto 0) := (OTHERS => '0');
	   begin
				display_temp := STD_LOGIC_VECTOR(abs(counter_R));
				valueToDisplay(7 DOWNTO 0) <= display_temp(7 DOWNTO 0);
				display_temp := STD_LOGIC_VECTOR(abs(counter_L));
				valueToDisplay(15 DOWNTO 8) <= display_temp(7 DOWNTO 0);
   end process;

end Behavioral;

