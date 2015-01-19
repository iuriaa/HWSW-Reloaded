----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:59:22 12/03/2014 
-- Design Name: 
-- Module Name:    cmd_velocity_i2c - Behavioral 
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity cmd_velocity_i2c is
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
					 cmd_vel_busy  : OUT 	  STD_LOGIC
					);
end cmd_velocity_i2c;

architecture Behavioral of cmd_velocity_i2c is
	signal enable : STD_LOGIC := '0';
	constant MC_addr : STD_LOGIC_VECTOR(6 DOWNTO 0) := "1100000"; -- 0x60
	signal rw : STD_LOGIC := '1';
	signal data_wr : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
	signal busy : STD_LOGIC;
	signal ack_error : STD_LOGIC;
	constant addr_motor1 : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"26";
	constant addr_motor2 : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"3A";
	signal busy_prev : STD_LOGIC := '0';
	signal data_rd : STD_LOGIC_VECTOR(7 DOWNTO 0);
	signal cmd_vel_busy_temp : STD_LOGIC := '0';
	
	TYPE state_type IS (idle, get_data);
	signal state : state_type := idle;
	
	--where all the 'work' is done: i2c_master.vhd
	component i2c_master
    		Port (
					 clk       : IN     STD_LOGIC;                    --system clock
					 reset_n   : IN     STD_LOGIC;                    --active low reset
					 ena       : IN     STD_LOGIC;                    --latch in command
					 addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
					 rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
					 data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
					 busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
					 data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
					 ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
					 sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
					 scl       : INOUT  STD_LOGIC                     --serial clock output of i2c bus
    			);
	end component;

	begin --architecture QuadratureCounter

	--instanciate the i2c
		i2ccomponent: i2c_master 
		port map	( 
						clk => clk,
						reset_n => not reset,
						ena => enable,
						addr => MC_addr,
						rw => rw,
						data_wr => data_wr,
						busy => busy,
						data_rd => data_rd,
						ack_error => ack_error,
						sda => sda,
						scl => scl
					);
					
    -- Control Logic
    p_ctrl : process(reset,clk) is
        variable busy_cnt : integer range 0 to 38;
		  variable addr_R_low : STD_LOGIC_VECTOR (7 DOWNTO 0);
		  variable addr_R_high : STD_LOGIC_VECTOR (7 DOWNTO 0);
		  variable addr_L_low : STD_LOGIC_VECTOR (7 DOWNTO 0);
		  variable addr_L_high : STD_LOGIC_VECTOR (7 DOWNTO 0);
    begin
        if reset = '1' then
            state <= idle;
            busy_cnt := 0;
            data_wr <= (others => '0');
            enable <= '0';
            rw <= '1';
				cmd_vel_busy_temp <= '0';
        elsif (clk'event and clk = '1') then
            enable <= '0';  -- default power-down
            rw <= '0';
            case state is
					 when idle =>
						  if (trigger = '1') then
						      cmd_vel_busy_temp  <= '1';
								busy_cnt := 0;                          -- reset busy_cnt for next transaction
								case R_fw_bw is
									when "00" =>
										addr_R_low := x"2A";		-- IN2 for motor 1
										addr_R_high := x"2E";	-- IN1 for motor 1
									when "01" =>
										addr_R_low := x"2A";		-- IN2 for motor 1
										addr_R_high := x"2E";	-- IN1 for motor 1
									when "10" =>
										addr_R_low := x"2E";		-- IN1 for motor 1
										addr_R_high := x"2A";	-- IN2 for motor 1
									when "11" =>
										addr_R_low := x"2A";		-- IN2 for motor 1
										addr_R_high := x"2E";	-- IN1 for motor 1
									when others => NULL;
								end case;	
								case L_fw_bw is
									when "00" =>
										addr_L_low := x"36";		-- IN2 for motor 1
										addr_L_high := x"32";	-- IN1 for motor 1
									when "01" =>
										addr_L_low := x"36";		-- IN2 for motor 1
										addr_L_high := x"32";	-- IN1 for motor 1
									when "10" =>
										addr_L_low := x"32";		-- IN1 for motor 1
										addr_L_high := x"36";	-- IN2 for motor 1
									when "11" =>
										addr_L_low := x"36";		-- IN2 for motor 1
										addr_L_high := x"32";	-- IN1 for motor 1
									when others => NULL;
								end case;	
								state <= get_data;
						  end if;
					 when get_data =>
						  busy_prev <= busy;                      -- latch the rising_edge of i2c_busy
						  if (busy_prev = '0' and busy = '1') then
								busy_cnt := busy_cnt + 1;
						  end if;
						  case busy_cnt is
								-- Set mode1
								when 0 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 1 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"20"; --enable internal clock and AI
								when 2 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
								-- Set speed for motor1 - LED8
								when 3 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= addr_motor1;
								when 4 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 5 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 6 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= speed_R(7 DOWNTO 0);
								when 7 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr(3 DOWNTO 0) <= speed_R(11 DOWNTO 8);
									 data_wr(7 DOWNTO 4) <= (others => '0');
								when 8 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
								-- Set IN LOW
								when 9 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= addr_R_low;
								when 10 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 11 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 12 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 13 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 14 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
								-- Set IN HIGH
								when 15 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= addr_R_high;
								when 16 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 17 =>
									 enable <= '1';
									 rw <= '0';
									 if ((R_fw_bw = "00") or (R_fw_bw = "11")) then
											data_wr <= x"00";
									 else
											data_wr <= x"10";
									 end if;
								when 18 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 19 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 20 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
								-- Set speed for motor2 - LED13
								when 21 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= addr_motor2;
								when 22 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 23 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 24 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= speed_L(7 DOWNTO 0);
								when 25 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr(3 DOWNTO 0) <= speed_L(11 DOWNTO 8);
									 data_wr(7 DOWNTO 4) <= (others => '0');
								when 26 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
								-- Set IN LOW
								when 27 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= addr_L_low;
								when 28 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 29 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 30 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 31 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 32 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
								-- Set IN HIGH
								when 33 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= addr_L_high;
								when 34 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 35 =>
									 enable <= '1';
									 rw <= '0';
									 if ((L_fw_bw = "00") or (L_fw_bw = "11")) then
											data_wr <= x"00";
									 else
											data_wr <= x"10";
									 end if;
								when 36 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 37 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 38 =>
									 enable <= '0';
									 cmd_vel_busy_temp  <= '0';
									 if (trigger = '0') then
											state <= idle;
									 end if;
								when others => null;
						  end case;
					 when others => null;
				end case;
        end if;
    end process;
	 cmd_vel_busy <= cmd_vel_busy_temp;
end Behavioral;