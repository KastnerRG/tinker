
package require ::quartus::flow
package require ::quartus::project

post_message "Running post-flow script"

# Dynamically determine the project name by finding the qpf in the directory.
set qpf_files [glob -nocomplain *.qpf]

if {[llength $qpf_files] == 0} {
    error "No QSF detected"
} elseif {[llength $qpf_files] > 1} {
    post_message "Warning: More than one QSF detected. Picking the first one."
}

set qpf_file [lindex $qpf_files 0]
set project_name [string range $qpf_file 0 [expr [string first . $qpf_file] - 1]]

post_message "Project name: $project_name"

project_open $project_name

# Run PLL adjust script
post_message "Running PLL adjustment script"
if {[catch {set sdk_root $::env(ALTERAOCLSDKROOT)} result]} {
          post_message -type error "OpenCL SDK installation not found.  Make sure ALTERAOCLSDKROOT is correctly set" -submsgs [list "Guaranteed timing flow not run - you may have timing failures on the kernel clock\n"]
    } else {
        source $::env(ALTERAOCLSDKROOT)/ip/board/bsp/adjust_plls.tcl
    }

# Generate CvP files
post_message "Generating CvP files"
if {[catch {execute_module -tool cpf -args "-c --cvp top.sof top.rbf"} result]} {
  post_message "Error generating CvP files! $result"
  exit 2
}

# Generate fpga.bin used for reprogramming
post_message "Generating fpga.bin"
if {[catch {qexec "quartus_sh -t scripts/create_fpga_bin.tcl top.sof top.core.rbf"} res]} {
  post_message "Error in create_fpga_bin.tcl! $res"
  exit 2
}
