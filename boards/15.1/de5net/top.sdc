#**************************************************************
# This .sbc file is created by Terasic Tool.
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
create_clock -period 50MHz [get_ports OSC_50_B3B]
create_clock -period 50MHz [get_ports OSC_50_B3D]
create_clock -period 50MHz [get_ports OSC_50_B4A]
create_clock -period 50MHz [get_ports OSC_50_B4D]
create_clock -period 50MHz [get_ports OSC_50_B7A]
create_clock -period 50MHz [get_ports OSC_50_B7D]
create_clock -period 50MHz [get_ports OSC_50_B8A]
create_clock -period 50MHz [get_ports OSC_50_B8D]

create_clock -period 100MHz [get_ports pcie_refclk]

# Override the default 10 MHz JTAG TCK:
create_clock -name altera_reserved_tck -period 30.00  -waveform {0.000 15.0} {altera_reserved_tck}
set_input_delay -clock altera_reserved_tck 8 [get_ports altera_reserved_tdi]
set_input_delay -clock altera_reserved_tck 8 [get_ports altera_reserved_tms]
set_output_delay -clock altera_reserved_tck -clock_fall  -fall -max 10 [get_ports altera_reserved_tdo]
set_output_delay -clock altera_reserved_tck -clock_fall  -rise -max 10 [get_ports altera_reserved_tdo]
set_output_delay -clock altera_reserved_tck -clock_fall  -fall -min .2 [get_ports altera_reserved_tdo]
set_output_delay -clock altera_reserved_tck -clock_fall  -rise -min .2 [get_ports altera_reserved_tdo]

#set_clock_groups -exclusive -group [get_clocks { *central_clk_div0* }] -group [get_clocks { *_hssi_pcie_hip* }]
#set_clock_groups -exclusive -group [get_clocks { refclk*clkout }] -group [get_clocks { *div0*coreclkout}]
#**************************************************************
# Set Clock Latency
#**************************************************************

#**************************************************************
# Set Input Delay
#**************************************************************

#**************************************************************
# Set Output Delay
#**************************************************************

#**************************************************************
# Set Multicycle Path
#**************************************************************

#**************************************************************
# Set Maximum Delay
#**************************************************************

#**************************************************************
# Set Minimum Delay
#**************************************************************

#**************************************************************
# Set Input Transition
#**************************************************************

#**************************************************************
# Set Load
#**************************************************************
