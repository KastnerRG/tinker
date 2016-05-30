# ----------------------------------------------------------------------
# Copyright (c) 2016, The Regents of the University of California All
# rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#
#     * Neither the name of The Regents of the University of California
#       nor the names of its contributors may be used to endorse or
#       promote products derived from this software without specific
#       prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL REGENTS OF THE
# UNIVERSITY OF CALIFORNIA BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
# USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.
# ----------------------------------------------------------------------
package require -exact qsys 15.1
lappend auto_path $::env(TCLXML_PATH)
package require xml

set_module_property NAME {ddr3_interface}
set_module_property DISPLAY_NAME {Tinker DDR3 Hardware Interface}
set_module_property VERSION {15.1}
set_module_property GROUP {Tinker}
set_module_property DESCRIPTION {default description}
set_module_property AUTHOR {Dustin Richmond, Matthew Hogains, Kevin Thai, Jeremy Blackstone}
set_module_property COMPOSITION_CALLBACK compose
set_module_property opaque_address_map false

#############################################################################
# parameters
#############################################################################
add_parameter BOARD_PATH String "Board Path"
set_parameter_property BOARD_PATH DEFAULT_VALUE $::env(TINKER_PATH)
set_parameter_property BOARD_PATH DISPLAY_NAME BOARD_PATH
set_parameter_property BOARD_PATH TYPE STRING
set_parameter_property BOARD_PATH UNITS None
set_parameter_property BOARD_PATH DESCRIPTION "Path to board directory containing board_specification.xml, with board-specific xml file in the parent directory"
set_parameter_property BOARD_PATH HDL_PARAMETER true

add_parameter MEMORY_IDENTIFIER String 1 "Memory Identifier"
set_parameter_property MEMORY_IDENTIFIER DEFAULT_VALUE a
set_parameter_property MEMORY_IDENTIFIER DISPLAY_NAME MEMORY_IDENTIFIER
set_parameter_property MEMORY_IDENTIFIER TYPE STRING
set_parameter_property MEMORY_IDENTIFIER UNITS None
set_parameter_property MEMORY_IDENTIFIER DESCRIPTION "Memory identifier, for timing parameters"
set_parameter_property MEMORY_IDENTIFIER HDL_PARAMETER true
set_parameter_property MEMORY_IDENTIFIER ALLOWED_RANGES {a b c d e f g h i j k l m n o p q r s t u v w x y z}

add_parameter SYSTEM_IDENTIFIER String 1 "System Identifier"
set_parameter_property MEMORY_IDENTIFIER DEFAULT_VALUE a
set_parameter_property MEMORY_IDENTIFIER DISPLAY_NAME SYSTEM_IDENTIFIER
set_parameter_property MEMORY_IDENTIFIER TYPE STRING
set_parameter_property MEMORY_IDENTIFIER UNITS None
set_parameter_property MEMORY_IDENTIFIER DESCRIPTION "System identifier, for parameters"
set_parameter_property MEMORY_IDENTIFIER HDL_PARAMETER true
set_parameter_property MEMORY_IDENTIFIER ALLOWED_RANGES {1:10}

