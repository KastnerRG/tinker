lappend auto_path /usr/lib/Tclxml3.2
package require xml
set board_path "/home/drichmond/Research/repositories/git/Tinker/board/de5net/de5_2XD2GB_4XQ8MB_4XL1MB"

set board_file $board_path/board_specification.xml
set board_fp [open $board_file]
set board_dom [dom::parse [read $board_fp]]

foreach type [dom::selectNode $board_dom {/board/global_mem/@type}] {
    foreach id [dom::selectNode $board_dom /board/global_mem\[@type=\"[$type stringValue]\"\]/interface/@id] {
        puts "set_global_assignment -name VERILOG_MACRO [string toupper \"Enable_[$type stringValue][$id stringValue]\"]"
    }
}
