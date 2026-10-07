proc required_env {name} {
  if {![info exists ::env($name)] || $::env($name) eq ""} { error "Missing environment variable $name" }
  return $::env($name)
}

set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
set kind [required_env BASELINE_KIND]
set precision [required_env BASELINE_PRECISION]
set n [required_env BASELINE_N]
set period [required_env BASELINE_PERIOD_NS]
set tag [required_env BASELINE_BUILD_TAG]
set out_dir [file normalize [required_env BASELINE_OUT_DIR]]
set source_manifest_sha256 [required_env BASELINE_SOURCE_MANIFEST_SHA256]
set tcl_sha256 [required_env BASELINE_TCL_SHA256]
set driver_sha256 [required_env BASELINE_DRIVER_SHA256]
set part xczu9eg-ffvb1156-2-e
file mkdir $out_dir

if {$kind eq "direct"} {
  foreach f {
    ntt46_direct_spatial_parpipe_baseline.sv
    direct_spatial_parpipe_baseline_top.sv
  } { read_verilog -sv [file join $root baselines direct rtl $f] }
  set top direct_spatial_parpipe_baseline_top
  set data_w $precision
  set acc_w 32
  set generics [list "NX=[expr {$n / 2}]" "PAR=4" "DATA_W=$data_w" "ACC_W=$acc_w" "CIN_MAX=4"]
} elseif {$kind eq "zero_pad"} {
  foreach f {
    ntt46_zero_pad_radix2_reference_engine.sv
    ntt46_zero_pad_radix2_residue_conv_core.sv
    ntt46_zero_pad_radix2_unified_baseline.sv
  } { read_verilog -sv [file join $root baselines zero_pad rtl $f] }
  set top ntt46_zero_pad_radix2_unified_baseline
  set generics [list "N=$n" "PRECISION=$precision"]
} else {
  error "Unsupported BASELINE_KIND=$kind"
}

set_param general.maxThreads 8
synth_design -top $top -part $part -flatten_hierarchy rebuilt -directive AreaOptimized_high -generic $generics
create_clock -name clk -period $period [get_ports clk]
opt_design
place_design -directive Explore
route_design -directive Explore
phys_opt_design -directive Explore
set route_errors [llength [get_nets -hierarchical -filter {ROUTE_STATUS == UNROUTED || ROUTE_STATUS == PARTIAL || ROUTE_STATUS == CONFLICTS}]]
set route_status [expr {$route_errors == 0 ? "ROUTED" : "ROUTE_ERRORS"}]
set setup_paths [get_timing_paths -delay_type max -max_paths 1]
set hold_paths [get_timing_paths -delay_type min -max_paths 1]
set wns [expr {[llength $setup_paths] ? [get_property SLACK [lindex $setup_paths 0]] : -999.0}]
set whs [expr {[llength $hold_paths] ? [get_property SLACK [lindex $hold_paths 0]] : -999.0}]
report_route_status -file [file join $out_dir "${tag}_route_status.rpt"]
report_timing_summary -delay_type min_max -max_paths 50 -file [file join $out_dir "${tag}_timing.rpt"]
report_utilization -file [file join $out_dir "${tag}_utilization.rpt"]
report_utilization -hierarchical -file [file join $out_dir "${tag}_utilization_hier.rpt"]
report_drc -file [file join $out_dir "${tag}_drc.rpt"]
report_power -file [file join $out_dir "${tag}_power_vectorless.rpt"]
write_checkpoint -force [file join $out_dir "${tag}_routed.dcp"]
set fp [open [file join $out_dir "${tag}_build_contract.txt"] w]
puts $fp "top=$top"
puts $fp "part=$part"
puts $fp "baseline=$kind"
puts $fp "precision=$precision"
puts $fp "N=$n"
puts $fp "period_ns=$period"
puts $fp "scope=normal_non_ooc_routed"
puts $fp "vivado_version=[version -short]"
puts $fp "rtl_source_manifest=rtl_sources_sha256.csv"
puts $fp "rtl_source_manifest_sha256=$source_manifest_sha256"
puts $fp "implement_tcl_sha256=$tcl_sha256"
puts $fp "run_baseline_implementation_ps1_sha256=$driver_sha256"
puts $fp "synth_directive=AreaOptimized_high"
puts $fp "place_directive=Explore"
puts $fp "route_directive=Explore"
puts $fp "post_route_phys_opt_directive=Explore"
puts $fp "tool_seed=Vivado_default"
puts $fp "clock_constraint=create_clock_period_${period}_port_clk"
puts $fp "route_status=$route_status"
puts $fp "route_errors=$route_errors"
puts $fp "wns_ns=$wns"
puts $fp "whs_ns=$whs"
close $fp
if {$route_errors != 0} { error "Route errors detected: $route_errors" }
if {$wns < 0.0 || $whs < 0.0} { error "Timing signoff failed: WNS=$wns WHS=$whs" }
puts "BASELINE_IMPLEMENTATION_DONE kind=$kind precision=$precision N=$n"
exit
