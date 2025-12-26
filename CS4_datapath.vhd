-----
--|  Computer Architecture course
--|  INSA Rennes / ECE Department (EII)
--|  Date: 2025
--|  Author: J-G. Cousin (jcousin@insa-rennes.fr)
-----
--
-->  CS4_datapath - data path


-----
--|  external libraries

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY work;
USE work.CS4_time.ALL;


-----
--|  external view of data path

ENTITY CS4_datapath IS
	GENERIC(
		  cmd_w : positive := 13;		--  CU commands    width = 13-bit
		  opc_w : positive :=  4;		--  opcode         width =  4-bit
		 data_w : positive := 12;		--  data           width = 12-bit
		   dm_w : positive :=  6;		--  data memory    width =  6-bit
		   rf_w : positive :=  5;		--  reg.file index width =  5-bit
		   pm_w : positive :=  7		--  program memory width =  7-bit
	);
	PORT(
		reset_i : IN  std_logic;		--  reset
		  clk_i : IN  std_logic;		--  synchronization

		 cmds_i : IN  std_logic_vector( cmd_w-1 downto 0);	--  CU command vector
		 Dbus_i : IN  std_logic_vector(data_w-1 downto 0);	--  Data    bus input
		 Dbus_o : OUT std_logic_vector(data_w-1 downto 0);	--  Data    bus output
		 Abus_o : OUT std_logic_vector(  dm_w-1 downto 0);	--  Address bus output

		 Dbug_o : OUT std_logic_vector(data_w-1 downto 0);	--  debug
		 Sbug_o : OUT std_logic;

		  opc_o : OUT std_logic_vector( opc_w   downto 1)	--  opcode
	);
END CS4_datapath;


-----
--|  internal view of data path

