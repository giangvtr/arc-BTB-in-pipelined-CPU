-----
--|  Computer Architecture course
--|  INSA Rennes / ECE Department (EII)
--|  Date: 2025
--|  Author: J-G. Cousin (jcousin@insa-rennes.fr)
-----
--
-->  CS4_pack - package


-----
--|  private library

PACKAGE CS4_pack IS

	----
	--| enumerated FSM states

	type  state  is (
			 IFe,			--  fetch   instruction
			 ID,			--  decode  instruction
			 EXr,			--  execute R-type operation
			 EXi,			--  execute I-type operation
			 EXn,			--  execute  NOP   operation
			 EXb,			--  execute relative branch
			 EXj,			--  execute absolute jump
			 EXa,			--  calculate  data memory address
			 Sdm,			--  store into data memory
			 Ldm,			--  load  from data memory
			 WBl,			--  write back  load  result
			 WBr,			--  write back R-type result
			 WBi,			--  write back I-type result
			 init,		--  (re-)initialize
			 error		--  error
	);

END CS4_pack;
--> end