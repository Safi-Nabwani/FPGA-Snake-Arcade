# Offline mock test. Never loads the real JTAG package or accesses a board.
package provide ::quartus::jtag 1.0
rename after actual_after
proc after {args} {}
set argv {MOCK_CABLE MOCK_FPGA}
set quartus(args) $argv
set writes 0
set reads 0
set closed 0
array set selected {}
proc open_device {args} {}
proc device_lock {args} {}
proc device_unlock {} {}
proc close_device {} {set ::closed 1}
# Flags are valueless, so parse only the two explicit key/value options.
proc device_virtual_ir_shift {args} {
    set index [lindex $args [expr {[lsearch -exact $args -instance_index]+1}]]
    set value [lindex $args [expr {[lsearch -exact $args -ir_value]+1}]]
    set ::selected($index) $value
    incr ::writes
}
proc device_virtual_dr_shift {args} {
    set index [lindex $args [expr {[lsearch -exact $args -instance_index]+1}]]
    incr ::reads
    return [format %08X%08X%s [expr {0x44500000+$index}] $::selected($index) [string repeat 0 48]]
}
source scripts/read_audio_noise_probe.tcl
if {!$closed || $writes!=120 || $reads!=240} {error "Offline reader protocol mismatch"}
puts "AUDIO_NOISE_READER_PASS writes=$writes reads=$reads closed=$closed"
