-----
--|  Computer Architecture course
--|  INSA Rennes / ECE Department (EII)
--|  Date: 2025
--|  Author: J-G. Cousin (jcousin@insa-rennes.fr)
-----
--
-->  CS4_time - time constants


-----
--|  private library

PACKAGE CS4_time IS

	-- ROM access time

	constant Trom : time := 40 ns;

	-- RAM access time

	constant Tram : time := 35 ns;

	-- optimization access time

	constant Topt : time := 15 ns;

	-- reg. file access time

	constant Trf  : time := 10 ns;

	-- clock period

	constant Tclk : time := 50 ns;

	-- clock cycle(s) per ROM access

	constant CPA : positive := Trom/Tclk+1;

END CS4_time;
--> end