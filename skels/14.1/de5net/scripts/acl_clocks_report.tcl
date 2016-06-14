#Run using: quartus_sta -t <script.tcl> <project>
set report_file acl_clocks_report.txt

if { $argc != 1} {error "Error: Usage: quartus_sta -t <script.tcl> <project_name>" }

set proj [lindex $argv 0]

project_open $proj

create_timing_netlist

read_sdc
update_timing_netlist

report_timing -setup -from_clock [get_clocks { kernel_clk }] -to_clock [get_clocks { kernel_clk }] -npaths 10 -detail full_path -panel_name {Kernel 1x Clock Setup} -file $report_file

report_timing -setup -from_clock [get_clocks { kernel_clk2x }] -to_clock [get_clocks { kernel_clk2x }] -npaths 10 -detail full_path -panel_name {Kernel 2x Clock Setup} -file $report_file -append

project_close
