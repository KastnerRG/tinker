
# Required packages


##############################################################################
##############################       MAIN        #############################
##############################################################################


# Create the file "fpga.bin" with board-specific programming files.
# At host program runtime, when the device needs to be reprogrammed
# an in-memory buffer with the contents of this "fpga.bin" file will be
# given to the board-specific communication layer.
# The memory buffer will be aligned to 128 bytes.
#
# This script expects two file arguments:
#  The first is the name of the SOF file, typically "top.sof"
#  The second is the name of the Core RBF file, typically "top.core.rbf"

# In this flow we create an ELF-formatted file with two sections.
# Section ".acl.sof" contains the contents of the SOF file.
# Section ".acl.core.rbf" contains the contents of the Core RBF file.
# Both secitons are aligned to 128 bytes.

set prog "create_fpga_bin.tcl"
set outfile "fpga.bin"
post_message "Creating $outfile from files: $argv"

set num_files 0
set file_sizes [list]
set files [list]

for {set i 0} {$i < $argc} {incr i} {
   set f [lindex $argv $i]

   if { [file exists $f] } {
     incr num_files
     lappend file_sizes [file size $f]
     lappend files $f
   }
}

if { $num_files != 2 } {
   post_message "$prog: Need exactly two file arguments: a SOF file and a Core RBF file"
}
set sof_file [ lindex $files 0 ]
set rbf_file [ lindex $files 1 ]

post_message "$prog: Input files: $files"
file delete $outfile

if {[catch {qexec "aocl binedit $outfile create"} res]} {
  post_message "$prog: Can't create device specific binary file fragment $outfile: $res"
  exit 2
}
if {[catch {qexec "aocl binedit $outfile add .acl.sof $sof_file"} res]} {
  post_message "$prog: Can't add SOF file $sof_file to $outfile: $res"
  exit 2
}
if {[catch {qexec "aocl binedit $outfile add .acl.core.rbf $rbf_file"} res]} {
  post_message "$prog: Can't add Core RBF file $rbf_file to $outfile: $res"
  exit 2
}
post_message "$prog: Created $outfile with two sections"