ARCHITECTURE arc_CS4_datapath OF CS4_datapath IS

	--| memory declarations

	constant inst_w : positive := 24;	--  instruction width
	type PAS_tab is array(natural range <>) of std_logic_vector(inst_w-1 downto 0);
	type DAS_tab is array(natural range <>) of std_logic_vector(data_w-1 downto 0);

	-- program memory: contents with forced format ; "preloaded"

	constant	PROM : PAS_tab(0 to 2**pm_w-1) := (
		-- first default address = 0x00
		 0 => x"F00000",	 1 => x"AE0010",	 2 => x"9E2C10",	 3 => x"300008",
		 4 => x"9E2C10",
		-- ...
		 8 => x"8E2C11",	 9 => x"9E2011",	10 => x"194BFD",	11 => x"142001",
		12 => x"300019",	13 => x"042D06",
		-- ...
		-- subprogram base address = 0x19
								25 => x"09C962",	26 => x"8E2C11",	27 => x"291805",
		28 => x"19CC0D",	29 => x"0E1960",	30 => x"95B800",	31 => x"09BA62",
		32 => x"300023",	33 => x"09CD60",	34 => x"09AE60",	35 => x"131BFF",
		36 => x"1E7003", 	37 => x"2003E4",
		-- ...
		-- default value: NOP instruction 
			others => x"F00000"
	);

	-- register file: contents with forced format ; initialized for test

	signal Rf : DAS_tab(0 to 2**rf_w-1) := (	--		integer values =
		x"000",  x"004",  x"FC5",  x"07E",		--      0,   +4,  -59, +126,
		x"F96",  x"F81",  x"01F",  x"04D",		--	  -106, -127,  +31,  +77,
		x"FFF",  x"01B",  x"004",  x"F7F",		--	    -1,  +27,   +4, -129, 
		x"FF4",  x"060",  x"001",  x"F80",		--    -12,  +96,   +1, -128,
		x"080",  x"004",  x"024",  x"07E",		--	  +128,   +4,  +36, +126,
		x"300",  x"004",  x"FC5",  x"07E",		--	  +768,   +4,  -59, +126,
		x"021",  x"05E",  x"FC5",  x"07E",		--	   +33,  +94,  -59, +126,
		x"005",  others => x"000"					--	    +5,   others 0
	);


	----
	--| pipeline - additionnal signals

	-- delayed signals in datapath

	signal PCinc_0: std_logic_vector(  pm_w-1 downto 0) := (others=>'0');
	signal SXoff_1: std_logic_vector(data_w-1 downto 0) := (others=>'0');
	signal Ra_1   : std_logic_vector(data_w-1 downto 0) := (others=>'0');
	signal Rb_1   : std_logic_vector(data_w-1 downto 0) := (others=>'0');
	signal waRf_0 : std_logic_vector(  rf_w-1 downto 0);
	signal ALU_2  : std_logic_vector(data_w-1 downto 0) := (others=>'0');
	signal ALU_3  : std_logic_vector(data_w-1 downto 0) := (others=>'0');
	signal DMi_1  : std_logic_vector(data_w-1 downto 0) := (others=>'0');
	signal DMo_3  : std_logic_vector(data_w-1 downto 0) := (others=>'0');

	-- delayed commands in pipeline stages

	signal cmds_1 : std_logic_vector(      10 downto 4) := (others=>'0');
	signal cmds_2 : std_logic_vector(      10 downto 8) := (others=>'0');
	signal cmds_3 : std_logic_vector(       9 downto 8) := (others=>'0');

	-- mask: cycle suspension (dynamic NOP)

	constant Mnop : std_logic_vector( cmd_w-3 downto 0) := (cmd_w-3 downto cmd_w-4 =>'0',others=>'1');

	-- hazards

	signal bubble : std_logic;		--  flag bubble
	signal RAW    : std_logic;		--  flag RAW


	----
	--| CS4 optimization

	-- 0 without / 1 with

	constant optim  : std_logic := '0';
	constant opt_BTB : std_logic := '1';	-- 0 without / 1 with

	-- L1-I cache miss

	signal L1I_miss : std_logic := '0';

	-- delay line

	signal delay : std_logic_vector(0 to CPA) := (0=>'1',others=>'0');


	----
	--| internal signals

	-- common signals: Instruction Register / Sign-eXtended offset

	signal IR	 : std_logic_vector( inst_w-1 downto 0) :=   (inst_w-1 downto inst_w-opc_w =>'1',others=>'0');
	alias  IRopc : std_logic_vector(  opc_w   downto 1) is IR(inst_w-1 downto inst_w-opc_w);
	signal SXoff : std_logic_vector( data_w-1 downto 0);

	-- instruction flow: current PC / future PC / incremented PC / if J / if B

	signal PC 	 : std_logic_vector(   pm_w-1 downto 0) := (others=>'0');
	signal PCf	 : std_logic_vector(   pm_w-1 downto 0);	--  PC future
	signal PCinc : std_logic_vector(   pm_w-1 downto 0);	--  PC incremented 
	alias  PCj	 : std_logic_vector(   pm_w-1 downto 0) is IR(pm_w-1 downto 0);
	signal PCrb	 : std_logic_vector(   pm_w-1 downto 0);	--  relative Branch
	signal Xbz	 : std_logic;			  --  mux select > conditional Bz
	signal Zab	 : std_logic;			  --  Ra=Rb ?

	-- register file: a & b read ports / w write port

	alias	 aRf	 : std_logic_vector(   rf_w-1 downto 0) is IR(19 downto 15);
	signal Ra	 : std_logic_vector( data_w-1 downto 0);	--  Ra output
	alias	 bRf	 : std_logic_vector(   rf_w-1 downto 0) is IR(14 downto 10);
	signal Rb 	 : std_logic_vector( data_w-1 downto 0);	--  Rb output
	signal waRf	 : std_logic_vector(   rf_w-1 downto 0) := (others=>'0'); --  Rf write address
	signal Rfw	 : std_logic_vector( data_w-1 downto 0);	--  Rf write input

	-- Arithmetic & Logic Unit: in1 & in2 operands / result / function / SLT LSbit

	alias	 in1	 : std_logic_vector( data_w-1 downto 0) is Ra_1; --  1st operand					--! CS3 modification		Before : in1	 : std_logic_vector( data_w-1 downto 0) is Ra;
	signal in2	 : std_logic_vector( data_w-1 downto 0);	--   2d operand
	signal ALU	 : std_logic_vector( data_w-1 downto 0);	--  ALU output
	signal Falu	 : std_logic_vector(        3 downto 1);	--  ALU function
	signal SLT   : std_logic;										--  SLT LSbit

	-- address spaces: Data Memory address / Data Memory I/O / Program Memory output

	alias  aDM	 : std_logic_vector(   dm_w-1 downto 0) is ALU_2(dm_w-1 downto 0);				--! CS3 modification		Before : aDM	 : std_logic_vector(   dm_w-1 downto 0) is ALU(dm_w-1 downto 0);
	signal DMi	 : std_logic_vector( data_w-1 downto 0) := (others=>'0'); --  RAM input
	signal DMo	 : std_logic_vector( data_w-1 downto 0);	--  RAM output
	signal PMo	 : std_logic_vector( inst_w-1 downto 0);	--  ROM output

	-- datapath commands

	signal cmds  : std_logic_vector(  cmd_w-1 downto 0);
	alias  Epc	 : std_logic is cmds( 12 );		--  PC enable
	alias  Eir	 : std_logic is cmds( 11 );		--  IR eanble	
	alias  Wdm	 : std_logic is cmds_2( 10 );		--  data mem. write									--! CS3 modification		Before : Wdm	 : std_logic is cmds( 10 );
	alias  Erf	 : std_logic is cmds_3(  9 );		--  reg. file enable									--! CS3 modification		Before : Erf	 : std_logic is cmds( 9 );
	alias  Xdmrf : std_logic is cmds_3(  8 );		--  mux select > DRAM|reg.-file					--! CS3 modification		Before : Xdmrf	 : std_logic is cmds( 8 );
	alias  Xalu	 : std_logic is cmds_1(  7 );		--  mux select > ALU									--! CS3 modification		Before : Xalu	 : std_logic is cmds( 7 );
	alias  Calu	 : std_logic_vector(2 downto 1) is cmds_1(6 downto 5); --  CU-alu commands		
	alias  Xrf	 : std_logic is cmds(  4 );		--  mux select > waRf
	alias  Xpc	 : std_logic is cmds(  3 );		--  mux select > PCf
	alias  Xjb	 : std_logic is cmds(  2 );		--  mux select > J|B
	alias  Crb	 : std_logic is cmds(  1 );		--  command branch
	alias  Xio	 : std_logic is cmds_1(  4 );		--  mux select > DMi									--! CS3 modification		Before : Xio	 : std_logic is cmds(  4 );

