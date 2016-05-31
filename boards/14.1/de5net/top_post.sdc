#**************************************************************
# Create Generated Clock
#**************************************************************
derive_pll_clocks 

#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty

#**************************************************************
# Set Clock Groups
#**************************************************************
set_clock_groups -asynchronous \
-group { \
   OSC_50_B3B \
} -group { \
   OSC_50_B3D \
} -group { \
   OSC_50_B4A \
} -group { \
   OSC_50_B4D \
} -group { \
   OSC_50_B7A \
} -group { \
   OSC_50_B7D \
} -group { \
   OSC_50_B8A \
} -group { \
   OSC_50_B8D \
} -group { \
   pcie_refclk \
   [get_clocks {system_inst|tinker|pcie|*}] \
} -group { \
   [get_clocks {system_inst|tinker|acl_kernel_clk|kernel_pll|*}] \
} -group { \
   altera_reserved_tck \
} -group { \
    [get_clocks {system_inst|tinker|ddr_system|*}] \
} -group {
    [get_clocks {system_inst|tinker|qdr_system|*}] \
}

#**************************************************************
# Set False Path
#**************************************************************

# Cut path to uniphy reset, this reset is asyncronous
set_false_path -from system:system_inst|system_tinker:tinker|altera_reset_controller:reset_controller_global|altera_reset_synchronizer:alt_rst_sync_uq1|altera_reset_synchronizer_int_chain_out -to [get_registers *umemphy*ureset*reset_reg*]

# Cut path to pcie npor - this signal is asynchronous
set_false_path -from system:system_inst|system_tinker:tinker|sw_reset:por_reset_counter|sw_reset_n_out -to system:system_inst|system_tinker:tinker|altera_pcie_sv_hip_avmm:pcie*

# Optionally overconstrain the kernel clock in the iface or relax the kernel
#if { $::TimeQuestInfo(nameofexecutable) == "quartus_fit" } {
#set_max_delay -to [get_clocks system_inst|acl_iface|acl_kernel_clk|kernel_pll|altera_pll_i|stratixv_pll|counter[0].output_counter|divclk] -through system_inst|acl_iface* 2.5
#set_max_delay -to [get_clocks system_inst|acl_iface|acl_kernel_clk|kernel_pll|altera_pll_i|stratixv_pll|counter[1].output_counter|divclk] -through system_inst|acl_iface* 1.25
#set non_iface_keepers [remove_from_collection [get_keepers *] [get_keepers system_inst\|acl_iface\|*]]
#set_max_delay 3.5 -from $non_iface_keepers -to $non_iface_keepers
#}

# Optionally tell router not to worry about these since post-place and routed
#set_false_path -to [get_clocks system_inst|acl_iface|ddr3*]
#set_false_path -to [get_clocks system_inst|acl_iface|pcie*]
#set_false_path -to [get_clocks Mem*]
#set_false_path -from [get_clocks system_inst|acl_iface|ddr3*]
#set_false_path -from [get_clocks system_inst|acl_iface|pcie*]
#set_false_path -from [get_clocks Mem*]
