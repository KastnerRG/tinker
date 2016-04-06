package require -exact qsys 14.0

# module properties
set_module_property NAME {system_export}
set_module_property DISPLAY_NAME {system_export_display}

# default module properties
set_module_property VERSION {1.0}
set_module_property GROUP {default group}
set_module_property DESCRIPTION {default description}
set_module_property AUTHOR {author}

set_module_property COMPOSITION_CALLBACK compose
set_module_property opaque_address_map false

proc compose { } {
    # Instances and instance parameters
    # (disabled instances are intentionally culled)
    add_instance acl_iface acl_iface_system 1.0

    add_instance global_reset altera_reset_bridge 14.1
    set_instance_parameter_value global_reset {ACTIVE_LOW_RESET} {1}
    set_instance_parameter_value global_reset {SYNCHRONOUS_EDGES} {none}
    set_instance_parameter_value global_reset {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value global_reset {USE_RESET_REQUEST} {0}

    # connections and connection parameters
    add_connection global_reset.out_reset acl_iface.global_reset reset

    # exported interfaces
    add_interface config_clk clock sink
    set_interface_property config_clk EXPORT_OF acl_iface.config_clk
    add_interface ddr3a conduit end
    set_interface_property ddr3a EXPORT_OF acl_iface.ddr3a
    add_interface ddr3a_mem_oct conduit end
    set_interface_property ddr3a_mem_oct EXPORT_OF acl_iface.ddr3a_oct
    add_interface ddr3a_pll_ref clock sink
    set_interface_property ddr3a_pll_ref EXPORT_OF acl_iface.ddr3a_pll_ref
    add_interface ddr3b conduit end
    set_interface_property ddr3b EXPORT_OF acl_iface.ddr3b
    add_interface global_reset reset sink
    set_interface_property global_reset EXPORT_OF global_reset.in_reset
    add_interface kernel_pll_refclk clock sink
    set_interface_property kernel_pll_refclk EXPORT_OF acl_iface.kernel_pll_refclk
    add_interface pcie conduit end
    set_interface_property pcie EXPORT_OF acl_iface.pcie_hip_serial
    add_interface pcie_npor conduit end
    set_interface_property pcie_npor EXPORT_OF acl_iface.pcie_npor
    add_interface pcie_npor_out reset source
    set_interface_property pcie_npor_out EXPORT_OF acl_iface.pcie_npor_out
    add_interface pcie_refclk clock sink
    set_interface_property pcie_refclk EXPORT_OF acl_iface.pcie_refclk
    add_interface qdriia conduit end
    set_interface_property qdriia EXPORT_OF acl_iface.qdriia
    add_interface qdriib conduit end
    set_interface_property qdriib EXPORT_OF acl_iface.qdriib
    add_interface qdriib_mem_oct conduit end
    set_interface_property qdriib_mem_oct EXPORT_OF acl_iface.qdriib_oct
    add_interface qdriib_pll_ref clock sink
    set_interface_property qdriib_pll_ref EXPORT_OF acl_iface.qdriib_pll_ref
    add_interface qdriic conduit end
    set_interface_property qdriic EXPORT_OF acl_iface.qdriic
    add_interface qdriid conduit end
    set_interface_property qdriid EXPORT_OF acl_iface.qdriid
    add_interface qdriid_pll_ref clock sink
    set_interface_property qdriid_pll_ref EXPORT_OF acl_iface.qdriid_pll_ref
    add_interface reconfig_from_xcvr conduit end
    set_interface_property reconfig_from_xcvr EXPORT_OF acl_iface.reconfig_from_xcvr
    add_interface reconfig_to_xcvr conduit end
    set_interface_property reconfig_to_xcvr EXPORT_OF acl_iface.reconfig_to_xcvr

    # interconnect requirements
    set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {FIFO}
    set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {0}
}
