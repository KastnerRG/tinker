package require -exact qsys 14.0

# module properties
set_module_property NAME {local_mem_module_export}
set_module_property DISPLAY_NAME {local_mem}

# default module properties
set_module_property VERSION {1.0}
set_module_property GROUP {default group}
set_module_property DESCRIPTION {default description}
set_module_property AUTHOR {author}

set_module_property COMPOSITION_CALLBACK compose
set_module_property opaque_address_map false

# parameters
add_parameter SHARED1 BOOLEAN false "Shared"
set_parameter_property SHARED1 DEFAULT_VALUE false
set_parameter_property SHARED1 DISPLAY_NAME SHARED
set_parameter_property SHARED1 TYPE BOOLEAN
set_parameter_property SHARED1 UNITS None
set_parameter_property SHARED1 DESCRIPTION "Shared"
set_parameter_property SHARED1 HDL_PARAMETER true
set_parameter_property SHARED1 ALLOWED_RANGES {true false}

add_parameter FIRST_MEM BOOLEAN false "First memory"
set_parameter_property FIRST_MEM DEFAULT_VALUE false
set_parameter_property FIRST_MEM DISPLAY_NAME FIRST_MEM
set_parameter_property FIRST_MEM TYPE BOOLEAN
set_parameter_property FIRST_MEM UNITS None
set_parameter_property FIRST_MEM DESCRIPTION "Special components are needed if this is the first memory and this ensures that everything is correctly connected"
set_parameter_property FIRST_MEM HDL_PARAMETER true
set_parameter_property FIRST_MEM ALLOWED_RANGES {true false}

add_parameter EXPORTED_OUTCLK BOOLEAN false "Export Outclk"
set_parameter_property EXPORTED_OUTCLK DEFAULT_VALUE false
set_parameter_property EXPORTED_OUTCLK DISPLAY_NAME EXPORT_OUTCLK
set_parameter_property EXPORTED_OUTCLK TYPE BOOLEAN
set_parameter_property EXPORTED_OUTCLK UNITS None
set_parameter_property EXPORTED_OUTCLK DESCRIPTION "If true, outclk will be exported, if not outclk will be removed, unless this is the first memory that runs the bank divider"
set_parameter_property EXPORTED_OUTCLK HDL_PARAMETER true
set_parameter_property EXPORTED_OUTCLK ALLOWED_RANGES {true false}

add_parameter CLOCK INTEGER 4 "Memory Clock Frequency"
set_parameter_property CLOCK DEFAULT_VALUE 100
set_parameter_property CLOCK DISPLAY_NAME CLOCK
set_parameter_property CLOCK TYPE FLOAT
set_parameter_property CLOCK UNITS None
set_parameter_property CLOCK DESCRIPTION "Memory Clock Frequency"
set_parameter_property CLOCK HDL_PARAMETER true
set_parameter_property CLOCK ALLOWED_RANGES {1:50000000000}

