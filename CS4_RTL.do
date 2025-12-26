#-----
#-|  Computer Architecture course
#-|  INSA Rennes / ECE Department (EII)
#-|  Date: 2025
#-|  Author: J-G. Cousin (jcousin@insa-rennes.fr)
#-----
#--
#--> ModelSim simulation script
#>   command in Transcript window:  do ../<script-filename>.do
#-
#--  target device:   Cyclone IV E - EP4CE40F29C7
#--  simulated model: Slow -7 1.2V 85 Model


#-----
#-|  procedure wave_config
#
#	  populate waveform window
#
	proc wave_config { } {

		# Wave display configuration

		configure wave -namecolwidth 120
		configure wave -valuecolwidth 50
		configure wave -justifyvalue left
		configure wave -signalnamewidth 1
		configure wave -snapdistance 10
		configure wave -datasetprefix 0
		configure wave -rowmargin 4
		configure wave -childrowmargin 2
		configure wave -gridoffset 0
		configure wave -gridperiod 1
		configure wave -griddelta 40
		configure wave -timeline 0
		configure wave -timelineunits ns
	}


#-----
#-|  RTL simulator resetting
#
#>   command:  do <project-name>_run_msim_RTL_vhdl.do

	do CS4_RISC_run_msim_RTL_vhdl.do
#quit -sim


#-----
#-|  RTL simulation system load
#
#--> functional simulation
#>	  command:  vsim +altera -do <project-name>_run_msim_rtl_vhdl.do work.<top-filename>

	vsim +altera -do CS4_RISC_run_msim_rtl_vhdl.do work.CS4


#-----
#-|  signal declarations
#
#>	  main command:  add wave <signal-name>

	restart all
	wave_config

	add wave -divider  " global control "
	add wave 		 -label " reset "				 reset_i
	add wave 		 -label " ext. clock "		 clk_i
	add wave 		 -label " chip select "		 CS_i

#  internal RTL signals

	add wave -divider  " instruction flow "
	add wave -hex	 -label " PROM output "		/CS4/data_path/PMo
	add wave -uns	 -label " delay "				/CS4/data_path/delay
	add wave 		 -label " int. clock " 		 clki_o
	add wave -uns 	 -label " PC future "		/CS4/data_path/PCf
	add wave -uns	 -label " PC "					/CS4/data_path/PC
	add wave -uns	 -label " IF|ID pip. "		/CS4/data_path/pipeline/ID
	add wave -uns	 -label " ID|EX pip. "		/CS4/data_path/pipeline/EX
	add wave -uns	 -label " EX|MEM pip. "		/CS4/data_path/pipeline/MEM
	add wave -uns	 -label " MEM|WB pip. "		/CS4/data_path/pipeline/WB
	add wave 		 -label " int. clock "	 	 clki_o
	add wave -hex	 -label " IR "					/CS4/data_path/IR
	add wave -hex	 -label " MSb cmds"			/CS4/cmds(12:1)
	add wave -hex	 -label " MSb cmds int. "	/CS4/data_path/cmds(12:1)

	add wave -divider  " hazards "
	add wave 		 -label " RAW "				/CS4/data_path/RAW
	add wave 		 -label " bubble "			/CS4/data_path/bubble

	add wave -divider  " branch "
	add wave 		 -label " Crb "				/CS4/data_path/Crb
	add wave 		 -label " Xbz "				/CS4/data_path/Xbz

	add wave -divider  " reg. file read "
	add wave -uns	 -label " a-Rf "				/CS4/data_path/aRf
	add wave -dec	 -label " Ra "					/CS4/data_path/Ra
	add wave 		 -label " Ra=Rb ? "	 		/CS4/data_path/Zab
	add wave -dec	 -label " Rb "					/CS4/data_path/Rb
	add wave -uns	 -label " b-Rf "				/CS4/data_path/bRf

	add wave -divider  " ALU op. "
	add wave -dec	 -label " offset delayed "	/CS4/data_path/SXoff_1
	add wave -dec	 -label " in1 "				/CS4/data_path/in1
	add wave -dec	 -label " in2 "				/CS4/data_path/in2
	add wave -dec	 -label " ALU "				/CS4/data_path/ALU
	add wave -oct	 -label " Falu "				/CS4/data_path/Falu

	add wave -divider  " reg. file write "
	add wave 		 -label " int. clock " 		 clki_o
	add wave -uns	 -label " w@-Rf "				/CS4/data_path/waRf
	add wave -dec	 -label " write data "		/CS4/data_path/Rfw
	add wave 		 -label " Erf "				/CS4/data_path/Erf

	add wave -divider  " data memory "
	add wave 		 -label " Wram "				/CS4/data_path/Wdm
	add wave -uns	 -label " address RAM "		 Abus_o
	add wave -dec	 -label " RAM input "		/CS4/data_path/DMi
	add wave -dec	 -label " RAM output "		/CS4/data_path/DMo
	add wave 		 -label " int. clock " 		 clki_o

	add wave -divider  " I/O "
	add wave -dec	 -label " Xio "				/CS4/data_path/Xio
	add wave -dec	 -label " Input "				 Dbus_i
	add wave -dec	 -label " Output "			 Dbus_o
	
#-----
#-| Adding signals for CS4 testing
	add wave 		 -label "BTB_J"            /CS4/data_path/pipeline/BTB_opt/BTB_buffer/BTB_J
	add wave 		 -label "BTB_B"            /CS4/data_path/pipeline/BTB_opt/BTB_buffer/BTB_B
	add wave 		 -label "BTB_IB"           /CS4/data_path/pipeline/BTB_opt/BTB_buffer/BTB_IB
	add wave 		 -label "match_0"   /CS4/data_path/pipeline/BTB_opt/BTB_buffer/BTB_match_0
	add wave 		 -label "PC_btb"     /CS4/data_path/pipeline/BTB_opt/BTB_buffer/PCbtb
	add wave -dec	 -label "BTB Table"   /CS4/data_path/pipeline/BTB_opt/BTB_buffer/BTB   
	add wave 		 -label "BTB Mngt"   /CS4/data_path/pipeline/BTB_opt/BTB_buffer/BTB_mgt	 
	add wave 		 -label "Counter mgt"   /CS4/data_path/pipeline/BTB_opt/BTB_buffer/counter_mgt


#-----
#-|  signal assignments
#
#>	  main command:  force -freeze <signal-name> value1 time1, value2 time2, ...
#	  with absolute time:  time1 < time2 < ...

	# reset | chip select
	force -freeze reset_i  0 0ns, 1  12ns, 1  55ns
	force -freeze CS_i	  1 0ns, 0 873ns, 1 969ns

	# external 40-MHz clock > internal 20-MHz clock
	force -freeze clk_i	  0 0ns, 1 {12500 ps} -r 25ns

	# external input (12-bit)
	force -freeze Dbus_i	  16#F80 0ns


#-----
#-|  simulation
#
#--> time execution
#>	  command:  run duration
#
#--> window display [ time1 to time2 ]
#>	  command:  wave zoom range time1 time2

	# avoid warning(s) of metavalue detected at 0 ps
	set NumericStdNoWarnings 1
	run 0 ps
	set NumericStdNoWarnings 0 

	run  15us
	wave zoom range 0ns 1300ns

#  end