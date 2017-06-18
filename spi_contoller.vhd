--library IEEE;
--use IEEE.STD_LOGIC_1164.ALL;


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_misc.all;
use IEEE.std_logic_unsigned.all;

entity spi_controller is
	port (
		clk: IN STD_LOGIC;
		reset: IN STD_LOGIC;
		EN: IN STD_LOGIC;
		RdWr: IN STD_LOGIC;
		CS: OUT STD_LOGIC;
		SPC: OUT STD_LOGIC;
		SDI: OUT STD_LOGIC;
		SDO: IN STD_LOGIC;
		regAddress: IN STD_LOGIC_VECTOR(5 DOWNTO 0);
		writeData: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		readData: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		dataReady: OUT STD_LOGIC
	);
end spi_controller;

architecture Behavioral of spi_controller is
	type state_t is (
		idle_state,
		lead_in_state,
		rw_state,
		ms_state,
		address_state,
		read_write_state,
		debug_state
	);
	signal timer, timer_next : time; -- for slowing down state transitions
	signal index, index_next : integer range 0 to 7; -- for indexing into registers
	signal state, state_next : state_t;
	signal rw, rw_next : STD_LOGIC;
	signal addr, addr_next : STD_LOGIC_VECTOR(5 DOWNTO 0);
	signal wData, wData_next : STD_LOGIC_VECTOR(7 DOWNTO 0);
	signal rData, rData_next : STD_LOGIC_VECTOR(7 DOWNTO 0);
	signal rDataReady, rDataReady_next : STD_LOGIC;
	signal cs_reg, cs_reg_next : STD_LOGIC;
	signal spc_reg, spc_reg_next : STD_LOGIC;
	signal sdi_reg, sdi_reg_next : STD_LOGIC;

	constant clk_period : time := 20 ns; -- 100 MHz ; 5 MHz: 200 ns
begin

CS <= cs_reg;
SPC <= spc_reg;
SDI <= sdi_reg;
readData <= rData;
dataReady <= rDataReady;

registers : process (clk)  begin
	if(rising_edge(clk)) then
		if(reset = '1') then
			state <= idle_state;
			timer <= 0 sec;
			index <= 0;
			rw <= '0';
			addr <= (others => '0');
			wData <= (others => '0');
			rData <= (others => '0');
			rDataReady <= '0';
			cs_reg <= '1';
			spc_reg <= '1';
			sdi_reg <= '0';
		else
			state <= state_next;
			timer <= timer_next;
			index <= index_next;
			rw <= rw_next;
			addr <= addr_next;
			wData <= wData_next;
			rData <= rData_next;
			rDataReady <= rDataReady_next;
			cs_reg <= cs_reg_next;
			spc_reg <= spc_reg_next;
			sdi_reg <= sdi_reg_next;
		end if;
	end if;
end process;

next_state : process (EN, RdWr, SDO, regAddress, writeData, state, timer, index, rw,
 					  addr, wData, rData, rDataReady, cs_reg, spc_reg, sdi_reg
) begin
	--default values for all the registers that the process sets:
	state_next <= state;
	timer_next <= timer;
	index_next <= index;
	addr_next <= addr;
	rw_next <= rw;
	wData_next <= wData;
	rData_next <= rData; 
	rDataReady_next <= rDataReady;
	cs_reg_next <= cs_reg;
	spc_reg_next <= spc_reg;
	sdi_reg_next <= sdi_reg;

	-- combinational logic for choosing the next state
	if(timer = 0 sec or (state = idle_state and EN = '1')) then
		--reset the timer so that the peripheral runs at 1 MHz:
		timer_next <= 1 us;
		-- toggle SPI clock when timer hits 0
		spc_reg_next <= not spc_reg;
		
		--switch on the current state
		-- If we are leaving the state, we will need to set everything up so
		-- that the correct outputs are asserted for the state we are entering!
		case(state) is
