package require -exact qsys 14.0
lappend auto_path /usr/lib/Tclxml3.3
package require xml

# module properties
set_module_property NAME {kernel_interface}
set_module_property DISPLAY_NAME {kernel_interface}

# default module properties
set_module_property VERSION {1.0}
set_module_property GROUP {default group}
set_module_property DESCRIPTION {default description}
set_module_property AUTHOR {author}

set_module_property COMPOSITION_CALLBACK compose
set_module_property opaque_address_map false

#############################################################################
# parameters
#############################################################################
add_parameter BOARD_PATH String "Board Path"
set_parameter_property BOARD_PATH DEFAULT_VALUE /data/mhogains/Tinker2/Tinker/board/de5net/de5_2XD2GB
set_parameter_property BOARD_PATH DISPLAY_NAME BOARD_PATH
set_parameter_property BOARD_PATH TYPE STRING
set_parameter_property BOARD_PATH UNITS None
set_parameter_property BOARD_PATH DESCRIPTION "Path to board directory containing board_specification.xml, with board-specific xml file in the parent directory"
set_parameter_property BOARD_PATH HDL_PARAMETER true

proc compose { } {

    set board_path [get_parameter_value BOARD_PATH]
    set board_file $board_path/board_specification.xml
    set board_fp [open $board_file]
    set board_dom [dom::parse [read $board_fp]]

    set param_file $board_path/../[[dom::selectNode $board_dom /board/@file] stringValue]
    set param_fp [open $param_file]
    set param_dom [dom::parse [read $param_fp]]

    # Use the board_specification.xml file to determine which memory systems are enabled
    set is_ddr [dom::selectNode $board_dom {/board/global_mem[@name="DDR"]}]
    set enable_ddr [dom::isNode $is_ddr]
    if { $enable_ddr } {
	set baseAddr_ddr [[dom::selectNode $board_dom /board/global_mem\[@name="DDR"\]/@config_addr] stringValue ]
	set index_ddr [[dom::selectNode $board_dom /board/global_mem\[@name="DDR"\]/@index] stringValue ]
    }
    set is_qdr [dom::selectNode $board_dom {/board/global_mem[@name="QDR"]}]
    set enable_qdr [dom::isNode $is_qdr]
    if { $enable_qdr } {
	set baseAddr_qdr [[dom::selectNode $board_dom /board/global_mem\[@name="QDR"\]/@config_addr] stringValue ]
	set index_qdr [[dom::selectNode $board_dom /board/global_mem\[@name="QDR"\]/@index] stringValue ]
    }
    set is_local [dom::selectNode $board_dom {/board/global_mem[@name="LOCAL"]}]
    set enable_local [dom::isNode $is_local]
    if { $enable_local } {
	set baseAddr_local [[dom::selectNode $board_dom /board/global_mem\[@name="LOCAL"\]/@config_addr] stringValue ]
	set index_local [[dom::selectNode $board_dom /board/global_mem\[@name="LOCAL"\]/@index] stringValue ]
    }
    #############################################################################
    # exported interfaces
    #############################################################################
    add_interface clk clock sink
    set_interface_property clk EXPORT_OF clk_reset.clk_in
    add_interface kernel_clk clock sink
    set_interface_property kernel_clk EXPORT_OF kernel_clk.in_clk
    add_interface kernel_cntrl avalon slave
    set_interface_property kernel_cntrl EXPORT_OF kernel_cntrl.s0
    add_interface kernel_cra avalon master
    set_interface_property kernel_cra EXPORT_OF kernel_cra.m0
    add_interface kernel_irq_from_kernel interrupt receiver
    set_interface_property kernel_irq_from_kernel EXPORT_OF irq_bridge_0.receiver_irq
    add_interface kernel_irq_to_host interrupt sender
    set_interface_property kernel_irq_to_host EXPORT_OF irq_bridge_0.sender0_irq
    add_interface kernel_reset reset source
    set_interface_property kernel_reset EXPORT_OF reset_bridge_0.out_reset

    # Memory systems, if enabled, export their mem_org hosting ports to the kernel
    if { $enable_ddr } {
	add_interface mem_org_mode_ddr_$index_ddr\_mem_organization_host conduit end
	set_interface_property mem_org_mode_ddr_$index_ddr\_mem_organization_host EXPORT_OF mem_org_mode_ddr_$index_ddr\.mem_organization_host
	add_interface mem_org_mode_ddr_$index_ddr\_mem_organization_kernel conduit end
	set_interface_property mem_org_mode_ddr_$index_ddr\_mem_organization_kernel EXPORT_OF mem_org_mode_ddr_$index_ddr\.mem_organization_kernel
    }
    if { $enable_qdr } {
	add_interface mem_org_mode_qdr_$index_qdr\_mem_organization_host conduit end
	set_interface_property mem_org_mode_qdr_$index_qdr\_mem_organization_host EXPORT_OF mem_org_mode_qdr_$index_qdr\.mem_organization_host
	add_interface mem_org_mode_qdr_$index_qdr\_mem_organization_kernel conduit end
	set_interface_property mem_org_mode_qdr_$index_qdr\_mem_organization_kernel EXPORT_OF mem_org_mode_qdr_$index_qdr\.mem_organization_kernel
    }
    if { $enable_local } {
	add_interface mem_org_mode_local_$index_local\_mem_organization_host conduit end
	set_interface_property mem_org_mode_local_$index_local\_mem_organization_host EXPORT_OF mem_org_mode_local_$index_local\.mem_organization_host
	add_interface mem_org_mode_local_$index_local\_mem_organization_kernel conduit end
	set_interface_property mem_org_mode_local_$index_local\_mem_organization_kernel EXPORT_OF mem_org_mode_local_$index_local\.mem_organization_kernel
    }
    ##############################################################################
    add_interface reset reset sink
    set_interface_property reset EXPORT_OF clk_reset.clk_in_reset
    add_interface sw_reset_export reset source
    set_interface_property sw_reset_export EXPORT_OF reset_bridge_1.out_reset
    add_interface sw_reset_in reset sink
    set_interface_property sw_reset_in EXPORT_OF sw_reset_in.in_reset

    ##############################################################################
    # Instances and instance parameters
    # (disabled instances are intentionally culled)
    ##############################################################################
    add_instance address_span_extender_0 altera_address_span_extender 14.1
    set_instance_parameter_value address_span_extender_0 {DATA_WIDTH} {32}
    set_instance_parameter_value address_span_extender_0 {MASTER_ADDRESS_WIDTH} {30}
    set_instance_parameter_value address_span_extender_0 {SLAVE_ADDRESS_WIDTH} {10}
    set_instance_parameter_value address_span_extender_0 {BURSTCOUNT_WIDTH} {1}
    set_instance_parameter_value address_span_extender_0 {SUB_WINDOW_COUNT} {1}
    set_instance_parameter_value address_span_extender_0 {MASTER_ADDRESS_DEF} {0}
    set_instance_parameter_value address_span_extender_0 {TERMINATE_SLAVE_PORT} {0}
    set_instance_parameter_value address_span_extender_0 {MAX_PENDING_READS} {1}

    add_instance clk_reset clock_source 14.1
    set_instance_parameter_value clk_reset {clockFrequency} {100000000.0}
    set_instance_parameter_value clk_reset {clockFrequencyKnown} {1}
    set_instance_parameter_value clk_reset {resetSynchronousEdges} {DEASSERT}

    add_instance irq_bridge_0 altera_irq_bridge 14.1
    set_instance_parameter_value irq_bridge_0 {IRQ_WIDTH} {1}
    set_instance_parameter_value irq_bridge_0 {IRQ_N} {0}

    add_instance kernel_clk altera_clock_bridge 14.1
    set_instance_parameter_value kernel_clk {EXPLICIT_CLOCK_RATE} {0.0}
    set_instance_parameter_value kernel_clk {NUM_CLOCK_OUTPUTS} {1}

    add_instance kernel_cntrl altera_avalon_mm_bridge 14.1
    set_instance_parameter_value kernel_cntrl {DATA_WIDTH} {32}
    set_instance_parameter_value kernel_cntrl {SYMBOL_WIDTH} {8}
    set_instance_parameter_value kernel_cntrl {ADDRESS_WIDTH} {14}
    set_instance_parameter_value kernel_cntrl {USE_AUTO_ADDRESS_WIDTH} {0}
    set_instance_parameter_value kernel_cntrl {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value kernel_cntrl {MAX_BURST_SIZE} {1}
    set_instance_parameter_value kernel_cntrl {MAX_PENDING_RESPONSES} {1}
    set_instance_parameter_value kernel_cntrl {LINEWRAPBURSTS} {0}
    set_instance_parameter_value kernel_cntrl {PIPELINE_COMMAND} {1}
    set_instance_parameter_value kernel_cntrl {PIPELINE_RESPONSE} {1}

    add_instance kernel_cra altera_avalon_mm_bridge 14.1
    set_instance_parameter_value kernel_cra {DATA_WIDTH} {64}
    set_instance_parameter_value kernel_cra {SYMBOL_WIDTH} {8}
    set_instance_parameter_value kernel_cra {ADDRESS_WIDTH} {30}
    set_instance_parameter_value kernel_cra {USE_AUTO_ADDRESS_WIDTH} {0}
    set_instance_parameter_value kernel_cra {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value kernel_cra {MAX_BURST_SIZE} {1}
    set_instance_parameter_value kernel_cra {MAX_PENDING_RESPONSES} {1}
    set_instance_parameter_value kernel_cra {LINEWRAPBURSTS} {0}
    set_instance_parameter_value kernel_cra {PIPELINE_COMMAND} {1}
    set_instance_parameter_value kernel_cra {PIPELINE_RESPONSE} {1}

    if { $enable_ddr } {
	add_instance mem_org_mode_ddr_$index_ddr mem_org_mode 10.0
	set_instance_parameter_value mem_org_mode_ddr_$index_ddr {WIDTH} {32}
    }

    if { $enable_qdr } {
	add_instance mem_org_mode_qdr_$index_qdr mem_org_mode 10.0
	set_instance_parameter_value mem_org_mode_qdr_$index_qdr {WIDTH} {32}
    }

    if { $enable_local } {
	add_instance mem_org_mode_local_$index_local mem_org_mode 10.0
	set_instance_parameter_value mem_org_mode_local_$index_local {WIDTH} {32}
    }

    add_instance reset_bridge_0 altera_reset_bridge 14.1
    set_instance_parameter_value reset_bridge_0 {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value reset_bridge_0 {SYNCHRONOUS_EDGES} {deassert}
    set_instance_parameter_value reset_bridge_0 {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value reset_bridge_0 {USE_RESET_REQUEST} {0}

    add_instance reset_bridge_1 altera_reset_bridge 14.1
    set_instance_parameter_value reset_bridge_1 {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value reset_bridge_1 {SYNCHRONOUS_EDGES} {deassert}
    set_instance_parameter_value reset_bridge_1 {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value reset_bridge_1 {USE_RESET_REQUEST} {0}

    add_instance reset_controller_sw altera_reset_controller 14.1
    set_instance_parameter_value reset_controller_sw {NUM_RESET_INPUTS} {2}
    set_instance_parameter_value reset_controller_sw {OUTPUT_RESET_SYNC_EDGES} {deassert}
    set_instance_parameter_value reset_controller_sw {SYNC_DEPTH} {2}
    set_instance_parameter_value reset_controller_sw {RESET_REQUEST_PRESENT} {0}
    set_instance_parameter_value reset_controller_sw {RESET_REQ_WAIT_TIME} {1}
    set_instance_parameter_value reset_controller_sw {MIN_RST_ASSERTION_TIME} {3}
    set_instance_parameter_value reset_controller_sw {RESET_REQ_EARLY_DSRT_TIME} {1}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN0} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN1} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN2} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN3} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN4} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN5} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN6} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN7} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN8} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN9} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN10} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN11} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN12} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN13} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN14} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_IN15} {0}
    set_instance_parameter_value reset_controller_sw {USE_RESET_REQUEST_INPUT} {0}

    add_instance sw_reset sw_reset 10.0
    set_instance_parameter_value sw_reset {WIDTH} {64}
    set_instance_parameter_value sw_reset {LOG2_RESET_CYCLES} {10}

    add_instance sw_reset_in altera_reset_bridge 14.1
    set_instance_parameter_value sw_reset_in {ACTIVE_LOW_RESET} {0}
    set_instance_parameter_value sw_reset_in {SYNCHRONOUS_EDGES} {deassert}
    set_instance_parameter_value sw_reset_in {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value sw_reset_in {USE_RESET_REQUEST} {0}

    add_instance sys_description_rom altera_avalon_onchip_memory2 14.1
    set_instance_parameter_value sys_description_rom {allowInSystemMemoryContentEditor} {0}
    set_instance_parameter_value sys_description_rom {blockType} {AUTO}
    set_instance_parameter_value sys_description_rom {dataWidth} {64}
    set_instance_parameter_value sys_description_rom {dualPort} {0}
    set_instance_parameter_value sys_description_rom {initMemContent} {1}
    set_instance_parameter_value sys_description_rom {initializationFileName} {sys_description}
    set_instance_parameter_value sys_description_rom {instanceID} {NONE}
    set_instance_parameter_value sys_description_rom {memorySize} {4096.0}
    set_instance_parameter_value sys_description_rom {readDuringWriteMode} {DONT_CARE}
    set_instance_parameter_value sys_description_rom {simAllowMRAMContentsFile} {0}
    set_instance_parameter_value sys_description_rom {simMemInitOnlyFilename} {0}
    set_instance_parameter_value sys_description_rom {singleClockOperation} {0}
    set_instance_parameter_value sys_description_rom {slave1Latency} {2}
    set_instance_parameter_value sys_description_rom {slave2Latency} {1}
    set_instance_parameter_value sys_description_rom {useNonDefaultInitFile} {1}
    set_instance_parameter_value sys_description_rom {copyInitFile} {0}
    set_instance_parameter_value sys_description_rom {useShallowMemBlocks} {0}
    set_instance_parameter_value sys_description_rom {writable} {0}
    set_instance_parameter_value sys_description_rom {ecc_enabled} {0}
    set_instance_parameter_value sys_description_rom {resetrequest_enabled} {1}

    add_instance version_id_0 version_id 10.0
    set_instance_parameter_value version_id_0 {WIDTH} {32}
    set_instance_parameter_value version_id_0 {VERSION_ID} {-1598029823}

    # connections and connection parameters
    add_connection address_span_extender_0.expanded_master kernel_cra.s0 avalon
    set_connection_parameter_value address_span_extender_0.expanded_master/kernel_cra.s0 arbitrationPriority {1}
    set_connection_parameter_value address_span_extender_0.expanded_master/kernel_cra.s0 baseAddress {0x0000}
    set_connection_parameter_value address_span_extender_0.expanded_master/kernel_cra.s0 defaultConnection {0}

    add_connection kernel_cntrl.m0 address_span_extender_0.cntl avalon
    set_connection_parameter_value kernel_cntrl.m0/address_span_extender_0.cntl arbitrationPriority {1}
    set_connection_parameter_value kernel_cntrl.m0/address_span_extender_0.cntl baseAddress {0x0020}
    set_connection_parameter_value kernel_cntrl.m0/address_span_extender_0.cntl defaultConnection {0}

    add_connection kernel_cntrl.m0 sw_reset.s avalon
    set_connection_parameter_value kernel_cntrl.m0/sw_reset.s arbitrationPriority {1}
    set_connection_parameter_value kernel_cntrl.m0/sw_reset.s baseAddress {0x0030}
    set_connection_parameter_value kernel_cntrl.m0/sw_reset.s defaultConnection {0}

    add_connection kernel_cntrl.m0 version_id_0.s avalon
    set_connection_parameter_value kernel_cntrl.m0/version_id_0.s arbitrationPriority {1}
    set_connection_parameter_value kernel_cntrl.m0/version_id_0.s baseAddress {0x0000}
    set_connection_parameter_value kernel_cntrl.m0/version_id_0.s defaultConnection {0}

    ##################################################################################
    # TODO: remove baseAddress from each and pull from board_specification.xml file
    # TODO: add index from xml file for each mem_org_mode_xxx_$index_xxx
    ##################################################################################

    if { $enable_ddr } {
	add_connection kernel_cntrl.m0 mem_org_mode_ddr_$index_ddr\.s avalon
	set_connection_parameter_value kernel_cntrl.m0/mem_org_mode_ddr_$index_ddr\.s arbitrationPriority {1}
	set_connection_parameter_value kernel_cntrl.m0/mem_org_mode_ddr_$index_ddr\.s baseAddress $baseAddr_ddr 
	# {0x0018}
	set_connection_parameter_value kernel_cntrl.m0/mem_org_mode_ddr_$index_ddr\.s defaultConnection {0}
        
	add_connection clk_reset.clk mem_org_mode_ddr_$index_ddr\.clk clock
	add_connection clk_reset.clk_reset mem_org_mode_ddr_$index_ddr\.clk_reset reset
    }
    if { $enable_qdr } {
	add_connection kernel_cntrl.m0 mem_org_mode_qdr_$index_qdr\.s avalon
	set_connection_parameter_value kernel_cntrl.m0/mem_org_mode_qdr_$index_qdr\.s arbitrationPriority {1}
	set_connection_parameter_value kernel_cntrl.m0/mem_org_mode_qdr_$index_qdr\.s baseAddress $baseAddr_qdr
	# {0x0100}
	set_connection_parameter_value kernel_cntrl.m0/mem_org_mode_qdr_$index_qdr\.s defaultConnection {0}

	add_connection clk_reset.clk mem_org_mode_qdr_$index_qdr\.clk clock
	add_connection clk_reset.clk_reset mem_org_mode_qdr_$index_qdr\.clk_reset reset
    }
    if { $enable_local } {
	add_connection kernel_cntrl.m0 mem_org_mode_local_$index_local\.s avalon
	set_connection_parameter_value kernel_cntrl.m0/mem_org_mode_local_$index_local\.s arbitrationPriority {1}
	set_connection_parameter_value kernel_cntrl.m0/mem_org_mode_local_$index_local\.s baseAddress $baseAddr_local
	# {0x0118}
	set_connection_parameter_value kernel_cntrl.m0/mem_org_mode_local_$index_local\.s defaultConnection {0}

	add_connection clk_reset.clk mem_org_mode_local_$index_local\.clk clock
	add_connection clk_reset.clk_reset mem_org_mode_local_$index_local\.clk_reset reset
    }

    add_connection kernel_cntrl.m0 sys_description_rom.s1 avalon
    set_connection_parameter_value kernel_cntrl.m0/sys_description_rom.s1 arbitrationPriority {1}
    set_connection_parameter_value kernel_cntrl.m0/sys_description_rom.s1 baseAddress {0x2000}
    set_connection_parameter_value kernel_cntrl.m0/sys_description_rom.s1 defaultConnection {0}

    add_connection kernel_cntrl.m0 address_span_extender_0.windowed_slave avalon
    set_connection_parameter_value kernel_cntrl.m0/address_span_extender_0.windowed_slave arbitrationPriority {1}
    set_connection_parameter_value kernel_cntrl.m0/address_span_extender_0.windowed_slave baseAddress {0x1000}
    set_connection_parameter_value kernel_cntrl.m0/address_span_extender_0.windowed_slave defaultConnection {0}

    add_connection clk_reset.clk kernel_cntrl.clk clock

    add_connection clk_reset.clk sw_reset.clk clock



    add_connection clk_reset.clk sw_reset_in.clk clock

    add_connection clk_reset.clk version_id_0.clk clock

    add_connection clk_reset.clk reset_bridge_1.clk clock



    add_connection clk_reset.clk sys_description_rom.clk1 clock

    add_connection kernel_clk.out_clk kernel_cra.clk clock

    add_connection kernel_clk.out_clk irq_bridge_0.clk clock

    add_connection kernel_clk.out_clk reset_controller_sw.clk clock

    add_connection kernel_clk.out_clk reset_bridge_0.clk clock

    add_connection kernel_clk.out_clk address_span_extender_0.clock clock

    add_connection clk_reset.clk_reset sw_reset.clk_reset reset



    add_connection clk_reset.clk_reset version_id_0.clk_reset reset



    add_connection clk_reset.clk_reset kernel_cntrl.reset reset

    add_connection clk_reset.clk_reset address_span_extender_0.reset reset

    add_connection clk_reset.clk_reset sys_description_rom.reset1 reset

    add_connection clk_reset.clk_reset reset_controller_sw.reset_in0 reset

    add_connection sw_reset_in.out_reset sw_reset.clk_reset reset

    add_connection reset_controller_sw.reset_out irq_bridge_0.clk_reset reset

    add_connection reset_controller_sw.reset_out reset_bridge_0.in_reset reset

    add_connection reset_controller_sw.reset_out kernel_cra.reset reset

    add_connection sw_reset.sw_reset reset_bridge_1.in_reset reset

    add_connection sw_reset.sw_reset reset_controller_sw.reset_in1 reset

    # interconnect requirements
    set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
    set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {0}
}
