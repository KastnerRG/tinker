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

# module properties
set_module_property NAME {tinker_kernel_clk}
set_module_property DISPLAY_NAME {Tinker Altera OpenCL Kernel Clock}

# default module properties
set_module_property VERSION {15.1}
set_module_property GROUP {Tinker}
set_module_property DESCRIPTION {Default}
set_module_property AUTHOR {Dustin Richmond}

set_module_property COMPOSITION_CALLBACK compose
set_module_property opaque_address_map false

add_parameter REF_CLK_RATE String "Reference Clock Rate"
set_parameter_property REF_CLK_RATE DEFAULT_VALUE 0
set_parameter_property REF_CLK_RATE DISPLAY_NAME Reference Clock Rate
set_parameter_property REF_CLK_RATE TYPE STRING
set_parameter_property REF_CLK_RATE UNITS Megahertz
set_parameter_property REF_CLK_RATE DESCRIPTION "This is the frequency of the PLL reference clock in Megahertz.  You can attain this value from your board manual."
set_parameter_property REF_CLK_RATE HDL_PARAMETER true

add_parameter TARGET_CLK_RATE String "Target Kernel Clock Rate"
set_parameter_property TARGET_CLK_RATE DEFAULT_VALUE 0
set_parameter_property TARGET_CLK_RATE DISPLAY_NAME Target Kernel Clock Rate
set_parameter_property TARGET_CLK_RATE TYPE STRING
set_parameter_property TARGET_CLK_RATE UNITS Megahertz
set_parameter_property TARGET_CLK_RATE DESCRIPTION "This is the default constraint applied to the OpenCL kernel in Megahertz.  Set this value such that even the most trivial kernel will be overconstrained during Quartus compilation."
set_parameter_property TARGET_CLK_RATE HDL_PARAMETER true

add_parameter QUARTUS_VERSION String "Altera OpenCL / Quartus Version"
set_parameter_property QUARTUS_VERSION DEFAULT_VALUE "15.1"
set_parameter_property QUARTUS_VERSION DISPLAY_NAME Quartus Version
set_parameter_property QUARTUS_VERSION TYPE STRING
set_parameter_property QUARTUS_VERSION UNITS None
set_parameter_property QUARTUS_VERSION DESCRIPTION "Version used in the Altera OpenCL Compiler for this board"
set_parameter_property QUARTUS_VERSION HDL_PARAMETER true

