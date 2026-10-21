# Read-only inspection of the existing fitted database. Never writes assignments
# or the atom database. Run from the project root with quartus_cdb -t.
# Optional argument "baseline" records the old emulation instead of passing it.
# Use quartus_sta and argument "timing" to also run latch/loop checks on the
# existing fitted timing netlist. This is inspection, not another compilation.
load_package atoms
set baseline [expr {[llength $quartus(args)] && [lindex $quartus(args) 0] eq "baseline"}]
set timing [expr {[llength $quartus(args)] && [lindex $quartus(args) 0] eq "timing"}]
project_open -revision Lab1Demo Lab1Demo
set failed [catch {
    read_atom_netlist -type cmp
    set registers 0
    set unspecifiedPowerUp 0
    set missingClear 0
    set feedback 0
    set bits [list]
    foreach_in_collection atom [get_atom_nodes] {
        set name [get_atom_node_info -node $atom -key NAME]
        if {![string match {*Audio_Block:*|*melody_player_1:*|noteTimeCounter*} $name]} {continue}
        set type [get_atom_node_info -node $atom -key TYPE]
        puts "AUDIO_TIMER_ATOM $name TYPE=$type"
        set hasClear 0
        foreach port [get_atom_iports -node $atom] {
            set portType [get_atom_port_info -node $atom -type iport -port_id $port -key type]
            set source [get_atom_port_info -node $atom -type iport -port_id $port -key fanin]
            set sourceName "CONSTANT_OR_UNCONNECTED"
            if {[llength $source] && [lindex $source 0] ne "-1"} {
                set sourceName [get_atom_node_info -node [lindex $source 0] -key NAME]
            }
            if {$type eq "FF"} {
                puts "  INPUT $portType SOURCE=$sourceName"
                if {[regexp -nocase {clr|clear} $portType] &&
                    ![get_atom_port_info -node $atom -type iport -port_id $port -key is_logical_gnd] &&
                    ![get_atom_port_info -node $atom -type iport -port_id $port -key is_logical_vcc]} {
                    set hasClear 1
                }
            } elseif {[llength $source] && [lindex $source 0] eq $atom} {
                incr feedback
                puts "  COMBINATIONAL_SELF_FEEDBACK $portType"
            }
        }
        if {$type eq "FF"} {
            incr registers
            if {[regexp {noteTimeCounter\[([0-4])\]} $name match bit]} {lappend bits $bit}
            set dontCare [get_atom_node_info -node $atom -key BOOL_POWER_UP_DONT_CARE]
            set powersUp [get_atom_node_info -node $atom -key BOOL_POWERS_UP]
            puts "  POWER_UP_DONT_CARE=$dontCare POWERS_UP=$powersUp HAS_ASYNC_CLEAR=$hasClear"
            # Configuration power-up metadata is not the asynchronous reset
            # value. Quartus may leave power-up unspecified even for an ordinary
            # CLRN register. Record it without mistaking it for latch evidence.
            if {$dontCare} {incr unspecifiedPowerUp}
            if {!$hasClear} {incr missingClear}
        }
    }
    set bits [lsort -unique $bits]
    puts "AUDIO_TIMER_NETLIST registers=$registers bits=$bits unspecified_powerup=$unspecifiedPowerUp missing_clear=$missingClear direct_comb_feedback=$feedback baseline=$baseline"
    if {!$baseline} {
        if {$bits ne "0 1 2 3 4" || $missingClear || $feedback} {
            error "Timer is not five covered constant-clear register bits without direct combinational feedback"
        }
        puts "AUDIO_TIMER_NETLIST_PASS"
    }
    if {$timing} {
        load_package sta
        create_timing_netlist
        read_sdc
        update_timing_netlist
        set timingRegisters 0
        set timingLatches 0
        foreach_in_collection reg [get_registers {*|noteTimeCounter*}] {
            incr timingRegisters
            set isLatch [get_register_info -is_latch $reg]
            if {$isLatch} {incr timingLatches}
            puts "AUDIO_TIMER_TIMING_REGISTER [get_register_info -name $reg] IS_LATCH=$isLatch"
        }
        if {$timingRegisters<5 || $timingLatches} {error "Missing timer registers or remaining timer latches"}
        check_timing -include {loops latches} -file db/audio_timer_reset_build/timing_loop_check.rpt -stdout
        puts "AUDIO_TIMER_TIMING_REGISTER_PASS registers=$timingRegisters latches=$timingLatches"
    }
} result]
project_close -dont_export_assignments
if {$failed} {error $result}