proc compose { } {
    # Instances and instance parameters
    # (disabled instances are intentionally culled)

#    if {[get_parameter_value FIRST_MEM] == true} {
#	set_parameter_value EXPORTED_OUTCLK true
 #   }

    set clk_freq [get_parameter_value CLOCK]

    add_instance input_clk clock_source 14.0
    set_instance_parameter_value input_clk {clockFrequency} $clk_freq
    set_instance_parameter_value input_clk {clockFrequencyKnown} {1}
    set_instance_parameter_value input_clk {resetSynchronousEdges} {NONE}

    add_instance local_mem altera_avalon_onchip_memory2 14.0
    set_instance_parameter_value local_mem {allowInSystemMemoryContentEditor} {0}
    set_instance_parameter_value local_mem {blockType} {AUTO}
    set_instance_parameter_value local_mem {dataWidth} {32}
    set_instance_parameter_value local_mem {dualPort} {0}
    set_instance_parameter_value local_mem {initMemContent} {0}
    set_instance_parameter_value local_mem {initializationFileName} {onchip_mem.hex}
    set_instance_parameter_value local_mem {instanceID} {NONE}
    set_instance_parameter_value local_mem {memorySize} {4096.0}
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

    add_instance local_pll altera_pll 14.0
    set_instance_parameter_value local_pll {debug_print_output} {0}
    set_instance_parameter_value local_pll {debug_use_rbc_taf_method} {0}
    set_instance_parameter_value local_pll {gui_device_speed_grade} {1}
    set_instance_parameter_value local_pll {gui_pll_mode} {Integer-N PLL}
    set_instance_parameter_value local_pll {gui_reference_clock_frequency} {100.0}
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
    set_instance_parameter_value local_pll {gui_output_clock_frequency0} {100.0}
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
    set_instance_parameter_value local_pll {gui_refclk1_frequency} {100.0}
    set_instance_parameter_value local_pll {gui_switchover_mode} {Automatic Switchover}
    set_instance_parameter_value local_pll {gui_switchover_delay} {0}
    set_instance_parameter_value local_pll {gui_active_clk} {0}
    set_instance_parameter_value local_pll {gui_clk_bad} {0}
    set_instance_parameter_value local_pll {gui_enable_cascade_out} {0}
    set_instance_parameter_value local_pll {gui_cascade_outclk_index} {0}
    set_instance_parameter_value local_pll {gui_enable_cascade_in} {0}
    set_instance_parameter_value local_pll {gui_pll_cascading_mode} {Create an adjpllin signal to connect with an upstream PLL}

    add_instance clock_cross_kernel_mem altera_avalon_mm_clock_crossing_bridge 14.0
    set_instance_parameter_value clock_cross_kernel_mem {DATA_WIDTH} {32}
    set_instance_parameter_value clock_cross_kernel_mem {SYMBOL_WIDTH} {8}
    set_instance_parameter_value clock_cross_kernel_mem {ADDRESS_WIDTH} {10}
    set_instance_parameter_value clock_cross_kernel_mem {USE_AUTO_ADDRESS_WIDTH} {1}
    set_instance_parameter_value clock_cross_kernel_mem {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value clock_cross_kernel_mem {MAX_BURST_SIZE} {1}
    set_instance_parameter_value clock_cross_kernel_mem {COMMAND_FIFO_DEPTH} {4}
    set_instance_parameter_value clock_cross_kernel_mem {RESPONSE_FIFO_DEPTH} {4}
    set_instance_parameter_value clock_cross_kernel_mem {MASTER_SYNC_DEPTH} {2}
    set_instance_parameter_value clock_cross_kernel_mem {SLAVE_SYNC_DEPTH} {2}

    add_instance kernel_clk clock_source 14.0
    set_instance_parameter_value kernel_clk {clockFrequency} {50000000.0}
    set_instance_parameter_value kernel_clk {clockFrequencyKnown} {1}
    set_instance_parameter_value kernel_clk {resetSynchronousEdges} {NONE}

    add_instance reset_controller altera_reset_controller 14.0
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

    # ONLY if outlck is desired by the user
    if {([get_parameter_value EXPORTED_OUTCLK] == true) || ([get_parameter_value FIRST_MEM] == true)} {
	add_instance outclk clock_source 14.0
	set_instance_parameter_value outclk {clockFrequency} {50000000.0}
	set_instance_parameter_value outclk {clockFrequencyKnown} {1}
	set_instance_parameter_value outclk {resetSynchronousEdges} {NONE}
    }
    
    # if false (NOT shared), clock_cross from bank to mem is need 
    if {[get_parameter_value SHARED1] == false} {
	add_instance clock_cross_bank_mem altera_avalon_mm_clock_crossing_bridge 14.0
	set_instance_parameter_value clock_cross_bank_mem {DATA_WIDTH} {32}
	set_instance_parameter_value clock_cross_bank_mem {SYMBOL_WIDTH} {8}
	set_instance_parameter_value clock_cross_bank_mem {ADDRESS_WIDTH} {10}
	set_instance_parameter_value clock_cross_bank_mem {USE_AUTO_ADDRESS_WIDTH} {1}
	set_instance_parameter_value clock_cross_bank_mem {ADDRESS_UNITS} {SYMBOLS}
	set_instance_parameter_value clock_cross_bank_mem {MAX_BURST_SIZE} {1}
	set_instance_parameter_value clock_cross_bank_mem {COMMAND_FIFO_DEPTH} {4}
	set_instance_parameter_value clock_cross_bank_mem {RESPONSE_FIFO_DEPTH} {4}
	set_instance_parameter_value clock_cross_bank_mem {MASTER_SYNC_DEPTH} {2}
	set_instance_parameter_value clock_cross_bank_mem {SLAVE_SYNC_DEPTH} {2}
    }

    # connections and connection parameters
    add_connection input_clk.clk local_pll.refclk clock

    add_connection local_pll.outclk0 local_mem.clk1 clock

    add_connection input_clk.clk_reset local_pll.reset reset

    add_connection input_clk.clk_reset reset_controller.reset_in0 reset

    add_connection local_pll.outclk0 reset_controller.clk clock

    add_connection reset_controller.reset_out clock_cross_kernel_mem.m0_reset reset

    add_connection local_pll.outclk0 clock_cross_kernel_mem.m0_clk clock

    add_connection reset_controller.reset_out local_mem.reset1 reset

    add_connection clock_cross_kernel_mem.m0 local_mem.s1 avalon
    set_connection_parameter_value clock_cross_kernel_mem.m0/local_mem.s1 arbitrationPriority {1}
    set_connection_parameter_value clock_cross_kernel_mem.m0/local_mem.s1 baseAddress {0x0000}
    set_connection_parameter_value clock_cross_kernel_mem.m0/local_mem.s1 defaultConnection {0}

    add_connection kernel_clk.clk_reset reset_controller.reset_in1 reset

    add_connection kernel_clk.clk clock_cross_kernel_mem.s0_clk clock

    add_connection kernel_clk.clk_reset clock_cross_kernel_mem.s0_reset reset

    # ONLY need outclk if desired by the user
    if {([get_parameter_value EXPORTED_OUTCLK] == true) || ([get_parameter_value FIRST_MEM] == true)} {  
	add_connection local_pll.outclk0 outclk.clk_in clock

	add_connection reset_controller.reset_out outclk.clk_in_reset reset
}

    # If false (not shared), make connection with clock cross.m0 
    # <- m0 will be exported to be connected at higher level since different clock domains
    # If else (shared), Export memory slave port to be written directly from bank_divider in same
    # time domain
    if {[get_parameter_value SHARED1] == false} {
	add_connection local_pll.outclk0 clock_cross_bank_mem.m0_clk clock
	add_connection reset_controller.reset_out clock_cross_bank_mem.m0_reset reset
	add_connection clock_cross_bank_mem.m0 local_mem.s1 avalon
	set_connection_parameter_value clock_cross_bank_mem.m0/local_mem.s1 arbitrationPriority {1}
	set_connection_parameter_value clock_cross_bank_mem.m0/local_mem.s1 baseAddress {0x0000}
	set_connection_parameter_value clock_cross_bank_mem.m0/local_mem.s1 defaultConnection {0}
    } else {
	add_interface s1_mem avalon slave
	set_interface_property s1_mem EXPORT_OF local_mem.s1
    }

    # exported interfaces
    add_interface sys_clk_mem clock sink
    set_interface_property sys_clk_mem EXPORT_OF input_clk.clk_in
    add_interface sys_reset_mem reset sink
    set_interface_property sys_reset_mem EXPORT_OF input_clk.clk_in_reset
    add_interface pll_locked_mem conduit end
    set_interface_property pll_locked_mem EXPORT_OF local_pll.locked
    add_interface kernel_clk_mem clock sink
    set_interface_property kernel_clk_mem EXPORT_OF kernel_clk.clk_in
    add_interface kernel_reset_mem reset sink
    set_interface_property kernel_reset_mem EXPORT_OF kernel_clk.clk_in_reset
    add_interface clock_cross_kernel_s0_mem avalon slave
    set_interface_property clock_cross_kernel_s0_mem EXPORT_OF clock_cross_kernel_mem.s0
 
    # ONLY exported if desired by the user
    if {([get_parameter_value EXPORTED_OUTCLK] == true) || ([get_parameter_value FIRST_MEM] == true)} {
	add_interface outclk_mem clock source
	set_interface_property outclk_mem EXPORT_OF outclk.clk
	add_interface outclk_reset_mem reset source
	set_interface_property outclk_reset_mem EXPORT_OF outclk.clk_reset
    }
    # if false (NOT shared), clock_cross from bank to mem is need and is exported from memory level 
    if {[get_parameter_value SHARED1] == false} {
	add_interface clock_cross_bank_s0_clk_mem clock sink
	set_interface_property clock_cross_bank_s0_clk_mem EXPORT_OF clock_cross_bank_mem.s0_clk
	add_interface clock_cross_bank_s0_reset_mem reset sink
	set_interface_property clock_cross_bank_s0_reset_mem EXPORT_OF clock_cross_bank_mem.s0_reset
	add_interface clock_cross_bank_s0_mem avalon slave
	set_interface_property clock_cross_bank_s0_mem EXPORT_OF clock_cross_bank_mem.s0
    }
    # interconnect requirements
    set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
    set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {1}
    set_interconnect_requirement {$system} {qsys_mm.insertDefaultSlave} {FALSE}
}
