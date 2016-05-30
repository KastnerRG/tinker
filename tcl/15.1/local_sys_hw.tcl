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

set_module_property NAME {local_interface}
set_module_property DISPLAY_NAME {Tinker Local (RAM/ROM) Hardware Interface}
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

    set bsp_version [[dom::selectNode $board_dom /board/@version] stringValue]
    set index [get_parameter_value MEMORY_INDEX]
    set primary_id [[dom::selectNode $board_dom /board/global_mem\[@type="LOCAL"\]\[@index=\"$index\"\]/interface\[@role="primary"\]/@id] stringValue]
    set sys_role [[dom::selectNode $board_dom /board/global_mem\[@type="LOCAL"\]\[@index=\"$index\"\]/@role] stringValue]
    set data_width [[dom::selectNode $board_dom /board/global_mem\[@type="LOCAL"\]\[@index=\"$index\"\]/@width] stringValue]
    set address_width [[dom::selectNode $board_dom /board/global_mem\[@type="LOCAL"\]\[@index=\"$index\"\]/@addr_width] stringValue]
    set sys_burst [[dom::selectNode $board_dom /board/global_mem\[@type="LOCAL"\]\[@index=\"$index\"\]/@maxburst] stringValue]

    set memory_ids {}
    foreach node [dom::selectNode $board_dom /board/global_mem\[@type="LOCAL"\]\[@index=\"$index\"\]/*/@id] {
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
	add_interface dma_local$index\_rw avalon slave
	set_interface_property dma_local$index\_rw EXPORT_OF dma_local$index\_clock_crossing_bridge.s0

	add_interface dma_local$index\_clk clock sink
	set_interface_property dma_local$index\_clk EXPORT_OF dma_local$index\_clock_crossing_bridge.s0_clk

	add_interface dma_local$index\_reset reset sink
	set_interface_property dma_local$index\_reset EXPORT_OF dma_local$index\_clock_crossing_bridge.s0_reset
    } else {
	add_interface dma_local$index\_rw avalon slave
	set_interface_property dma_local$index\_rw EXPORT_OF dma_local$index\_pipe_stage.s0
    }

    # Memory Kernel, Pin, and clock interfaces
    foreach id $memory_ids {
	set id_role [[dom::selectNode $board_dom /board/global_mem\[@type="LOCAL"\]\[@index=\"$index\"\]/interface\[@id=\"$id\"\]/@role] stringValue]

	# Kernel read/write interface
	add_interface kernel_$index\_local$id\_rw avalon slave
	set_interface_property kernel_$index\_local$id\_rw EXPORT_OF local$id.kernel_rw
	
	if {$id_role == "primary" || $id_role == "independent"} {
	    add_interface local$id\_pll_ref clock sink
	    set_interface_property local$id\_pll_ref EXPORT_OF local$id\.ref_clk
	}
    }

    ############################################################################
    # Instances and instance parameters
    # (disabled instances are intentionally culled)
    ############################################################################

    add_instance kernel_clk_bridge clock_source $bsp_version
    set_instance_parameter_value kernel_clk_bridge {clockFrequency} {50000000.0}
    set_instance_parameter_value kernel_clk_bridge {clockFrequencyKnown} {0}
    set_instance_parameter_value kernel_clk_bridge {resetSynchronousEdges} {DEASSERT}

    add_instance system_clk_bridge clock_source $bsp_version
    set_instance_parameter_value system_clk_bridge {clockFrequency} {50000000.0}
    set_instance_parameter_value system_clk_bridge {clockFrequencyKnown} {0}
    set_instance_parameter_value system_clk_bridge {resetSynchronousEdges} {DEASSERT}

    add_instance sw_kernel_reset_bridge altera_reset_bridge $bsp_version
    set_instance_parameter_value sw_kernel_reset_bridge {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value sw_kernel_reset_bridge {SYNCHRONOUS_EDGES} {none}
    set_instance_parameter_value sw_kernel_reset_bridge {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value sw_kernel_reset_bridge {USE_RESET_REQUEST} {0}

    add_instance global_reset_bridge altera_reset_bridge $bsp_version
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
	add_instance dma_local$index\_clock_crossing_bridge altera_avalon_mm_clock_crossing_bridge $bsp_version
	set_instance_parameter_value dma_local$index\_clock_crossing_bridge {DATA_WIDTH} $data_width
	set_instance_parameter_value dma_local$index\_clock_crossing_bridge {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value dma_local$index\_clock_crossing_bridge {ADDRESS_WIDTH} $address_width
	set_instance_parameter_value dma_local$index\_clock_crossing_bridge {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value dma_local$index\_clock_crossing_bridge {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value dma_local$index\_clock_crossing_bridge {MAX_BURST_SIZE} $sys_burst
	set_instance_parameter_value dma_local$index\_clock_crossing_bridge {COMMAND_FIFO_DEPTH} {128}
	set_instance_parameter_value dma_local$index\_clock_crossing_bridge {RESPONSE_FIFO_DEPTH} {128}
	set_instance_parameter_value dma_local$index\_clock_crossing_bridge {MASTER_SYNC_DEPTH} {2}
	set_instance_parameter_value dma_local$index\_clock_crossing_bridge {SLAVE_SYNC_DEPTH} {2}
    } else {
	add_instance dma_local$index\_pipe_stage altera_avalon_mm_bridge $bsp_version
	set_instance_parameter_value dma_local$index\_pipe_stage {DATA_WIDTH} $data_width
	set_instance_parameter_value dma_local$index\_pipe_stage {SYMBOL_WIDTH} $symbol_width
	set_instance_parameter_value dma_local$index\_pipe_stage {ADDRESS_WIDTH} $address_width
	set_instance_parameter_value dma_local$index\_pipe_stage {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value dma_local$index\_pipe_stage {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value dma_local$index\_pipe_stage {MAX_BURST_SIZE} $sys_burst
	set_instance_parameter_value dma_local$index\_pipe_stage {MAX_PENDING_RESPONSES} {32}
	set_instance_parameter_value dma_local$index\_pipe_stage {LINEWRAPBURSTS} {0}
	set_instance_parameter_value dma_local$index\_pipe_stage {PIPELINE_COMMAND} {1}
	set_instance_parameter_value dma_local$index\_pipe_stage {PIPELINE_RESPONSE} {1}
    }

    foreach id $memory_ids {
	add_instance local$id local_mem 15.1
	set_instance_parameter_value local$id {BOARD_PATH} $board_path
	set_instance_parameter_value local$id {MEMORY_IDENTIFIER} $id
	set_instance_parameter_value local$id {SYSTEM_IDENTIFIER} $index
    }

    ############################################################################
    # connections and connection parameters
    ############################################################################
    add_connection kernel_clk_bridge.clk acl_memory_bank_divider_$index.kernel_clk clock
    add_connection kernel_clk_bridge.clk_reset acl_memory_bank_divider_$index.kernel_reset reset

    add_connection local$primary_id.afi_clk acl_memory_bank_divider_$index.clk clock
    add_connection local$primary_id.afi_reset acl_memory_bank_divider_$index.reset reset

    add_connection local$primary_id.afi_clk system_clk_bridge.clk_in clock
    add_connection local$primary_id.afi_reset system_clk_bridge.clk_in_reset reset

    if {$sys_role == "secondary"} {
	add_connection local$primary_id.afi_clk dma_local$index\_clock_crossing_bridge.m0_clk clock
	add_connection local$primary_id.memory_reset dma_local$index\_clock_crossing_bridge.m0_reset reset

	add_connection dma_local$index\_clock_crossing_bridge.m0 acl_memory_bank_divider_$index.s avalon
	set_connection_parameter_value dma_local$index\_clock_crossing_bridge.m0/acl_memory_bank_divider_$index.s arbitrationPriority {1}
	set_connection_parameter_value dma_local$index\_clock_crossing_bridge.m0/acl_memory_bank_divider_$index.s baseAddress {0x0000}
	set_connection_parameter_value dma_local$index\_clock_crossing_bridge.m0/acl_memory_bank_divider_$index.s defaultConnection {0}
    } else {
	add_connection local$primary_id.afi_clk dma_local$index\_pipe_stage.clk clock
	add_connection local$primary_id.memory_reset dma_local$index\_pipe_stage.reset reset

	add_connection dma_local$index\_pipe_stage.m0 acl_memory_bank_divider_$index.s avalon
	set_connection_parameter_value dma_local$index\_pipe_stage.m0/acl_memory_bank_divider_$index.s arbitrationPriority {1}
	set_connection_parameter_value dma_local$index\_pipe_stage.m0/acl_memory_bank_divider_$index.s baseAddress {0x0000}
	set_connection_parameter_value dma_local$index\_pipe_stage.m0/acl_memory_bank_divider_$index.s defaultConnection {0}
    }

    set i 0
    foreach id $memory_ids {
	set i [expr {$i + 1}]

	add_connection kernel_clk_bridge.clk local$id.kernel_clk clock
	add_connection kernel_clk_bridge.clk_reset local$id.kernel_reset reset
	add_connection sw_kernel_reset_bridge.out_reset local$id.sw_kernel_reset reset
	add_connection global_reset_bridge.out_reset local$id.global_reset

	add_connection acl_memory_bank_divider_$index.bank$i local$id.dma_rw avalon
	set_connection_parameter_value acl_memory_bank_divider_$index.bank$i/local$id.dma_rw arbitrationPriority {1}
	set_connection_parameter_value acl_memory_bank_divider_$index.bank$i/local$id.dma_rw baseAddress {0x0000}
	set_connection_parameter_value acl_memory_bank_divider_$index.bank$i/local$id.dma_rw defaultConnection {0}

	set board_file $board_path/board_specification.xml
	set board_fp [open $board_file]
	set board_dom [dom::parse [read $board_fp]]

	foreach dep [dom::selectNode $board_dom /board/global_mem\[@type="LOCAL"\]\[@index=\"$index\"\]/*\[@primary=\"$id\"\]/@id] {
	    set dep_id [$dep stringValue]

	    add_connection local$id.memory_reset local$dep_id.dma_reset reset
	    add_connection local$id.afi_clk local$dep_id.dma_clk clock
	    add_connection local$id.afi_clk local$dep_id.afi_clk clock
	    add_connection local$id.afi_reset local$dep_id.afi_reset reset
	}

	set id_role [[dom::selectNode $board_dom /board/global_mem\[@type="LOCAL"\]\[@index=\"$index\"\]/interface\[@id=\"$id\"\]/@role] stringValue]
	if {$id_role == "independent"} {
	    add_connection local$primary_id.afi_clk local$id.dma_clk clock
	    add_connection local$primary_id.memory_reset local$id.dma_reset reset
	}
    }
}
