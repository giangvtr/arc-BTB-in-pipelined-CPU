-----
--|  Computer Architecture course
--|  INSA Rennes / ECE Department (EII)
--|  Date: 2025
--|  Author: J-G. Cousin (jcousin@insa-rennes.fr)
-----
--
-->  CS4_CU - control unit


-----
--|  external libraries

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
LIBRARY work;
USE work.CS4_pack.ALL;
USE work.CS4_time.ALL;


-----
--|  external view of CU

ENTITY CS4_CU IS
	GENERIC(
		  cmd_w : positive := 13;		--  CU command width: 13-bit
		  opc_w : positive :=  4		--  opcode     width:  4-bit
	);
	PORT(
		reset_i : IN  std_logic;		--  reset
		  clk_i : IN  std_logic;		--  synchronization
		  cdt_i : IN  std_logic;		--  external condition

		  opc_i : IN  std_logic_vector(opc_w   downto 1);	--  opcode
		 cmds_o : OUT std_logic_vector(cmd_w-1 downto 0)	--  command vector
	);
END CS4_CU;


-----
--|  internal view of CU

ARCHITECTURE arc_CS4_CU OF CS4_CU IS

	----
	--| internal signals

	signal cmds      : std_logic_vector(cmd_w-1 downto 0);
	signal opc       : std_logic_vector(opc_w   downto 1);
	signal state_c   : state := init;	--  current   state
	signal state_f   : state;				--  future    state
	signal state_tmp : state;				--  temporary state

	-- delay line

	signal delay  : std_logic_vector(0 to CPA) := (0=>'1',others=>'0');

BEGIN

	----
	--| I/O assignments

		opc    <=  opc_i;
		cmds_o <=  cmds;


	----
	--| control
	--
	--  

	--> output function: command assignments

		-- LSbit: internal/external memory input

		cmds(0) <= '0'  when  opc(4 downto 1)/=b"1010"  else  '1';

		-- MSbits
		
		--! CS3 modification from there ...   Before : cmds(cmd_w-1 downto 1) <= ('1','1',others=>'0');

		with opc(4 downto 1) select
		cmds (cmd_w-1 downto 1) <=
		x"D28" when b"0000",   -- R-type instruction
		x"D40" when b"0001",   -- I-type instruction
		x"C00" when b"1111",   -- NOP    instruction  
		x"C05" when b"0010",   -- Branch instruction
		x"C06" when b"0011",   -- Jump   instruction
		x"EC0" when b"1000",	  -- Memory instruction (store)
		x"EC0" when b"1010",	  -- Memory instruction (store)
		x"DC0" when b"1001",	  -- Memory instruction (load)
		x"000" when others;
		
		--! CS3 modification ... to there


	----
	--| delay line

		D_line : PROCESS ( reset_i, clk_i )
		BEGIN
			if ( reset_i='0' ) then  delay <= (0=>'1',others=>'0');
			elsif rising_edge(clk_i) then
				if ( cmds(12)='1' ) then  delay <= (1=>'1',others=>'0');
				else  delay <= '0' & ( delay(0) or delay(CPA) ) & delay(1 to CPA-1);
				end if;
			end if;
		END PROCESS;

END arc_CS4_CU;
--> end