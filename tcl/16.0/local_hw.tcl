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
package require -exact qsys 16.0
lappend auto_path $::env(TCLXML_PATH)
package require xml

# module properties
set_module_property NAME {local_system}
set_module_property DISPLAY_NAME {Tinker Local (RAM/ROM) Memory System}
set_module_property VERSION {16.0}
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
    set clock_ddr_ratio 2 

    set board_path [get_parameter_value BOARD_PATH]
    set board_file $board_path/board_specification.xml
    set board_fp [open $board_file]
    set board_dom [dom::parse [read $board_fp]]
    set bsp_version [[dom::selectNode $board_dom /board/@version] stringValue]
    set param_file $board_path/../[[dom::selectNode $board_dom /board/@file] stringValue]
    set param_fp [open $param_file]
    set param_dom [dom::parse [read $param_fp]]

    set result {}
    foreach node [dom::selectNode $board_dom {/board/global_mem[@type="LOCAL"]/*/@id}] {
	lappend result [$node stringValue]
    }

    set_parameter_property MEMORY_IDENTIFIER ALLOWED_RANGES $result
    set mem_id [get_parameter_value MEMORY_IDENTIFIER]

    set sysids {}
    foreach node [dom::selectNode $board_dom {/board/global_mem[@type="LOCAL"]/*/@index}] {
	lappend sysids [$node stringValue]
    }

    set_parameter_property SYSTEM_IDENTIFIER ALLOWED_RANGES $sysids
    set sys_id [get_parameter_value SYSTEM_IDENTIFIER]

    # Memory-system specific variables
    set mem_clock_freq [[dom::selectNode $board_dom /board/global_mem\[@index=\"$sys_id\"\]/@mem_frequency_mhz] stringValue]
    set ref_clock_freq [[dom::selectNode $board_dom /board/global_mem\[@index=\"$sys_id\"\]/@ref_frequency_mhz] stringValue]

    # Memory-specific parameters
    set addr_width [[dom::selectNode $board_dom /board/global_mem\[@index=\"$sys_id\"\]/interface\[@id=\"$mem_id\"\]/@address_width] stringValue]
    set mem_size [expr pow(2,$addr_width)]
    set max_burst [[dom::selectNode $board_dom /board/global_mem\[@index=\"$sys_id\"\]/interface\[@id=\"$mem_id\"\]/@maxburst] stringValue]
    set num_shared [llength [dom::selectNode $board_dom /board/global_mem\[@index=\"$sys_id\"\]/interface\[@primary=\"$mem_id\"\]/@id]]
    set role [[dom::selectNode $board_dom /board/global_mem\[@index=\"$sys_id\"\]/interface\[@id=\"$mem_id\"\]/@role] stringValue]
    
    set fabric_data_width [[dom::selectNode $board_dom /board/global_mem\[@index=\"$sys_id\"\]/interface\[@id=\"$mem_id\"\]/@width] stringValue]
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

    # Global Reset
    add_interface global_reset reset sink
    set_interface_property global_reset EXPORT_OF global_reset_bridge.in_reset

    if {($role == "primary") || ($role == "independent")} {
	add_interface ref_clk clock sink
	set_interface_property ref_clk EXPORT_OF ref_clk_bridge.in_clk

	# Export afi_clk to drive the DMA and other shared interfaces
	add_interface afi_clk clock source
	set_interface_property afi_clk EXPORT_OF afi_bridge.clk

	add_interface afi_reset reset source
	set_interface_property afi_reset EXPORT_OF afi_bridge.clk_reset

    } else {
	# Otherwise, provide inputs for the AFI clock
	add_interface afi_clk clock sink
	set_interface_property afi_clk EXPORT_OF afi_bridge.clk_in clock

	add_interface afi_reset reset sink
	set_interface_property afi_reset EXPORT_OF afi_bridge.clk_in_reset reset
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
    # stopped here
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
	add_instance ref_clk_bridge altera_clock_bridge $bsp_version
	# TODO: Set clock frequency
	set_instance_parameter_value ref_clk_bridge {EXPLICIT_CLOCK_RATE} {50000000.0}
	set_instance_parameter_value ref_clk_bridge {NUM_CLOCK_OUTPUTS} {1}
    }

    add_instance dma_clk clock_source $bsp_version
    set_instance_parameter_value dma_clk {clockFrequency} {50000000.0}
    set_instance_parameter_value dma_clk {clockFrequencyKnown} {1}
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
    set_instance_parameter_value reset_controller {NUM_RESET_INPUTS} {1}
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
    # Local Memory Instantiation
    # Variable $size is in Bytes
    add_instance local_mem altera_avalon_onchip_memory2 $bsp_version
    set_instance_parameter_value local_mem {allowInSystemMemoryContentEditor} {0}
    set_instance_parameter_value local_mem {blockType} {AUTO}
    set_instance_parameter_value local_mem {dataWidth} $fabric_data_width
    set_instance_parameter_value local_mem {dualPort} {0}
    set_instance_parameter_value local_mem {initMemContent} {0}
    set_instance_parameter_value local_mem {initializationFileName} {onchip_mem.hex}
    set_instance_parameter_value local_mem {instanceID} {NONE}
    set_instance_parameter_value local_mem {memorySize} $mem_size
    set_instance_parameter_value local_mem {readDuringWriteMode} {DONT_CARE}
    set_instance_parameter_value local_mem {simAllowMRAMContentsFile} {0}
    set_instance_parameter_value local_mem {simMemInitOnlyFilename} {0}
    set_instance_parameter_value local_mem {singleClockOperation} {1}
    set_instance_parameter_value local_mem {slave1Latency} {1}
    set_instance_parameter_value local_mem {slave2Latency} {1}
    set_instance_parameter_value local_mem {useNonDefaultInitFile} {0}
    set_instance_parameter_value local_mem {useShallowMemBlocks} {0}
    set_instance_parameter_value local_mem {writable} {1}
    set_instance_parameter_value local_mem {ecc_enabled} {0}
    set_instance_parameter_value local_mem {resetrequest_enabled} {1}

    # Instantiate a PLL if this is the first mem or this memory is non-shared
    if {($role == "primary") || ($role == "independent")} {
	add_instance local_pll altera_pll $bsp_version
	set_instance_parameter_value local_pll {debug_print_output} {1}
	set_instance_parameter_value local_pll {debug_use_rbc_taf_method} {0}
	set_instance_parameter_value local_pll {gui_device_speed_grade} {1}
	set_instance_parameter_value local_pll {gui_pll_mode} {Integer-N PLL}
	set_instance_parameter_value local_pll {gui_reference_clock_frequency} $ref_clock_freq
	set_instance_parameter_value local_pll {gui_channel_spacing} {0.0}
	set_instance_parameter_value local_pll {gui_operation_mode} {direct}
	set_instance_parameter_value local_pll {gui_feedback_clock} {Global Clock}
	set_instance_parameter_value local_pll {gui_fractional_cout} {32}
	set_instance_parameter_value local_pll {gui_dsm_out_sel} {1st_order}
	set_instance_parameter_value local_pll {gui_use_locked} {1}
	set_instance_parameter_value local_pll {gui_en_adv_params} {0}
	set_instance_parameter_value local_pll {gui_number_of_clocks} {1}
	set_instance_parameter_value local_pll {gui_multiply_factor} {1}
	set_instance_parameter_value local_pll {gui_frac_multiply_factor} {1.0}
	set_instance_parameter_value local_pll {gui_divide_factor_n} {1}
	set_instance_parameter_value local_pll {gui_cascade_counter0} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency0} $mem_clock_freq
	set_instance_parameter_value local_pll {gui_divide_factor_c0} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency0} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units0} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift0} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg0} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift0} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle0} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter1} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency1} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c1} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency1} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units1} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift1} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg1} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift1} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle1} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter2} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency2} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c2} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency2} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units2} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift2} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg2} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift2} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle2} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter3} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency3} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c3} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency3} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units3} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift3} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg3} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift3} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle3} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter4} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency4} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c4} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency4} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units4} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift4} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg4} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift4} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle4} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter5} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency5} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c5} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency5} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units5} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift5} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg5} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift5} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle5} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter6} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency6} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c6} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency6} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units6} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift6} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg6} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift6} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle6} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter7} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency7} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c7} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency7} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units7} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift7} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg7} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift7} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle7} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter8} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency8} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c8} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency8} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units8} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift8} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg8} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift8} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle8} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter9} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency9} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c9} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency9} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units9} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift9} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg9} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift9} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle9} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter10} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency10} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c10} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency10} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units10} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift10} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg10} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift10} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle10} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter11} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency11} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c11} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency11} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units11} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift11} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg11} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift11} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle11} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter12} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency12} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c12} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency12} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units12} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift12} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg12} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift12} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle12} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter13} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency13} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c13} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency13} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units13} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift13} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg13} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift13} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle13} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter14} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency14} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c14} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency14} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units14} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift14} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg14} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift14} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle14} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter15} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency15} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c15} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency15} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units15} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift15} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg15} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift15} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle15} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter16} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency16} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c16} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency16} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units16} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift16} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg16} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift16} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle16} {50}
	set_instance_parameter_value local_pll {gui_cascade_counter17} {0}
	set_instance_parameter_value local_pll {gui_output_clock_frequency17} {100.0}
	set_instance_parameter_value local_pll {gui_divide_factor_c17} {1}
	set_instance_parameter_value local_pll {gui_actual_output_clock_frequency17} {0 MHz}
	set_instance_parameter_value local_pll {gui_ps_units17} {ps}
	set_instance_parameter_value local_pll {gui_phase_shift17} {0}
	set_instance_parameter_value local_pll {gui_phase_shift_deg17} {0.0}
	set_instance_parameter_value local_pll {gui_actual_phase_shift17} {0}
	set_instance_parameter_value local_pll {gui_duty_cycle17} {50}
	set_instance_parameter_value local_pll {gui_pll_auto_reset} {Off}
	set_instance_parameter_value local_pll {gui_pll_bandwidth_preset} {Auto}
	set_instance_parameter_value local_pll {gui_en_reconf} {0}
	set_instance_parameter_value local_pll {gui_en_dps_ports} {0}
	set_instance_parameter_value local_pll {gui_en_phout_ports} {0}
	set_instance_parameter_value local_pll {gui_phout_division} {1}
	set_instance_parameter_value local_pll {gui_en_lvds_ports} {0}
	set_instance_parameter_value local_pll {gui_mif_generate} {0}
	set_instance_parameter_value local_pll {gui_enable_mif_dps} {0}
	set_instance_parameter_value local_pll {gui_dps_cntr} {C0}
	set_instance_parameter_value local_pll {gui_dps_num} {1}
	set_instance_parameter_value local_pll {gui_dps_dir} {Positive}
	set_instance_parameter_value local_pll {gui_refclk_switch} {0}
	set_instance_parameter_value local_pll {gui_refclk1_frequency} $ref_clock_freq
	set_instance_parameter_value local_pll {gui_switchover_mode} {Automatic Switchover}
	set_instance_parameter_value local_pll {gui_switchover_delay} {0}
	set_instance_parameter_value local_pll {gui_active_clk} {0}
	set_instance_parameter_value local_pll {gui_clk_bad} {0}
	set_instance_parameter_value local_pll {gui_enable_cascade_out} {0}
	set_instance_parameter_value local_pll {gui_cascade_outclk_index} {0}
	set_instance_parameter_value local_pll {gui_enable_cascade_in} {0}
	set_instance_parameter_value local_pll {gui_pll_cascading_mode} {Create an adjpllin signal to connect with an upstream PLL}
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

    # If we are the first memory, we defin the DMA clock domain
    if {$role == "primary"} {
	add_connection local_pll.outclk0 dma_clk.clk_in clock
	add_connection global_reset_bridge.out_reset local_pll.reset reset
	add_connection reset_controller.reset_out dma_clk.clk_in_reset reset
    } elseif {$role == "independent"} {
	add_connection global_reset_bridge.out_reset local_pll.reset reset
    } else {
	# Else, these connections are exported above
    }

    # PS Local Passthrough to Local Memory
    add_connection pipe_stage_interface.m0 local_mem.s1 avalon
    set_connection_parameter_value pipe_stage_interface.m0/local_mem.s1 arbitrationPriority {1}
    set_connection_parameter_value pipe_stage_interface.m0/local_mem.s1 baseAddress {0x0000}
    set_connection_parameter_value pipe_stage_interface.m0/local_mem.s1 defaultConnection {0}

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
	add_connection local_pll.outclk0 clock_cross_dma.m0_clk clock

	add_connection reset_controller.reset_out clock_cross_dma.m0_reset reset
    }

    if {($role == "primary") || ($role == "independent")} {
        add_connection local_pll.outclk0 reset_controller.clk clock
	add_connection local_pll.outclk0 memory_reset_bridge.clk clock

	#add_connection local_pll.locked reset_controller.reset_in1 reset

	add_connection local_pll.outclk0 afi_bridge.clk_in clock
	add_connection reset_controller.reset_out afi_bridge.clk_in_reset reset

        add_connection local_pll.outclk0 clock_cross_kernel.m0_clk clock

	add_connection ref_clk_bridge.out_clk local_pll.refclk clock
        #add_connection local_pll.outclk0 sw_kernel_reset_bridge.clk clock

	add_connection local_pll.outclk0 pipe_stage_arb.clk clock
        add_connection local_pll.outclk0 pipe_stage_interface.clk clock

	add_connection local_pll.outclk0 local_mem.clk1 clock
	add_connection reset_controller.reset_out local_mem.reset1 reset

    } else {
	add_connection afi_bridge.clk reset_controller.clk clock
	add_connection afi_bridge.clk memory_reset_bridge.clk clock

	#add_connection afi_bridge.reset reset_controller.reset_in1 reset

	# Exported...
	# add_connection local_pll.outclk0 afi_bridge.clk_in clock
	# add_connection local_pll.locked afi_bridge.clk_in_reset reset

	add_connection afi_bridge.clk clock_cross_kernel.m0_clk clock

	# Not needed..
	# add_connection ref_clk_bridge.out_clk local_pll.refclk clock
        # add_connection afi_bridge.clk sw_kernel_reset_bridge.clk clock

	add_connection afi_bridge.clk pipe_stage_arb.clk clock
	add_connection afi_bridge.clk pipe_stage_interface.clk clock	

	add_connection afi_bridge.clk local_mem.clk1 clock
	add_connection reset_controller.reset_out local_mem.reset1 reset
    }

    add_connection reset_controller.reset_out pipe_stage_arb.reset reset
    add_connection reset_controller.reset_out pipe_stage_interface.reset reset

    add_connection sw_kernel_reset_bridge.out_reset clock_cross_kernel.m0_reset reset

    # interconnect requirements
    set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
    set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {1}
}