proc compose { } {
    ############################################################################
    # Variable initialization
    ############################################################################
    set symbol_width 8
    set ddr_multiplier 2
    
    set board_path [get_parameter_value BOARD_PATH]
    set board_file $board_path/board_specification.xml

    set board_fp [open $board_file]
    set board_dom [dom::parse [read $board_fp]]
    set bsp_version [[dom::selectNode $board_dom /board/@version] stringValue]
    set param_file $board_path/[[dom::selectNode $board_dom /board/@file] stringValue]
    set param_fp [open $param_file]
    set param_dom [dom::parse [read $param_fp]]

    set result {}
    foreach node [dom::selectNode $board_dom {/board/global_mem[@type="DDR3"]/*/@id}] {
	lappend result [$node stringValue]
    }

    set_parameter_property MEMORY_IDENTIFIER ALLOWED_RANGES $result
    set mem_id [get_parameter_value MEMORY_IDENTIFIER]

    set sysids {}
    foreach node [dom::selectNode $board_dom {/board/global_mem[@type="DDR3"]/*/@sys_id}] {
	lappend sysids [$node stringValue]
    }

    set_parameter_property SYSTEM_IDENTIFIER ALLOWED_RANGES $sysids
    set sys_id [get_parameter_value SYSTEM_IDENTIFIER]

    # Memory-system specific variables
    set mem_clock_freq [[dom::selectNode $board_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@id=\"$mem_id\"\]/@mem_frequency_mhz] stringValue]
    set ref_clock_freq [[dom::selectNode $board_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@id=\"$mem_id\"\]/@ref_frequency_mhz] stringValue]
    set fabric_ratio [[dom::selectNode $board_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@id=\"$mem_id\"\]/@ratio] stringValue]

    # Memory-specific parameters
    set bank_pins [[dom::selectNode $param_dom /board/memory\[@type="DDR3"\]/phy\[@id=\"$mem_id\"\]/@bank_pins] stringValue]
    set row_pins [[dom::selectNode $param_dom /board/memory\[@type="DDR3"\]/phy\[@id=\"$mem_id\"\]/@row_pins] stringValue]
    set col_pins [[dom::selectNode $param_dom /board/memory\[@type="DDR3"\]/phy\[@id=\"$mem_id\"\]/@column_pins] stringValue]
    set dq_pins [[dom::selectNode $param_dom /board/memory\[@type="DDR3"\]/phy\[@id=\"$mem_id\"\]/@dq_pins] stringValue]
    set addr_width [expr log($dq_pins/$symbol_width)/log(2) + $bank_pins + $row_pins + $col_pins]

    set shared_nodes [dom::selectNode $board_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@primary=\"$mem_id\"\]/@id]

    set max_burst [[dom::selectNode $board_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@id=\"$mem_id\"\]/@maxburst] stringValue]
    set shared_ids {}
    foreach node $shared_nodes {
	lappend shared_ids [$node stringValue]
    }
    set num_shared [llength $shared_ids]
    set shared_interfaces [split [[dom::selectNode $board_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@id=\"$mem_id\"\]/@shared] stringValue] ","]

    set role [[dom::selectNode $board_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@id=\"$mem_id\"\]/@role] stringValue]

    # determine numeric representation from its string equivalent
    if [string match "Quarter" $fabric_ratio] {
	set fabric_mem_ratio 4
    } elseif [string match "Half" $fabric_ratio] {
	set fabric_mem_ratio 2
    } else {
	set fabric_mem_ratio 1
    }
    
    # DDR returns data at twice the rate of the clock
    set fabric_data_width [expr $dq_pins * $fabric_mem_ratio * $ddr_multiplier]
    ############################################################################
    # exported interfaces
    ############################################################################
    # Kernel Clock
    add_interface kernel_clk clock sink
    set_interface_property kernel_clk EXPORT_OF kernel_clk_bridge.clk_in

    # Kernel Reset
    add_interface kernel_reset reset sink
    set_interface_property kernel_reset EXPORT_OF kernel_clk_bridge.clk_in_reset

    # Reset Source for XC Kernel
    add_interface sw_kernel_reset reset sink
    set_interface_property sw_kernel_reset EXPORT_OF sw_kernel_reset_bridge.in_reset

    # Export the reset controller reset
    add_interface memory_reset reset source
    set_interface_property memory_reset EXPORT_OF memory_reset_bridge.out_reset

    # Kernel read/write interface
    add_interface kernel_rw avalon slave
    set_interface_property kernel_rw EXPORT_OF clock_cross_kernel.s0

    # DDR Pins    
    add_interface ddr_pins conduit end
    set_interface_property ddr_pins EXPORT_OF ddr3.memory

    # Global Reset
    add_interface global_reset reset sink
    set_interface_property global_reset EXPORT_OF global_reset_bridge.in_reset

    # DDR Status interface
    add_interface status conduit end
    set_interface_property status EXPORT_OF ddr3.status

    if {$role == "primary" || ($role == "independent" && !("oct" in $shared_interfaces))} {
	add_interface oct conduit end
	set_interface_property oct EXPORT_OF ddr3.oct
    }

    if {$role == "primary" || $role == "independent"} {
	add_interface ref_clk clock sink
	set_interface_property ref_clk EXPORT_OF ref_clk_bridge.in_clk

	# Export afi_clk to drive the DMA and other shared interfaces
	add_interface afi_clk clock source
	set_interface_property afi_clk EXPORT_OF afi_bridge.clk

	add_interface afi_reset reset source
	set_interface_property afi_reset EXPORT_OF afi_bridge.clk_reset

	add_interface afi_half_clk clock source
	set_interface_property afi_half_clk EXPORT_OF ddr3.afi_half_clk
    } else {
	# Else, secondary.
	# Otherwise, provide inputs for the AFI clock
	add_interface afi_clk clock sink
	set_interface_property afi_clk EXPORT_OF afi_bridge.clk_in clock

	add_interface afi_reset reset sink
	set_interface_property afi_reset EXPORT_OF afi_bridge.clk_in_reset reset

	add_interface afi_half_clk clock sink
	set_interface_property afi_half_clk EXPORT_OF ddr3.afi_half_clk_in clock
    }

    if {$role == "primary"} {
	for {set i 1} {$i <= $num_shared} {incr i} {
	    set id [lindex $shared_ids [expr $i-1]]
	    if {$i == 1} {
		add_interface pll_sharing_$id conduit end
		set_interface_property pll_sharing_$id EXPORT_OF ddr3.pll_sharing
		add_interface dll_sharing_$id conduit end
		set_interface_property dll_sharing_$id EXPORT_OF ddr3.dll_sharing
		add_interface oct_sharing_$id conduit end
		set_interface_property oct_sharing_$id EXPORT_OF ddr3.oct_sharing
	    } else {
		set x [expr $i-1]
		add_interface pll_sharing_$id conduit end
		set_interface_property pll_sharing_$id EXPORT_OF ddr3.pll_sharing_$x
		add_interface dll_sharing_$id conduit end
		set_interface_property dll_sharing_$id EXPORT_OF ddr3.dll_sharing_$x
		add_interface oct_sharing_$id conduit end
		set_interface_property oct_sharing_$id EXPORT_OF ddr3.oct_sharing_$x				
	    }	    
	}
    } else {
	if {"pll" in $shared_interfaces} {
	    add_interface pll_sharing_$mem_id conduit end
	    set_interface_property pll_sharing_$mem_id EXPORT_OF ddr3.pll_sharing
	} 
	if {"dll" in $shared_interfaces} {
	    add_interface dll_sharing_$mem_id conduit end
	    set_interface_property dll_sharing_$mem_id EXPORT_OF ddr3.dll_sharing
	}
	if {"oct" in $shared_interfaces} {
	    add_interface oct_sharing_$mem_id conduit end
	    set_interface_property oct_sharing_$mem_id EXPORT_OF ddr3.oct_sharing
	}
    }

    # If the memory is shared, or it is the first memory, it runs in the DMA
    # clock domain, so export the pipeline stage for DMA
    if {($role == "primary") || ($role == "secondary")} {
	add_interface dma_rw avalon slave
	set_interface_property dma_rw EXPORT_OF pipe_stage_dma.s0
    } else {
	# If the memory runs on it's own PLL, it is not running in the DMA
	# domain. Export the clock-cross interfaces
	add_interface dma_rw avalon slave
	set_interface_property dma_rw EXPORT_OF clock_cross_dma.s0

    }

    # If the memory is not on the DMA clock domain, we need inputs for the DMA
    # clock and reset
    if {$role == "independent" || $role == "secondary"} {
	add_interface dma_clk clock sink
	set_interface_property dma_clk EXPORT_OF dma_clk.clk_in

	add_interface dma_reset reset sink
	set_interface_property dma_reset EXPORT_OF dma_clk.clk_in_reset
    }

    ############################################################################
    # Instances and instance parameters
    ############################################################################
    if {($role == "primary") || ($role == "independent")} {
	add_instance ref_clk_bridge altera_clock_bridge $bsp_version
	set_instance_parameter_value ref_clk_bridge {EXPLICIT_CLOCK_RATE} {50000000.0}
	set_instance_parameter_value ref_clk_bridge {NUM_CLOCK_OUTPUTS} {1}
    }

    add_instance dma_clk clock_source $bsp_version
    set_instance_parameter_value dma_clk {clockFrequency} {50000000.0}
    set_instance_parameter_value dma_clk {clockFrequencyKnown} {0}
    set_instance_parameter_value dma_clk {resetSynchronousEdges} {DEASSERT}

    add_instance global_reset_bridge altera_reset_bridge $bsp_version
    set_instance_parameter_value global_reset_bridge {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value global_reset_bridge {SYNCHRONOUS_EDGES} {none}
    set_instance_parameter_value global_reset_bridge {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value global_reset_bridge {USE_RESET_REQUEST} {0}

    add_instance sw_kernel_reset_bridge altera_reset_bridge $bsp_version
    set_instance_parameter_value sw_kernel_reset_bridge {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value sw_kernel_reset_bridge {SYNCHRONOUS_EDGES} {none}
    set_instance_parameter_value sw_kernel_reset_bridge {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value sw_kernel_reset_bridge {USE_RESET_REQUEST} {0}

    add_instance memory_reset_bridge altera_reset_bridge $bsp_version
    set_instance_parameter_value memory_reset_bridge {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value memory_reset_bridge {SYNCHRONOUS_EDGES} {deassert}
    set_instance_parameter_value memory_reset_bridge {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value memory_reset_bridge {USE_RESET_REQUEST} {0}

    add_instance kernel_clk_bridge clock_source $bsp_version
    set_instance_parameter_value kernel_clk_bridge {clockFrequency} {50000000.0}
    set_instance_parameter_value kernel_clk_bridge {clockFrequencyKnown} {0}
    set_instance_parameter_value kernel_clk_bridge {resetSynchronousEdges} {DEASSERT}

    add_instance afi_bridge clock_source $bsp_version
    set_instance_parameter_value afi_bridge {clockFrequency} {50000000.0}
    set_instance_parameter_value afi_bridge {clockFrequencyKnown} {0}
    set_instance_parameter_value afi_bridge {resetSynchronousEdges} {DEASSERT}

    add_instance reset_controller altera_reset_controller $bsp_version
    set_instance_parameter_value reset_controller {NUM_RESET_INPUTS} {2}
    set_instance_parameter_value reset_controller {OUTPUT_RESET_SYNC_EDGES} {deassert}
    set_instance_parameter_value reset_controller {SYNC_DEPTH} {2}
    set_instance_parameter_value reset_controller {RESET_REQUEST_PRESENT} {0}
    set_instance_parameter_value reset_controller {RESET_REQ_WAIT_TIME} {1}
    set_instance_parameter_value reset_controller {MIN_RST_ASSERTION_TIME} {3}
    set_instance_parameter_value reset_controller {RESET_REQ_EARLY_DSRT_TIME} {1}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN0} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN1} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN2} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN3} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN4} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN5} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN6} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN7} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN8} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN9} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN10} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN11} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN12} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN13} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN14} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_IN15} {0}
    set_instance_parameter_value reset_controller {USE_RESET_REQUEST_INPUT} {0}

    add_instance clock_cross_kernel altera_avalon_mm_clock_crossing_bridge $bsp_version
    set_instance_parameter_value clock_cross_kernel {DATA_WIDTH} $fabric_data_width
    set_instance_parameter_value clock_cross_kernel {SYMBOL_WIDTH} $symbol_width
    set_instance_parameter_value clock_cross_kernel {ADDRESS_WIDTH} $addr_width
    set_instance_parameter_value clock_cross_kernel {USE_AUTO_ADDRESS_WIDTH} {1}
    set_instance_parameter_value clock_cross_kernel {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value clock_cross_kernel {MAX_BURST_SIZE} $max_burst
    set_instance_parameter_value clock_cross_kernel {COMMAND_FIFO_DEPTH} {16}
    set_instance_parameter_value clock_cross_kernel {RESPONSE_FIFO_DEPTH} {64}
    set_instance_parameter_value clock_cross_kernel {MASTER_SYNC_DEPTH} {2}
    set_instance_parameter_value clock_cross_kernel {SLAVE_SYNC_DEPTH} {2}

     # Memory Interface Pipeline Stage
    add_instance pipe_stage_interface altera_avalon_mm_bridge $bsp_version
    set_instance_parameter_value pipe_stage_interface {DATA_WIDTH} $fabric_data_width
    set_instance_parameter_value pipe_stage_interface {SYMBOL_WIDTH} $symbol_width
    set_instance_parameter_value pipe_stage_interface {ADDRESS_WIDTH} $addr_width
    #address_width used to be {31}
    set_instance_parameter_value pipe_stage_interface {USE_AUTO_ADDRESS_WIDTH} {1}
    set_instance_parameter_value pipe_stage_interface {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value pipe_stage_interface {MAX_BURST_SIZE} $max_burst
    set_instance_parameter_value pipe_stage_interface {MAX_PENDING_RESPONSES} {32}
    set_instance_parameter_value pipe_stage_interface {LINEWRAPBURSTS} {0}
    set_instance_parameter_value pipe_stage_interface {PIPELINE_COMMAND} {1}
    set_instance_parameter_value pipe_stage_interface {PIPELINE_RESPONSE} {1}
   
	# Post Kernel/DMA Arbiter Pipeline Stage
    add_instance pipe_stage_arb altera_avalon_mm_bridge $bsp_version
    set_instance_parameter_value pipe_stage_arb {DATA_WIDTH} $fabric_data_width
    set_instance_parameter_value pipe_stage_arb {SYMBOL_WIDTH} $symbol_width
    set_instance_parameter_value pipe_stage_arb {ADDRESS_WIDTH} $addr_width
    set_instance_parameter_value pipe_stage_arb {USE_AUTO_ADDRESS_WIDTH} {1}
    set_instance_parameter_value pipe_stage_arb {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value pipe_stage_arb {MAX_BURST_SIZE} $max_burst
    set_instance_parameter_value pipe_stage_arb {MAX_PENDING_RESPONSES} {32}
    set_instance_parameter_value pipe_stage_arb {LINEWRAPBURSTS} {0}
    set_instance_parameter_value pipe_stage_arb {PIPELINE_COMMAND} {1}
    set_instance_parameter_value pipe_stage_arb {PIPELINE_RESPONSE} {1}

    if {($role == "primary") || ($role == "secondary")} {
	#this pipe stage replaces the clock cross when its the first memory or shared memory
	add_instance pipe_stage_dma altera_avalon_mm_bridge $bsp_version
	set_instance_parameter_value pipe_stage_dma {DATA_WIDTH} $fabric_data_width
	set_instance_parameter_value pipe_stage_dma {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value pipe_stage_dma {ADDRESS_WIDTH} {31}
	set_instance_parameter_value pipe_stage_dma {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value pipe_stage_dma {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value pipe_stage_dma {MAX_BURST_SIZE} $max_burst
	set_instance_parameter_value pipe_stage_dma {MAX_PENDING_RESPONSES} {32}
	set_instance_parameter_value pipe_stage_dma {LINEWRAPBURSTS} {0}
	set_instance_parameter_value pipe_stage_dma {PIPELINE_COMMAND} {1}
	set_instance_parameter_value pipe_stage_dma {PIPELINE_RESPONSE} {1}
    } else {
	add_instance clock_cross_dma altera_avalon_mm_clock_crossing_bridge $bsp_version
	set_instance_parameter_value clock_cross_dma {DATA_WIDTH} $fabric_data_width
	set_instance_parameter_value clock_cross_dma {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value clock_cross_dma {ADDRESS_WIDTH} {31}
	set_instance_parameter_value clock_cross_dma {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value clock_cross_dma {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value clock_cross_dma {MAX_BURST_SIZE} $max_burst
	set_instance_parameter_value clock_cross_dma {COMMAND_FIFO_DEPTH} {16}
	set_instance_parameter_value clock_cross_dma {RESPONSE_FIFO_DEPTH} {64}
	set_instance_parameter_value clock_cross_dma {MASTER_SYNC_DEPTH} {2}
	set_instance_parameter_value clock_cross_dma {SLAVE_SYNC_DEPTH} {2}
    }

    add_instance ddr3 altera_mem_if_ddr3_emif $bsp_version
    set_instance_parameter_value ddr3 {MEM_VENDOR} {JEDEC}
    set_instance_parameter_value ddr3 {MEM_FORMAT} {UNBUFFERED}
    set_instance_parameter_value ddr3 {RDIMM_CONFIG} {0000000000000000}
    set_instance_parameter_value ddr3 {LRDIMM_EXTENDED_CONFIG} {0x000000000000000000}
    set_instance_parameter_value ddr3 {DISCRETE_FLY_BY} {1}
    set_instance_parameter_value ddr3 {DEVICE_DEPTH} {1}
    set_instance_parameter_value ddr3 {MEM_MIRROR_ADDRESSING} {0}
    set_instance_parameter_value ddr3 {MEM_CLK_FREQ_MAX} $mem_clock_freq
    set_instance_parameter_value ddr3 {MEM_ROW_ADDR_WIDTH} $row_pins
    #{15}
    set_instance_parameter_value ddr3 {MEM_COL_ADDR_WIDTH} $col_pins
    #{10}
    set_instance_parameter_value ddr3 {MEM_DQ_WIDTH} $dq_pins
    #{64}
    set_instance_parameter_value ddr3 {MEM_DQ_PER_DQS} {8}
    set_instance_parameter_value ddr3 {MEM_BANKADDR_WIDTH} $bank_pins
    #{3}
    set_instance_parameter_value ddr3 {MEM_IF_DM_PINS_EN} {1}
    set_instance_parameter_value ddr3 {MEM_IF_DQSN_EN} {1}
    set_instance_parameter_value ddr3 {MEM_NUMBER_OF_DIMMS} {1}
    set_instance_parameter_value ddr3 {MEM_NUMBER_OF_RANKS_PER_DIMM} {1}
    set_instance_parameter_value ddr3 {MEM_NUMBER_OF_RANKS_PER_DEVICE} {1}
    set_instance_parameter_value ddr3 {MEM_RANK_MULTIPLICATION_FACTOR} {1}
    set_instance_parameter_value ddr3 {MEM_CK_WIDTH} {1}
    set_instance_parameter_value ddr3 {MEM_CS_WIDTH} {1}
    set_instance_parameter_value ddr3 {MEM_CLK_EN_WIDTH} {1}
    set_instance_parameter_value ddr3 {ALTMEMPHY_COMPATIBLE_MODE} {0}
    set_instance_parameter_value ddr3 {NEXTGEN} {1}
    set_instance_parameter_value ddr3 {MEM_IF_BOARD_BASE_DELAY} {10}
    set_instance_parameter_value ddr3 {MEM_IF_SIM_VALID_WINDOW} {0}
    set_instance_parameter_value ddr3 {MEM_GUARANTEED_WRITE_INIT} {0}
    set_instance_parameter_value ddr3 {MEM_VERBOSE} {0}
    set_instance_parameter_value ddr3 {PINGPONGPHY_EN} {0}
    set_instance_parameter_value ddr3 {DUPLICATE_AC} {0}
    set_instance_parameter_value ddr3 {REFRESH_BURST_VALIDATION} {0}
    set_instance_parameter_value ddr3 {AP_MODE_EN} {0}
    set_instance_parameter_value ddr3 {AP_MODE} {0}
    set_instance_parameter_value ddr3 {MEM_BL} {OTF}
    set_instance_parameter_value ddr3 {MEM_BT} {Sequential}
    set_instance_parameter_value ddr3 {MEM_ASR} {Manual}
    set_instance_parameter_value ddr3 {MEM_SRT} {Normal}
    set_instance_parameter_value ddr3 {MEM_PD} {DLL off}
    set_instance_parameter_value ddr3 {MEM_DRV_STR} {RZQ/6}
    set_instance_parameter_value ddr3 {MEM_DLL_EN} {1}
    set_instance_parameter_value ddr3 {MEM_RTT_NOM} {RZQ/6}
    set_instance_parameter_value ddr3 {MEM_RTT_WR} {RZQ/4}
    set_instance_parameter_value ddr3 {MEM_WTCL} {8}
    set_instance_parameter_value ddr3 {MEM_ATCL} {Disabled}
    set_instance_parameter_value ddr3 {MEM_TCL} {11}
    set_instance_parameter_value ddr3 {MEM_AUTO_LEVELING_MODE} {1}
    set_instance_parameter_value ddr3 {MEM_USER_LEVELING_MODE} {Leveling}
    set_instance_parameter_value ddr3 {MEM_INIT_EN} {0}
    set_instance_parameter_value ddr3 {MEM_INIT_FILE} {}
    set_instance_parameter_value ddr3 {DAT_DATA_WIDTH} {32}
    set_instance_parameter_value ddr3 {TIMING_TIS} {170}
    set_instance_parameter_value ddr3 {TIMING_TIH} {120}
    set_instance_parameter_value ddr3 {TIMING_TDS} {10}
    set_instance_parameter_value ddr3 {TIMING_TDH} {45}
    set_instance_parameter_value ddr3 {TIMING_TDQSQ} {100}
    set_instance_parameter_value ddr3 {TIMING_TQH} {0.38}
    set_instance_parameter_value ddr3 {TIMING_TDQSCK} {225}
    set_instance_parameter_value ddr3 {TIMING_TDQSCKDS} {450}
    set_instance_parameter_value ddr3 {TIMING_TDQSCKDM} {900}
    set_instance_parameter_value ddr3 {TIMING_TDQSCKDL} {1200}
    set_instance_parameter_value ddr3 {TIMING_TDQSS} {0.25}
    set_instance_parameter_value ddr3 {TIMING_TQSH} {0.4}
    set_instance_parameter_value ddr3 {TIMING_TDSH} {0.18}
    set_instance_parameter_value ddr3 {TIMING_TDSS} {0.18}
    set_instance_parameter_value ddr3 {MEM_TINIT_US} {500}
    set_instance_parameter_value ddr3 {MEM_TMRD_CK} {4}
    set_instance_parameter_value ddr3 {MEM_TRAS_NS} {35.0}
    set_instance_parameter_value ddr3 {MEM_TRCD_NS} {13.75}
    set_instance_parameter_value ddr3 {MEM_TRP_NS} {13.75}
    set_instance_parameter_value ddr3 {MEM_TREFI_US} {7.8}
    set_instance_parameter_value ddr3 {MEM_TRFC_NS} {160.0}
    set_instance_parameter_value ddr3 {CFG_TCCD_NS} {2.5}
    set_instance_parameter_value ddr3 {MEM_TWR_NS} {15.0}
    set_instance_parameter_value ddr3 {MEM_TWTR} {4}
    set_instance_parameter_value ddr3 {MEM_TFAW_NS} {30.0}
    set_instance_parameter_value ddr3 {MEM_TRRD_NS} {6.0}
    set_instance_parameter_value ddr3 {MEM_TRTP_NS} {7.5}
    set_instance_parameter_value ddr3 {RATE} $fabric_ratio
    set_instance_parameter_value ddr3 {MEM_CLK_FREQ} $mem_clock_freq
    set_instance_parameter_value ddr3 {USE_MEM_CLK_FREQ} {0}
    set_instance_parameter_value ddr3 {FORCE_DQS_TRACKING} {DISABLED}
    set_instance_parameter_value ddr3 {FORCE_SHADOW_REGS} {AUTO}
    set_instance_parameter_value ddr3 {MRS_MIRROR_PING_PONG_ATSO} {0}
    set_instance_parameter_value ddr3 {PARSE_FRIENDLY_DEVICE_FAMILY_PARAM_VALID} {0}
    set_instance_parameter_value ddr3 {PARSE_FRIENDLY_DEVICE_FAMILY_PARAM} {}
    set_instance_parameter_value ddr3 {DEVICE_FAMILY_PARAM} {}
    set_instance_parameter_value ddr3 {SPEED_GRADE} {2}
    set_instance_parameter_value ddr3 {IS_ES_DEVICE} {0}
    set_instance_parameter_value ddr3 {DISABLE_CHILD_MESSAGING} {0}
    set_instance_parameter_value ddr3 {HARD_EMIF} {0}
    set_instance_parameter_value ddr3 {HHP_HPS} {0}
    set_instance_parameter_value ddr3 {HHP_HPS_VERIFICATION} {0}
    set_instance_parameter_value ddr3 {HHP_HPS_SIMULATION} {0}
    set_instance_parameter_value ddr3 {HPS_PROTOCOL} {DEFAULT}
    set_instance_parameter_value ddr3 {CUT_NEW_FAMILY_TIMING} {1}
    set_instance_parameter_value ddr3 {POWER_OF_TWO_BUS} {1}
    set_instance_parameter_value ddr3 {SOPC_COMPAT_RESET} {0}
    set_instance_parameter_value ddr3 {AVL_MAX_SIZE} $max_burst
    set_instance_parameter_value ddr3 {BYTE_ENABLE} {1}
    set_instance_parameter_value ddr3 {ENABLE_CTRL_AVALON_INTERFACE} {1}
    set_instance_parameter_value ddr3 {CTL_DEEP_POWERDN_EN} {0}
    set_instance_parameter_value ddr3 {CTL_SELF_REFRESH_EN} {0}
    set_instance_parameter_value ddr3 {AUTO_POWERDN_EN} {0}
    set_instance_parameter_value ddr3 {AUTO_PD_CYCLES} {0}
    set_instance_parameter_value ddr3 {CTL_USR_REFRESH_EN} {0}
    set_instance_parameter_value ddr3 {CTL_AUTOPCH_EN} {0}
    set_instance_parameter_value ddr3 {CTL_ZQCAL_EN} {0}
    set_instance_parameter_value ddr3 {ADDR_ORDER} {0}
    set_instance_parameter_value ddr3 {CTL_LOOK_AHEAD_DEPTH} {8}
    set_instance_parameter_value ddr3 {CONTROLLER_LATENCY} {5}
    set_instance_parameter_value ddr3 {CFG_REORDER_DATA} {1}
    set_instance_parameter_value ddr3 {STARVE_LIMIT} {10}
    set_instance_parameter_value ddr3 {CTL_CSR_ENABLED} {0}
    set_instance_parameter_value ddr3 {CTL_CSR_CONNECTION} {INTERNAL_JTAG}
    set_instance_parameter_value ddr3 {CTL_ECC_ENABLED} {0}
    set_instance_parameter_value ddr3 {CTL_HRB_ENABLED} {0}
    set_instance_parameter_value ddr3 {CTL_ECC_AUTO_CORRECTION_ENABLED} {0}
    set_instance_parameter_value ddr3 {MULTICAST_EN} {0}
    set_instance_parameter_value ddr3 {CTL_DYNAMIC_BANK_ALLOCATION} {0}
    set_instance_parameter_value ddr3 {CTL_DYNAMIC_BANK_NUM} {4}
    set_instance_parameter_value ddr3 {DEBUG_MODE} {0}
    set_instance_parameter_value ddr3 {ENABLE_BURST_MERGE} {0}
    set_instance_parameter_value ddr3 {CTL_ENABLE_BURST_INTERRUPT} {1}
    set_instance_parameter_value ddr3 {CTL_ENABLE_BURST_TERMINATE} {1}
    set_instance_parameter_value ddr3 {LOCAL_ID_WIDTH} {8}
    set_instance_parameter_value ddr3 {WRBUFFER_ADDR_WIDTH} {6}
    set_instance_parameter_value ddr3 {MAX_PENDING_WR_CMD} {8}
    set_instance_parameter_value ddr3 {MAX_PENDING_RD_CMD} {16}
    set_instance_parameter_value ddr3 {USE_MM_ADAPTOR} {1}
    set_instance_parameter_value ddr3 {USE_AXI_ADAPTOR} {0}
    set_instance_parameter_value ddr3 {HCX_COMPAT_MODE} {0}
    set_instance_parameter_value ddr3 {CTL_CMD_QUEUE_DEPTH} {8}
    set_instance_parameter_value ddr3 {CTL_CSR_READ_ONLY} {1}
    set_instance_parameter_value ddr3 {CFG_DATA_REORDERING_TYPE} {INTER_BANK}
    set_instance_parameter_value ddr3 {NUM_OF_PORTS} {1}
    set_instance_parameter_value ddr3 {ENABLE_BONDING} {0}
    set_instance_parameter_value ddr3 {ENABLE_USER_ECC} {0}
    set_instance_parameter_value ddr3 {AVL_DATA_WIDTH_PORT} {32 32 32 32 32 32}
    set_instance_parameter_value ddr3 {PRIORITY_PORT} {1 1 1 1 1 1}
    set_instance_parameter_value ddr3 {WEIGHT_PORT} {0 0 0 0 0 0}
    set_instance_parameter_value ddr3 {CPORT_TYPE_PORT} {Bidirectional Bidirectional Bidirectional Bidirectional Bidirectional Bidirectional}
    set_instance_parameter_value ddr3 {ENABLE_EMIT_BFM_MASTER} {0}
    set_instance_parameter_value ddr3 {FORCE_SEQUENCER_TCL_DEBUG_MODE} {0}
    set_instance_parameter_value ddr3 {ENABLE_SEQUENCER_MARGINING_ON_BY_DEFAULT} {0}
    set_instance_parameter_value ddr3 {REF_CLK_FREQ} $ref_clock_freq
    set_instance_parameter_value ddr3 {REF_CLK_FREQ_PARAM_VALID} {0}
    set_instance_parameter_value ddr3 {REF_CLK_FREQ_MIN_PARAM} {0.0}
    set_instance_parameter_value ddr3 {REF_CLK_FREQ_MAX_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_DR_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_DR_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_DR_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_DR_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_DR_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_DR_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_MEM_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_MEM_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_MEM_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_MEM_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_MEM_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_MEM_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_AFI_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_AFI_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_AFI_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_AFI_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_AFI_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_AFI_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_WRITE_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_WRITE_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_WRITE_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_WRITE_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_WRITE_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_WRITE_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_ADDR_CMD_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_ADDR_CMD_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_ADDR_CMD_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_ADDR_CMD_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_ADDR_CMD_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_ADDR_CMD_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_AFI_HALF_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_AFI_HALF_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_AFI_HALF_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_AFI_HALF_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_AFI_HALF_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_AFI_HALF_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_NIOS_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_NIOS_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_NIOS_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_NIOS_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_NIOS_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_NIOS_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_CONFIG_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_CONFIG_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_CONFIG_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_CONFIG_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_CONFIG_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_CONFIG_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_P2C_READ_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_P2C_READ_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_P2C_READ_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_P2C_READ_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_P2C_READ_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_P2C_READ_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_C2P_WRITE_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_C2P_WRITE_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_C2P_WRITE_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_C2P_WRITE_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_C2P_WRITE_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_C2P_WRITE_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_HR_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_HR_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_HR_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_HR_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_HR_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_HR_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_AFI_PHY_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value ddr3 {PLL_AFI_PHY_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_AFI_PHY_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_AFI_PHY_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value ddr3 {PLL_AFI_PHY_CLK_MULT_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_AFI_PHY_CLK_DIV_PARAM} {0}
    set_instance_parameter_value ddr3 {PLL_CLK_PARAM_VALID} {0}
    set_instance_parameter_value ddr3 {ENABLE_EXTRA_REPORTING} {0}
    set_instance_parameter_value ddr3 {NUM_EXTRA_REPORT_PATH} {10}
    set_instance_parameter_value ddr3 {ENABLE_ISS_PROBES} {0}
    set_instance_parameter_value ddr3 {CALIB_REG_WIDTH} {8}
    set_instance_parameter_value ddr3 {USE_SEQUENCER_BFM} {0}
    set_instance_parameter_value ddr3 {PLL_SHARING_MODE} {None}
    set_instance_parameter_value ddr3 {NUM_PLL_SHARING_INTERFACES} {1}
    set_instance_parameter_value ddr3 {EXPORT_AFI_HALF_CLK} {0}
    set_instance_parameter_value ddr3 {ABSTRACT_REAL_COMPARE_TEST} {0}
    set_instance_parameter_value ddr3 {INCLUDE_BOARD_DELAY_MODEL} {0}
    set_instance_parameter_value ddr3 {INCLUDE_MULTIRANK_BOARD_DELAY_MODEL} {0}
    set_instance_parameter_value ddr3 {USE_FAKE_PHY} {0}
    set_instance_parameter_value ddr3 {FORCE_MAX_LATENCY_COUNT_WIDTH} {0}
    set_instance_parameter_value ddr3 {ENABLE_NON_DESTRUCTIVE_CALIB} {0}
    set_instance_parameter_value ddr3 {ENABLE_DELAY_CHAIN_WRITE} {0}
    set_instance_parameter_value ddr3 {TRACKING_ERROR_TEST} {0}
    set_instance_parameter_value ddr3 {TRACKING_WATCH_TEST} {0}
    set_instance_parameter_value ddr3 {MARGIN_VARIATION_TEST} {0}
    set_instance_parameter_value ddr3 {AC_ROM_USER_ADD_0} {0_0000_0000_0000}
    set_instance_parameter_value ddr3 {AC_ROM_USER_ADD_1} {0_0000_0000_1000}
    set_instance_parameter_value ddr3 {TREFI} {35100}
    set_instance_parameter_value ddr3 {REFRESH_INTERVAL} {15000}
    set_instance_parameter_value ddr3 {ENABLE_NON_DES_CAL_TEST} {0}
    set_instance_parameter_value ddr3 {TRFC} {350}
    set_instance_parameter_value ddr3 {ENABLE_NON_DES_CAL} {0}
    set_instance_parameter_value ddr3 {EXTRA_SETTINGS} {}
    set_instance_parameter_value ddr3 {MEM_DEVICE} {MISSING_MODEL}
    set_instance_parameter_value ddr3 {FORCE_SYNTHESIS_LANGUAGE} {}
    set_instance_parameter_value ddr3 {FORCED_NUM_WRITE_FR_CYCLE_SHIFTS} {0}
    set_instance_parameter_value ddr3 {SEQUENCER_TYPE} {NIOS}
    set_instance_parameter_value ddr3 {ADVERTIZE_SEQUENCER_SW_BUILD_FILES} {0}
    set_instance_parameter_value ddr3 {FORCED_NON_LDC_ADDR_CMD_MEM_CK_INVERT} {0}
    set_instance_parameter_value ddr3 {PHY_ONLY} {0}
    set_instance_parameter_value ddr3 {SEQ_MODE} {0}
    set_instance_parameter_value ddr3 {ADVANCED_CK_PHASES} {0}
    set_instance_parameter_value ddr3 {COMMAND_PHASE} {0.0}
    set_instance_parameter_value ddr3 {MEM_CK_PHASE} {0.0}
    set_instance_parameter_value ddr3 {P2C_READ_CLOCK_ADD_PHASE} {0.0}
    set_instance_parameter_value ddr3 {C2P_WRITE_CLOCK_ADD_PHASE} {0.0}
    set_instance_parameter_value ddr3 {ACV_PHY_CLK_ADD_FR_PHASE} {0.0}
    set_instance_parameter_value ddr3 {MEM_VOLTAGE} {1.5V DDR3}
    set_instance_parameter_value ddr3 {PLL_LOCATION} {Top_Bottom}
    set_instance_parameter_value ddr3 {SKIP_MEM_INIT} {1}
    set_instance_parameter_value ddr3 {READ_DQ_DQS_CLOCK_SOURCE} {INVERTED_DQS_BUS}
    set_instance_parameter_value ddr3 {DQ_INPUT_REG_USE_CLKN} {0}
    set_instance_parameter_value ddr3 {DQS_DQSN_MODE} {DIFFERENTIAL}
    set_instance_parameter_value ddr3 {AFI_DEBUG_INFO_WIDTH} {32}
    set_instance_parameter_value ddr3 {CALIBRATION_MODE} {Skip}
    set_instance_parameter_value ddr3 {NIOS_ROM_DATA_WIDTH} {32}
    set_instance_parameter_value ddr3 {READ_FIFO_SIZE} {8}
    set_instance_parameter_value ddr3 {PHY_CSR_ENABLED} {0}
    set_instance_parameter_value ddr3 {PHY_CSR_CONNECTION} {INTERNAL_JTAG}
    set_instance_parameter_value ddr3 {USER_DEBUG_LEVEL} {0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_DERATE_METHOD} {AUTO}
    set_instance_parameter_value ddr3 {TIMING_BOARD_CK_CKN_SLEW_RATE} {2.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_AC_SLEW_RATE} {1.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_DQS_DQSN_SLEW_RATE} {2.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_DQ_SLEW_RATE} {1.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_TIS} {0.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_TIH} {0.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_TDS} {0.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_TDH} {0.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_ISI_METHOD} {AUTO}
    set_instance_parameter_value ddr3 {TIMING_BOARD_AC_EYE_REDUCTION_SU} {0.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_AC_EYE_REDUCTION_H} {0.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_DQ_EYE_REDUCTION} {0.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_DELTA_DQS_ARRIVAL_TIME} {0.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_READ_DQ_EYE_REDUCTION} {0.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_DELTA_READ_DQS_ARRIVAL_TIME} {0.0}
    set_instance_parameter_value ddr3 {PACKAGE_DESKEW} {1}
    set_instance_parameter_value ddr3 {AC_PACKAGE_DESKEW} {1}
    set_instance_parameter_value ddr3 {TIMING_BOARD_MAX_CK_DELAY} {1.344965382}
    set_instance_parameter_value ddr3 {TIMING_BOARD_MAX_DQS_DELAY} {0.6220263175}
    set_instance_parameter_value ddr3 {TIMING_BOARD_SKEW_CKDQS_DIMM_MIN} {0.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_SKEW_CKDQS_DIMM_MAX} {0.0}
    set_instance_parameter_value ddr3 {TIMING_BOARD_SKEW_BETWEEN_DIMMS} {0.05}
    set_instance_parameter_value ddr3 {TIMING_BOARD_SKEW_WITHIN_DQS} {0.006914298045}
    set_instance_parameter_value ddr3 {TIMING_BOARD_SKEW_BETWEEN_DQS} {0.091996905}
    set_instance_parameter_value ddr3 {TIMING_BOARD_DQ_TO_DQS_SKEW} {-0.000858383134}
    set_instance_parameter_value ddr3 {TIMING_BOARD_AC_SKEW} {0.01654451376}
    set_instance_parameter_value ddr3 {TIMING_BOARD_AC_TO_CK_SKEW} {-0.001268865261}
    set_instance_parameter_value ddr3 {ENABLE_EXPORT_SEQ_DEBUG_BRIDGE} {0}
    set_instance_parameter_value ddr3 {CORE_DEBUG_CONNECTION} {EXPORT}
    set_instance_parameter_value ddr3 {ADD_EXTERNAL_SEQ_DEBUG_NIOS} {0}
    set_instance_parameter_value ddr3 {ED_EXPORT_SEQ_DEBUG} {0}
    set_instance_parameter_value ddr3 {ADD_EFFICIENCY_MONITOR} {0}
    set_instance_parameter_value ddr3 {ENABLE_ABS_RAM_MEM_INIT} {0}
    set_instance_parameter_value ddr3 {ABS_RAM_MEM_INIT_FILENAME} {meminit}
    # TODO: Read from XML File
    foreach parameter [dom::selectNode $param_dom /board/memory\[@type="DDR3"\]/phy\[@id=\"$mem_id\"\]/parameter/@name] {
	set name [$parameter stringValue]
	set value [[dom::selectNode $param_dom /board/memory\[@type="DDR3"\]/phy\[@id=\"$mem_id\"\]/parameter\[@name=\"$name\"\]/@value] stringValue]
	set_instance_parameter_value ddr3 $name $value
    }

    if {$role == "primary" && $num_shared > 0} {
	#set number of sharing interfaces on DDR to number of banks 
	set_instance_parameter_value ddr3 {PLL_SHARING_MODE} {Master}
	set_instance_parameter_value ddr3 {NUM_PLL_SHARING_INTERFACES} $num_shared
	set_instance_parameter_value ddr3 {DLL_SHARING_MODE} {Master}
	set_instance_parameter_value ddr3 {NUM_DLL_SHARING_INTERFACES} $num_shared
	set_instance_parameter_value ddr3 {OCT_SHARING_MODE} {Master}
	set_instance_parameter_value ddr3 {NUM_OCT_SHARING_INTERFACES} $num_shared
    } else {
	if {"pll" in $shared_interfaces} {
	    set_instance_parameter_value ddr3 {PLL_SHARING_MODE} {Slave}
	    set_instance_parameter_value ddr3 {NUM_PLL_SHARING_INTERFACES} {1}
	} else {
	    set_instance_parameter_value ddr3 {PLL_SHARING_MODE} {None}
	    set_instance_parameter_value ddr3 {NUM_PLL_SHARING_INTERFACES} {1}
	} 
	if {"dll" in $shared_interfaces} {
	    set_instance_parameter_value ddr3 {DLL_SHARING_MODE} {Slave}
	    set_instance_parameter_value ddr3 {NUM_DLL_SHARING_INTERFACES} {1}
	} else {
	    set_instance_parameter_value ddr3 {DLL_SHARING_MODE} {None}
	    set_instance_parameter_value ddr3 {NUM_DLL_SHARING_INTERFACES} {1}
	}
	if {"oct" in $shared_interfaces} {
	    set_instance_parameter_value ddr3 {OCT_SHARING_MODE} {Slave}
	    set_instance_parameter_value ddr3 {NUM_OCT_SHARING_INTERFACES} {1}
	} else {
	    set_instance_parameter_value ddr3 {OCT_SHARING_MODE} {None}
	    set_instance_parameter_value ddr3 {NUM_OCT_SHARING_INTERFACES} {1}
	}
    }
    ############################################################################
    # connections and connection parameters
    ############################################################################
    add_connection reset_controller.reset_out memory_reset_bridge.in_reset reset

    # Kernel Clk
    add_connection kernel_clk_bridge.clk clock_cross_kernel.s0_clk clock

    # Kernel Reset
    add_connection kernel_clk_bridge.clk_reset clock_cross_kernel.s0_reset reset

    # Kernel/DDR Read/Write interface
    add_connection clock_cross_kernel.m0 pipe_stage_arb.s0 avalon
    set_connection_parameter_value clock_cross_kernel.m0/pipe_stage_arb.s0 arbitrationPriority {1}
    set_connection_parameter_value clock_cross_kernel.m0/pipe_stage_arb.s0 baseAddress {0x0000}
    set_connection_parameter_value clock_cross_kernel.m0/pipe_stage_arb.s0 defaultConnection {0}

    # Global Reset Connections
    add_connection global_reset_bridge.out_reset reset_controller.reset_in0 reset
    add_connection global_reset_bridge.out_reset ddr3.global_reset reset
    add_connection global_reset_bridge.out_reset ddr3.soft_reset reset

    # If we are the first memory, we defin the DMA clock domain
    if {$role == "primary"} {
	add_connection ddr3.afi_clk dma_clk.clk_in clock
	add_connection reset_controller.reset_out dma_clk.clk_in_reset reset

    } else {
	# Else, these connections are exported above
    }

    # PS Local Passthrough to Local Memory
    add_connection pipe_stage_interface.m0 ddr3.avl avalon
    set_connection_parameter_value pipe_stage_interface.m0/ddr3.avl arbitrationPriority {1}
    set_connection_parameter_value pipe_stage_interface.m0/ddr3.avl baseAddress {0x0000}
    set_connection_parameter_value pipe_stage_interface.m0/ddr3.avl defaultConnection {0}

    # PS Local Iface to PS Local Passthrough
    add_connection pipe_stage_arb.m0 pipe_stage_interface.s0 avalon
    set_connection_parameter_value pipe_stage_arb.m0/pipe_stage_interface.s0 arbitrationPriority {1}
    set_connection_parameter_value pipe_stage_arb.m0/pipe_stage_interface.s0 baseAddress {0x0000}
    set_connection_parameter_value pipe_stage_arb.m0/pipe_stage_interface.s0 defaultConnection {0}

    if {($role == "primary") || ($role == "secondary")} {
	# connections and connection parameters
	add_connection pipe_stage_dma.m0 pipe_stage_arb.s0 avalon
	set_connection_parameter_value pipe_stage_dma.m0/pipe_stage_arb.s0 arbitrationPriority {1}
	set_connection_parameter_value pipe_stage_dma.m0/pipe_stage_arb.s0 baseAddress {0x0000}
	set_connection_parameter_value pipe_stage_dma.m0/pipe_stage_arb.s0 defaultConnection {0}
	
	add_connection dma_clk.clk pipe_stage_dma.clk clock
	add_connection dma_clk.clk_reset pipe_stage_dma.reset reset

    } else {
	add_connection clock_cross_dma.m0 pipe_stage_arb.s0 avalon
	set_connection_parameter_value clock_cross_dma.m0/pipe_stage_arb.s0 arbitrationPriority {1}
	set_connection_parameter_value clock_cross_dma.m0/pipe_stage_arb.s0 baseAddress {0x0000}
	set_connection_parameter_value clock_cross_dma.m0/pipe_stage_arb.s0 defaultConnection {0}

	add_connection dma_clk.clk clock_cross_dma.s0_clk clock
	add_connection dma_clk.clk_reset clock_cross_dma.s0_reset reset
	add_connection ddr3.afi_clk clock_cross_dma.m0_clk clock

	add_connection reset_controller.reset_out clock_cross_dma.m0_reset reset
    }

    if {($role == "primary") || ($role == "independent")} {
        add_connection ddr3.afi_clk reset_controller.clk clock
	add_connection ddr3.afi_clk memory_reset_bridge.clk clock

	add_connection ddr3.afi_reset reset_controller.reset_in1 reset

	add_connection ddr3.afi_clk afi_bridge.clk_in clock
	add_connection ddr3.afi_reset afi_bridge.clk_in_reset reset

        add_connection ddr3.afi_clk clock_cross_kernel.m0_clk clock

	add_connection ref_clk_bridge.out_clk ddr3.pll_ref_clk clock
        #add_connection ddr3.afi_clk sw_kernel_reset_bridge.clk clock

	add_connection ddr3.afi_clk pipe_stage_arb.clk clock
        add_connection ddr3.afi_clk pipe_stage_interface.clk clock

    } else {
	add_connection afi_bridge.clk reset_controller.clk clock
	add_connection afi_bridge.clk memory_reset_bridge.clk clock

	add_connection afi_bridge.clk_reset reset_controller.reset_in1 reset

	add_connection afi_bridge.clk ddr3.afi_clk_in clock
	add_connection afi_bridge.clk_reset ddr3.afi_reset_in clock

	add_connection afi_bridge.clk clock_cross_kernel.m0_clk clock

        #add_connection afi_bridge.clk sw_kernel_reset_bridge.clk clock

	add_connection afi_bridge.clk pipe_stage_arb.clk clock
	add_connection afi_bridge.clk pipe_stage_interface.clk clock	
    }

    add_connection reset_controller.reset_out pipe_stage_arb.reset reset
    add_connection reset_controller.reset_out pipe_stage_interface.reset reset

    add_connection sw_kernel_reset_bridge.out_reset clock_cross_kernel.m0_reset reset

    # interconnect requirements
    set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
    set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {2}
}

