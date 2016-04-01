package require ::quartus::flow
package require ::quartus::project

set top top

file copy -force $top.qsf $top.qsf.ba

#if {[catch {execute_module -tool cdb -args "top --back_annotate=lc"} result]} {
if {[catch {qexec "quartus_cdb $top --back_annotate=lc"} result]} {
  post_message "Error back annotating: $result"
  exit 2
}

set f [open $top.qsf r]
set data [read $f]
close $f
set qsf [split $data \n]

set greppedqsf [list]

#To clone the original shell version, do these separately

#grep PLL
foreach l $qsf {
  if { [string match "*PLL*" $l ] == 1 } {
    lappend greppedqsf $l
  }
}

#grep DLL
foreach l $qsf {
  if { [string match "*DLL*" $l ] == 1 } {
    lappend greppedqsf $l
  }
}

#grep GLOBAL_SIGNAL
foreach l $qsf {
  if { [string match "*GLOBAL_SIGNAL*" $l ] == 1 } {
    lappend greppedqsf $l
  }
}

#grep CLKCTRL
foreach l $qsf {
  if { [string match "*CLKCTRL*" $l ] == 1 } {
    regsub {_Duplicate} $l "" x
    lappend greppedqsf $x
  }
}

set greppedqsf [lsort -unique $greppedqsf]

set f [open extra_qsf_constraints.qsf w]
puts $f [join $greppedqsf "\n"]
close $f

file copy -force $top.qsf $top.qsf.full_lc
file copy -force $top.qsf.ba $top.qsf

project_open $top
source extra_qsf_constraints.qsf
project_close 
