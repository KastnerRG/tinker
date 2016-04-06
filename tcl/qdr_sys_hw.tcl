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
package require -exact qsys 14.1
lappend auto_path $::env(TCLXML_PATH)
package require xml

set_module_property NAME {qdr_system}
set_module_property DISPLAY_NAME {Tinker QDR Memory System}
set_module_property VERSION {14.1}
set_module_property GROUP {Tinker}
set_module_property DESCRIPTION {default description}
set_module_property AUTHOR {Dustin Richmond, Matthew Hogains, Kevin Thai, Jeremy Blackstone}
set_module_property COMPOSITION_CALLBACK compose
set_module_property opaque_address_map false

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

add_parameter MEMORY_SYS_ID String 1 "Global Memory System ID Number"
set_parameter_property MEMORY_SYS_ID DEFAULT_VALUE 1
set_parameter_property MEMORY_SYS_ID DISPLAY_NAME MEMORY_SYS_ID
set_parameter_property MEMORY_SYS_ID TYPE String
set_parameter_property MEMORY_SYS_ID UNITS None
set_parameter_property MEMORY_SYS_ID DESCRIPTION "Global Memory System ID Number"
set_parameter_property MEMORY_SYS_ID HDL_PARAMETER true
set_parameter_property MEMORY_SYS_ID ALLOWED_RANGES {0 1 2 3 4 5 6 7 8}

