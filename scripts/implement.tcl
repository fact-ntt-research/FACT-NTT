proc required_env {name} {
  if {![info exists ::env($name)] || $::env($name) eq ""} { error "Missing environment variable $name" }
  return $::env($name)
}

set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
set precision [required_env FACT_PRECISION]
set n [required_env FACT_N]
set period [required_env FACT_PERIOD_NS]
set tag [required_env FACT_BUILD_TAG]
set source_list [required_env FACT_RTL_SOURCE_LIST]
set source_manifest [required_env FACT_RTL_SOURCE_MANIFEST]
set source_manifest_sha256 [required_env FACT_SOURCE_MANIFEST_SHA256]
set tcl_sha256 [required_env FACT_TCL_SHA256]
set driver_sha256 [required_env FACT_DRIVER_SHA256]
set r [expr {$n / 2}]
set lanes [expr {$n == 1024 ? 16 : 8}]

set source_fp [open $source_list r]
while {[gets $source_fp source_file] >= 0} {
  set source_file [string trim $source_file]
  if {$source_file ne ""} { read_verilog -sv $source_file }
}
close $source_fp

set_param general.maxThreads 8
synth_design -top ntt46_fact_lean_ip_unified_axi_lite_core \
  -part xczu9eg-ffvb1156-2-e -flatten_hierarchy rebuilt \
  -directive AreaOptimized_high \
  -generic "PRECISION=$precision R=$r LANES=$lanes CIN_MAX=4 COUT_MAX=4"
create_clock -period $period -name clk [get_ports clk]
opt_design
place_design -directive Explore
route_design -directive Explore
phys_opt_design -directive AggressiveExplore

set route_errors [llength [get_nets -hierarchical -filter {ROUTE_STATUS == UNROUTED || ROUTE_STATUS == PARTIAL || ROUTE_STATUS == CONFLICTS}]]
set route_status [expr {$route_errors == 0 ? "ROUTED" : "ROUTE_ERRORS"}]
set setup_paths [get_timing_paths -delay_type max -max_paths 1]
set hold_paths [get_timing_paths -delay_type min -max_paths 1]
set wns [expr {[llength $setup_paths] ? [get_property SLACK [lindex $setup_paths 0]] : -999.0}]
set whs [expr {[llength $hold_paths] ? [get_property SLACK [lindex $hold_paths 0]] : -999.0}]

report_route_status -file "${tag}_route_status.rpt"
report_timing_summary -file "${tag}_timing.rpt"
report_utilization -file "${tag}_util.rpt"
report_utilization -hierarchical -file "${tag}_util_hier.rpt"
report_drc -file "${tag}_drc.rpt"
report_power -file "${tag}_power_vectorless.rpt"
write_checkpoint -force "${tag}_routed.dcp"
set fp [open "${tag}_build_contract.txt" w]
puts $fp "top=ntt46_fact_lean_ip_unified_axi_lite_core"
puts $fp "part=xczu9eg-ffvb1156-2-e"
puts $fp "precision=$precision"
puts $fp "N=$n"
puts $fp "R=$r"
puts $fp "lanes=$lanes"
puts $fp "period_ns=$period"
puts $fp "scope=normal_non_ooc_routed"
puts $fp "vivado_version=[version -short]"
puts $fp "rtl_source_manifest=rtl_sources_sha256.csv"
puts $fp "rtl_source_manifest_sha256=$source_manifest_sha256"
puts $fp "implement_tcl_sha256=$tcl_sha256"
puts $fp "run_implementation_ps1_sha256=$driver_sha256"
puts $fp "synth_directive=AreaOptimized_high"
puts $fp "place_directive=Explore"
puts $fp "route_directive=Explore"
puts $fp "post_route_phys_opt_directive=AggressiveExplore"
puts $fp "tool_seed=Vivado_default"
puts $fp "clock_constraint=create_clock_period_${period}_port_clk"
puts $fp "route_status=$route_status"
puts $fp "route_errors=$route_errors"
puts $fp "wns_ns=$wns"
puts $fp "whs_ns=$whs"
close $fp
if {$route_errors != 0} { error "Route errors detected: $route_errors" }
if {$wns < 0.0 || $whs < 0.0} { error "Timing signoff failed: WNS=$wns WHS=$whs" }
puts "FACT_IMPLEMENTATION_DONE tag=$tag"
exit
