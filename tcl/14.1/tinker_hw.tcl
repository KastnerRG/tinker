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
# A few TODO's: 

# TODO: The data width on the DMA path is currently set to 512, but could be set
# to whatever the largest interface provides. 
# TODO: There could be a better way to specify OCT pins (currently, you need to
# know the type of the memory to name them). For instance, they could be read
# from the XML.
# TODO: The kernel reference clock frequency could be provided by the
# Board-Specific XML file. Right now it is set to 50 MHz

package require -exact qsys 14.1
lappend auto_path $::env(TCLXML_PATH)
package require xml

set_module_property NAME {tinker_architecture}
set_module_property DISPLAY_NAME {Tinker Automatic Architecture Generator}
set_module_property VERSION {14.1}
set_module_property GROUP {Tinker}
set_module_property DESCRIPTION {default description}
set_module_property AUTHOR {Dustin Richmond, Matthew Hogains, Kevin Thai, Jeremy Blackstone}
set_module_property COMPOSITION_CALLBACK compose
set_module_property opaque_address_map false

add_parameter BOARD_PATH String "Board Path"
set_parameter_property BOARD_PATH DEFAULT_VALUE $::env(TINKER_PATH)
set_parameter_property BOARD_PATH DISPLAY_NAME BOARD_PATH
set_parameter_property BOARD_PATH TYPE STRING
set_parameter_property BOARD_PATH UNITS None
set_parameter_property BOARD_PATH DESCRIPTION "Path to board directory containing board_specification.xml, with board-specific xml file in the parent directory"
set_parameter_property BOARD_PATH HDL_PARAMETER true

