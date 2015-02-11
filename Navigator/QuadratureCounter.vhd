library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- c2003 Franks Development, LLC
-- http://www.franks-development.com
-- !This source is distributed under the terms & conditions specified at opencores.org

--resource or companion to this code: 
	-- Xilinx Application note 12 - "Quadrature Phase Decoder" - xapp012.pdf
	-- no longer appears on xilinx website (to best of my knowledge), perhaps it has been superceeded?

--this code was origonally intended for use on Xilinx XPLA3 'coolrunner' CPLD devices
--origonally compiled/synthesized with Xilinx 'Webpack' 5.2 software

--How we 'talk' to the outside world:
entity TicksPerSecCounter is
    Port ( clock : in std_logic;	--system clock, i.e. 10MHz oscillator
		 prescaledClk : in std_logic;
   	 reset : in std_logic;	--counter reset
		 QuadA : in std_logic;	--first input from quadrature device  (i.e. optical disk encoder)
		 QuadB : in std_logic;	--second input from quadrature device (i.e. optical disk encoder)
		 CountsPerSec : out std_logic_vector(11 downto 0) --just an example debuggin output
		);
end TicksPerSecCounter;

--What we 'do':
architecture QuadratureCounter of TicksPerSecCounter is

	--Our encoder is the 5420-es214 which has 200 ticks, ~400 counts per revolute
	--The frequency of the prescaled clock is decided to be 16Hz (62.5 milliseconds cycles)
	--In order to calculate the velocity, we shift the counted values by four bits to the left (1 sec),
	--sum 4 consecutive shifted counts and shift the result by 2 bits to the right(Averaging it).
	
	-- local 'variables' or 'registers'
	
	--This is the counter for how many quadrature ticks have gone past.
	--the size of this counter is dependant on how far you need to count
	--it was origonally used with a circular disk encoder having 2048 ticks/revolution
	--thus this 16-bit count could hold 2^15 ticks in either direction, or a total
	--of 32768/2048 = 16 revolutions in either direction.  if the disk
	--was turned more than 16 times in a given direction, the counter overflows
	--and the origonal location is lost.  If you had a linear instead of 
	--circular encoder that physically could not move more than 2048 ticks,
	--then Count would only need to be 11 downto 0, and you could count
	--2048 ticks in either direction, regardless of the position of the 
	--encoder at system bootup.
	
	TYPE count_states IS (first_counter, second_counter, third_counter, fourth_counter); -- declaring enumeration
	signal count_state : count_states := first_counter;
	signal counter_one, counter_two, counter_three, counter_four : signed(11 downto 0) := (others => '0');
	
	signal main_counter : signed(11 downto 0);
	
	signal prevPrescaledClk : std_logic := '0';
	--this is the signal from the quadrature logic that it is time to change
	--the value of the counter on this clock signal (either + or -)
	signal CountEnable : std_logic;
	
	--should we increment or decrement count?
	signal CountDirection : std_logic;

	--where all the 'work' is done: quadraturedecoder.vhd
	component QuadratureDecoderPorts
    		Port (
        			clock     : in    std_logic;
        			QuadA     : in    std_logic;
        			QuadB     : in    std_logic;
        			Direction : out std_logic;
	   			CountEnable : out std_logic
    			);
	end component;

	begin --architecture QuadratureCounter		 

	--instanciate the decoder
	iQuadratureDecoder: QuadratureDecoderPorts 
	port map	( 
					clock => clock,
	      		QuadA => QuadA,
 	   			QuadB => QuadB,
    				Direction => CountDirection,
	       		CountEnable => CountEnable
			);


	-- do our actual work every clock cycle
	process(clock, reset, main_counter)
	begin
		--keep track of the counter
		if reset = '1' then 
			main_counter <= (OTHERS => '0');
			counter_one <= (others => '0');
			counter_two <= (others => '0');
			counter_three <= (others => '0');
			counter_four <= (others => '0');
		elsif ( (clock'event) and (clock = '1') ) then
			prevPrescaledClk <= prescaledClk;
			if (prevPrescaledClk /= prescaledClk and prescaledClk = '1') then
				CASE count_state IS
					when first_counter => 
						counter_one <= main_counter sll 4;
						count_state <= second_counter;
					when second_counter =>
						counter_two <= main_counter sll 4;
						count_state <= third_counter;
					when third_counter =>
						counter_three <= main_counter sll 4;
						count_state <= fourth_counter;
					when fourth_counter =>
						counter_four <= main_counter sll 4;
						count_state <= first_counter;
					when OTHERS => 
						NULL;
				end case;
				main_counter <= (others => '0');
				CountsPerSec <= std_logic_vector((counter_one + counter_two + counter_three + counter_four) srl 2);
			end if;
			if (CountEnable = '1') then
				if (CountDirection = '1') then main_counter <= main_counter + 1; end if;
				if (CountDirection = '0') then main_counter <= main_counter - 1; end if;
			end if;
		end if; --clock'event
		
		--CountsPerSec <= Count;

	end process; --(clock)
				   			  					
end QuadratureCounter;
