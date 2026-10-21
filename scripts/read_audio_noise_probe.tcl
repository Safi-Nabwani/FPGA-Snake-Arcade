# Read-only diagnostic snapshots. Does not program, reset, or control audio.
# No arguments: list exact cable/device names. Two arguments: capture 20 sets.
package require ::quartus::jtag
set arguments $argv
if {[info exists quartus(args)]} {set arguments $quartus(args)}
if {[llength $arguments] == 0} {
    foreach cable [get_hardware_names] {
        puts "CABLE: $cable"
        foreach device [get_device_names -hardware_name $cable] {puts "  DEVICE: $device"}
    }
    puts {Usage: quartus_stp -t scripts/read_audio_noise_probe.tcl "exact cable" "exact FPGA device"}
    exit
}
if {[llength $arguments] != 2} {error "Specify exact cable and FPGA device names"}
proc word {hex index} {
    set last [expr {[string length $hex]-1-8*$index}]
    set first [expr {$last-7}]
    scan [string range $hex $first $last] %x result
    return $result
}
proc snapshot {index} {
    foreach toggle {0 1} {
        device_virtual_ir_shift -instance_index $index -ir_value $toggle -no_captured_ir_value
        after 10
        set confirmed 0
        for {set retry 0} {$retry<5} {incr retry} {
            set first [device_virtual_dr_shift -instance_index $index -length 256 -value_in_hex]
            set second [device_virtual_dr_shift -instance_index $index -length 256 -value_in_hex]
            if {[string length $second]!=64} {error "Unexpected DR width: $second"}
            if {[word $second 7] != 0x44500000+$index} {error "Wrong diagnostic header/index $index"}
            if {[word $second 6]==$toggle && $first eq $second} {set confirmed 1;break}
            after 10
        }
        if {!$confirmed} {error "Snapshot acknowledgement/coherence timeout at node $index; check diagnostic SOF and running main clock"}
    }
    return $second
}
open_device -hardware_name [lindex $arguments 0] -device_name [lindex $arguments 1]
set failed [catch {
    device_lock -timeout 10000
    for {set n 0} {$n<20} {incr n} {
        puts "CAPTURE $n [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
        foreach index {80 81 82} {
            set packet [snapshot $index]
            puts "NODE $index RAW=$packet"
            set w1 [word $packet 1];set w2 [word $packet 2];set w3 [word $packet 3]
            set w4 [word $packet 4];set w5 [word $packet 5]
            if {$index==80} {
                puts [format {PLAYER cycles=%u state=%d bank=%d priority=%d enable=%d timer=%d duration=%d gap=%d index=%d note=%04X rom=%04X accepted=%d ended=%d} $w1 [expr {($w2>>7)&7}] [expr {($w2>>3)&15}] [expr {$w2&7}] [expr {($w2>>10)&1}] [expr {($w3>>11)&31}] [expr {($w3>>6)&31}] [expr {($w3>>1)&31}] [expr {($w3>>16)&255}] [expr {$w4>>16}] [expr {$w4&65535}] [expr {$w5>>16}] [expr {$w5&65535}]]
            } elseif {$index==81} {
                set pcm [expr {$w3&65535}];if {$pcm>=32768} {incr pcm -65536}
                puts [format {SAMPLE cycles=%u phase=%d volume=%d pcm=%d changes=%u last_change=%u} $w1 [expr {($w2>>8)&255}] [expr {($w2>>2)&3}] $pcm $w4 $w5]
            } else {
                puts [format {DIVIDER cycles=%u counter=%u divisor=%d pulses=%u last_pulse=%u} $w1 $w2 [expr {($w3>>2)&4095}] $w4 $w5]
            }
        }
        after 400
    }
} result]
catch {device_unlock}
close_device
if {$failed} {error $result}
