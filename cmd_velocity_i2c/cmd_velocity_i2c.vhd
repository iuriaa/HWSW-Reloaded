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
					 scl       : INOUT  STD_LOGIC;                   --serial clock output of i2c bus
					 leds		  : OUT	  STD_LOGIC_VECTOR (7 DOWNTO 0);
					 switches  : IN	  STD_LOGIC_VECTOR (7 DOWNTO 0);
					 start	  : IN	  STD_LOGIC;
					 stop		  : IN	  STD_LOGIC
					 --start	  : IN	STD_LOGIC
					);
end cmd_velocity_i2c;

architecture Behavioral of cmd_velocity_i2c is
	signal enable : STD_LOGIC := '0';
	constant MC_addr : STD_LOGIC_VECTOR(6 DOWNTO 0) := "1100000"; -- 0x60
	signal rw : STD_LOGIC := '1';
	signal data_wr : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
	signal busy : STD_LOGIC;
	signal data_rd : STD_LOGIC_VECTOR(7 DOWNTO 0);
	signal ack_error : STD_LOGIC;
	constant addr_motor1 : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"26";--001001110010100000101001";
	constant addr_motor2 : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"3A";--001110110011110000111101";
	signal busy_prev : STD_LOGIC := '0';
	signal speed : STD_LOGIC_VECTOR(15 DOWNTO 0) := (others => '0');
	
	TYPE state_type IS (idle, get_data);
	signal state : state_type := idle;
	
	--where all the 'work' is done: quadraturedecoder.vhd
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
					 scl       : INOUT  STD_LOGIC                   --serial clock output of i2c bus
    			);
	end component;

	begin --architecture QuadratureCounter		 

	--instanciate the decoder
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
        variable busy_cnt : integer range 0 to 41;
    begin
        if reset = '1' then
            state <= idle;
            busy_cnt := 0;
            data_wr <= (others => '0');
            enable <= '0';
            rw <= '1';
				leds <= x"00";
        elsif (clk'event and clk = '1') then
            enable <= '0';  -- default power-down
            rw <= '0';
            case state is
					 when idle =>
						  if (start = '1') then
								busy_cnt := 0;                          -- reset busy_cnt for next transaction
								leds <= x"00";
								speed <= x"07FF";
								state <= get_data;
						  elsif (stop = '1') then
								busy_cnt := 0;                          -- reset busy_cnt for next transaction
								leds <= x"00";
								speed <= x"0000";
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
									 leds <= x"00";
								when 1 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"20"; --enable internal clock and AI
									 leds <= x"01";
								when 2 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
									 leds <= x"02";
								-- Set speed for motor1 - LED8
								when 3 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= addr_motor1;
									 leds <= x"03";
								when 4 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= speed(7 DOWNTO 0);
									 leds <= x"04";
								when 5 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= speed(15 DOWNTO 8);
									 leds <= x"05";
								when 6 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"06";
								when 7 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"07";
								when 8 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
									 leds <= x"08";
								-- Set LED9 In2 to LOW
								when 9 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"2A";
									 leds <= x"09";
								when 10 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 11 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"0A";
								when 12 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"0B";
								when 13 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"0C";
								when 14 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
									 leds <= x"0D";
								-- Set LED10 In1 to HIGH
								when 15 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"2E";
									 leds <= x"0E";
								when 16 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"0F";
								when 17 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"10";
									 leds <= x"10";
								when 18 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"11";
								when 19 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"12";
								when 20 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
									 leds <= x"13";
								-- Set speed for motor2 - LED13
								when 21 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= addr_motor2;
									 leds <= x"03";
								when 22 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= speed(7 DOWNTO 0);
									 leds <= x"04";
								when 23 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= speed(15 DOWNTO 8);
									 leds <= x"05";
								when 24 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"06";
								when 25 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"07";
								when 26 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
									 leds <= x"08";
								-- Set LED12 In2 to LOW
								when 27 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"36";
									 leds <= x"09";
								when 28 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
								when 29 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"0A";
								when 30 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"0B";
								when 31 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"0C";
								when 32 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
									 leds <= x"0D";
								-- Set LED11 In1 to HIGH
								when 33 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"32";
									 leds <= x"32";
								when 34 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"0F";
								when 35 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"10";
									 leds <= x"10";
								when 36 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"11";
								when 37 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= x"00";
									 leds <= x"12";
								when 38 =>
									 enable <= '0';
									 if busy='0' then
                                busy_cnt := busy_cnt + 1;
                            end if;
									 leds <= x"13";
								-- read register with addr according to switches
								when 39 =>
									 enable <= '1';
									 rw <= '0';
									 data_wr <= switches;
								when 40 =>
									 enable <= '1';
									 rw <= '1';
									 leds <= data_rd;
								when 41 =>
									 enable <= '0';
									 rw <= '1';
									 leds <= data_rd;
									 --leds(7) <= ack_error;
									 if (start = '0') then
											state <= idle;
									 end if;
									 --leds(6 DOWNTO 0) <= "0010100";
								when others => null;
						  end case;
					 when others => null;
				end case;
        end if;
    end process;
end Behavioral;

