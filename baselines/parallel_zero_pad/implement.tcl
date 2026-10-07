# Reproduce the archived sequence: route at 4.250 ns, then time the same
# placement/routing at 4.750 ns. This flow is not run by the quick checks.
if {$argc != 2} { error "Usage: implement.tcl baseline_directory output_directory" }
set root [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
file mkdir $out
cd $out
set fp [open [file join $root sources.f] r]
set entries [split [read $fp] "\n"]
close $fp
set sources [list]
foreach entry $entries {
    set entry [string trim $entry]
    if {[string match "rtl/*" $entry]} { lappend sources [file join $root $entry] }
}
set part xczu9eg-ffvb1156-2-e
create_project -in_memory -part $part
set_param general.maxThreads 8
read_verilog -sv $sources
synth_design -top ntt46_zero_pad_p520_n1024_local_core -part $part -flatten_hierarchy rebuilt
create_clock -name clk -period 4.250 [get_ports clk]
set_false_path -from [get_ports rst]
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $out routed_p425.dcp]
report_timing_summary -delay_type min_max -max_paths 50 -file [file join $out routed_timing_p425.rpt]
reset_timing
create_clock -name clk -period 4.750 [get_ports clk]
set_false_path -from [get_ports rst]
update_timing
report_timing_summary -delay_type min_max -max_paths 50 -file [file join $out routed_timing_p475.rpt]
report_utilization -file [file join $out routed_util.rpt]
report_route_status -file [file join $out route_status.rpt]
report_drc -file [file join $out drc.rpt]
report_power -file [file join $out vectorless_power_p475.rpt]
write_checkpoint -force [file join $out routed_p475.dcp]
puts "PARALLEL_ZERO_PAD_IMPLEMENTATION_COMPLETE reports=$out"
