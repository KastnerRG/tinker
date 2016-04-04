package require -exact qsys 14.0
lappend auto_path $::env(TCLXML_PATH)
package require xml

# module properties
set_module_property NAME {qdr1}
set_module_property DISPLAY_NAME {qdr1}

# default module properties
set_module_property VERSION {1.0}
set_module_property GROUP {Memory group}
set_module_property DESCRIPTION {default description}
set_module_property AUTHOR {author}

set_module_property COMPOSITION_CALLBACK compose
set_module_property opaque_address_map false

#############################################################################
# parameters
#############################################################################
add_parameter BOARD_PATH String "Board Path"
set_parameter_property BOARD_PATH DEFAULT_VALUE a
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

    set param_file $board_path/../[[dom::selectNode $board_dom /board/@file] stringValue]
    set param_fp [open $param_file]
    set param_dom [dom::parse [read $param_fp]]

    set result {}
    foreach node [dom::selectNode $board_dom {/board/global_mem[@type="QDRII"]/*/@id}] {
	lappend result [$node stringValue]
    }

    set_parameter_property MEMORY_IDENTIFIER ALLOWED_RANGES $result
    set mem_id [get_parameter_value MEMORY_IDENTIFIER]

    set sysids {}
    foreach node [dom::selectNode $board_dom {/board/global_mem[@type="QDRII"]/*/@sys_id}] {
	lappend sysids [$node stringValue]
    }

    set_parameter_property SYSTEM_IDENTIFIER ALLOWED_RANGES $sysids
    set sys_id [get_parameter_value SYSTEM_IDENTIFIER]
    
    set dq_pins [[dom::selectNode $param_dom /board/memory\[@type="QDRII"\]/phy\[@id=\"$mem_id\"\]/@dq_pins] stringValue]
    set address_pins [[dom::selectNode $param_dom /board/memory\[@type="QDRII"\]/phy\[@id=\"$mem_id\"\]/@address_pins] stringValue]

    # Memory-system specific variables
    set mem_clock_freq [[dom::selectNode $board_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@primary=\"$mem_id\"\]/@mem_frequency_mhz] stringValue]
    set ref_clock_freq [[dom::selectNode $board_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@primary=\"$mem_id\"\]/@ref_frequency_mhz] stringValue]
    set fabric_ratio [[dom::selectNode $board_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@primary=\"$mem_id\"\]/@ratio] stringValue]

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

    if {$dq_pins == 9} {
	set log2_dq_pins 1
	set pow2_dq_pins 8
    } elseif {$dq_pins == 18} {
	set log2_dq_pins 2
	set pow2_dq_pins 16
    } elseif {$dq_pins == 36} {
	set log2_dq_pins 4
	set pow2_dq_pins 32
    }

    set fabric_data_width [expr $pow2_dq_pins * $fabric_mem_ratio * $ddr_multiplier]

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

    # Kernel read interface
    add_interface kernel_r avalon slave
    set_interface_property kernel_r EXPORT_OF clock_cross_kernel_r.s0

    # Kernel write interface
    add_interface kernel_w avalon slave
    set_interface_property kernel_w EXPORT_OF clock_cross_kernel_w.s0

    # QDR Pins
    add_interface qdr_pins conduit end
    set_interface_property qdr_pins EXPORT_OF qdr.memory

    # Global Reset
    add_interface global_reset reset sink
    set_interface_property global_reset EXPORT_OF global_reset_bridge.in_reset

    # QDR Status Interface
    add_interface status conduit end
    set_interface_property status EXPORT_OF qdr.status

    if {$role == "primary" || ($role == "independent" && !("oct" in $shared_interfaces))} {
	add_interface oct conduit end
	set_interface_property oct EXPORT_OF qdr.oct
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
	set_interface_property afi_half_clk EXPORT_OF qdr.afi_half_clk 
    } else {
	# Else, secondary.
	# Otherwise, provide inputs for the AFI clock
	add_interface afi_clk clock sink
	set_interface_property afi_clk EXPORT_OF afi_bridge.clk_in

	add_interface afi_reset reset sink
	set_interface_property afi_reset EXPORT_OF afi_bridge.clk_in_reset

	add_interface afi_half_clk clock sink
	set_interface_property afi_half_clk EXPORT_OF qdr.afi_half_clk_in 
    }

    if {$role == "primary"} {
	for {set i 1} {$i <= $num_shared} {incr i} {
	    set id [lindex $shared_ids [expr $i-1]]
	    if {$i == 1} {
		add_interface pll_sharing_$id conduit end
		set_interface_property pll_sharing_$id EXPORT_OF qdr.pll_sharing
		add_interface dll_sharing_$id conduit end
		set_interface_property dll_sharing_$id EXPORT_OF qdr.dll_sharing
		add_interface oct_sharing_$id conduit end
		set_interface_property oct_sharing_$id EXPORT_OF qdr.oct_sharing
	    } else {
		set x [expr $i-1]
		add_interface pll_sharing_$id conduit end
		set_interface_property pll_sharing_$id EXPORT_OF qdr.pll_sharing_$x
		add_interface dll_sharing_$id conduit end
		set_interface_property dll_sharing_$id EXPORT_OF qdr.dll_sharing_$x
		add_interface oct_sharing_$id conduit end
		set_interface_property oct_sharing_$id EXPORT_OF qdr.oct_sharing_$x				
	    }	    
	}
    } else {
	if {"pll" in $shared_interfaces} {
	    add_interface pll_sharing_$mem_id conduit end
	    set_interface_property pll_sharing_$mem_id EXPORT_OF qdr.pll_sharing
	} 
	if {"dll" in $shared_interfaces} {
	    add_interface dll_sharing_$mem_id conduit end
	    set_interface_property dll_sharing_$mem_id EXPORT_OF qdr.dll_sharing
	}
	if {"oct" in $shared_interfaces} {
	    add_interface oct_sharing_$mem_id conduit end
	    set_interface_property oct_sharing_$mem_id EXPORT_OF qdr.oct_sharing
	}
    }

    # If the memory is shared, or it is the first memory, it runs in the DMA
    # clock domain, so export the pipeline stage for DMA
    if {$role == "primary" || $role == "secondary"} {
	add_interface dma_r avalon slave
	set_interface_property dma_r EXPORT_OF pipe_stage_dma_r.s0

	add_interface dma_w avalon slave
	set_interface_property dma_w EXPORT_OF pipe_stage_dma_w.s0
    } else {
	# If the memory runs on it's own PLL, it is not running in the DMA
	# domain. Export the clock-cross interfaces
	add_interface dma_r avalon slave
	set_interface_property dma_r EXPORT_OF clock_cross_dma_r.s0

	add_interface dma_w avalon slave
	set_interface_property dma_w EXPORT_OF clock_cross_dma_w.s0
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
    # (disabled instances are intentionally culled)
    ############################################################################
    if {($role == "primary") || ($role == "independent")} {
	add_instance ref_clk_bridge altera_clock_bridge 14.1
	set_instance_parameter_value ref_clk_bridge {EXPLICIT_CLOCK_RATE} {50000000.0}
	set_instance_parameter_value ref_clk_bridge {NUM_CLOCK_OUTPUTS} {1}
    }

    add_instance dma_clk clock_source 14.1
    set_instance_parameter_value dma_clk {clockFrequency} {50000000.0}
    set_instance_parameter_value dma_clk {clockFrequencyKnown} {0}
    set_instance_parameter_value dma_clk {resetSynchronousEdges} {DEASSERT}

    add_instance global_reset_bridge altera_reset_bridge 14.1
    set_instance_parameter_value global_reset_bridge {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value global_reset_bridge {SYNCHRONOUS_EDGES} {none}
    set_instance_parameter_value global_reset_bridge {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value global_reset_bridge {USE_RESET_REQUEST} {0}

    add_instance sw_kernel_reset_bridge altera_reset_bridge 14.1
    set_instance_parameter_value sw_kernel_reset_bridge {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value sw_kernel_reset_bridge {SYNCHRONOUS_EDGES} {none}
    set_instance_parameter_value sw_kernel_reset_bridge {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value sw_kernel_reset_bridge {USE_RESET_REQUEST} {0}

    add_instance memory_reset_bridge altera_reset_bridge 14.1
    set_instance_parameter_value memory_reset_bridge {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value memory_reset_bridge {SYNCHRONOUS_EDGES} {deassert}
    set_instance_parameter_value memory_reset_bridge {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value memory_reset_bridge {USE_RESET_REQUEST} {0}

    add_instance kernel_clk_bridge clock_source 14.1
    set_instance_parameter_value kernel_clk_bridge {clockFrequency} {50000000.0}
    set_instance_parameter_value kernel_clk_bridge {clockFrequencyKnown} {0}
    set_instance_parameter_value kernel_clk_bridge {resetSynchronousEdges} {DEASSERT}

    add_instance afi_bridge clock_source 14.1
    set_instance_parameter_value afi_bridge {clockFrequency} {50000000.0}
    set_instance_parameter_value afi_bridge {clockFrequencyKnown} {0}
    set_instance_parameter_value afi_bridge {resetSynchronousEdges} {DEASSERT}

    add_instance reset_controller altera_reset_controller 14.1
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

    add_instance clock_cross_kernel_r altera_avalon_mm_clock_crossing_bridge 14.1
    set_instance_parameter_value clock_cross_kernel_r {DATA_WIDTH} $fabric_data_width
    set_instance_parameter_value clock_cross_kernel_r {SYMBOL_WIDTH} $symbol_width
    set_instance_parameter_value clock_cross_kernel_r {ADDRESS_WIDTH} {31}
    set_instance_parameter_value clock_cross_kernel_r {USE_AUTO_ADDRESS_WIDTH} {1}
    set_instance_parameter_value clock_cross_kernel_r {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value clock_cross_kernel_r {MAX_BURST_SIZE} $max_burst
    set_instance_parameter_value clock_cross_kernel_r {COMMAND_FIFO_DEPTH} {16}
    set_instance_parameter_value clock_cross_kernel_r {RESPONSE_FIFO_DEPTH} {64}
    set_instance_parameter_value clock_cross_kernel_r {MASTER_SYNC_DEPTH} {2}
    set_instance_parameter_value clock_cross_kernel_r {SLAVE_SYNC_DEPTH} {2}

    add_instance clock_cross_kernel_w altera_avalon_mm_clock_crossing_bridge 14.1
    set_instance_parameter_value clock_cross_kernel_w {DATA_WIDTH} $fabric_data_width
    set_instance_parameter_value clock_cross_kernel_w {SYMBOL_WIDTH} $symbol_width
    set_instance_parameter_value clock_cross_kernel_w {ADDRESS_WIDTH} {31}
    set_instance_parameter_value clock_cross_kernel_w {USE_AUTO_ADDRESS_WIDTH} {1}
    set_instance_parameter_value clock_cross_kernel_w {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value clock_cross_kernel_w {MAX_BURST_SIZE} $max_burst
    set_instance_parameter_value clock_cross_kernel_w {COMMAND_FIFO_DEPTH} {16}
    set_instance_parameter_value clock_cross_kernel_w {RESPONSE_FIFO_DEPTH} {64}
    set_instance_parameter_value clock_cross_kernel_w {MASTER_SYNC_DEPTH} {2}
    set_instance_parameter_value clock_cross_kernel_w {SLAVE_SYNC_DEPTH} {2}

    if {($role == "primary") || ($role == "secondary")} {
	add_instance pipe_stage_dma_w altera_avalon_mm_bridge 14.1
	set_instance_parameter_value pipe_stage_dma_w {DATA_WIDTH} $fabric_data_width
	set_instance_parameter_value pipe_stage_dma_w {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value pipe_stage_dma_w {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value pipe_stage_dma_w {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value pipe_stage_dma_w {MAX_BURST_SIZE} $max_burst
	set_instance_parameter_value pipe_stage_dma_w {MAX_PENDING_RESPONSES} {4}
	set_instance_parameter_value pipe_stage_dma_w {LINEWRAPBURSTS} {0}
	set_instance_parameter_value pipe_stage_dma_w {PIPELINE_COMMAND} {1}
	set_instance_parameter_value pipe_stage_dma_w {PIPELINE_RESPONSE} {1}
	
	add_instance pipe_stage_dma_r altera_avalon_mm_bridge 14.1
	set_instance_parameter_value pipe_stage_dma_r {DATA_WIDTH} $fabric_data_width
	set_instance_parameter_value pipe_stage_dma_r {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value pipe_stage_dma_r {ADDRESS_WIDTH} {20}
	set_instance_parameter_value pipe_stage_dma_r {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value pipe_stage_dma_r {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value pipe_stage_dma_r {MAX_BURST_SIZE} $max_burst
	set_instance_parameter_value pipe_stage_dma_r {MAX_PENDING_RESPONSES} {4}
	set_instance_parameter_value pipe_stage_dma_r {LINEWRAPBURSTS} {0}
	set_instance_parameter_value pipe_stage_dma_r {PIPELINE_COMMAND} {1}
	set_instance_parameter_value pipe_stage_dma_r {PIPELINE_RESPONSE} {1}

    } else {

	add_instance clock_cross_dma_r altera_avalon_mm_clock_crossing_bridge 14.1
	set_instance_parameter_value clock_cross_dma_r {DATA_WIDTH} $fabric_data_width
	set_instance_parameter_value clock_cross_dma_r {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value clock_cross_dma_r {ADDRESS_WIDTH} {31}
	set_instance_parameter_value clock_cross_dma_r {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value clock_cross_dma_r {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value clock_cross_dma_r {MAX_BURST_SIZE} $max_burst
	set_instance_parameter_value clock_cross_dma_r {COMMAND_FIFO_DEPTH} {16}
	set_instance_parameter_value clock_cross_dma_r {RESPONSE_FIFO_DEPTH} {64}
	set_instance_parameter_value clock_cross_dma_r {MASTER_SYNC_DEPTH} {2}
	set_instance_parameter_value clock_cross_dma_r {SLAVE_SYNC_DEPTH} {2}
	
	add_instance clock_cross_dma_w altera_avalon_mm_clock_crossing_bridge 14.1
	set_instance_parameter_value clock_cross_dma_w {DATA_WIDTH} $fabric_data_width
	set_instance_parameter_value clock_cross_dma_w {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value clock_cross_dma_w {ADDRESS_WIDTH} {31}
	set_instance_parameter_value clock_cross_dma_w {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value clock_cross_dma_w {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value clock_cross_dma_w {MAX_BURST_SIZE} $max_burst
	set_instance_parameter_value clock_cross_dma_w {COMMAND_FIFO_DEPTH} {16}
	set_instance_parameter_value clock_cross_dma_w {RESPONSE_FIFO_DEPTH} {64}
	set_instance_parameter_value clock_cross_dma_w {MASTER_SYNC_DEPTH} {2}
	set_instance_parameter_value clock_cross_dma_w {SLAVE_SYNC_DEPTH} {2}
    }

    add_instance qdr altera_mem_if_qdrii_emif 14.1
    set_instance_parameter_value qdr {MEM_ADDR_WIDTH} $address_pins
    set_instance_parameter_value qdr {MEM_DQ_WIDTH} $dq_pins
    set_instance_parameter_value qdr {MEM_CS_WIDTH} {1}
    set_instance_parameter_value qdr {MEM_DM_WIDTH} $log2_dq_pins
    set_instance_parameter_value qdr {MEM_CONTROL_WIDTH} {1}
    set_instance_parameter_value qdr {MEM_READ_DQS_WIDTH} {1}
    set_instance_parameter_value qdr {MEM_WRITE_DQS_WIDTH} {1}
    set_instance_parameter_value qdr {MEM_BURST_LENGTH} {4}
    set_instance_parameter_value qdr {EMULATED_MODE} {0}
    set_instance_parameter_value qdr {EMULATED_WRITE_GROUPS} {2}
    set_instance_parameter_value qdr {DEVICE_WIDTH} {1}
    set_instance_parameter_value qdr {DEVICE_DEPTH} {1}
    set_instance_parameter_value qdr {MEM_USE_DENALI_MODEL} {0}
    set_instance_parameter_value qdr {QDRII_PLUS_MODE} {0}
    set_instance_parameter_value qdr {MEM_DENALI_SOMA_FILE} {qdrii.soma}
    set_instance_parameter_value qdr {MEM_IF_BOARD_BASE_DELAY} {10}
    set_instance_parameter_value qdr {MEM_SUPPRESS_CMD_TIMING_ERROR} {0}
    set_instance_parameter_value qdr {MEM_VERBOSE} {1}
    set_instance_parameter_value qdr {PINGPONGPHY_EN} {0}
    set_instance_parameter_value qdr {DUPLICATE_AC} {0}
    set_instance_parameter_value qdr {MEM_T_WL} {1}
    set_instance_parameter_value qdr {MEM_T_RL} {2.5}
    set_instance_parameter_value qdr {TIMING_TKH} {400}
    set_instance_parameter_value qdr {TIMING_TSA} {300}
    set_instance_parameter_value qdr {TIMING_THA} {300}
    set_instance_parameter_value qdr {TIMING_TSD} {250}
    set_instance_parameter_value qdr {TIMING_THD} {250}
    set_instance_parameter_value qdr {TIMING_TCQD} {200}
    set_instance_parameter_value qdr {TIMING_TCQDOH} {-200}
    set_instance_parameter_value qdr {TIMING_QDR_INTERNAL_JITTER} {150}
    set_instance_parameter_value qdr {TIMING_TCQHCQnH} {895}
    set_instance_parameter_value qdr {TIMING_TKHKnH} {990}
    set_instance_parameter_value qdr {PARSE_FRIENDLY_DEVICE_FAMILY_PARAM_VALID} {0}
    set_instance_parameter_value qdr {PARSE_FRIENDLY_DEVICE_FAMILY_PARAM} {}
    set_instance_parameter_value qdr {DEVICE_FAMILY_PARAM} {}
    set_instance_parameter_value qdr {SPEED_GRADE} {2}
    set_instance_parameter_value qdr {IS_ES_DEVICE} {0}
    set_instance_parameter_value qdr {DISABLE_CHILD_MESSAGING} {0}
    set_instance_parameter_value qdr {HARD_EMIF} {0}
    set_instance_parameter_value qdr {HHP_HPS} {0}
    set_instance_parameter_value qdr {HHP_HPS_VERIFICATION} {0}
    set_instance_parameter_value qdr {HHP_HPS_SIMULATION} {0}
    set_instance_parameter_value qdr {HPS_PROTOCOL} {DEFAULT}
    set_instance_parameter_value qdr {CUT_NEW_FAMILY_TIMING} {1}
    set_instance_parameter_value qdr {POWER_OF_TWO_BUS} {1}
    set_instance_parameter_value qdr {SOPC_COMPAT_RESET} {0}
    set_instance_parameter_value qdr {AVL_MAX_SIZE} $max_burst
    set_instance_parameter_value qdr {BYTE_ENABLE} {1}
    set_instance_parameter_value qdr {CTL_LATENCY} {1}
    set_instance_parameter_value qdr {ENABLE_CTRL_AVALON_INTERFACE} {1}
    set_instance_parameter_value qdr {ENABLE_EMIT_BFM_MASTER} {0}
    set_instance_parameter_value qdr {FORCE_SEQUENCER_TCL_DEBUG_MODE} {0}
    set_instance_parameter_value qdr {ENABLE_SEQUENCER_MARGINING_ON_BY_DEFAULT} {0}
    set_instance_parameter_value qdr {REF_CLK_FREQ} $ref_clock_freq
    set_instance_parameter_value qdr {REF_CLK_FREQ_PARAM_VALID} {0}
    set_instance_parameter_value qdr {REF_CLK_FREQ_MIN_PARAM} {0.0}
    set_instance_parameter_value qdr {REF_CLK_FREQ_MAX_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_DR_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_DR_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_DR_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_DR_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_DR_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_DR_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_MEM_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_MEM_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_MEM_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_MEM_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_MEM_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_MEM_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_AFI_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_AFI_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_AFI_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_AFI_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_AFI_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_AFI_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_WRITE_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_WRITE_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_WRITE_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_WRITE_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_WRITE_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_WRITE_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_ADDR_CMD_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_ADDR_CMD_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_ADDR_CMD_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_ADDR_CMD_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_ADDR_CMD_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_ADDR_CMD_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_AFI_HALF_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_AFI_HALF_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_AFI_HALF_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_AFI_HALF_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_AFI_HALF_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_AFI_HALF_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_NIOS_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_NIOS_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_NIOS_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_NIOS_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_NIOS_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_NIOS_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_CONFIG_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_CONFIG_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_CONFIG_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_CONFIG_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_CONFIG_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_CONFIG_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_P2C_READ_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_P2C_READ_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_P2C_READ_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_P2C_READ_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_P2C_READ_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_P2C_READ_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_C2P_WRITE_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_C2P_WRITE_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_C2P_WRITE_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_C2P_WRITE_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_C2P_WRITE_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_C2P_WRITE_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_HR_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_HR_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_HR_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_HR_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_HR_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_HR_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_AFI_PHY_CLK_FREQ_PARAM} {0.0}
    set_instance_parameter_value qdr {PLL_AFI_PHY_CLK_FREQ_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_AFI_PHY_CLK_PHASE_PS_PARAM} {0}
    set_instance_parameter_value qdr {PLL_AFI_PHY_CLK_PHASE_PS_SIM_STR_PARAM} {}
    set_instance_parameter_value qdr {PLL_AFI_PHY_CLK_MULT_PARAM} {0}
    set_instance_parameter_value qdr {PLL_AFI_PHY_CLK_DIV_PARAM} {0}
    set_instance_parameter_value qdr {PLL_CLK_PARAM_VALID} {0}
    set_instance_parameter_value qdr {ENABLE_EXTRA_REPORTING} {0}
    set_instance_parameter_value qdr {NUM_EXTRA_REPORT_PATH} {10}
    set_instance_parameter_value qdr {ENABLE_ISS_PROBES} {0}
    set_instance_parameter_value qdr {CALIB_REG_WIDTH} {8}
    set_instance_parameter_value qdr {USE_SEQUENCER_BFM} {0}
    set_instance_parameter_value qdr {EXPORT_AFI_HALF_CLK} {0}
    set_instance_parameter_value qdr {ABSTRACT_REAL_COMPARE_TEST} {0}
    set_instance_parameter_value qdr {INCLUDE_BOARD_DELAY_MODEL} {0}
    set_instance_parameter_value qdr {INCLUDE_MULTIRANK_BOARD_DELAY_MODEL} {0}
    set_instance_parameter_value qdr {USE_FAKE_PHY} {0}
    set_instance_parameter_value qdr {FORCE_MAX_LATENCY_COUNT_WIDTH} {0}
    set_instance_parameter_value qdr {ENABLE_NON_DESTRUCTIVE_CALIB} {0}
    set_instance_parameter_value qdr {ENABLE_DELAY_CHAIN_WRITE} {0}
    set_instance_parameter_value qdr {TRACKING_ERROR_TEST} {0}
    set_instance_parameter_value qdr {TRACKING_WATCH_TEST} {0}
    set_instance_parameter_value qdr {MARGIN_VARIATION_TEST} {0}
    set_instance_parameter_value qdr {AC_ROM_USER_ADD_0} {0_0000_0000_0000}
    set_instance_parameter_value qdr {AC_ROM_USER_ADD_1} {0_0000_0000_1000}
    set_instance_parameter_value qdr {TREFI} {35100}
    set_instance_parameter_value qdr {REFRESH_INTERVAL} {15000}
    set_instance_parameter_value qdr {ENABLE_NON_DES_CAL_TEST} {0}
    set_instance_parameter_value qdr {TRFC} {350}
    set_instance_parameter_value qdr {ENABLE_NON_DES_CAL} {0}
    set_instance_parameter_value qdr {EXTRA_SETTINGS} {}
    set_instance_parameter_value qdr {MEM_DEVICE} {MISSING_MODEL}
    set_instance_parameter_value qdr {FORCE_SYNTHESIS_LANGUAGE} {}
    set_instance_parameter_value qdr {AFI_DEBUG_INFO_WIDTH} {32}
    set_instance_parameter_value qdr {ADVERTIZE_SEQUENCER_SW_BUILD_FILES} {0}
    set_instance_parameter_value qdr {PHY_ONLY} {0}
    set_instance_parameter_value qdr {COMMAND_PHASE} {0}
    set_instance_parameter_value qdr {MEM_CK_PHASE} {0.0}
    set_instance_parameter_value qdr {P2C_READ_CLOCK_ADD_PHASE} {0.0}
    set_instance_parameter_value qdr {C2P_WRITE_CLOCK_ADD_PHASE} {0.0}
    set_instance_parameter_value qdr {ACV_PHY_CLK_ADD_FR_PHASE} {0.0}
    set_instance_parameter_value qdr {IO_STANDARD} {1.5-V HSTL}
    set_instance_parameter_value qdr {HCX_COMPAT_MODE} {0}
    set_instance_parameter_value qdr {PLL_LOCATION} {Top_Bottom}
    set_instance_parameter_value qdr {SEQUENCER_TYPE} {NIOS}
    set_instance_parameter_value qdr {SKIP_MEM_INIT} {1}
    set_instance_parameter_value qdr {CALIBRATION_MODE} {Skip}
    set_instance_parameter_value qdr {MEM_IF_DM_PINS_EN} {1}
    set_instance_parameter_value qdr {MEM_IF_DQSN_EN} {1}
    set_instance_parameter_value qdr {MEM_LEVELING} {0}
    set_instance_parameter_value qdr {READ_DQ_DQS_CLOCK_SOURCE} {DQS_BUS}
    set_instance_parameter_value qdr {DQ_INPUT_REG_USE_CLKN} {1}
    set_instance_parameter_value qdr {DQS_DQSN_MODE} {COMPLEMENTARY}
    set_instance_parameter_value qdr {READ_FIFO_SIZE} {8}
    set_instance_parameter_value qdr {NIOS_ROM_DATA_WIDTH} {32}
    set_instance_parameter_value qdr {PHY_CSR_ENABLED} {0}
    set_instance_parameter_value qdr {MAX10_RTL_SEQ} {0}
    set_instance_parameter_value qdr {TIMING_BOARD_AC_EYE_REDUCTION_SU} {0}
    set_instance_parameter_value qdr {TIMING_BOARD_AC_EYE_REDUCTION_H} {0}
    set_instance_parameter_value qdr {TIMING_BOARD_DQ_EYE_REDUCTION} {0}
    set_instance_parameter_value qdr {TIMING_BOARD_DELTA_DQS_ARRIVAL_TIME} {0}
    set_instance_parameter_value qdr {TIMING_BOARD_READ_DQ_EYE_REDUCTION} {0.0}
    set_instance_parameter_value qdr {TIMING_BOARD_DELTA_READ_DQS_ARRIVAL_TIME} {0.0}
    set_instance_parameter_value qdr {PACKAGE_DESKEW} {0}
    set_instance_parameter_value qdr {AC_PACKAGE_DESKEW} {0}
    set_instance_parameter_value qdr {TIMING_BOARD_SKEW_BETWEEN_DIMMS} {0}
    set_instance_parameter_value qdr {TIMING_BOARD_SKEW} {20}
    set_instance_parameter_value qdr {USER_DEBUG_LEVEL} {1}
    set_instance_parameter_value qdr {RATE} $fabric_ratio
    set_instance_parameter_value qdr {MEM_CLK_FREQ} $mem_clock_freq
    set_instance_parameter_value qdr {USE_MEM_CLK_FREQ} {0}
    set_instance_parameter_value qdr {FORCE_DQS_TRACKING} {AUTO}
    set_instance_parameter_value qdr {FORCE_SHADOW_REGS} {AUTO}
    set_instance_parameter_value qdr {MRS_MIRROR_PING_PONG_ATSO} {0}
    set_instance_parameter_value qdr {ENABLE_EXPORT_SEQ_DEBUG_BRIDGE} {0}
    set_instance_parameter_value qdr {CORE_DEBUG_CONNECTION} {EXPORT}
    set_instance_parameter_value qdr {ADD_EXTERNAL_SEQ_DEBUG_NIOS} {0}
    set_instance_parameter_value qdr {ED_EXPORT_SEQ_DEBUG} {0}
    set_instance_parameter_value qdr {ADD_EFFICIENCY_MONITOR} {0}
    # TODO: Read from XML File
    foreach parameter [dom::selectNode $param_dom /board/memory\[@type="QDRII"\]/phy\[@id=\"$mem_id\"\]/parameter/@name] {
	set name [$parameter stringValue]
	set value [[dom::selectNode $param_dom /board/memory\[@type="QDRII"\]/phy\[@id=\"$mem_id\"\]/parameter\[@name=\"$name\"\]/@value] stringValue]
	set_instance_parameter_value qdr $name $value
    }

    ############################################################################
    # setting up sharing conduits and exporting their connections 
    ############################################################################
    # TODO: What about independent shared?
    if {$role == "primary" && $num_shared > 0} {
	    set_instance_parameter_value qdr {PLL_SHARING_MODE} {Master}
	    set_instance_parameter_value qdr {NUM_PLL_SHARING_INTERFACES} $num_shared
	    set_instance_parameter_value qdr {DLL_SHARING_MODE} {Master}
	    set_instance_parameter_value qdr {NUM_DLL_SHARING_INTERFACES} $num_shared
	    set_instance_parameter_value qdr {OCT_SHARING_MODE} {Master}
	    set_instance_parameter_value qdr {NUM_OCT_SHARING_INTERFACES} $num_shared
    } else {
	if {"pll" in $shared_interfaces} {
	    set_instance_parameter_value qdr {PLL_SHARING_MODE} {Slave}
	    set_instance_parameter_value qdr {NUM_PLL_SHARING_INTERFACES} {1}
	} else {
	    set_instance_parameter_value qdr {PLL_SHARING_MODE} {None}
	    set_instance_parameter_value qdr {NUM_PLL_SHARING_INTERFACES} {1}
	} 
	if {"dll" in $shared_interfaces} {
	    set_instance_parameter_value qdr {DLL_SHARING_MODE} {Slave}
	    set_instance_parameter_value qdr {NUM_DLL_SHARING_INTERFACES} {1}
	} else {
	    set_instance_parameter_value qdr {DLL_SHARING_MODE} {None}
	    set_instance_parameter_value qdr {NUM_DLL_SHARING_INTERFACES} {1}
	}
	if {"oct" in $shared_interfaces} {
	    set_instance_parameter_value qdr {OCT_SHARING_MODE} {Slave}
	    set_instance_parameter_value qdr {NUM_OCT_SHARING_INTERFACES} {1}
	} else {
	    set_instance_parameter_value qdr {OCT_SHARING_MODE} {None}
	    set_instance_parameter_value qdr {NUM_OCT_SHARING_INTERFACES} {1}
	}
    }

    ############################################################################
    # connections and connection parameters
    ############################################################################
    add_connection reset_controller.reset_out memory_reset_bridge.in_reset reset

    # Kernel Clk
    add_connection kernel_clk_bridge.clk clock_cross_kernel_r.s0_clk clock
    add_connection kernel_clk_bridge.clk clock_cross_kernel_w.s0_clk clock

    # Kernel Reset
    add_connection kernel_clk_bridge.clk_reset clock_cross_kernel_r.s0_reset reset
    add_connection kernel_clk_bridge.clk_reset clock_cross_kernel_w.s0_reset reset

    # Kernel/QDR Read Interface
    add_connection clock_cross_kernel_r.m0 qdr.avl_r avalon
    set_connection_parameter_value clock_cross_kernel_r.m0/qdr.avl_r arbitrationPriority {1}
    set_connection_parameter_value clock_cross_kernel_r.m0/qdr.avl_r baseAddress {0x0000}
    set_connection_parameter_value clock_cross_kernel_r.m0/qdr.avl_r defaultConnection {0}

    # Kernel/QDR Write Interface
    add_connection clock_cross_kernel_w.m0 qdr.avl_w avalon
    set_connection_parameter_value clock_cross_kernel_w.m0/qdr.avl_w arbitrationPriority {1}
    set_connection_parameter_value clock_cross_kernel_w.m0/qdr.avl_w baseAddress {0x0000}
    set_connection_parameter_value clock_cross_kernel_w.m0/qdr.avl_w defaultConnection {0}

    # Global Reset Connections
    add_connection global_reset_bridge.out_reset reset_controller.reset_in0 reset
    add_connection global_reset_bridge.out_reset qdr.soft_reset reset
    add_connection global_reset_bridge.out_reset qdr.global_reset reset

    # If we are the first memory, we defin the DMA clock domain
    if {$role == "primary"} {
	add_connection qdr.afi_clk dma_clk.clk_in clock
	add_connection reset_controller.reset_out dma_clk.clk_in_reset reset
    } else {
	# Else, these connections are exported above
    }

    if {($role == "primary") || ($role == "secondary")} {
	add_connection pipe_stage_dma_r.m0 qdr.avl_r avalon
	set_connection_parameter_value pipe_stage_dma_r.m0/qdr.avl_r arbitrationPriority {1}
	set_connection_parameter_value pipe_stage_dma_r.m0/qdr.avl_r baseAddress {0x0000}
	set_connection_parameter_value pipe_stage_dma_r.m0/qdr.avl_r defaultConnection {0}

	add_connection pipe_stage_dma_w.m0 qdr.avl_w avalon
	set_connection_parameter_value pipe_stage_dma_w.m0/qdr.avl_w arbitrationPriority {1}
	set_connection_parameter_value pipe_stage_dma_w.m0/qdr.avl_w baseAddress {0x0000}
	set_connection_parameter_value pipe_stage_dma_w.m0/qdr.avl_w defaultConnection {0}

	add_connection dma_clk.clk pipe_stage_dma_w.clk clock
	add_connection dma_clk.clk pipe_stage_dma_r.clk clock
	add_connection dma_clk.clk_reset pipe_stage_dma_w.reset reset
	add_connection dma_clk.clk_reset pipe_stage_dma_r.reset reset
    } else {
	add_connection clock_cross_dma_r.m0 qdr.avl_r avalon
	set_connection_parameter_value clock_cross_dma_r.m0/qdr.avl_r arbitrationPriority {1}
	set_connection_parameter_value clock_cross_dma_r.m0/qdr.avl_r baseAddress {0x0000}
	set_connection_parameter_value clock_cross_dma_r.m0/qdr.avl_r defaultConnection {0}
	
	add_connection clock_cross_dma_w.m0 qdr.avl_w avalon
	set_connection_parameter_value clock_cross_dma_w.m0/qdr.avl_w arbitrationPriority {1}
	set_connection_parameter_value clock_cross_dma_w.m0/qdr.avl_w baseAddress {0x0000}
	set_connection_parameter_value clock_cross_dma_w.m0/qdr.avl_w defaultConnection {0}

	add_connection dma_clk.clk clock_cross_dma_r.s0_clk clock
	add_connection dma_clk.clk clock_cross_dma_w.s0_clk clock
	add_connection dma_clk.clk_reset clock_cross_dma_r.s0_reset reset
	add_connection dma_clk.clk_reset clock_cross_dma_w.s0_reset reset
	add_connection qdr.afi_clk clock_cross_dma_r.m0_clk clock
	add_connection qdr.afi_clk clock_cross_dma_w.m0_clk clock
	add_connection reset_controller.reset_out clock_cross_dma_r.m0_reset reset
	add_connection reset_controller.reset_out clock_cross_dma_w.m0_reset reset
    }

    if {($role == "primary") || ($role == "independent")} {
	add_connection qdr.afi_clk reset_controller.clk clock
	add_connection qdr.afi_clk memory_reset_bridge.clk clock

	# NOTE: In DDR, this reset is not driven
	add_connection qdr.afi_reset reset_controller.reset_in1 reset

	add_connection qdr.afi_clk afi_bridge.clk_in clock
	add_connection qdr.afi_reset afi_bridge.clk_in_reset reset

	add_connection qdr.afi_clk clock_cross_kernel_r.m0_clk clock
	add_connection qdr.afi_clk clock_cross_kernel_w.m0_clk clock

	add_connection ref_clk_bridge.out_clk qdr.pll_ref_clk clock
	#add_connection qdr.afi_clk sw_kernel_reset_bridge.clk clock
    } else {
	add_connection afi_bridge.clk reset_controller.clk clock
	add_connection afi_bridge.clk memory_reset_bridge.clk clock
	# NOTE: In DDR, this reset is not driven
	add_connection afi_bridge.clk_reset reset_controller.reset_in1 reset

	add_connection afi_bridge.clk qdr.afi_clk_in clock
	add_connection afi_bridge.clk_reset qdr.afi_reset_in clock

	add_connection afi_bridge.clk clock_cross_kernel_r.m0_clk clock
	add_connection afi_bridge.clk clock_cross_kernel_w.m0_clk clock

	#add_connection afi_bridge.clk sw_kernel_reset_bridge.clk clock
    }

    add_connection sw_kernel_reset_bridge.out_reset clock_cross_kernel_r.m0_reset reset
    add_connection sw_kernel_reset_bridge.out_reset clock_cross_kernel_w.m0_reset reset

    # interconnect requirements
    set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
    set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {2}
}