proc compose { } {
    set bsp_path [get_parameter_value BOARD_PATH]
    set spec_file $bsp_path/board_specification.xml
    set spec_fp [open $spec_file]
    set spec_dom [dom::parse [read $spec_fp]]

    set board_file_name [[dom::selectNode $spec_dom /board/@file] stringValue]
    set board_file $bsp_path/$board_file_name

    set bsp_version [[dom::selectNode $spec_dom /board/@version] stringValue]
    set primary_id [[dom::selectNode $spec_dom /board/global_mem\[@default="1"\]/@sys_id] stringValue]
    set system_ids {}
    set secondary_ids {}
    set mem_dict [dict create]
    set num_intfs 0

    foreach sys_id_e [dom::selectNode $spec_dom /board/global_mem/@sys_id] {
	set sys_id [$sys_id_e stringValue]
	set sys_type [[dom::selectNode $spec_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/@type] stringValue]
	set intf_config_addr [[dom::selectNode $spec_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/@config_addr] stringValue]
	dict set mem_dict $sys_id config_addr $intf_config_addr
	set base_address [[dom::selectNode $spec_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/@base_address] stringValue]
	lappend system_ids $sys_id
	if {![string match $sys_id $primary_id]} {
	    lappend secondary_ids $sys_id
	}
	set interfaces {}
	foreach intf_e [dom::selectNode $spec_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/*/@id] {
	    incr num_intfs
	    set intf [$intf_e stringValue]
	    lappend interfaces $intf
	    set intf_role [[dom::selectNode $spec_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@id=\"$intf\"\]/@role] stringValue]

	    if {[string match $sys_type "QDRII"]} {
		set kintf_port_w [[dom::selectNode $spec_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@id=\"$intf\"\]/port\[@direction="w"\]/@name] stringValue]
		set kintf_port_r [[dom::selectNode $spec_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@id=\"$intf\"\]/port\[@direction="r"\]/@name] stringValue]
		dict set mem_dict $sys_id type $sys_type
		dict set mem_dict $sys_id $intf ports [list $kintf_port_r $kintf_port_w]
	    } elseif {[string match $sys_type "DDR3"]} {
		set kintf_port [[dom::selectNode $spec_dom /board/global_mem\[@sys_id=\"$sys_id\"\]/interface\[@id=\"$intf\"\]/@port] stringValue]
		dict set mem_dict $sys_id type $sys_type
		dict set mem_dict $sys_id $intf ports [list $kintf_port]
	    }
	    dict set mem_dict $sys_id interfaces $interfaces
	    dict set mem_dict $sys_id $intf role $intf_role
	    dict set mem_dict $sys_id address $base_address
	}
    }

    ############################################################################
    # Exported Interfaces (Ports)
    ############################################################################
    add_interface config_clk clock sink
    set_interface_property config_clk EXPORT_OF config_clk.in_clk

    add_interface global_reset reset sink
    set_interface_property global_reset EXPORT_OF global_reset_in.in_reset

    # Kernel Interface
    add_interface kernel_clk clock source
    set_interface_property kernel_clk EXPORT_OF kernel_clk.clk

    add_interface kernel_clk2x clock source
    set_interface_property kernel_clk2x EXPORT_OF acl_kernel_clk.kernel_clk2x

    add_interface kernel_cra avalon master
    set_interface_property kernel_cra EXPORT_OF kernel_interface.kernel_cra

    add_interface kernel_irq interrupt receiver
    set_interface_property kernel_irq EXPORT_OF kernel_interface.kernel_irq_from_kernel

    add_interface kernel_pll_refclk clock sink
    set_interface_property kernel_pll_refclk EXPORT_OF acl_kernel_clk.pll_refclk

    add_interface kernel_reset reset source
    set_interface_property kernel_reset EXPORT_OF kernel_clk.clk_reset

    # PCIe Interface
    add_interface pcie_hip_ctrl conduit end
    set_interface_property pcie_hip_ctrl EXPORT_OF pcie.hip_ctrl

    add_interface pcie_hip_serial conduit end
    set_interface_property pcie_hip_serial EXPORT_OF pcie.hip_serial

    add_interface pcie_npor conduit end
    set_interface_property pcie_npor EXPORT_OF pcie.npor

    add_interface pcie_npor_out reset source
    set_interface_property pcie_npor_out EXPORT_OF npor_export.out_reset

    add_interface pcie_refclk clock sink
    set_interface_property pcie_refclk EXPORT_OF pcie.refclk

    add_interface pcie_reconfig_from_xcvr conduit end
    set_interface_property pcie_reconfig_from_xcvr EXPORT_OF pcie.reconfig_from_xcvr

    add_interface pcie_reconfig_to_xcvr conduit end
    set_interface_property pcie_reconfig_to_xcvr EXPORT_OF pcie.reconfig_to_xcvr

    # DDR / QDR, Memory-system specific
    # Conduit name is the concatentation of system type, and id (in lower case)
    foreach sys_id $system_ids {
	if {$sys_id == $primary_id} {
	    add_interface acl_internal_snoop avalon_streaming source
	    set_interface_property acl_internal_snoop EXPORT_OF system_$sys_id.acl_internal_snoop
	}

	set if_type [string tolower [dict get $mem_dict $sys_id type]]
	foreach if_id [dict get $mem_dict $sys_id interfaces] {

	    # Export Physical Pins
	    add_interface $if_type\_$if_id conduit end
	    set_interface_property $if_type\_$if_id EXPORT_OF system_$sys_id.if_$if_id

	    # Export PLL Reference 
	    if {[string match [dict get $mem_dict $sys_id $if_id role] "primary"] ||
		[string match [dict get $mem_dict $sys_id $if_id role] "independent"]} {
		add_interface $if_type\_$if_id\_pll_ref clock sink
		set_interface_property $if_type\_$if_id\_pll_ref EXPORT_OF system_$sys_id.$if_type\_$if_id\_pll_ref
	    }

	    # OCT Pins
	    if {[string match [dict get $mem_dict $sys_id $if_id role] "primary"]} {
		add_interface $if_type\_$if_id\_oct conduit end
		set_interface_property $if_type\_$if_id\_oct EXPORT_OF system_$sys_id.$if_type\_$if_id\_oct
	    }

	    # Kernel Interfaces
	    foreach port [dict get $mem_dict $sys_id $if_id ports] {
		add_interface $port avalon slave
		set_interface_property $port EXPORT_OF system_$sys_id.$port
	    }
	}
    }

    ############################################################################
    # Instances and instance parameters
    ############################################################################
    # Reset Controllers
    add_instance global_reset_in altera_reset_bridge $bsp_version
    set_instance_parameter_value global_reset_in {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value global_reset_in {SYNCHRONOUS_EDGES} {none}
    set_instance_parameter_value global_reset_in {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value global_reset_in {USE_RESET_REQUEST} {0}

    add_instance config_clk altera_clock_bridge $bsp_version
    set_instance_parameter_value config_clk {EXPLICIT_CLOCK_RATE} {50000000.0}
    set_instance_parameter_value config_clk {NUM_CLOCK_OUTPUTS} {1}

    add_instance por_reset_counter sw_reset 10.0
    set_instance_parameter_value por_reset_counter {WIDTH} {8}
    set_instance_parameter_value por_reset_counter {LOG2_RESET_CYCLES} {10}

    add_instance reset_controller_global altera_reset_controller $bsp_version
    set_instance_parameter_value reset_controller_global {NUM_RESET_INPUTS} {2}
    set_instance_parameter_value reset_controller_global {OUTPUT_RESET_SYNC_EDGES} {deassert}
    set_instance_parameter_value reset_controller_global {SYNC_DEPTH} {2}
    set_instance_parameter_value reset_controller_global {RESET_REQUEST_PRESENT} {0}
    set_instance_parameter_value reset_controller_global {RESET_REQ_WAIT_TIME} {1}
    set_instance_parameter_value reset_controller_global {MIN_RST_ASSERTION_TIME} {3}
    set_instance_parameter_value reset_controller_global {RESET_REQ_EARLY_DSRT_TIME} {1}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN0} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN1} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN2} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN3} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN4} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN5} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN6} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN7} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN8} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN9} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN10} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN11} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN12} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN13} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN14} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_IN15} {0}
    set_instance_parameter_value reset_controller_global {USE_RESET_REQUEST_INPUT} {0}

    add_instance global_reset altera_reset_bridge $bsp_version
    set_instance_parameter_value global_reset {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value global_reset {SYNCHRONOUS_EDGES} {deassert}
    set_instance_parameter_value global_reset {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value global_reset {USE_RESET_REQUEST} {0}

    add_instance reset_controller_pcie altera_reset_controller $bsp_version
    set_instance_parameter_value reset_controller_pcie {NUM_RESET_INPUTS} {1}
    set_instance_parameter_value reset_controller_pcie {OUTPUT_RESET_SYNC_EDGES} {deassert}
    set_instance_parameter_value reset_controller_pcie {SYNC_DEPTH} {2}
    set_instance_parameter_value reset_controller_pcie {RESET_REQUEST_PRESENT} {0}
    set_instance_parameter_value reset_controller_pcie {RESET_REQ_WAIT_TIME} {1}
    set_instance_parameter_value reset_controller_pcie {MIN_RST_ASSERTION_TIME} {3}
    set_instance_parameter_value reset_controller_pcie {RESET_REQ_EARLY_DSRT_TIME} {1}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN0} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN1} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN2} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN3} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN4} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN5} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN6} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN7} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN8} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN9} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN10} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN11} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN12} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN13} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN14} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_IN15} {0}
    set_instance_parameter_value reset_controller_pcie {USE_RESET_REQUEST_INPUT} {0}

    add_instance npor_export altera_reset_bridge $bsp_version
    set_instance_parameter_value npor_export {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value npor_export {SYNCHRONOUS_EDGES} {none}
    set_instance_parameter_value npor_export {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value npor_export {USE_RESET_REQUEST} {0}

    # PCIe logic 
    add_instance pcie altera_pcie_sv_hip_avmm $bsp_version
    set_instance_parameter_value pcie {pcie_qsys} {1}
    set_instance_parameter_value pcie {lane_mask_hwtcl} {x8}
    set_instance_parameter_value pcie {gen123_lane_rate_mode_hwtcl} {Gen2 (5.0 Gbps)}
    set_instance_parameter_value pcie {port_type_hwtcl} {Native endpoint}
    set_instance_parameter_value pcie {rxbuffer_rxreq_hwtcl} {Low}
    set_instance_parameter_value pcie {pll_refclk_freq_hwtcl} {100 MHz}
    set_instance_parameter_value pcie {set_pld_clk_x1_625MHz_hwtcl} {0}
    set_instance_parameter_value pcie {in_cvp_mode_hwtcl} {1}
    set_instance_parameter_value pcie {enable_tl_only_sim_hwtcl} {0}
    set_instance_parameter_value pcie {use_atx_pll_hwtcl} {0}
    set_instance_parameter_value pcie {enable_power_on_rst_pulse_hwtcl} {0}
    set_instance_parameter_value pcie {enable_pcisigtest_hwtcl} {0}
    set_instance_parameter_value pcie {hip_tag_checking_hwtcl} {1}
    set_instance_parameter_value pcie {NUM_PREFETCH_MASTERS} {1}
    set_instance_parameter_value pcie {bar0_type_hwtcl} {1}
    set_instance_parameter_value pcie {bar1_type_hwtcl} {0}
    set_instance_parameter_value pcie {bar2_type_hwtcl} {0}
    set_instance_parameter_value pcie {bar3_type_hwtcl} {0}
    set_instance_parameter_value pcie {bar4_type_hwtcl} {0}
    set_instance_parameter_value pcie {bar5_type_hwtcl} {0}
    set_instance_parameter_value pcie {CB_P2A_AVALON_ADDR_B0} {0}
    set_instance_parameter_value pcie {CB_P2A_AVALON_ADDR_B1} {0}
    set_instance_parameter_value pcie {CB_P2A_AVALON_ADDR_B2} {0}
    set_instance_parameter_value pcie {CB_P2A_AVALON_ADDR_B3} {0}
    set_instance_parameter_value pcie {CB_P2A_AVALON_ADDR_B4} {0}
    set_instance_parameter_value pcie {CB_P2A_AVALON_ADDR_B5} {0}
    set_instance_parameter_value pcie {fixed_address_mode} {0}
    set_instance_parameter_value pcie {CB_P2A_FIXED_AVALON_ADDR_B0} {0}
    set_instance_parameter_value pcie {CB_P2A_FIXED_AVALON_ADDR_B1} {0}
    set_instance_parameter_value pcie {CB_P2A_FIXED_AVALON_ADDR_B2} {0}
    set_instance_parameter_value pcie {CB_P2A_FIXED_AVALON_ADDR_B3} {0}
    set_instance_parameter_value pcie {CB_P2A_FIXED_AVALON_ADDR_B4} {0}
    set_instance_parameter_value pcie {CB_P2A_FIXED_AVALON_ADDR_B5} {0}
    set_instance_parameter_value pcie {vendor_id_hwtcl} {4466}
    set_instance_parameter_value pcie {device_id_hwtcl} {43776}
    set_instance_parameter_value pcie {revision_id_hwtcl} {1}
    set_instance_parameter_value pcie {class_code_hwtcl} {16711680}
    set_instance_parameter_value pcie {subsystem_vendor_id_hwtcl} {4466}
    set_instance_parameter_value pcie {subsystem_device_id_hwtcl} {4}
    set_instance_parameter_value pcie {max_payload_size_hwtcl} {256}
    set_instance_parameter_value pcie {extend_tag_field_hwtcl} {32}
    set_instance_parameter_value pcie {completion_timeout_hwtcl} {ABCD}
    set_instance_parameter_value pcie {enable_completion_timeout_disable_hwtcl} {1}
    set_instance_parameter_value pcie {use_aer_hwtcl} {0}
    set_instance_parameter_value pcie {ecrc_check_capable_hwtcl} {0}
    set_instance_parameter_value pcie {ecrc_gen_capable_hwtcl} {0}
    set_instance_parameter_value pcie {use_crc_forwarding_hwtcl} {0}
    set_instance_parameter_value pcie {port_link_number_hwtcl} {1}
    set_instance_parameter_value pcie {dll_active_report_support_hwtcl} {0}
    set_instance_parameter_value pcie {surprise_down_error_support_hwtcl} {0}
    set_instance_parameter_value pcie {slotclkcfg_hwtcl} {1}
    set_instance_parameter_value pcie {msi_multi_message_capable_hwtcl} {4}
    set_instance_parameter_value pcie {msi_64bit_addressing_capable_hwtcl} {true}
    set_instance_parameter_value pcie {msi_masking_capable_hwtcl} {false}
    set_instance_parameter_value pcie {msi_support_hwtcl} {true}
    set_instance_parameter_value pcie {enable_function_msix_support_hwtcl} {0}
    set_instance_parameter_value pcie {msix_table_size_hwtcl} {0}
    set_instance_parameter_value pcie {msix_table_offset_hwtcl} {0.0}
    set_instance_parameter_value pcie {msix_table_bir_hwtcl} {0}
    set_instance_parameter_value pcie {msix_pba_offset_hwtcl} {0.0}
    set_instance_parameter_value pcie {msix_pba_bir_hwtcl} {0}
    set_instance_parameter_value pcie {enable_slot_register_hwtcl} {0}
    set_instance_parameter_value pcie {slot_power_scale_hwtcl} {0}
    set_instance_parameter_value pcie {slot_power_limit_hwtcl} {0}
    set_instance_parameter_value pcie {slot_number_hwtcl} {0}
    set_instance_parameter_value pcie {endpoint_l0_latency_hwtcl} {0}
    set_instance_parameter_value pcie {endpoint_l1_latency_hwtcl} {0}
    set_instance_parameter_value pcie {CG_COMMON_CLOCK_MODE} {1}
    set_instance_parameter_value pcie {avmm_width_hwtcl} {128}
    set_instance_parameter_value pcie {AVALON_ADDR_WIDTH} {32}
    set_instance_parameter_value pcie {CB_PCIE_MODE} {0}
    set_instance_parameter_value pcie {CB_PCIE_RX_LITE} {0}
    set_instance_parameter_value pcie {AST_LITE} {0}
    set_instance_parameter_value pcie {CG_RXM_IRQ_NUM} {16}
    set_instance_parameter_value pcie {bypass_tl} {false}
    set_instance_parameter_value pcie {CG_IMPL_CRA_AV_SLAVE_PORT} {1}
    set_instance_parameter_value pcie {CG_ENABLE_ADVANCED_INTERRUPT} {0}
    set_instance_parameter_value pcie {CG_ENABLE_A2P_INTERRUPT} {0}
    set_instance_parameter_value pcie {CG_ENABLE_HIP_STATUS} {0}
    set_instance_parameter_value pcie {CG_ENABLE_HIP_STATUS_EXTENSION} {0}
    set_instance_parameter_value pcie {TX_S_ADDR_WIDTH} {32}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_IS_FIXED} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_NUM_ENTRIES} {256}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_PASS_THRU_BITS} {12}
    set_instance_parameter_value pcie {BYPASSS_A2P_TRANSLATION} {0}
    set_instance_parameter_value pcie {CB_RP_S_ADDR_WIDTH} {32}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_0_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_0_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_1_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_1_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_2_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_2_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_3_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_3_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_4_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_4_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_5_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_5_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_6_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_6_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_7_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_7_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_8_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_8_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_9_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_9_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_10_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_10_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_11_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_11_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_12_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_12_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_13_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_13_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_14_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_14_LOW} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_15_HIGH} {0}
    set_instance_parameter_value pcie {CB_A2P_ADDR_MAP_FIXED_TABLE_15_LOW} {0}
    set_instance_parameter_value pcie {AddressPage} {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}
    set_instance_parameter_value pcie {PCIeAddress63_32} {0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000}
    set_instance_parameter_value pcie {PCIeAddress31_0} {0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000}
    set_instance_parameter_value pcie {RXM_DATA_WIDTH} {64}
    set_instance_parameter_value pcie {RXM_BEN_WIDTH} {8}
    set_instance_parameter_value pcie {use_rx_st_be_hwtcl} {0}
    set_instance_parameter_value pcie {use_ast_parity} {0}
    set_instance_parameter_value pcie {hip_reconfig_hwtcl} {1}
    set_instance_parameter_value pcie {vsec_id_hwtcl} {40960}
    set_instance_parameter_value pcie {vsec_rev_hwtcl} {0}
    set_instance_parameter_value pcie {expansion_base_address_register_hwtcl} {0}
    set_instance_parameter_value pcie {io_window_addr_width_hwtcl} {0}
    set_instance_parameter_value pcie {prefetchable_mem_window_addr_width_hwtcl} {0}
    set_instance_parameter_value pcie {advanced_default_parameter_override} {0}
    set_instance_parameter_value pcie {override_tbpartner_driver_setting_hwtcl} {0}
    set_instance_parameter_value pcie {override_rxbuffer_cred_preset} {0}
    set_instance_parameter_value pcie {gen3_rxfreqlock_counter_hwtcl} {0}
    set_instance_parameter_value pcie {force_hrc} {1}
    set_instance_parameter_value pcie {force_src} {0}
    set_instance_parameter_value pcie {serial_sim_hwtcl} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_bypass_cdc} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_enable_rx_buffer_checking} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_disable_link_x2_support} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_wrong_device_id} {disable}
    set_instance_parameter_value pcie {advanced_default_hwtcl_data_pack_rx} {disable}
    set_instance_parameter_value pcie {advanced_default_hwtcl_ltssm_1ms_timeout} {disable}
    set_instance_parameter_value pcie {advanced_default_hwtcl_ltssm_freqlocked_check} {disable}
    set_instance_parameter_value pcie {advanced_default_hwtcl_deskew_comma} {com_deskw}
    set_instance_parameter_value pcie {advanced_default_hwtcl_device_number} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_pipex1_debug_sel} {disable}
    set_instance_parameter_value pcie {advanced_default_hwtcl_pclk_out_sel} {pclk}
    set_instance_parameter_value pcie {advanced_default_hwtcl_no_soft_reset} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_maximum_current} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_d1_support} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_d2_support} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_d0_pme} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_d1_pme} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_d2_pme} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_d3_hot_pme} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_d3_cold_pme} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_low_priority_vc} {single_vc}
    set_instance_parameter_value pcie {advanced_default_hwtcl_disable_snoop_packet} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_enable_l1_aspm} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_set_l0s} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_l1_exit_latency_sameclock} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_l1_exit_latency_diffclock} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_hot_plug_support} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_extended_tag_reset} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_no_command_completed} {true}
    set_instance_parameter_value pcie {advanced_default_hwtcl_interrupt_pin} {inta}
    set_instance_parameter_value pcie {advanced_default_hwtcl_bridge_port_vga_enable} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_bridge_port_ssid_support} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_ssvid} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_ssid} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_eie_before_nfts_count} {4}
    set_instance_parameter_value pcie {advanced_default_hwtcl_gen2_diffclock_nfts_count} {255}
    set_instance_parameter_value pcie {advanced_default_hwtcl_gen2_sameclock_nfts_count} {255}
    set_instance_parameter_value pcie {advanced_default_hwtcl_l0_exit_latency_sameclock} {6}
    set_instance_parameter_value pcie {advanced_default_hwtcl_l0_exit_latency_diffclock} {6}
    set_instance_parameter_value pcie {advanced_default_hwtcl_atomic_op_routing} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_atomic_op_completer_32bit} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_atomic_op_completer_64bit} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_cas_completer_128bit} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_ltr_mechanism} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_tph_completer} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_extended_format_field} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_atomic_malformed} {true}
    set_instance_parameter_value pcie {advanced_default_hwtcl_flr_capability} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_enable_adapter_half_rate_mode} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_vc0_clk_enable} {true}
    set_instance_parameter_value pcie {advanced_default_hwtcl_register_pipe_signals} {false}
    set_instance_parameter_value pcie {advanced_default_hwtcl_skp_os_gen3_count} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_tx_cdc_almost_empty} {5}
    set_instance_parameter_value pcie {advanced_default_hwtcl_rx_l0s_count_idl} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_cdc_dummy_insert_limit} {11}
    set_instance_parameter_value pcie {advanced_default_hwtcl_ei_delay_powerdown_count} {10}
    set_instance_parameter_value pcie {advanced_default_hwtcl_skp_os_schedule_count} {0}
    set_instance_parameter_value pcie {advanced_default_hwtcl_fc_init_timer} {1024}
    set_instance_parameter_value pcie {advanced_default_hwtcl_l01_entry_latency} {31}
    set_instance_parameter_value pcie {advanced_default_hwtcl_flow_control_update_count} {30}
    set_instance_parameter_value pcie {advanced_default_hwtcl_flow_control_timeout_count} {200}
    set_instance_parameter_value pcie {advanced_default_hwtcl_retry_buffer_last_active_address} {2047}
    set_instance_parameter_value pcie {advanced_default_hwtcl_reserved_debug} {0}
    set_instance_parameter_value pcie {use_cvp_update_core_pof_hwtcl} {0}
    set_instance_parameter_value pcie {pcie_inspector_hwtcl} {0}
    set_instance_parameter_value pcie {tlp_inspector_hwtcl} {0}
    set_instance_parameter_value pcie {tlp_inspector_use_signal_probe_hwtcl} {0}
    set_instance_parameter_value pcie {tlp_insp_trg_dw0_hwtcl} {2049}
    set_instance_parameter_value pcie {tlp_insp_trg_dw1_hwtcl} {0}
    set_instance_parameter_value pcie {tlp_insp_trg_dw2_hwtcl} {0}
    set_instance_parameter_value pcie {tlp_insp_trg_dw3_hwtcl} {0}
    set_instance_parameter_value pcie {hwtcl_override_g2_txvod} {1}
    set_instance_parameter_value pcie {rpre_emph_a_val_hwtcl} {9}
    set_instance_parameter_value pcie {rpre_emph_b_val_hwtcl} {0}
    set_instance_parameter_value pcie {rpre_emph_c_val_hwtcl} {16}
    set_instance_parameter_value pcie {rpre_emph_d_val_hwtcl} {13}
    set_instance_parameter_value pcie {rpre_emph_e_val_hwtcl} {5}
    set_instance_parameter_value pcie {rvod_sel_a_val_hwtcl} {42}
    set_instance_parameter_value pcie {rvod_sel_b_val_hwtcl} {38}
    set_instance_parameter_value pcie {rvod_sel_c_val_hwtcl} {38}
    set_instance_parameter_value pcie {rvod_sel_d_val_hwtcl} {43}
    set_instance_parameter_value pcie {rvod_sel_e_val_hwtcl} {15}

    add_instance pipe_stage_host_ctrl altera_avalon_mm_bridge $bsp_version
    set_instance_parameter_value pipe_stage_host_ctrl {DATA_WIDTH} {64}
    set_instance_parameter_value pipe_stage_host_ctrl {SYMBOL_WIDTH} {8}
    set_instance_parameter_value pipe_stage_host_ctrl {ADDRESS_WIDTH} {18}
    set_instance_parameter_value pipe_stage_host_ctrl {USE_AUTO_ADDRESS_WIDTH} {0}
    set_instance_parameter_value pipe_stage_host_ctrl {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value pipe_stage_host_ctrl {MAX_BURST_SIZE} {1}
    set_instance_parameter_value pipe_stage_host_ctrl {MAX_PENDING_RESPONSES} {1}
    set_instance_parameter_value pipe_stage_host_ctrl {LINEWRAPBURSTS} {0}
    set_instance_parameter_value pipe_stage_host_ctrl {PIPELINE_COMMAND} {1}
    set_instance_parameter_value pipe_stage_host_ctrl {PIPELINE_RESPONSE} {1}

    # Version, Uniphy, and Temperature
    add_instance version_id version_id 10.0
    set_instance_parameter_value version_id {WIDTH} {32}
    set_instance_parameter_value version_id {VERSION_ID} {-1597521440}

    add_instance uniphy_status uniphy_status 10.0
    set_instance_parameter_value uniphy_status {WIDTH} {32}
    set_instance_parameter_value uniphy_status {NUM_UNIPHYS} $num_intfs

    add_instance clock_cross_temp_to_pcie altera_avalon_mm_clock_crossing_bridge $bsp_version
    set_instance_parameter_value clock_cross_temp_to_pcie {DATA_WIDTH} {32}
    set_instance_parameter_value clock_cross_temp_to_pcie {SYMBOL_WIDTH} {8}
    set_instance_parameter_value clock_cross_temp_to_pcie {ADDRESS_WIDTH} {3}
    set_instance_parameter_value clock_cross_temp_to_pcie {USE_AUTO_ADDRESS_WIDTH} {1}
    set_instance_parameter_value clock_cross_temp_to_pcie {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value clock_cross_temp_to_pcie {MAX_BURST_SIZE} {1}
    set_instance_parameter_value clock_cross_temp_to_pcie {COMMAND_FIFO_DEPTH} {2}
    set_instance_parameter_value clock_cross_temp_to_pcie {RESPONSE_FIFO_DEPTH} {2}
    set_instance_parameter_value clock_cross_temp_to_pcie {MASTER_SYNC_DEPTH} {2}
    set_instance_parameter_value clock_cross_temp_to_pcie {SLAVE_SYNC_DEPTH} {2}

    add_instance reset_controller_temp altera_reset_controller $bsp_version
    set_instance_parameter_value reset_controller_temp {NUM_RESET_INPUTS} {1}
    set_instance_parameter_value reset_controller_temp {OUTPUT_RESET_SYNC_EDGES} {deassert}
    set_instance_parameter_value reset_controller_temp {SYNC_DEPTH} {2}
    set_instance_parameter_value reset_controller_temp {RESET_REQUEST_PRESENT} {0}
    set_instance_parameter_value reset_controller_temp {RESET_REQ_WAIT_TIME} {1}
    set_instance_parameter_value reset_controller_temp {MIN_RST_ASSERTION_TIME} {3}
    set_instance_parameter_value reset_controller_temp {RESET_REQ_EARLY_DSRT_TIME} {1}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN0} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN1} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN2} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN3} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN4} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN5} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN6} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN7} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN8} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN9} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN10} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN11} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN12} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN13} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN14} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_IN15} {0}
    set_instance_parameter_value reset_controller_temp {USE_RESET_REQUEST_INPUT} {0}

    add_instance temperature_pll altera_pll $bsp_version
    set_instance_parameter_value temperature_pll {debug_print_output} {0}
    set_instance_parameter_value temperature_pll {debug_use_rbc_taf_method} {0}
    set_instance_parameter_value temperature_pll {gui_device_speed_grade} {2}
    set_instance_parameter_value temperature_pll {gui_pll_mode} {Integer-N PLL}
    set_instance_parameter_value temperature_pll {gui_reference_clock_frequency} {50.0}
    set_instance_parameter_value temperature_pll {gui_channel_spacing} {0.0}
    set_instance_parameter_value temperature_pll {gui_operation_mode} {direct}
    set_instance_parameter_value temperature_pll {gui_feedback_clock} {Global Clock}
    set_instance_parameter_value temperature_pll {gui_fractional_cout} {32}
    set_instance_parameter_value temperature_pll {gui_dsm_out_sel} {1st_order}
    set_instance_parameter_value temperature_pll {gui_use_locked} {1}
    set_instance_parameter_value temperature_pll {gui_en_adv_params} {0}
    set_instance_parameter_value temperature_pll {gui_number_of_clocks} {1}
    set_instance_parameter_value temperature_pll {gui_multiply_factor} {1}
    set_instance_parameter_value temperature_pll {gui_frac_multiply_factor} {1.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_n} {1}
    set_instance_parameter_value temperature_pll {gui_cascade_counter0} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency0} {80.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c0} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency0} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units0} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift0} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg0} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift0} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle0} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter1} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency1} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c1} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency1} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units1} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift1} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg1} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift1} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle1} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter2} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency2} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c2} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency2} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units2} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift2} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg2} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift2} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle2} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter3} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency3} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c3} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency3} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units3} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift3} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg3} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift3} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle3} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter4} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency4} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c4} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency4} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units4} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift4} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg4} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift4} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle4} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter5} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency5} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c5} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency5} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units5} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift5} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg5} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift5} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle5} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter6} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency6} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c6} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency6} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units6} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift6} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg6} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift6} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle6} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter7} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency7} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c7} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency7} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units7} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift7} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg7} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift7} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle7} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter8} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency8} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c8} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency8} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units8} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift8} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg8} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift8} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle8} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter9} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency9} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c9} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency9} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units9} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift9} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg9} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift9} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle9} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter10} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency10} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c10} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency10} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units10} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift10} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg10} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift10} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle10} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter11} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency11} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c11} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency11} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units11} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift11} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg11} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift11} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle11} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter12} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency12} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c12} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency12} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units12} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift12} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg12} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift12} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle12} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter13} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency13} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c13} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency13} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units13} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift13} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg13} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift13} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle13} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter14} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency14} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c14} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency14} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units14} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift14} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg14} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift14} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle14} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter15} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency15} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c15} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency15} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units15} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift15} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg15} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift15} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle15} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter16} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency16} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c16} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency16} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units16} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift16} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg16} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift16} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle16} {50}
    set_instance_parameter_value temperature_pll {gui_cascade_counter17} {0}
    set_instance_parameter_value temperature_pll {gui_output_clock_frequency17} {100.0}
    set_instance_parameter_value temperature_pll {gui_divide_factor_c17} {1}
    set_instance_parameter_value temperature_pll {gui_actual_output_clock_frequency17} {0 MHz}
    set_instance_parameter_value temperature_pll {gui_ps_units17} {ps}
    set_instance_parameter_value temperature_pll {gui_phase_shift17} {0}
    set_instance_parameter_value temperature_pll {gui_phase_shift_deg17} {0.0}
    set_instance_parameter_value temperature_pll {gui_actual_phase_shift17} {0}
    set_instance_parameter_value temperature_pll {gui_duty_cycle17} {50}
    set_instance_parameter_value temperature_pll {gui_pll_auto_reset} {Off}
    set_instance_parameter_value temperature_pll {gui_pll_bandwidth_preset} {Auto}
    set_instance_parameter_value temperature_pll {gui_en_reconf} {0}
    set_instance_parameter_value temperature_pll {gui_en_dps_ports} {0}
    set_instance_parameter_value temperature_pll {gui_en_phout_ports} {0}
    set_instance_parameter_value temperature_pll {gui_phout_division} {1}
    set_instance_parameter_value temperature_pll {gui_en_lvds_ports} {0}
    set_instance_parameter_value temperature_pll {gui_mif_generate} {0}
    set_instance_parameter_value temperature_pll {gui_enable_mif_dps} {0}
    set_instance_parameter_value temperature_pll {gui_dps_cntr} {C0}
    set_instance_parameter_value temperature_pll {gui_dps_num} {1}
    set_instance_parameter_value temperature_pll {gui_dps_dir} {Positive}
    set_instance_parameter_value temperature_pll {gui_refclk_switch} {0}
    set_instance_parameter_value temperature_pll {gui_refclk1_frequency} {100.0}
    set_instance_parameter_value temperature_pll {gui_switchover_mode} {Automatic Switchover}
    set_instance_parameter_value temperature_pll {gui_switchover_delay} {0}
    set_instance_parameter_value temperature_pll {gui_active_clk} {0}
    set_instance_parameter_value temperature_pll {gui_clk_bad} {0}
    set_instance_parameter_value temperature_pll {gui_enable_cascade_out} {0}
    set_instance_parameter_value temperature_pll {gui_cascade_outclk_index} {0}
    set_instance_parameter_value temperature_pll {gui_enable_cascade_in} {0}
    set_instance_parameter_value temperature_pll {gui_pll_cascading_mode} {Create an adjpllin signal to connect with an upstream PLL}

    add_instance temperature_0 temperature 10.0

    # ACL Kernel Interface
    add_instance clock_cross_aclkernelclk_to_pcie altera_avalon_mm_clock_crossing_bridge $bsp_version
    set_instance_parameter_value clock_cross_aclkernelclk_to_pcie {DATA_WIDTH} {32}
    set_instance_parameter_value clock_cross_aclkernelclk_to_pcie {SYMBOL_WIDTH} {8}
    set_instance_parameter_value clock_cross_aclkernelclk_to_pcie {ADDRESS_WIDTH} {16}
    set_instance_parameter_value clock_cross_aclkernelclk_to_pcie {USE_AUTO_ADDRESS_WIDTH} {1}
    set_instance_parameter_value clock_cross_aclkernelclk_to_pcie {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value clock_cross_aclkernelclk_to_pcie {MAX_BURST_SIZE} {1}
    set_instance_parameter_value clock_cross_aclkernelclk_to_pcie {COMMAND_FIFO_DEPTH} {2}
    set_instance_parameter_value clock_cross_aclkernelclk_to_pcie {RESPONSE_FIFO_DEPTH} {2}
    set_instance_parameter_value clock_cross_aclkernelclk_to_pcie {MASTER_SYNC_DEPTH} {2}
    set_instance_parameter_value clock_cross_aclkernelclk_to_pcie {SLAVE_SYNC_DEPTH} {2}

    add_instance kernel_interface acl_kernel_interface 1.0

    add_instance acl_kernel_clk acl_kernel_clk 1.0

    set_instance_parameter_value acl_kernel_clk {REF_CLK_RATE} {50}

    add_instance clock_cross_kernel_irq altera_irq_clock_crosser $bsp_version
    set_instance_parameter_value clock_cross_kernel_irq {IRQ_WIDTH} {1}

    add_instance kernel_clk clock_source $bsp_version
    set_instance_parameter_value kernel_clk {clockFrequency} {50000000.0}
    set_instance_parameter_value kernel_clk {clockFrequencyKnown} {0}
    set_instance_parameter_value kernel_clk {resetSynchronousEdges} {DEASSERT}

    # DMA Logic
    add_instance clock_cross_dma_to_pcie altera_avalon_mm_clock_crossing_bridge $bsp_version
    set_instance_parameter_value clock_cross_dma_to_pcie {DATA_WIDTH} {512}
    set_instance_parameter_value clock_cross_dma_to_pcie {SYMBOL_WIDTH} {8}
    set_instance_parameter_value clock_cross_dma_to_pcie {ADDRESS_WIDTH} {20}
    set_instance_parameter_value clock_cross_dma_to_pcie {USE_AUTO_ADDRESS_WIDTH} {0}
    set_instance_parameter_value clock_cross_dma_to_pcie {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value clock_cross_dma_to_pcie {MAX_BURST_SIZE} {16}
    set_instance_parameter_value clock_cross_dma_to_pcie {COMMAND_FIFO_DEPTH} {16}
    set_instance_parameter_value clock_cross_dma_to_pcie {RESPONSE_FIFO_DEPTH} {64}
    set_instance_parameter_value clock_cross_dma_to_pcie {MASTER_SYNC_DEPTH} {2}
    set_instance_parameter_value clock_cross_dma_to_pcie {SLAVE_SYNC_DEPTH} {2}

    add_instance clock_cross_dmacsr_to_pcie altera_avalon_mm_clock_crossing_bridge $bsp_version
    set_instance_parameter_value clock_cross_dmacsr_to_pcie {DATA_WIDTH} {64}
    set_instance_parameter_value clock_cross_dmacsr_to_pcie {SYMBOL_WIDTH} {8}
    set_instance_parameter_value clock_cross_dmacsr_to_pcie {ADDRESS_WIDTH} {20}
    set_instance_parameter_value clock_cross_dmacsr_to_pcie {USE_AUTO_ADDRESS_WIDTH} {1}
    set_instance_parameter_value clock_cross_dmacsr_to_pcie {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value clock_cross_dmacsr_to_pcie {MAX_BURST_SIZE} {1}
    set_instance_parameter_value clock_cross_dmacsr_to_pcie {COMMAND_FIFO_DEPTH} {2}
    set_instance_parameter_value clock_cross_dmacsr_to_pcie {RESPONSE_FIFO_DEPTH} {2}
    set_instance_parameter_value clock_cross_dmacsr_to_pcie {MASTER_SYNC_DEPTH} {2}
    set_instance_parameter_value clock_cross_dmacsr_to_pcie {SLAVE_SYNC_DEPTH} {2}

    add_instance clock_cross_dmanondma_to_pcie altera_avalon_mm_clock_crossing_bridge $bsp_version
    set_instance_parameter_value clock_cross_dmanondma_to_pcie {DATA_WIDTH} {64}
    set_instance_parameter_value clock_cross_dmanondma_to_pcie {SYMBOL_WIDTH} {8}
    set_instance_parameter_value clock_cross_dmanondma_to_pcie {ADDRESS_WIDTH} {20}
    set_instance_parameter_value clock_cross_dmanondma_to_pcie {USE_AUTO_ADDRESS_WIDTH} {1}
    set_instance_parameter_value clock_cross_dmanondma_to_pcie {ADDRESS_UNITS} {SYMBOLS}
    set_instance_parameter_value clock_cross_dmanondma_to_pcie {MAX_BURST_SIZE} {1}
    set_instance_parameter_value clock_cross_dmanondma_to_pcie {COMMAND_FIFO_DEPTH} {2}
    set_instance_parameter_value clock_cross_dmanondma_to_pcie {RESPONSE_FIFO_DEPTH} {2}
    set_instance_parameter_value clock_cross_dmanondma_to_pcie {MASTER_SYNC_DEPTH} {2}
    set_instance_parameter_value clock_cross_dmanondma_to_pcie {SLAVE_SYNC_DEPTH} {2}

    add_instance clock_cross_dma_irq altera_irq_clock_crosser $bsp_version
    set_instance_parameter_value clock_cross_dma_irq {IRQ_WIDTH} {1}

    add_instance dma acl_dma 1.0
    set_instance_parameter_value dma {BYTE_ADDR_WIDTH} {34}
    set_instance_parameter_value dma {DATA_WIDTH} {512}
    set_instance_parameter_value dma {BURST_SIZE} {16}

    foreach sys_id $system_ids {
	set if_type [string tolower [dict get $mem_dict $sys_id type]]
	if {[string match $if_type "qdrii"]} {
	    add_instance system_$sys_id qdr_system $bsp_version
	    set_instance_parameter_value system_$sys_id {BOARD_PATH} $bsp_path
	    set_instance_parameter_value system_$sys_id {MEMORY_SYS_ID} $sys_id
	} elseif {[string match $if_type "ddr3"]} {
	    add_instance system_$sys_id ddr_system $bsp_version
	    set_instance_parameter_value system_$sys_id {BOARD_PATH} $bsp_path
	    set_instance_parameter_value system_$sys_id {MEMORY_SYS_ID} $sys_id
	}
    }

    ############################################################################
    # connections and connection parameters (Organized by source)
    ############################################################################
    # Clocks and resets
    add_connection global_reset_in.out_reset por_reset_counter.clk_reset reset

    add_connection config_clk.out_clk acl_kernel_clk.clk clock
    add_connection config_clk.out_clk global_reset.clk clock
    add_connection config_clk.out_clk por_reset_counter.clk clock
    add_connection config_clk.out_clk reset_controller_global.clk clock
    add_connection config_clk.out_clk temperature_pll.refclk clock

    add_connection por_reset_counter.sw_reset npor_export.in_reset reset
    add_connection por_reset_counter.sw_reset reset_controller_global.reset_in0 reset

    add_connection reset_controller_global.reset_out global_reset.in_reset reset

    add_connection global_reset.out_reset acl_kernel_clk.reset reset
    add_connection global_reset.out_reset clock_cross_aclkernelclk_to_pcie.m0_reset reset
    foreach sys_id $system_ids {
	add_connection global_reset.out_reset system_$sys_id.global_reset reset
    }
    add_connection global_reset.out_reset reset_controller_temp.reset_in0 reset
    add_connection global_reset.out_reset temperature_pll.reset reset
    add_connection global_reset.out_reset reset_controller_pcie.reset_in0 reset

    add_connection reset_controller_pcie.reset_out clock_cross_aclkernelclk_to_pcie.s0_reset reset
    add_connection reset_controller_pcie.reset_out clock_cross_dmacsr_to_pcie.s0_reset reset
    add_connection reset_controller_pcie.reset_out clock_cross_dma_irq.sender_clk_reset reset
    add_connection reset_controller_pcie.reset_out clock_cross_dma_to_pcie.m0_reset reset
    add_connection reset_controller_pcie.reset_out clock_cross_dmanondma_to_pcie.s0_reset reset
    add_connection reset_controller_pcie.reset_out clock_cross_kernel_irq.sender_clk_reset reset
    add_connection reset_controller_pcie.reset_out clock_cross_temp_to_pcie.s0_reset reset
    add_connection reset_controller_pcie.reset_out kernel_interface.reset reset
    add_connection reset_controller_pcie.reset_out kernel_interface.sw_reset_in reset
    add_connection reset_controller_pcie.reset_out pipe_stage_host_ctrl.reset reset
    add_connection reset_controller_pcie.reset_out uniphy_status.clk_reset reset
    add_connection reset_controller_pcie.reset_out version_id.clk_reset reset

    add_connection pcie.coreclkout clock_cross_aclkernelclk_to_pcie.s0_clk clock
    add_connection pcie.coreclkout clock_cross_dmacsr_to_pcie.s0_clk clock
    add_connection pcie.coreclkout clock_cross_dmanondma_to_pcie.s0_clk clock
    add_connection pcie.coreclkout clock_cross_dma_irq.sender_clk clock
    add_connection pcie.coreclkout clock_cross_dma_to_pcie.m0_clk clock
    add_connection pcie.coreclkout clock_cross_kernel_irq.sender_clk clock
    add_connection pcie.coreclkout clock_cross_temp_to_pcie.s0_clk clock
    add_connection pcie.coreclkout kernel_interface.clk clock
    add_connection pcie.coreclkout pipe_stage_host_ctrl.clk clock
    add_connection pcie.coreclkout reset_controller_pcie.clk clock
    add_connection pcie.coreclkout uniphy_status.clk clock
    add_connection pcie.coreclkout version_id.clk clock
    add_connection pcie.nreset_status reset_controller_global.reset_in1 reset

    add_connection reset_controller_temp.reset_out clock_cross_temp_to_pcie.m0_reset reset
    add_connection reset_controller_temp.reset_out temperature_0.clk_reset reset

    add_connection temperature_pll.outclk0 clock_cross_temp_to_pcie.m0_clk clock
    add_connection temperature_pll.outclk0 reset_controller_temp.clk clock

    add_connection config_clk.out_clk clock_cross_aclkernelclk_to_pcie.m0_clk clock

    add_connection temperature_pll.outclk0 temperature_0.clk clock

    add_connection acl_kernel_clk.kernel_clk clock_cross_kernel_irq.receiver_clk clock
    add_connection acl_kernel_clk.kernel_clk kernel_clk.clk_in clock
    add_connection acl_kernel_clk.kernel_clk kernel_interface.kernel_clk clock

    foreach sys_id $system_ids {
	add_connection acl_kernel_clk.kernel_clk system_$sys_id.kernel_clk clock
    }
    #add_connection acl_kernel_clk.kernel_clk system_1.kernel_clk clock

    add_connection kernel_interface.kernel_reset kernel_clk.clk_in_reset reset
    add_connection kernel_interface.kernel_reset clock_cross_kernel_irq.receiver_clk_reset reset
    foreach sys_id $system_ids {
	add_connection kernel_interface.kernel_reset system_$sys_id.kernel_reset reset
	add_connection kernel_interface.sw_reset_export system_$sys_id.sw_kernel_reset reset
    }
    # add_connection kernel_interface.kernel_reset system_0.kernel_reset reset
    # add_connection kernel_interface.kernel_reset system_1.kernel_reset reset
    # add_connection kernel_interface.sw_reset_export system_0.sw_kernel_reset reset
    # add_connection kernel_interface.sw_reset_export system_1.sw_kernel_reset reset

    add_connection system_$primary_id.system_clk dma.clk clock
    add_connection system_$primary_id.system_clk clock_cross_dmacsr_to_pcie.m0_clk clock
    add_connection system_$primary_id.system_clk clock_cross_dma_irq.receiver_clk clock
    add_connection system_$primary_id.system_clk clock_cross_dma_to_pcie.s0_clk clock
    add_connection system_$primary_id.system_clk clock_cross_dmanondma_to_pcie.m0_clk clock
    add_connection system_$primary_id.system_reset dma.reset reset
    add_connection system_$primary_id.system_reset clock_cross_dmacsr_to_pcie.m0_reset reset
    add_connection system_$primary_id.system_reset clock_cross_dma_irq.receiver_clk_reset reset
    add_connection system_$primary_id.system_reset clock_cross_dma_to_pcie.s0_reset reset
    add_connection system_$primary_id.system_reset clock_cross_dmanondma_to_pcie.m0_reset reset

    foreach sec_id $secondary_ids {
	add_connection system_$primary_id.system_clk system_$sec_id.dma_clk clock
	add_connection system_$primary_id.system_reset system_$sec_id.dma_reset reset
    }
    # add_connection system_0.system_clk system_1.dma_clk clock
    # add_connection system_0.system_reset system_1.dma_reset reset

    # IRQ
    add_connection pcie.RxmIrq clock_cross_kernel_irq.sender interrupt
    set_connection_parameter_value pcie.RxmIrq/clock_cross_kernel_irq.sender irqNumber {0}

    add_connection clock_cross_kernel_irq.receiver kernel_interface.kernel_irq_to_host interrupt
    set_connection_parameter_value clock_cross_kernel_irq.receiver/kernel_interface.kernel_irq_to_host irqNumber {0}

    add_connection pcie.RxmIrq clock_cross_dma_irq.sender interrupt
    set_connection_parameter_value pcie.RxmIrq/clock_cross_dma_irq.sender irqNumber {1}

    add_connection clock_cross_dma_irq.receiver dma.dma_irq interrupt
    set_connection_parameter_value clock_cross_dma_irq.receiver/dma.dma_irq irqNumber {0}

    # Avalon Connections
    # PCIe RX Master
    add_connection pcie.Rxm_BAR0 pipe_stage_host_ctrl.s0 avalon
    set_connection_parameter_value pcie.Rxm_BAR0/pipe_stage_host_ctrl.s0 arbitrationPriority {1}
    set_connection_parameter_value pcie.Rxm_BAR0/pipe_stage_host_ctrl.s0 baseAddress {0x0000}
    set_connection_parameter_value pcie.Rxm_BAR0/pipe_stage_host_ctrl.s0 defaultConnection {0}

    add_connection pipe_stage_host_ctrl.m0 pcie.Cra avalon
    set_connection_parameter_value pipe_stage_host_ctrl.m0/pcie.Cra arbitrationPriority {1}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/pcie.Cra baseAddress {0x0000}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/pcie.Cra defaultConnection {0}

    add_connection pipe_stage_host_ctrl.m0 kernel_interface.kernel_cntrl avalon
    set_connection_parameter_value pipe_stage_host_ctrl.m0/kernel_interface.kernel_cntrl arbitrationPriority {1}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/kernel_interface.kernel_cntrl baseAddress {0x4000}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/kernel_interface.kernel_cntrl defaultConnection {0}

    add_connection pipe_stage_host_ctrl.m0 clock_cross_aclkernelclk_to_pcie.s0 avalon
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_aclkernelclk_to_pcie.s0 arbitrationPriority {1}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_aclkernelclk_to_pcie.s0 baseAddress {0xc000}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_aclkernelclk_to_pcie.s0 defaultConnection {0}

    add_connection clock_cross_aclkernelclk_to_pcie.m0 acl_kernel_clk.ctrl avalon
    set_connection_parameter_value clock_cross_aclkernelclk_to_pcie.m0/acl_kernel_clk.ctrl arbitrationPriority {1}
    set_connection_parameter_value clock_cross_aclkernelclk_to_pcie.m0/acl_kernel_clk.ctrl baseAddress {0x0000}
    set_connection_parameter_value clock_cross_aclkernelclk_to_pcie.m0/acl_kernel_clk.ctrl defaultConnection {0}

    add_connection pipe_stage_host_ctrl.m0 clock_cross_dmacsr_to_pcie.s0 avalon
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_dmacsr_to_pcie.s0 arbitrationPriority {1}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_dmacsr_to_pcie.s0 baseAddress {0xc800}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_dmacsr_to_pcie.s0 defaultConnection {0}

    add_connection clock_cross_dmacsr_to_pcie.m0 dma.csr avalon
    set_connection_parameter_value clock_cross_dmacsr_to_pcie.m0/dma.csr arbitrationPriority {1}
    set_connection_parameter_value clock_cross_dmacsr_to_pcie.m0/dma.csr baseAddress {0x0000}
    set_connection_parameter_value clock_cross_dmacsr_to_pcie.m0/dma.csr defaultConnection {0}

    add_connection pipe_stage_host_ctrl.m0 version_id.s avalon
    set_connection_parameter_value pipe_stage_host_ctrl.m0/version_id.s arbitrationPriority {1}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/version_id.s baseAddress {0xcfc0}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/version_id.s defaultConnection {0}

    add_connection pipe_stage_host_ctrl.m0 uniphy_status.s avalon
    set_connection_parameter_value pipe_stage_host_ctrl.m0/uniphy_status.s arbitrationPriority {1}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/uniphy_status.s baseAddress {0xcfe0}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/uniphy_status.s defaultConnection {0}

    add_connection pipe_stage_host_ctrl.m0 clock_cross_temp_to_pcie.s0 avalon
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_temp_to_pcie.s0 arbitrationPriority {1}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_temp_to_pcie.s0 baseAddress {0xcff0}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_temp_to_pcie.s0 defaultConnection {0}

    add_connection clock_cross_temp_to_pcie.m0 temperature_0.s avalon
    set_connection_parameter_value clock_cross_temp_to_pcie.m0/temperature_0.s arbitrationPriority {1}
    set_connection_parameter_value clock_cross_temp_to_pcie.m0/temperature_0.s baseAddress {0x0000}
    set_connection_parameter_value clock_cross_temp_to_pcie.m0/temperature_0.s defaultConnection {0}

    add_connection pipe_stage_host_ctrl.m0 clock_cross_dmanondma_to_pcie.s0 avalon
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_dmanondma_to_pcie.s0 arbitrationPriority {1}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_dmanondma_to_pcie.s0 baseAddress {0x00010000}
    set_connection_parameter_value pipe_stage_host_ctrl.m0/clock_cross_dmanondma_to_pcie.s0 defaultConnection {0}

    add_connection clock_cross_dmanondma_to_pcie.m0 dma.s_nondma avalon
    set_connection_parameter_value clock_cross_dmanondma_to_pcie.m0/dma.s_nondma arbitrationPriority {1}
    set_connection_parameter_value clock_cross_dmanondma_to_pcie.m0/dma.s_nondma baseAddress {0x0000}
    set_connection_parameter_value clock_cross_dmanondma_to_pcie.m0/dma.s_nondma defaultConnection {0}


    # DMA
    add_connection dma.m clock_cross_dma_to_pcie.s0 avalon
    set_connection_parameter_value dma.m/clock_cross_dma_to_pcie.s0 arbitrationPriority {1}
    set_connection_parameter_value dma.m/clock_cross_dma_to_pcie.s0 baseAddress {0x0000000200000000}
    set_connection_parameter_value dma.m/clock_cross_dma_to_pcie.s0 defaultConnection {0}

    add_connection clock_cross_dma_to_pcie.m0 pcie.Txs avalon
    set_connection_parameter_value clock_cross_dma_to_pcie.m0/pcie.Txs arbitrationPriority {1}
    set_connection_parameter_value clock_cross_dma_to_pcie.m0/pcie.Txs baseAddress {0x0000}
    set_connection_parameter_value clock_cross_dma_to_pcie.m0/pcie.Txs defaultConnection {0}

    # Memory Systems
    foreach sys_id $system_ids {
	set base_address [dict get $mem_dict $sys_id address]
	add_connection dma.m system_$sys_id.dma_rw avalon
	set_connection_parameter_value dma.m/system_$sys_id.dma_rw arbitrationPriority {1}
	set_connection_parameter_value dma.m/system_$sys_id.dma_rw baseAddress $base_address
	set_connection_parameter_value dma.m/system_$sys_id.dma_rw defaultConnection {0}
    }

    # Memorg connections
    foreach sys_id $system_ids {
	set config_addr [dict get $mem_dict $sys_id config_addr]
	set quantity [llength [dict get $mem_dict $sys_id interfaces]]
	# handles odd requirement Dictated by Altera OpenCL
	if {$quantity > 1} {
	    add_connection kernel_interface.mem_org_mode_$config_addr\_host system_$sys_id.memorg_host conduit
	    set_connection_parameter_value kernel_interface.mem_org_mode_$config_addr\_host/system_$sys_id.memorg_host endPort {}
	    set_connection_parameter_value kernel_interface.mem_org_mode_$config_addr\_host/system_$sys_id.memorg_host endPortLSB {0}
	    set_connection_parameter_value kernel_interface.mem_org_mode_$config_addr\_host/system_$sys_id.memorg_host startPort {}
	    set_connection_parameter_value kernel_interface.mem_org_mode_$config_addr\_host/system_$sys_id.memorg_host startPortLSB {0}
	    set_connection_parameter_value kernel_interface.mem_org_mode_$config_addr\_host/system_$sys_id.memorg_host width {0}
	}
    }

    # Uniphy status
    set idx 0
    foreach sys_id $system_ids {
	foreach if_id [dict get $mem_dict $sys_id interfaces] {
	    add_connection uniphy_status.mem$idx\_status system_$sys_id.if_$if_id\_status conduit
	    set_connection_parameter_value uniphy_status.mem$idx\_status/system_$sys_id.if_$if_id\_status endPort {}
	    set_connection_parameter_value uniphy_status.mem$idx\_status/system_$sys_id.if_$if_id\_status endPortLSB {0}
	    set_connection_parameter_value uniphy_status.mem$idx\_status/system_$sys_id.if_$if_id\_status startPort {}
	    set_connection_parameter_value uniphy_status.mem$idx\_status/system_$sys_id.if_$if_id\_status startPortLSB {0}
	    set_connection_parameter_value uniphy_status.mem$idx\_status/system_$sys_id.if_$if_id\_status width {0}
	    incr idx

	}
	# interconnect requirements
	set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
	set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {2}
    }
}