--		when init_state => --initial state
--
--			--don't toggle the SPI clock when we're idle:
--			spc_reg_next <= '0';
--			--keep cs and sdi high:
--			cs_reg_next <= '1';
--			sdi_reg_next <= '1';
--			
--
--			if(EN = '1') then
--				--switch out of the idle state
--				state_next <= idle_state;
--				--set outputs to what they should be when we get to lead_in_state:
--				cs_reg_next <= '0';
--				--store all of the inputs into registers
--				wData_next <= writeData;
--				addr_next <= regAddress;
--				rw_next <= RdWr;
--				--reset the readData register
--				rData_next <= (others => '0');
--			end if;

		when idle_state => -- state 0 in timing diagram
			--don't toggle the SPI clock when we're idle:
			spc_reg_next <= '1';
			--keep cs and sdi high:
			cs_reg_next <= '1';
			sdi_reg_next <= '1';
			

			if(EN = '1') then
				--switch out of the idle state
				state_next <= lead_in_state;
				--set outputs to what they should be when we get to lead_in_state:
				cs_reg_next <= '0';
				--store all of the inputs into registers
				wData_next <= writeData;
				addr_next <= regAddress;
				rw_next <= RdWr;
				--reset the readData register
				rData_next <= (others => '0');

			--else -- ENABLE = 0
				
			--	state_next <= idle_state;
			end if;

		when lead_in_state => -- state 1 in timing diagram
			state_next <= rw_state;
			--when we enter rw_state, we want rw to be output:
			sdi_reg_next <= rw;
			rDataReady_next <= '0';

		when rw_state => -- states 2,3
			--when the spi clock is high, we can switch to the next state
			if(spc_reg = '1') then
				state_next <= ms_state;
				--when we enter ms_state, we want to output 0 for the ms bit
				sdi_reg_next <= '0';
			end if;
			
		when ms_state => -- states 4,5
			if(spc_reg = '1') then
				state_next <= address_state;
				--for when we enter address_state:
				sdi_reg_next <= addr(5);
				index_next <= 5;
			end if;
			
		when address_state => -- states 6-17
			--cycle through the bits of addr register and output them
			if(spc_reg = '1') then
				if(index = 0) then
					--we're done with addr, so go to read_write_state:
					state_next <= read_write_state;
					sdi_reg_next <= wData(7);
					index_next <= 7;
				else
					--next bit of addr:
					sdi_reg_next <= addr(index-1);
					index_next <= index - 1;
				end if;


			end if;	

			--if (spc_reg = '0') and (index = 7) then
			--	rData_next(index) <= SDO;
			--end if;
			
		when read_write_state => -- states 18-33, 35-50
			if(spc_reg = '1') then
				-- we're about to have a falling edge on SPC
				-- write data to SDI from wData
				-- decrement the index
				-- what do we do when we're done?
				if (index =0) then
					--state_next <= debug_state;
					sdi_reg_next <=  wData(0);
					--index_next <= 15;
				else
					--next bit of data
					sdi_reg_next <= wData(index);
					--index_next <= index - 1;
				
				end if;
			else -- spc_reg = '0'
				-- we're about to have a rising edge on SPC
				-- read data from SDO to rData_next
				if (index=0) then
					state_next <= debug_state;
					rData_next(0) <= SDO;
					rDataReady_next <= '1';
					
				else
					rData_next(index) <= SDO;
					index_next <= index - 1;
					--rDataReady_next <= '1';
					
				end if;

--				if (index=1) then
--					rDataReady_next <= '1';
--					--cs_reg_next <= '1';
--					state_next <= idle_state;
--				end if;

				
			
			end if;

			--when read_write_state => -- states 18-33, 35-50

			--readData <= rData_next;

		when debug_state =>

			cs_reg_next <= '1';
			spc_reg_next <= '1';


		end case;
	else --timer is not zero:
		timer_next <= timer - clk_period;
	end if;
end process;

end Behavioral;