proc compose { } {
    set ref_clk_rate [get_parameter_value REF_CLK_RATE]
    set target_clk_rate [get_parameter_value TARGET_CLK_RATE]
    set bsp_version [get_parameter_value QUARTUS_VERSION]
    ############################################################################
    # Exported Interfaces (Ports)
    ############################################################################
    add_interface pll_refclk clock sink
    set_interface_property pll_refclk EXPORT_OF kernel_pll_refclk.in_clk

    add_interface kernel_clk clock source
    set_interface_property kernel_clk EXPORT_OF kernel_clk.clk

    add_interface kernel_clk2x clock source
    set_interface_property kernel_clk2x EXPORT_OF global_routing_kernel_clk2x.global_clk

    add_interface config_clk clock sink
    set_interface_property config_clk EXPORT_OF clk.clk_in

    add_interface reset reset sink
    set_interface_property reset EXPORT_OF clk.clk_in_reset

    add_interface ctrl avalon slave
    set_interface_property ctrl EXPORT_OF ctrl.s0

    add_interface kernel_pll_locked conduit end
    set_interface_property kernel_pll_locked EXPORT_OF pll_lock_avs_0.lock_export

    # Instances and instance parameters
    # (disabled instances are intentionally culled)

    add_instance global_routing_kernel_clk global_routing_clk 10.0

    add_instance global_routing_kernel_clk2x global_routing_clk 10.0

    add_instance counter acl_timer 10.0
    set_instance_parameter_value counter {WIDTH} {32}

    add_instance pll_lock_avs_0 pll_lock_avs 10.0
    set_instance_parameter_value pll_lock_avs_0 {WIDTH} {32}

    add_instance version_id version_id 10.0
    set_instance_parameter_value version_id {WIDTH} {32}
    set_instance_parameter_value version_id {VERSION_ID} {-1598029822}

    add_instance pll_sw_reset sw_reset 10.0
    set_instance_parameter_value pll_sw_reset {WIDTH} {32}
    set_instance_parameter_value pll_sw_reset {LOG2_RESET_CYCLES} {10}

    add_instance kernel_pll_refclk altera_clock_bridge $bsp_version
    set_instance_parameter_value kernel_pll_refclk {EXPLICIT_CLOCK_RATE} {0.0}
    set_instance_parameter_value kernel_pll_refclk {NUM_CLOCK_OUTPUTS} {1}

    add_instance clk clock_source $bsp_version
    set_instance_parameter_value clk {clockFrequency} {50000000.0}
    set_instance_parameter_value clk {clockFrequencyKnown} {1}
    set_instance_parameter_value clk {resetSynchronousEdges} {DEASSERT}

    add_instance pll_reconfig_0 altera_pll_reconfig $bsp_version
    set_instance_parameter_value pll_reconfig_0 {ENABLE_MIF} {0}
    set_instance_parameter_value pll_reconfig_0 {MIF_FILE_NAME} {}
    set_instance_parameter_value pll_reconfig_0 {ENABLE_BYTEENABLE} {0}

    add_instance kernel_clk clock_source $bsp_version
    set_instance_parameter_value kernel_clk {clockFrequency} {100000000.0}
    set_instance_parameter_value kernel_clk {clockFrequencyKnown} {0}
    set_instance_parameter_value kernel_clk {resetSynchronousEdges} {NONE}

    add_instance ctrl altera_avalon_mm_bridge $bsp_version
    set_instance_parameter_value ctrl {DATA_WIDTH} {32}
    set_instance_parameter_value ctrl {SYMBOL_WIDTH} {8}
    set_instance_parameter_value ctrl {ADDRESS_WIDTH} {11}
    set_instance_parameter_value ctrl {USE_AUTO_ADDRESS_WIDTH} {0}
    set_instance_parameter_value ctrl {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value ctrl {MAX_BURST_SIZE} {1}
    set_instance_parameter_value ctrl {MAX_PENDING_RESPONSES} {4}
    set_instance_parameter_value ctrl {LINEWRAPBURSTS} {0}
    set_instance_parameter_value ctrl {PIPELINE_COMMAND} {0}
    set_instance_parameter_value ctrl {PIPELINE_RESPONSE} {0}
    set_instance_parameter_value ctrl {USE_RESPONSE} {0}

    add_instance pll_rom altera_avalon_onchip_memory2 $bsp_version
    set_instance_parameter_value pll_rom {allowInSystemMemoryContentEditor} {0}
    set_instance_parameter_value pll_rom {blockType} {AUTO}
    set_instance_parameter_value pll_rom {dataWidth} {32}
    set_instance_parameter_value pll_rom {dataWidth} {32}
    set_instance_parameter_value pll_rom {dualPort} {0}
    set_instance_parameter_value pll_rom {initMemContent} {1}
    set_instance_parameter_value pll_rom {initializationFileName} {pll_rom}
    set_instance_parameter_value pll_rom {instanceID} {PLLM}
    set_instance_parameter_value pll_rom {memorySize} {1024.0}
    set_instance_parameter_value pll_rom {readDuringWriteMode} {DONT_CARE}
    set_instance_parameter_value pll_rom {simAllowMRAMContentsFile} {0}
    set_instance_parameter_value pll_rom {simMemInitOnlyFilename} {0}
    set_instance_parameter_value pll_rom {singleClockOperation} {0}
    set_instance_parameter_value pll_rom {slave1Latency} {2}
    set_instance_parameter_value pll_rom {slave2Latency} {1}
    set_instance_parameter_value pll_rom {useNonDefaultInitFile} {1}
    set_instance_parameter_value pll_rom {copyInitFile} {0}
    set_instance_parameter_value pll_rom {useShallowMemBlocks} {0}
    set_instance_parameter_value pll_rom {writable} {0}
    set_instance_parameter_value pll_rom {ecc_enabled} {0}
    set_instance_parameter_value pll_rom {resetrequest_enabled} {1}

    add_instance kernel_pll altera_pll $bsp_version
    set_instance_parameter_value kernel_pll {debug_print_output} {0}
    set_instance_parameter_value kernel_pll {debug_use_rbc_taf_method} {0}
    set_instance_parameter_value kernel_pll {gui_device_speed_grade} {2}
    set_instance_parameter_value kernel_pll {gui_pll_mode} {Fractional-N PLL}
    set_instance_parameter_value kernel_pll {gui_reference_clock_frequency} $ref_clk_rate
    set_instance_parameter_value kernel_pll {gui_channel_spacing} {0.0}
    set_instance_parameter_value kernel_pll {gui_operation_mode} {direct}
    set_instance_parameter_value kernel_pll {gui_feedback_clock} {Global Clock}
    set_instance_parameter_value kernel_pll {gui_fractional_cout} {24}
    set_instance_parameter_value kernel_pll {gui_dsm_out_sel} {1st_order}
    set_instance_parameter_value kernel_pll {gui_use_locked} {1}
    set_instance_parameter_value kernel_pll {gui_en_adv_params} {0}
    set_instance_parameter_value kernel_pll {gui_number_of_clocks} {2}
    set_instance_parameter_value kernel_pll {gui_multiply_factor} {1}
    set_instance_parameter_value kernel_pll {gui_frac_multiply_factor} {1.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_n} {1}
    set_instance_parameter_value kernel_pll {gui_cascade_counter0} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency0} $target_clk_rate
    set_instance_parameter_value kernel_pll {gui_divide_factor_c0} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency0} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units0} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift0} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg0} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift0} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle0} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter1} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency1} [expr 2.0 * $target_clk_rate]
    set_instance_parameter_value kernel_pll {gui_divide_factor_c1} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency1} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units1} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift1} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg1} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift1} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle1} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter2} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency2} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c2} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency2} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units2} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift2} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg2} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift2} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle2} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter3} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency3} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c3} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency3} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units3} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift3} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg3} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift3} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle3} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter4} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency4} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c4} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency4} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units4} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift4} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg4} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift4} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle4} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter5} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency5} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c5} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency5} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units5} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift5} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg5} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift5} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle5} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter6} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency6} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c6} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency6} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units6} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift6} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg6} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift6} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle6} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter7} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency7} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c7} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency7} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units7} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift7} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg7} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift7} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle7} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter8} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency8} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c8} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency8} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units8} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift8} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg8} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift8} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle8} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter9} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency9} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c9} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency9} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units9} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift9} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg9} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift9} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle9} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter10} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency10} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c10} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency10} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units10} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift10} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg10} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift10} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle10} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter11} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency11} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c11} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency11} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units11} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift11} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg11} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift11} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle11} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter12} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency12} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c12} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency12} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units12} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift12} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg12} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift12} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle12} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter13} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency13} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c13} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency13} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units13} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift13} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg13} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift13} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle13} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter14} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency14} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c14} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency14} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units14} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift14} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg14} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift14} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle14} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter15} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency15} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c15} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency15} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units15} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift15} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg15} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift15} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle15} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter16} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency16} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c16} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency16} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units16} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift16} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg16} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift16} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle16} {50}
    set_instance_parameter_value kernel_pll {gui_cascade_counter17} {0}
    set_instance_parameter_value kernel_pll {gui_output_clock_frequency17} {100.0}
    set_instance_parameter_value kernel_pll {gui_divide_factor_c17} {1}
    set_instance_parameter_value kernel_pll {gui_actual_output_clock_frequency17} {0 MHz}
    set_instance_parameter_value kernel_pll {gui_ps_units17} {ps}
    set_instance_parameter_value kernel_pll {gui_phase_shift17} {0}
    set_instance_parameter_value kernel_pll {gui_phase_shift_deg17} {0.0}
    set_instance_parameter_value kernel_pll {gui_actual_phase_shift17} {0}
    set_instance_parameter_value kernel_pll {gui_duty_cycle17} {50}
    set_instance_parameter_value kernel_pll {gui_pll_auto_reset} {Off}
    set_instance_parameter_value kernel_pll {gui_pll_bandwidth_preset} {Auto}
    set_instance_parameter_value kernel_pll {gui_en_reconf} {1}
    set_instance_parameter_value kernel_pll {gui_en_dps_ports} {0}
    set_instance_parameter_value kernel_pll {gui_en_phout_ports} {0}
    set_instance_parameter_value kernel_pll {gui_phout_division} {1}
    set_instance_parameter_value kernel_pll {gui_mif_generate} {0}
    set_instance_parameter_value kernel_pll {gui_enable_mif_dps} {0}
    set_instance_parameter_value kernel_pll {gui_dps_cntr} {C0}
    set_instance_parameter_value kernel_pll {gui_dps_num} {1}
    set_instance_parameter_value kernel_pll {gui_dps_dir} {Positive}
    set_instance_parameter_value kernel_pll {gui_refclk_switch} {0}
    set_instance_parameter_value kernel_pll {gui_refclk1_frequency} {100.0}
    set_instance_parameter_value kernel_pll {gui_switchover_mode} {Automatic Switchover}
    set_instance_parameter_value kernel_pll {gui_switchover_delay} {0}
    set_instance_parameter_value kernel_pll {gui_active_clk} {0}
    set_instance_parameter_value kernel_pll {gui_clk_bad} {0}
    set_instance_parameter_value kernel_pll {gui_enable_cascade_out} {0}
    set_instance_parameter_value kernel_pll {gui_cascade_outclk_index} {0}
    set_instance_parameter_value kernel_pll {gui_enable_cascade_in} {0}
    set_instance_parameter_value kernel_pll {gui_pll_cascading_mode} {Create an adjpllin signal to connect with an upstream PLL}

    # connections and connection parameters
    add_connection global_routing_kernel_clk.global_clk kernel_clk.clk_in clock

    # Reference Clock
    add_connection kernel_pll_refclk.out_clk kernel_pll.refclk clock

    # Kernel PLL Reset
    add_connection pll_sw_reset.sw_reset kernel_pll.reset reset

    # Kernel CLK
    add_connection kernel_pll.outclk0 global_routing_kernel_clk.clk clock

    # Kernel 2x CLK
    add_connection kernel_pll.outclk1 global_routing_kernel_clk2x.clk clock
    
    # Counter CLK
    add_connection kernel_pll.outclk0 counter.clk clock

    # Counter 2x CLK
    add_connection kernel_pll.outclk1 counter.clk2x clock

    # Config Clock Connections
    add_connection clk.clk ctrl.clk clock
    add_connection clk.clk pll_rom.clk1 clock
    add_connection clk.clk pll_reconfig_0.mgmt_clk clock
    add_connection clk.clk pll_sw_reset.clk clock
    add_connection clk.clk pll_lock_avs_0.clk clock
    add_connection clk.clk version_id.clk clock

    # Config Clock Reset Connections
    add_connection clk.clk_reset pll_lock_avs_0.clk_reset reset
    add_connection clk.clk_reset pll_sw_reset.clk_reset reset
    add_connection clk.clk_reset counter.clk_reset reset
    add_connection clk.clk_reset pll_rom.reset1 reset
    add_connection clk.clk_reset pll_reconfig_0.mgmt_reset reset
    add_connection clk.clk_reset kernel_pll.reset reset
    add_connection clk.clk_reset ctrl.reset reset
    add_connection clk.clk_reset kernel_clk.clk_in_reset reset
    add_connection clk.clk_reset version_id.clk_reset reset

    # Avalon Conections
    add_connection ctrl.m0 version_id.s avalon
    set_connection_parameter_value ctrl.m0/version_id.s arbitrationPriority {1}
    set_connection_parameter_value ctrl.m0/version_id.s baseAddress {0x0000}
    set_connection_parameter_value ctrl.m0/version_id.s defaultConnection {0}

    add_connection ctrl.m0 counter.s avalon
    set_connection_parameter_value ctrl.m0/counter.s arbitrationPriority {1}
    set_connection_parameter_value ctrl.m0/counter.s baseAddress {0x0100}
    set_connection_parameter_value ctrl.m0/counter.s defaultConnection {0}

    add_connection ctrl.m0 pll_sw_reset.s avalon
    set_connection_parameter_value ctrl.m0/pll_sw_reset.s arbitrationPriority {1}
    set_connection_parameter_value ctrl.m0/pll_sw_reset.s baseAddress {0x0110}
    set_connection_parameter_value ctrl.m0/pll_sw_reset.s defaultConnection {0}

    add_connection ctrl.m0 pll_lock_avs_0.s avalon
    set_connection_parameter_value ctrl.m0/pll_lock_avs_0.s arbitrationPriority {1}
    set_connection_parameter_value ctrl.m0/pll_lock_avs_0.s baseAddress {0x0120}
    set_connection_parameter_value ctrl.m0/pll_lock_avs_0.s defaultConnection {0}

    add_connection ctrl.m0 pll_reconfig_0.mgmt_avalon_slave avalon
    set_connection_parameter_value ctrl.m0/pll_reconfig_0.mgmt_avalon_slave arbitrationPriority {1}
    set_connection_parameter_value ctrl.m0/pll_reconfig_0.mgmt_avalon_slave baseAddress {0x0200}
    set_connection_parameter_value ctrl.m0/pll_reconfig_0.mgmt_avalon_slave defaultConnection {0}

    add_connection ctrl.m0 pll_rom.s1 avalon
    set_connection_parameter_value ctrl.m0/pll_rom.s1 arbitrationPriority {1}
    set_connection_parameter_value ctrl.m0/pll_rom.s1 baseAddress {0x0400}
    set_connection_parameter_value ctrl.m0/pll_rom.s1 defaultConnection {0}

    # PLL Locked
    add_connection pll_lock_avs_0.lock kernel_pll.locked conduit
    set_connection_parameter_value pll_lock_avs_0.lock/kernel_pll.locked endPort {}
    set_connection_parameter_value pll_lock_avs_0.lock/kernel_pll.locked endPortLSB {0}
    set_connection_parameter_value pll_lock_avs_0.lock/kernel_pll.locked startPort {}
    set_connection_parameter_value pll_lock_avs_0.lock/kernel_pll.locked startPortLSB {0}
    set_connection_parameter_value pll_lock_avs_0.lock/kernel_pll.locked width {0}

    # Reconfig to PLL
    add_connection pll_reconfig_0.reconfig_to_pll kernel_pll.reconfig_to_pll conduit
    set_connection_parameter_value pll_reconfig_0.reconfig_to_pll/kernel_pll.reconfig_to_pll endPort {}
    set_connection_parameter_value pll_reconfig_0.reconfig_to_pll/kernel_pll.reconfig_to_pll endPortLSB {0}
    set_connection_parameter_value pll_reconfig_0.reconfig_to_pll/kernel_pll.reconfig_to_pll startPort {}
    set_connection_parameter_value pll_reconfig_0.reconfig_to_pll/kernel_pll.reconfig_to_pll startPortLSB {0}
    set_connection_parameter_value pll_reconfig_0.reconfig_to_pll/kernel_pll.reconfig_to_pll width {0}

    # Reconfig from PLL
    add_connection kernel_pll.reconfig_from_pll pll_reconfig_0.reconfig_from_pll conduit
    set_connection_parameter_value kernel_pll.reconfig_from_pll/pll_reconfig_0.reconfig_from_pll endPort {}
    set_connection_parameter_value kernel_pll.reconfig_from_pll/pll_reconfig_0.reconfig_from_pll endPortLSB {0}
    set_connection_parameter_value kernel_pll.reconfig_from_pll/pll_reconfig_0.reconfig_from_pll startPort {}
    set_connection_parameter_value kernel_pll.reconfig_from_pll/pll_reconfig_0.reconfig_from_pll startPortLSB {0}
    set_connection_parameter_value kernel_pll.reconfig_from_pll/pll_reconfig_0.reconfig_from_pll width {0}

    # interconnect requirements
    set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {FIFO}
    set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {1}
}
