package require -exact qsys 14.0
lappend auto_path $::env(TCLXML_PATH)
package require xml

# module properties
set_module_property NAME {ddr3_system}
set_module_property DISPLAY_NAME {ddr3_system}

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

add_parameter MEMORY_INDEX String 1 "Global Memory System ID Number"
set_parameter_property MEMORY_INDEX DEFAULT_VALUE 1
set_parameter_property MEMORY_INDEX DISPLAY_NAME MEMORY_INDEX
set_parameter_property MEMORY_INDEX TYPE String
set_parameter_property MEMORY_INDEX UNITS None
set_parameter_property MEMORY_INDEX DESCRIPTION "Global Memory System ID Number"
set_parameter_property MEMORY_INDEX HDL_PARAMETER true
set_parameter_property MEMORY_INDEX ALLOWED_RANGES {0 1 2 3 4 5 6 7 8}

proc compose { } {
    set symbol_width 8
    set board_path [get_parameter_value BOARD_PATH]
    set board_file $board_path/board_specification.xml
    set board_fp [open $board_file]
    set board_dom [dom::parse [read $board_fp]]

    set index [get_parameter_value MEMORY_INDEX]
    set primary_id [[dom::selectNode $board_dom /board/global_mem\[@type="DDR3"\]\[@index=\"$index\"\]/interface\[@role="primary"\]/@id] stringValue]
    set sys_role [[dom::selectNode $board_dom /board/global_mem\[@type="DDR3"\]\[@index=\"$index\"\]/@role] stringValue]
    set data_width [[dom::selectNode $board_dom /board/global_mem\[@type="DDR3"\]\[@index=\"$index\"\]/@width] stringValue]
    set address_width [[dom::selectNode $board_dom /board/global_mem\[@type="DDR3"\]\[@index=\"$index\"\]/@addr_width] stringValue]
    set sys_burst [[dom::selectNode $board_dom /board/global_mem\[@type="DDR3"\]\[@index=\"$index\"\]/@maxburst] stringValue]

    set memory_ids {}
    foreach node [dom::selectNode $board_dom /board/global_mem\[@type="DDR3"\]\[@index=\"$index\"\]/*/@id] {
	lappend memory_ids [$node stringValue]
    }
    set num_memories [llength $memory_ids]


    ############################################################################
    # exported interfaces
    ############################################################################

    # Kernel Clock (input)
    add_interface kernel_clk clock sink
    set_interface_property kernel_clk EXPORT_OF kernel_clk_bridge.clk_in

    # Kernel Reset (input)
    add_interface kernel_reset reset sink
    set_interface_property kernel_reset EXPORT_OF kernel_clk_bridge.clk_in_reset

    # System Clock (output)
    add_interface system_clk clock source
    set_interface_property system_clk EXPORT_OF system_clk_bridge.clk

    # System Reset (output)
    add_interface system_reset reset source
    set_interface_property system_reset EXPORT_OF system_clk_bridge.clk_reset

    # SW Kernel Reset (input)
    add_interface sw_kernel_reset reset sink
    set_interface_property sw_kernel_reset EXPORT_OF sw_kernel_reset_bridge.in_reset

    # Global Reset (input)
    add_interface global_reset reset sink
    set_interface_property global_reset EXPORT_OF global_reset_bridge.in_reset

    # Memorg Conduit
    add_interface acl_internal_snoop avalon_streaming source
    set_interface_property acl_internal_snoop EXPORT_OF acl_memory_bank_divider_$index.acl_bsp_snoop

    if {$num_memories > 1} {
	add_interface acl_bsp_memorg_$index conduit end
	set_interface_property acl_bsp_memorg_$index EXPORT_OF acl_memory_bank_divider_$index.acl_bsp_memorg_host
    }

    # System DMA clock, reset, and data interfaces
    if {$sys_role == "secondary"} {
	add_interface dma_ddr$index\_rw avalon slave
	set_interface_property dma_ddr$index\_rw EXPORT_OF dma_ddr$index\_clock_crossing_bridge.s0

	add_interface dma_ddr$index\_clk clock sink
	set_interface_property dma_ddr$index\_clk EXPORT_OF dma_ddr$index\_clock_crossing_bridge.s0_clk

	add_interface dma_ddr$index\_reset reset sink
	set_interface_property dma_ddr$index\_reset EXPORT_OF dma_ddr$index\_clock_crossing_bridge.s0_reset
    } else {
	add_interface dma_ddr$index\_rw avalon slave
	set_interface_property dma_ddr$index\_rw EXPORT_OF dma_ddr$index\_pipe_stage.s0
    }

    # Memory Kernel, Pin, and clock interfaces
    foreach id $memory_ids {
	set id_role [[dom::selectNode $board_dom /board/global_mem\[@type="DDR3"\]\[@index=\"$index\"\]/interface\[@id=\"$id\"\]/@role] stringValue]

	# Kernel read/write interface
	add_interface kernel_$index\_ddr3$id\_rw avalon slave
	set_interface_property kernel_$index\_ddr3$id\_rw EXPORT_OF ddr3$id.kernel_rw

	# DDR Memory Interface
	add_interface ddr3$id conduit end
	set_interface_property ddr3$id EXPORT_OF ddr3$id.ddr_pins

	# DDR Status
	add_interface ddr3$id\_status conduit end
	set_interface_property ddr3$id\_status EXPORT_OF ddr3$id.status

	if {$id_role == "primary"} {
	    add_interface ddr3$id\_pll_ref clock sink
	    set_interface_property ddr3$id\_pll_ref EXPORT_OF ddr3$id\.ref_clk

	    add_interface ddr3$id\_oct conduit end
	    set_interface_property ddr3$id\_oct EXPORT_OF ddr3$id\.oct
	}

	if {$id_role == "independent"} {
	    set shared_interfaces [split [[dom::selectNode $board_dom /board/global_mem\[@type="DDR3"\]/interface\[@id=\"$id\"\]/@shared] stringValue] ","]
	    
	    if {!("pll" in $shared_interfaces)} {
		add_interface ddr3$id\_pll_ref clock sink
		set_interface_property ddr3$id\_pll_ref EXPORT_OF ddr3$id\.ref_clk
	    } 

	    if {!("oct" in $shared_interfaces)} {
		add_interface ddr3$id\_oct conduit end
		set_interface_property ddr3$id\_oct EXPORT_OF ddr3$id\.oct
	    }
	}
    }

    ############################################################################
    # Instances and instance parameters
    # (disabled instances are intentionally culled)
    ############################################################################

    add_instance kernel_clk_bridge clock_source 14.1
    set_instance_parameter_value kernel_clk_bridge {clockFrequency} {50000000.0}
    set_instance_parameter_value kernel_clk_bridge {clockFrequencyKnown} {0}
    set_instance_parameter_value kernel_clk_bridge {resetSynchronousEdges} {DEASSERT}

    add_instance system_clk_bridge clock_source 14.1
    set_instance_parameter_value system_clk_bridge {clockFrequency} {50000000.0}
    set_instance_parameter_value system_clk_bridge {clockFrequencyKnown} {0}
    set_instance_parameter_value system_clk_bridge {resetSynchronousEdges} {DEASSERT}

    add_instance sw_kernel_reset_bridge altera_reset_bridge 14.1
    set_instance_parameter_value sw_kernel_reset_bridge {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value sw_kernel_reset_bridge {SYNCHRONOUS_EDGES} {none}
    set_instance_parameter_value sw_kernel_reset_bridge {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value sw_kernel_reset_bridge {USE_RESET_REQUEST} {0}

    add_instance global_reset_bridge altera_reset_bridge 14.1
    set_instance_parameter_value global_reset_bridge {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value global_reset_bridge {SYNCHRONOUS_EDGES} {none}
    set_instance_parameter_value global_reset_bridge {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value global_reset_bridge {USE_RESET_REQUEST} {0}

    add_instance acl_memory_bank_divider_$index acl_memory_bank_divider 1.0
    set_instance_parameter_value acl_memory_bank_divider_$index {NUM_BANKS} $num_memories
    set_instance_parameter_value acl_memory_bank_divider_$index {SEPARATE_RW_PORTS} {0}
    set_instance_parameter_value acl_memory_bank_divider_$index {PIPELINE_OUTPUTS} {0}
    set_instance_parameter_value acl_memory_bank_divider_$index {DATA_WIDTH} $data_width
    set_instance_parameter_value acl_memory_bank_divider_$index {ADDRESS_WIDTH} $address_width
    set_instance_parameter_value acl_memory_bank_divider_$index {BURST_SIZE} $sys_burst
    set_instance_parameter_value acl_memory_bank_divider_$index {MAX_PENDING_READS} {64}

    if {$sys_role == "secondary"} {
	add_instance dma_ddr$index\_clock_crossing_bridge altera_avalon_mm_clock_crossing_bridge 14.1
	set_instance_parameter_value dma_ddr$index\_clock_crossing_bridge {DATA_WIDTH} $data_width
	set_instance_parameter_value dma_ddr$index\_clock_crossing_bridge {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value dma_ddr$index\_clock_crossing_bridge {ADDRESS_WIDTH} $address_width
	set_instance_parameter_value dma_ddr$index\_clock_crossing_bridge {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value dma_ddr$index\_clock_crossing_bridge {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value dma_ddr$index\_clock_crossing_bridge {MAX_BURST_SIZE} $sys_burst
	set_instance_parameter_value dma_ddr$index\_clock_crossing_bridge {COMMAND_FIFO_DEPTH} {128}
	set_instance_parameter_value dma_ddr$index\_clock_crossing_bridge {RESPONSE_FIFO_DEPTH} {128}
	set_instance_parameter_value dma_ddr$index\_clock_crossing_bridge {MASTER_SYNC_DEPTH} {2}
	set_instance_parameter_value dma_ddr$index\_clock_crossing_bridge {SLAVE_SYNC_DEPTH} {2}
    } else {
	add_instance dma_ddr$index\_pipe_stage altera_avalon_mm_bridge 14.1
	set_instance_parameter_value dma_ddr$index\_pipe_stage {DATA_WIDTH} $data_width
	set_instance_parameter_value dma_ddr$index\_pipe_stage {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value dma_ddr$index\_pipe_stage {ADDRESS_WIDTH} $address_width
	set_instance_parameter_value dma_ddr$index\_pipe_stage {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value dma_ddr$index\_pipe_stage {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value dma_ddr$index\_pipe_stage {MAX_BURST_SIZE} $sys_burst
	set_instance_parameter_value dma_ddr$index\_pipe_stage {MAX_PENDING_RESPONSES} {32}
	set_instance_parameter_value dma_ddr$index\_pipe_stage {LINEWRAPBURSTS} {0}
	set_instance_parameter_value dma_ddr$index\_pipe_stage {PIPELINE_COMMAND} {1}
	set_instance_parameter_value dma_ddr$index\_pipe_stage {PIPELINE_RESPONSE} {1}
    }

    foreach id $memory_ids {
	add_instance ddr3$id ddr3 1.0
	set_instance_parameter_value ddr3$id {BOARD_PATH} $board_path
	set_instance_parameter_value ddr3$id {MEMORY_IDENTIFIER} $id
	set_instance_parameter_value ddr3$id {SYSTEM_IDENTIFIER} $index
    }

    ############################################################################
    # connections and connection parameters
    ############################################################################
    add_connection kernel_clk_bridge.clk acl_memory_bank_divider_$index.kernel_clk clock
    add_connection kernel_clk_bridge.clk_reset acl_memory_bank_divider_$index.kernel_reset reset

    add_connection ddr3$primary_id.afi_clk acl_memory_bank_divider_$index.clk clock
    add_connection ddr3$primary_id.afi_reset acl_memory_bank_divider_$index.reset reset

    add_connection ddr3$primary_id.afi_clk system_clk_bridge.clk_in clock
    add_connection ddr3$primary_id.afi_reset system_clk_bridge.clk_in_reset reset

    if {$sys_role == "secondary"} {
	add_connection ddr3$primary_id.afi_clk dma_ddr$index\_clock_crossing_bridge.m0_clk clock
	add_connection ddr3$primary_id.memory_reset dma_ddr$index\_clock_crossing_bridge.m0_reset reset

	add_connection dma_ddr$index\_clock_crossing_bridge.m0 acl_memory_bank_divider_$index.s avalon
	set_connection_parameter_value dma_ddr$index\_clock_crossing_bridge.m0/acl_memory_bank_divider_$index.s arbitrationPriority {1}
	set_connection_parameter_value dma_ddr$index\_clock_crossing_bridge.m0/acl_memory_bank_divider_$index.s baseAddress {0x0000}
	set_connection_parameter_value dma_ddr$index\_clock_crossing_bridge.m0/acl_memory_bank_divider_$index.s defaultConnection {0}
    } else {
	add_connection ddr3$primary_id.afi_clk dma_ddr$index\_pipe_stage.clk
	add_connection ddr3$primary_id.memory_reset dma_ddr$index\_pipe_stage.reset

	add_connection dma_ddr$index\_pipe_stage.m0 acl_memory_bank_divider_$index.s avalon
	set_connection_parameter_value dma_ddr$index\_pipe_stage.m0/acl_memory_bank_divider_$index.s arbitrationPriority {1}
	set_connection_parameter_value dma_ddr$index\_pipe_stage.m0/acl_memory_bank_divider_$index.s baseAddress {0x0000}
	set_connection_parameter_value dma_ddr$index\_pipe_stage.m0/acl_memory_bank_divider_$index.s defaultConnection {0}
    }

    set i 0
    foreach id $memory_ids {
	set i [expr {$i + 1}]

	add_connection kernel_clk_bridge.clk ddr3$id.kernel_clk clock
	add_connection kernel_clk_bridge.clk_reset ddr3$id.kernel_reset reset
	add_connection sw_kernel_reset_bridge.out_reset ddr3$id.sw_kernel_reset reset
	add_connection global_reset_bridge.out_reset ddr3$id.global_reset

	add_connection acl_memory_bank_divider_$index.bank$i ddr3$id.dma_rw avalon
	set_connection_parameter_value acl_memory_bank_divider_$index.bank$i/ddr3$id.dma_rw arbitrationPriority {1}
	set_connection_parameter_value acl_memory_bank_divider_$index.bank$i/ddr3$id.dma_rw baseAddress {0x0000}
	set_connection_parameter_value acl_memory_bank_divider_$index.bank$i/ddr3$id.dma_rw defaultConnection {0}

	set board_file $board_path/board_specification.xml
	set board_fp [open $board_file]
	set board_dom [dom::parse [read $board_fp]]

	foreach dep [dom::selectNode $board_dom /board/global_mem\[@type="DDR3"\]\[@index=\"$index\"\]/*\[@primary=\"$id\"\]/@id] {
	    set dep_id [$dep stringValue]
	    set shared_node [[dom::selectNode $board_dom /board/global_mem\[@type="DDR3"\]\[@index=\"$index\"\]/*\[@id=\"$dep_id\"\]/@shared] stringValue]
	    set shared_interfaces [split [[dom::selectNode $board_dom /board/global_mem\[@type="DDR3"\]/interface\[@id=\"$dep_id\"\]/@shared] stringValue] ","]

	    foreach interface $shared_interfaces {
		add_connection ddr3$id.$interface\_sharing_$dep_id ddr3$dep_id.$interface\_sharing_$dep_id conduit
		set_connection_parameter_value ddr3$id.$interface\_sharing_$dep_id/ddr3$dep_id.$interface\_sharing_$dep_id endPort {}
		set_connection_parameter_value ddr3$id.$interface\_sharing_$dep_id/ddr3$dep_id.$interface\_sharing_$dep_id endPortLSB {0}
		set_connection_parameter_value ddr3$id.$interface\_sharing_$dep_id/ddr3$dep_id.$interface\_sharing_$dep_id startPort {}
		set_connection_parameter_value ddr3$id.$interface\_sharing_$dep_id/ddr3$dep_id.$interface\_sharing_$dep_id startPortLSB {0}
		set_connection_parameter_value ddr3$id.$interface\_sharing_$dep_id/ddr3$dep_id.$interface\_sharing_$dep_id width {0}
	    }

	    if {"pll" in $shared_interfaces} {
		add_connection ddr3$id.memory_reset ddr3$dep_id.dma_reset reset
		add_connection ddr3$id.afi_clk ddr3$dep_id.dma_clk clock
		add_connection ddr3$id.afi_clk ddr3$dep_id.afi_clk clock
		add_connection ddr3$id.afi_reset ddr3$dep_id.afi_reset reset
		add_connection ddr3$id.afi_half_clk ddr3$dep_id.afi_half_clk clock
	    }
	}
    }
}