BEGIN

	----
	--| I/O assignments

	cmds   <= cmds_i  when  ( RAW='0' and L1I_miss='0' )  else  ( cmds_i and bubble & bubble & Mnop );
	 opc_o <= IRopc;
	Abus_o <= aDM;
	Dbus_o <= DMo;

	Dbug_o <= DMi;
	Sbug_o <= Wdm;


	----
	--| instruction flow

	PC_mgt: BLOCK IS
	BEGIN

	--> PC management: PC incremented (PC++)

		PCinc <= std_logic_vector( to_unsigned(((to_integer(unsigned(PC))+1) mod 2**pm_w),pm_w) );

	--> PC future

		PCf_nopt: IF ( opt_BTB='0' ) GENERATE    --! CS4 optim modified by opt_BTB
		PCf <= PCinc  when  Xpc='0'  else  PCj  when  Xjb='1'  else  PCrb  when  Xbz='1'  else  PCinc;
		END GENERATE PCf_nopt;

	--> synchronous load into PC

		PC_reg : PROCESS ( reset_i, clk_i )
		BEGIN
			if ( reset_i='0' ) then  PC <= (others=>'0');
			elsif rising_edge(clk_i) then
				if ( Epc='1' ) then
					if ( optim='1' ) then  PC <= PCf;															-- Finalement j'ai laissé optim et pas opt_BTB car besoin du delay si on augmente le temps de Trom à 120 ns
					elsif ( delay(CPA)='1' or bubble='1' ) then  PC <= PCf;
					end if;
				end if;
			end if;
		END PROCESS;

	END BLOCK PC_mgt;


	----
	--| IF - Instruction Fetch

	IF_stage: BLOCK IS
	BEGIN

	--> asynchronous fetch from program memory

		PMo_nopt: IF ( optim='0' ) GENERATE
		PMo <= PROM( to_integer(unsigned(PC)) ) after Trom;
		END GENERATE PMo_nopt;

	--> synchronous load into IR

		IR_reg : PROCESS ( reset_i, clk_i )
		BEGIN
			if ( reset_i='0' ) then  IR <= (inst_w-1 downto inst_w-opc_w =>'1',others=>'0');
			elsif rising_edge(clk_i) then
				if ( Eir='1' ) then
					if ( optim='1' ) then
						if ( bubble='0' ) then  IR <= PMo;
						else IR <= (inst_w-1 downto inst_w-opc_w =>'1',others=>'0');
						end if;
					elsif ( bubble='0' and delay(CPA)='1' ) then  IR <= PMo;
					else IR <= (inst_w-1 downto inst_w-opc_w =>'1',others=>'0');
					end if;
				end if;
			end if;
		END PROCESS;

	END BLOCK IF_stage;


	----
	--| ID - Instruction Decode

	ID_stage: BLOCK IS
	BEGIN

	--> Sign-eXtended offset / register-file reads / write address of register file

		SXoff  <= std_logic_vector( to_signed(to_integer(signed(IR(9 downto 0))),data_w) );
		Ra     <= Rf( to_integer(unsigned(aRf)) ) after Trf;
		Rb     <= Rf( to_integer(unsigned(bRf)) ) after Trf;
		waRf_0 <= IR(9 downto 5)  when  Xrf='1'  else  IR(14 downto 10);

	--> relative branch: address / comparison / mux select

		PCrb  <= std_logic_vector( to_unsigned(((to_integer(signed(PCinc_0))+to_integer(signed(SXoff))) mod 2**pm_w),pm_w) );
		Zab   <= '1'  when  ( Ra=Rb )  else  '0';
		Xbz   <= Crb and Zab;

	END BLOCK ID_stage;


	----
	--| EX - EXecute

	EX_stage: BLOCK IS
	BEGIN

	--> ALU management: 2d operand select / SLT LSbit / functions

		in2  <= SXoff_1  when  Xalu='1'  else  Rb_1; 
		SLT  <= '1'  when  ( signed(in1)<signed(in2) )  else '0';
		Falu <= '0' & Calu  when  Calu(2)='0'  else  SXoff_1(2 downto 0);

		with  Falu  select
				ALU  <=	( in1 and in2 )  when  "100",					--  AND
							( in1  or in2 )  when  "101",					--  OR
							( in1 xor in2 )  when  "110",					--  XOR
							( 0=>SLT, others=>'0' )  when  "011",		--  SLT
	std_logic_vector( to_signed((to_integer(signed(in1))-to_integer(signed(in2))),data_w) )  when  "001",	--  minus
	std_logic_vector( to_signed((to_integer(signed(in1))-to_integer(signed(in2))),data_w) )  when  "010",	--  minus
	std_logic_vector( to_signed((to_integer(signed(in1))+to_integer(signed(in2))),data_w) )  when others;	--  plus

	--> RAM input select: incoming from register file | outside (peripheral device)

		DMi_1 <= Rb_1  when  Xio='0'  else  Dbus_i;

	END BLOCK EX_stage;


	-----
	--|  MEM - data MEMory

	MEM_stage: BLOCK IS
	BEGIN

	--> data RAM: contents with forced format ; initialized for test

		Data_Memory : PROCESS ( aDM, clk_i )
			variable DRAM : DAS_tab(0 to 2**dm_w-1) := (			--  integer values =
				11 => x"FF1",  12 => x"00B",	25 => x"FE9",		--   -15,  +11,  -23, 
				31 => x"043",	32 => x"001",  33 => x"05D",		--   +67,   +1,  +93,
				34 => x"FF3",  35 => x"FCA",	36 => x"063",		--   -13,  -54,  +99,
				37 => x"FF9",	38 => x"FFE",  others => x"111"	--    -7,   -2,  others +273
			);
		BEGIN
			if rising_edge(clk_i) then		--   synchronous RAM write
				if ( Wdm='1' ) then  DRAM( to_integer(unsigned(aDM)) ) := DMi;
				end if;
			end if;								--  asynchronous RAM read
			DMo <= DRAM( to_integer(unsigned(aDM)) ) after Tram;
		END PROCESS;

	END BLOCK MEM_stage;


	-----
	--|  WB - Write Back to register file

	WB_stage: BLOCK IS
	BEGIN

	--> write input select

		Rfw <= DMo_3  when  Xdmrf='1'  else  ALU_3;

	--> synchronous register file write

		reg_file : PROCESS ( clk_i )
		BEGIN
			if falling_edge(clk_i) then
				if ( Erf='1' ) then
					if ( to_integer(unsigned(waRf))>0 ) then
						Rf( to_integer(unsigned(waRf)) ) <= Rfw;
					end if;
				end if;
			end if;
		END PROCESS;

	END BLOCK WB_stage;


	-----
	--|  pipeline add-ons

	pipeline: BLOCK IS

		-- delayed signals in datapath

		signal waRf_1 : std_logic_vector(  rf_w-1 downto 0) := (others=>'0');
		signal waRf_2 : std_logic_vector(  rf_w-1 downto 0) := (others=>'0');
		alias  Erf_1  : std_logic is cmds_1( 9 );
		alias  Erf_2  : std_logic is cmds_2( 9 );

		-- pipeline stages: display and debugging only (with tri-state Z)

		signal ID     : std_logic_vector(  pm_w-1 downto 0) := (others=>'Z');
		signal EX     : std_logic_vector(  pm_w-1 downto 0) := (others=>'Z');
		signal MEM    : std_logic_vector(  pm_w-1 downto 0) := (others=>'Z');
		signal WB     : std_logic_vector(  pm_w-1 downto 0) := (others=>'Z');

	BEGIN

	--> delay line

		Dline_nopt: IF ( optim='0' ) GENERATE
		D_line : PROCESS ( reset_i, clk_i )
		BEGIN
			if ( reset_i='0' ) then  delay <= (0=>'1',others=>'0');
			elsif rising_edge(clk_i) then
				if ( bubble='1' ) then  delay <= (1=>'1',others=>'0');
				elsif ( Epc='1' or delay(CPA)='0' ) then  delay <= '0' & ( delay(0) or delay(CPA) ) & delay(1 to CPA-1);
				end if;
			end if;
		END PROCESS;
		END GENERATE Dline_nopt;

	-->  hazard detect - what about?
	
		-- control dependence: dynamic NOP generated when ...

		bubble_nopt: IF ( opt_BTB='0' ) GENERATE				--! CS4 optim modified by opt_BTB
		bubble <= '1' when (Xjb='1' or Xbz='1') else '0';		--! CS3 modification		Before : bubble <= '1'  when  ( IRopc=b"0011" )  else  '0';
		END GENERATE bubble_nopt;

		-- Read-After-Write data dependence: suspended cycle when ...

		RAW <= '1'  when  (( Erf_1='1' and (((IRopc="0001" or IRopc="1001") and waRf_1=aRf)		--! CS3 modification		Before : RAW <= '1' when ( Mnop( 1 )='0' ) else '0';
					or ((IRopc="0000" or IRopc="1000" or IRopc="1010" or Crb='1') and (waRf_1=aRf or waRf_1=bRf))))
					or( Erf_2='1' and (((IRopc="0001" or IRopc="1001") and waRf_2=aRf)
					or ((IRopc="0000" or IRopc="1000" or IRopc="1010" or Crb='1') and (waRf_2=aRf or waRf_2=bRf)))))          
               else  '0';

	--> pipeline registers

		IFID : PROCESS ( reset_i, clk_i )
		BEGIN
			if ( reset_i='0' ) then  PCinc_0 <= (others=>'0');
			elsif rising_edge(clk_i) then
				if ( Eir='1' ) then  PCinc_0 <= PCinc;
				end if;
			end if;
		END PROCESS;
		IDEX : PROCESS ( reset_i, clk_i )
		BEGIN
			if ( reset_i='0' ) then  cmds_1 <= (others=>'0');
			elsif rising_edge(clk_i) then
				if ( RAW='0' ) then
						Ra_1 <= Ra;
						Rb_1 <= Rb;
					SXoff_1 <= SXoff;
					 waRf_1 <= waRf_0;
				end if;
				cmds_1 <= cmds(10 downto 5) & cmds(0);
			end if;
		END PROCESS;
		EXMEM : PROCESS ( reset_i, clk_i )
		BEGIN
			if ( reset_i='0' ) then  cmds_2 <= (others => '0');
			elsif rising_edge(clk_i) then
				 ALU_2 <=  ALU;
				 DMi   <=  DMi_1;
				waRf_2 <= waRf_1;
				cmds_2 <= cmds_1(10 downto 8);
			end if;
		END PROCESS;
		MEMWB : PROCESS ( reset_i, clk_i )
		BEGIN
			if ( reset_i='0' ) then  cmds_3 <= (others=>'0');
			elsif rising_edge(clk_i) then
				 ALU_3 <=  ALU_2;
				 DMo_3 <=  DMo;
				 waRf  <= waRf_2;
				cmds_3 <= cmds_2(9 downto 8);
			end if;
		END PROCESS;
		
		
	--! # =========================== Beginning of BTB implementation ===============================


	--| BTB - Branch Target Buffer

	BTB_opt: IF ( opt_BTB='1' ) GENERATE
	BTB_buffer: BLOCK IS

		constant BTB_line : positive := 3;				--  line number	

		subtype  mod_nat is natural range 0 to 1;
		constant BTB_mode : mod_nat  := 1;				--	 management mode

		type BTB_1_line is record
			CV  : std_logic_vector(1 to 2);				--  branch condition & validated line 
			PC  : std_logic_vector(pm_w-1 downto 0);	--  source address
			PCo : std_logic_vector(pm_w-1 downto 0);	--  target address
		end record BTB_1_line;								--  line reset
		constant BTB_init : BTB_1_line := (CV=>b"10",PC=>(others=>'0'),PCo=>(others=>'0'));

		type    BTB_tab is array(natural range <>) of BTB_1_line;
		signal  BTB	   : BTB_tab(0 to BTB_line-1)  := (others=>BTB_init);		--  BTB
			
		signal PC_0		: std_logic_vector(pm_w-1 downto 0) := (others=>'0');	--  
		signal PCbtb	: std_logic_vector(pm_w-1 downto 0) := (others=>'0');	--  BTB output (Program counter predit par BTB)
		signal BTB_match   : std_logic := '0';											--  presence in BTB ?
		signal BTB_match_0 : std_logic := '0';											--  
		signal BTB_J	: std_logic;														--  detect a jump
		signal BTB_B	: std_logic;														--  detect a branch
		signal BTB_IB	: std_logic;														--  detect an inconditional branch 

		type   BTB_tab_mgt is array(natural range <>) of std_logic_vector(BTB_line-1 downto 0);
		signal BTB_mgt : BTB_tab_mgt(0 to BTB_line-1) := (others=>(others=>'0'));	--  BTB line management

		subtype BTB_nat is natural range 0 to BTB_line-1;
		
		signal slg_read : BTB_nat := 0;	--! CS4 line number saved for its management when there is a reading
		signal counter_mgt : natural range 0 to BTB_line := BTB_line; --! CS4 counter for management FIFO (like the index of the load) or LRU (like the number of line which have their priority equal to 0)

	BEGIN

	--> PC future

		PCf  <=  PCbtb  when  ( BTB_match='1' and BTB_J = '0' and BTB_IB = '0' )  else  PCinc  when  Xpc='0'  else  PCj  when  BTB_J='1'  else  PCrb  when  (BTB_B='1' or BTB_IB ='1')  else  PCinc; --! CS4 modified		Before : PCf  <=  PCbtb  when  ( BTB_match='1' and BTB_J='0' and BTB_IB='0' )  else  PCinc  when  Xpc='0'  else  PCj  when  BTB_J='1'  else  PCrb  when  BTB_B='1'  else  PCinc;

	--> asynchronous read in BTB

		BTB_read : PROCESS ( reset_i, PC )
			variable hit : std_logic;
			variable slg : BTB_nat;
		BEGIN
			hit := '0';
			if ( reset_i='1' ) then		--! CS4 spaces completed from there ...
				for k in 0 to BTB_line-1 loop
				
					--! If the current PC is already loaded in the BTB and the line is valid
					if(PC=BTB(k).PC and BTB(k).CV(2) = '1') then
						hit := '1';
						slg :=k;	
						slg_read <= slg;	--! Number of the line checked is saved to keep the information for LRU
						exit;						
					end if;
				end loop;
			end if; 							--! CS4 ... to there
			if ( hit='1' ) then
				if ( BTB(slg).CV(1)='1' ) then
					PCbtb <= BTB(slg).PCo after Topt;
				else	PCbtb <= PCinc;
				end if;
			end if;
			BTB_match <= hit;
		END PROCESS;

	--> BTB pipeline register

		BTB_pipe : PROCESS (reset_i, clk_i)		--! CS4 parameters added
		BEGIN
			if ( reset_i='0' ) then
				PC_0 <= (others=>'0');
				BTB_match_0 <= '0';
			elsif rising_edge(clk_i) then
				if ( Eir='1' ) then
					PC_0 <= PC;
					BTB_match_0 <= BTB_match;
				end if;
			end if;
		END PROCESS;

	--> three wrong equations: to be updated

		BTB_J   <= '1'  when IRopc = "0011"          and BTB_match_0 = '0' else '0';	--! CS4 line modified		Before : BTB_J   <= '0';
		BTB_B   <= '1'  when  Xbz = '1' and aRf/=bRf and BTB_match_0 = '0' else '0';	--! CS4 line modified		Before : BTB_B   <= '1'  when  ( BTB_match_0='0' )  else  '0';
		BTB_IB  <= '1'  when  Xbz = '1' and aRf=bRf  and BTB_match_0 = '0' else '0';	--! CS4 line modified		Before : BTB_IB  <= '1'  when  ( BTB_B='1' )  else  '0';

	--> control dependence: dynamic NOP generated when ...	

		bubble <= '1'  when  ( BTB_J='1' or BTB_IB='1' or BTB_B='1' )	else  '0';	--! CS4 line modified		Before : bubble <= '1'  when  ( IRopc=b"0011" )  else  '0';

	--> synchronous load into BTB

		BTB_load : PROCESS (reset_i, clk_i)		--! CS4 parameters added
		
			variable slg : BTB_nat;
		BEGIN
			if ( reset_i='0' ) then
				for k in 0 to BTB_line-1 loop
					BTB(k).CV(2) <= '0';
				end loop;
				
			elsif rising_edge(clk_i) then
				if ( RAW='0' and ( BTB_IB='1' or BTB_J='1')) then --! CS4 parameters BTB_IB and BTB_J added
					
					
					--! If BTB_mode = 1 (mode LRU)
					if(BTB_mode /= 0) then					--! CS4 spaces completed from there ...
						slg := 0;
						for k in BTB_line-1 downto 0 loop
						
							--! If there is no reset at the beginning
							if(counter_mgt /= 0) then
								if(unsigned(BTB_mgt(k)) = 0) then	 --! Research the first line with a priority equal to 0	
									slg:=k;								
									exit;
								end if;
								
							--! If there is no priority equal to 0
							elsif (BTB_mgt(k)(0) = '1') then		--!  Research the oldest line
									slg:=k;								
									exit;
							end if;
						end loop;

					--! If BTB_mode = 0 (mode FIFO), use counter_mgt as index to write	
					else
						slg := BTB_line-counter_mgt;
					end if;										--! CS4 ... to there
					
					
					
					if ( BTB_J='1') then		-- ?  

						BTB(slg).PC  <= PC_0;	--! CS4 line completed
						BTB(slg).PCo <= PCj;		--! CS4 line completed
						BTB(slg).CV  <= "11";	--! CS4 line completed
					end if;
					
					
					if ( BTB_IB='1') then		-- ?
						BTB(slg).PC  <= PC_0;	--! CS4 line completed
						BTB(slg).PCo <= PCrb;	--! CS4 line completed
						BTB(slg).CV  <= "11";	--! CS4 line completed
					end if;
					
				end if;
			end if;
		END PROCESS;

	--> BTB management
 
		BTB_management : PROCESS (reset_i, clk_i)		--! CS4 parameters added
			--! CS4 variable not used Before : variable mgt : std_logic_vector(BTB_line-1 downto 0);
			--! CS4 variable not used Before : variable slg : std_logic_vector(BTB_line-1 downto 0);
		BEGIN
			if ( reset_i='0' ) then
				for k in 0 to BTB_line-1 loop
					BTB_mgt(BTB_line-1-k) <= (k=>'1',others=>'0');
				end loop;
				if (BTB_mode /= 0) then
					counter_mgt <= 0;			--! CS4 line added to initilize the counter_mgt to 0 is the BTB_mode is LRU
				end if;
			elsif (Rising_edge(clk_i) and (BTB_match_0='1' or BTB_IB='1' or BTB_J='1')) then  --! CS4 parameters modified	Before : elsif falling_edge(clk_i) then
				case BTB_mode is
					when 0		=>		-- 0 mode FIFO			--! CS4 spaces completed from there ...
						--! If there was a load
						if(BTB_match_0 = '0') then
							if(counter_mgt /= 1) then
								counter_mgt <= counter_mgt-1; --! Decrement of the counter
							else
								counter_mgt <= BTB_line;	--! Modulo on the counter
							end if;
						end if;										--! CS4 ... to there
							
					when others	=>		--  default mode LRU		--! CS4 spaces completed from there ...
						
						--! If there was a match in the BTB_read and the line used is not the most recent
						if(BTB_match_0='1' and BTB_mgt(slg_read)(BTB_line-1)/= '1') then
						
							for k in 0 to BTB_line-1 loop
							
								--! If the priority is higher than the read_priority of the line which is used in the BTB_read
								if( unsigned(BTB_mgt(k)) > unsigned(BTB_mgt(slg_read))) then 
									if (BTB_mgt(k)(0)/='1') then
										--! Shift to the right direction
										BTB_mgt(k)<= '0' & BTB_mgt(k)(BTB_line-1 downto 1);
									end if;
								end if;
							end loop;
							--! Update to the most recent line 
							BTB_mgt(slg_read)<= (BTB_line-1 => '1', others => '0');

						--! If there was a load in the BTB
						elsif (BTB_match_0='0') then
						
							--! If all the priority are different of 0
							if( counter_mgt = 0 ) then
					
							for k in BTB_line-1 downto 0 loop
								--! If the line is the oldest
								if (BTB_mgt(k)(0)= '1') then
									--! Update to the most recent line 
									BTB_mgt(k) <= (BTB_line-1 => '1', others => '0');
								else
									--! Shift to the right direction to decrease their priority
									BTB_mgt(k)<= '0' & BTB_mgt(k)(BTB_line-1 downto 1);
								end if;
							end loop;
						
							--! If there is still priority equal to 0
							else
								for k in BTB_line-1 downto 0 loop
									if(unsigned(BTB_mgt(k))= 0) then								--! Research the first line with a priority equal to 0	 	
										BTB_mgt(k) <= (BTB_line-1 => '1', others => '0');	--! Update to the most recent line
										exit;
									else
									BTB_mgt(k)<= '0' & BTB_mgt(k)(BTB_line-1 downto 1);		--! Shift to the right direction to decrease their priority
									end if;
								end loop;
								counter_mgt <= counter_mgt-1; 	--! Decrease the counter to know how many lines with a priority of 0 are still present
							end if;
						end if;

				end case;												--! CS4 ... to there
			end if;
		END PROCESS;

	END BLOCK BTB_buffer;
	END GENERATE BTB_opt;

--> end 


  	--! # =========================== End of BTB implementation ===============================
		
		
		
		
		
		
		
		

	--> display - pipeline debugging only
	--
	--# do not change!

		dbug_pipes : PROCESS ( reset_i, clk_i )
			variable ID_v,EX_v,MEM_v,WB_v : std_logic_vector(pm_w downto 1) := (others=>'Z');
		BEGIN
			if ( reset_i='0' ) then 
				 WB_v := (others=>'Z');
				MEM_v := (others=>'Z');
				 EX_v := (others=>'Z');
				 ID_v := (others=>'Z');
			elsif rising_edge(clk_i) then
				 WB_v := MEM_v;
				MEM_v :=  EX_v;
				if ( RAW='0' ) then  EX_v := ID_v;
					if ( bubble='0' ) then
						if ( optim='1' ) then
							if ( L1I_miss='0' ) then  ID_v := PC;
							end if;
						elsif ( delay(CPA)='1' ) then  ID_v := PC;
						end if;
					end if;
				end if;
			end if;
			ID  <= ID_v;
			EX  <= EX_v;
			MEM <= MEM_v;
			WB  <= WB_v;
		END PROCESS;

	END BLOCK pipeline;

END arc_CS4_datapath;
--> end