proc compose { } {
    set symbol_width 8
    set board_path [get_parameter_value BOARD_PATH]
    set board_file $board_path/board_specification.xml
    set board_fp [open $board_file]
    set board_dom [dom::parse [read $board_fp]]

    set sys_id [get_parameter_value MEMORY_SYS_ID]
    set primary_id [[dom::selectNode $board_dom /board/global_mem\[@type="QDRII"\]\[@sys_id=\"$sys_id\"\]/interface\[@role="primary"\]/@id] stringValue]
    set sys_role [[dom::selectNode $board_dom /board/global_mem\[@type="QDRII"\]\[@sys_id=\"$sys_id\"\]/@role] stringValue]
    set data_width [[dom::selectNode $board_dom /board/global_mem\[@type="QDRII"\]\[@sys_id=\"$sys_id\"\]/@width] stringValue]
    set address_width [[dom::selectNode $board_dom /board/global_mem\[@type="QDRII"\]\[@sys_id=\"$sys_id\"\]/@addr_width] stringValue]
    set sys_burst [[dom::selectNode $board_dom /board/global_mem\[@type="QDRII"\]\[@sys_id=\"$sys_id\"\]/@maxburst] stringValue]

    set memory_ids {}
    foreach node [dom::selectNode $board_dom /board/global_mem\[@type="QDRII"\]\[@sys_id=\"$sys_id\"\]/*/@id] {
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
    add_interface snoop avalon_streaming source
    set_interface_property snoop EXPORT_OF acl_memory_bank_divider.acl_bsp_snoop

    if {$num_memories > 1} {
	add_interface memorg conduit end
	set_interface_property memorg EXPORT_OF acl_memory_bank_divider.acl_bsp_memorg_host
    }

    # System DMA clock, reset, and data interfaces
    if {$sys_role == "secondary"} {
	add_interface dma_rw avalon slave
	set_interface_property dma_rw EXPORT_OF dma_clock_crossing_bridge.s0

	add_interface dma_clk clock sink
	set_interface_property dma_clk EXPORT_OF dma_clock_crossing_bridge.s0_clk

	add_interface dma_reset reset sink
	set_interface_property dma_reset EXPORT_OF dma_clock_crossing_bridge.s0_reset
    } else {
	add_interface dma_rw avalon slave
	set_interface_property dma_rw EXPORT_OF dma_pipe_stage.s0
    }

    # Memory Kernel, Pin, and clock interfaces
    foreach mem_id $memory_ids {
	set mem_id_role [[dom::selectNode $board_dom /board/global_mem\[@type="QDRII"\]\[@sys_id=\"$sys_id\"\]/interface\[@id=\"$mem_id\"\]/@role] stringValue]

	# Kernel read/write interfaces
	add_interface kernel_$sys_id\_if_$mem_id\_r avalon slave
	set_interface_property kernel_$sys_id\_if_$mem_id\_r EXPORT_OF if_$mem_id.kernel_r
	
	add_interface kernel_$sys_id\_if_$mem_id\_w avalon slave
	set_interface_property kernel_$sys_id\_if_$mem_id\_w EXPORT_OF if_$mem_id.kernel_w

	# QDR Memory Interface
	add_interface if_$mem_id conduit end
	set_interface_property if_$mem_id EXPORT_OF if_$mem_id.qdr_pins

	# QDR Status
	add_interface if_$mem_id\_status conduit end
	set_interface_property if_$mem_id\_status EXPORT_OF if_$mem_id.status

	if {$mem_id_role == "primary"} {
	    add_interface qdrii_$mem_id\_pll_ref clock sink
	    set_interface_property if_$mem_id\_pll_ref EXPORT_OF if_$mem_id\.ref_clk

	    add_interface qdrii_$mem_id\_oct conduit end
	    set_interface_property if_$mem_id\_oct EXPORT_OF if_$mem_id\.oct
	}

	if {$mem_id_role == "independent"} {
	    set shared_interfaces [split [[dom::selectNode $board_dom /board/global_mem\[@type="QDRII"\]/interface\[@id=\"$mem_id\"\]/@shared] stringValue] ","]
	    
	    if {!("pll" in $shared_interfaces)} {
		add_interface if_$mem_id\_pll_ref clock sink
		set_interface_property if_$mem_id\_pll_ref EXPORT_OF if_$mem_id\.ref_clk
	    } 

	    if {!("oct" in $shared_interfaces)} {
		add_interface if_$mem_id\_oct conduit end
		set_interface_property if_$mem_id\_oct EXPORT_OF if_$mem_id\.oct
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

    add_instance acl_memory_bank_divider acl_memory_bank_divider 1.0
    set_instance_parameter_value acl_memory_bank_divider {NUM_BANKS} $num_memories
    set_instance_parameter_value acl_memory_bank_divider {SEPARATE_RW_PORTS} {1}
    set_instance_parameter_value acl_memory_bank_divider {PIPELINE_OUTPUTS} {0}
    set_instance_parameter_value acl_memory_bank_divider {DATA_WIDTH} $data_width
    set_instance_parameter_value acl_memory_bank_divider {ADDRESS_WIDTH} $address_width
    set_instance_parameter_value acl_memory_bank_divider {BURST_SIZE} $sys_burst
    set_instance_parameter_value acl_memory_bank_divider {MAX_PENDING_READS} {64}

    if {$sys_role == "secondary"} {
	add_instance dma_clock_crossing_bridge altera_avalon_mm_clock_crossing_bridge 14.1
	set_instance_parameter_value dma_clock_crossing_bridge {DATA_WIDTH} $data_width
	set_instance_parameter_value dma_clock_crossing_bridge {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value dma_clock_crossing_bridge {ADDRESS_WIDTH} $address_width
	set_instance_parameter_value dma_clock_crossing_bridge {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value dma_clock_crossing_bridge {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value dma_clock_crossing_bridge {MAX_BURST_SIZE} $sys_burst
	set_instance_parameter_value dma_clock_crossing_bridge {COMMAND_FIFO_DEPTH} {128}
	set_instance_parameter_value dma_clock_crossing_bridge {RESPONSE_FIFO_DEPTH} {128}
	set_instance_parameter_value dma_clock_crossing_bridge {MASTER_SYNC_DEPTH} {2}
	set_instance_parameter_value dma_clock_crossing_bridge {SLAVE_SYNC_DEPTH} {2}
    } else {
	add_instance dma_pipe_stage altera_avalon_mm_bridge 14.1
	set_instance_parameter_value dma_pipe_stage {DATA_WIDTH} $data_width
	set_instance_parameter_value dma_pipe_stage {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value dma_pipe_stage {ADDRESS_WIDTH} $address_width
	set_instance_parameter_value dma_pipe_stage {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value dma_pipe_stage {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value dma_pipe_stage {MAX_BURST_SIZE} $sys_burst
	set_instance_parameter_value dma_pipe_stage {MAX_PENDING_RESPONSES} {32}
	set_instance_parameter_value dma_pipe_stage {LINEWRAPBURSTS} {0}
	set_instance_parameter_value dma_pipe_stage {PIPELINE_COMMAND} {1}
	set_instance_parameter_value dma_pipe_stage {PIPELINE_RESPONSE} {1}
    }

    foreach id $memory_ids {
	add_instance if_$mem_id qdr1 1.0
	set_instance_parameter_value if_$mem_id {BOARD_PATH} $board_path
	set_instance_parameter_value if_$mem_id {MEMORY_IDENTIFIER} $mem_id
	set_instance_parameter_value if_$mem_id {SYSTEM_IDENTIFIER} $sys_id
    }

    ############################################################################
    # connections and connection parameters
    ############################################################################
    add_connection kernel_clk_bridge.clk acl_memory_bank_divider.kernel_clk clock
    add_connection kernel_clk_bridge.clk_reset acl_memory_bank_divider.kernel_reset reset

    add_connection if_$primary_id.afi_clk acl_memory_bank_divider.clk clock
    add_connection if_$primary_id.afi_reset acl_memory_bank_divider.reset reset

    add_connection if_$primary_id.afi_clk system_clk_bridge.clk_in clock
    add_connection if_$primary_id.afi_reset system_clk_bridge.clk_in_reset reset

    if {$sys_role == "secondary"} {
	add_connection if_$primary_id.afi_clk dma_clock_crossing_bridge.m0_clk clock
	add_connection if_$primary_id.memory_reset dma_clock_crossing_bridge.m0_reset reset
	add_connection dma_clock_crossing_bridge.m0 acl_memory_bank_divider.s avalon
	set_connection_parameter_value dma_clock_crossing_bridge.m0/acl_memory_bank_divider.s arbitrationPriority {1}
	set_connection_parameter_value dma_clock_crossing_bridge.m0/acl_memory_bank_divider.s baseAddress {0x0000}
	set_connection_parameter_value dma_clock_crossing_bridge.m0/acl_memory_bank_divider.s defaultConnection {0}
    } else {
	add_connection if_$primary_id.afi_clk dma_pipe_stage.clk clock
	add_connection if_$primary_id.memory_reset dma_pipe_stage.reset reset

	add_connection dma_pipe_stage.m0 acl_memory_bank_divider.s avalon
	set_connection_parameter_value dma_pipe_stage.m0/acl_memory_bank_divider.s arbitrationPriority {1}
	set_connection_parameter_value dma_pipe_stage.m0/acl_memory_bank_divider.s baseAddress {0x0000}
	set_connection_parameter_value dma_pipe_stage.m0/acl_memory_bank_divider.s defaultConnection {0}
    }

    set i 0
    foreach id $memory_ids {
	set i [expr {$i + 1}]

	add_connection kernel_clk_bridge.clk if_$mem_id.kernel_clk clock
	add_connection kernel_clk_bridge.clk_reset if_$mem_id.kernel_reset reset
	add_connection sw_kernel_reset_bridge.out_reset if_$mem_id.sw_kernel_reset reset
	add_connection global_reset_bridge.out_reset if_$mem_id.global_reset

	add_connection acl_memory_bank_divider.bank$i\_r if_$mem_id.dma_r avalon
	set_connection_parameter_value acl_memory_bank_divider.bank$i\_r/if_$mem_id.dma_r arbitrationPriority {1}
	set_connection_parameter_value acl_memory_bank_divider.bank$i\_r/if_$mem_id.dma_r baseAddress {0x0000}
	set_connection_parameter_value acl_memory_bank_divider.bank$i\_r/if_$mem_id.dma_r defaultConnection {0}

	add_connection acl_memory_bank_divider.bank$i\_w if_$mem_id.dma_w avalon
	set_connection_parameter_value acl_memory_bank_divider.bank$i\_w/if_$mem_id.dma_w arbitrationPriority {1}
	set_connection_parameter_value acl_memory_bank_divider.bank$i\_w/if_$mem_id.dma_w baseAddress {0x0000}
	set_connection_parameter_value acl_memory_bank_divider.bank$i\_w/if_$mem_id.dma_w defaultConnection {0}

	set board_file $board_path/board_specification.xml
	set board_fp [open $board_file]
	set board_dom [dom::parse [read $board_fp]]

	foreach dep [dom::selectNode $board_dom /board/global_mem\[@type="QDRII"\]\[@sys_id=\"$sys_id\"\]/*\[@primary=\"$mem_id\"\]/@id] {
	    set dep_id [$dep stringValue]
	    set shared_node [[dom::selectNode $board_dom /board/global_mem\[@type="QDRII"\]\[@sys_id=\"$sys_id\"\]/*\[@id=\"$dep_id\"\]/@shared] stringValue]
	    set shared_interfaces [split [[dom::selectNode $board_dom /board/global_mem\[@type="QDRII"\]/interface\[@id=\"$dep_id\"\]/@shared] stringValue] ","]

	    foreach interface $shared_interfaces {
		add_connection if_$mem_id.$interface\_sharing_$dep_id if_$dep_id.$interface\_sharing_$dep_id conduit
		set_connection_parameter_value if_$mem_id.$interface\_sharing_$dep_id/if_$dep_id.$interface\_sharing_$dep_id endPort {}
		set_connection_parameter_value if_$mem_id.$interface\_sharing_$dep_id/if_$dep_id.$interface\_sharing_$dep_id endPortLSB {0}
		set_connection_parameter_value if_$mem_id.$interface\_sharing_$dep_id/if_$dep_id.$interface\_sharing_$dep_id startPort {}
		set_connection_parameter_value if_$mem_id.$interface\_sharing_$dep_id/if_$dep_id.$interface\_sharing_$dep_id startPortLSB {0}
		set_connection_parameter_value if_$mem_id.$interface\_sharing_$dep_id/if_$dep_id.$interface\_sharing_$dep_id width {0}
	    }

	    if {"pll" in $shared_interfaces} {
		add_connection if_$mem_id.afi_clk if_$dep_id.afi_clk clock
		add_connection if_$mem_id.afi_reset if_$dep_id.afi_reset reset
		add_connection if_$mem_id.afi_half_clk if_$dep_id.afi_half_clk clock
	    }
	    # TODO: This is not right, it should be checking for independent and secondary, but w/e (for now)
	    add_connection if_$mem_id.memory_reset if_$dep_id.dma_reset reset
	    add_connection if_$mem_id.afi_clk if_$dep_id.dma_clk clock
	}
    }
}
