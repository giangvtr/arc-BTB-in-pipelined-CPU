-----
--|  Computer Architecture course
--|  INSA Rennes / ECE Department (EII)
--|  Date: 2025
--|  Author: J-G. Cousin (jcousin@insa-rennes.fr)
-----
--
-->  top of hierarchy: core of a RISC CPU
--
--   target device:	  Cyclone IV E - EP4CE40F29C7


-----
--|  external library

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;


-----
--|  external view of CPU

ENTITY CS4 IS
	GENERIC(
		  data_w : positive := 12;		--  data        width = 12-bit
		  	 dm_w : positive :=  6		--  data memory width =  6-bit
	);
	PORT(
		 reset_i : IN  std_logic;		--  reset
			 CS_i : IN  std_logic;		--  chip select
		   clk_i : IN  std_logic;		--  external synchronization
		   cdt_i : IN  std_logic;		--  external condition

		  Dbus_i	: IN  std_logic_vector(data_w-1 downto 0);	--  data bus input
		  Dbus_o	: OUT std_logic_vector(data_w-1 downto 0);	--  data bus output
		  Abus_o	: OUT std_logic_vector(  dm_w-1 downto 0);	--  address bus

		  Dbug_o	: OUT std_logic_vector(data_w-1 downto 0);	--  debug
		  Sbug_o	: OUT std_logic;

		  clki_o	: OUT std_logic		--  internal synchronization
	);
END CS4;


-----
--*  internal view of CPU

ARCHITECTURE arc_CS4 OF CS4 IS

	----
	--| components used

	COMPONENT CS4_datapath IS
		GENERIC(
			  cmd_w : positive;			--  CU commands    width
			  opc_w : positive;			--  opcode         width
			 data_w : positive;			--  data           width
				dm_w : positive;			--  data memory    width
				rf_w : positive;			--  reg.file index width
				pm_w : positive			--  program memory width
		);
		PORT(
			reset_i : IN  std_logic;	--  reset
			  clk_i : IN  std_logic;	--  synchronization

			 cmds_i : IN  std_logic_vector( cmd_w-1 downto 0);	--  CU command vector
			 Dbus_i : IN  std_logic_vector(data_w-1 downto 0);	--  Data    bus input
			 Dbus_o : OUT std_logic_vector(data_w-1 downto 0);	--  Data    bus output
			 Abus_o : OUT std_logic_vector(  dm_w-1 downto 0);	--  Address bus output

			 Dbug_o : OUT std_logic_vector(data_w-1 downto 0);	--  debug
			 Sbug_o : OUT std_logic;

			  opc_o : OUT std_logic_vector( opc_w   downto 1)	--  opcode
		);
	END COMPONENT;

	COMPONENT CS4_CU IS
		GENERIC(
			  cmd_w : positive;			--  CU command width
			  opc_w : positive			--  opcode     width
		);
		PORT(
			reset_i : IN  std_logic;	--  reset
			  clk_i : IN  std_logic;	--  synchronization
			  cdt_i : IN  std_logic;	--  external condition

			  opc_i : IN  std_logic_vector(opc_w   downto 1);	-- opcode
			 cmds_o : OUT std_logic_vector(cmd_w-1 downto 0)	-- command vector
		);
	END COMPONENT;

	----
	--| internal signals

	-- main sizing

	constant cmd_w : positive := 13;	--  command width = 13-bit
	constant opc_w : positive :=  4;	--  opcode  width =  4-bit

	-- internal signals

	signal cmds	   : std_logic_vector(cmd_w-1 downto 0);
	signal opcode  : std_logic_vector(opc_w   downto 1);
	signal clk_int : std_logic := '0';

BEGIN

	----
	--| output assignment

	clki_o <= clk_int;


	----
	--| component mapping

	--> pipelined version

	Ctrl_Unit :	CS4_CU
					GENERIC MAP ( cmd_w, opc_w )
					PORT    MAP ( reset_i, clk_int, cdt_i, opcode, cmds );

	data_path :	CS4_datapath
					GENERIC MAP ( cmd_w, opc_w, data_w, dm_w, 5, 7 )
					PORT    MAP ( reset_i, clk_int, cmds, Dbus_i, Dbus_o, Abus_o, Dbug_o, Sbug_o, opcode );


	----
	--| internal frequency divider

	--> characteristics:
	--		with priority asynchronous reset
	--		triggered on positive edge of the synchronization
	--		enabled by the chip select

	freq_divider : PROCESS ( reset_i, clk_i )
	BEGIN
		if ( reset_i='0' ) then  clk_int <= '0';
		elsif ( clk_i'event and clk_i='1' )  then
			if ( CS_i='1' ) then  clk_int <= not( clk_int );
			end if;
		end if;
	END PROCESS;

END arc_CS4;
--> end