# TD's native path-margin groups survive clock re-creation during P&R.
# Reapply at stage boundaries and remove only the additional implementation goal.
proc v42_apply_impl_margin {} {
    reset_path_margin -all
    set_path_margin -group v42_setup -global -setup 0.200
    set_path_margin -group v42_hold -global -hold 0.025
}
if {[catch {
    # Avoid TD's localized Windows pwd; pass this script's absolute filename.
    set v42_build_root [file dirname [info script]]
    if {$v42_build_root eq "."} {error "Run this script using its full absolute filename"}
    cd $v42_build_root
    set v42_route_output [file join $v42_build_root v42_route_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
    if {[file exists $v42_route_output]} {error "Use a fresh route output directory"}
    import_device ph1_35p.db -package PH1P35MDG324 -speed 3
    open_project camera_to_dsi_display.al -single_run
    load_run_param -run syn_1
    # Limit dedicated adder chains to long arithmetic paths to fit the fusion.
    set_param rtl min_ripple_len 32
    set_param gate mapper_lut_delay 1800
    set_param gate map_mode area_prior
    set_param rtl resource_sharing auto
    set_param rtl shifter_style shifter_reg
    elaborate -top design_top_wrapper
    read_adc ../user_source/constraints_source/pin.adc
    read_ip_adc -ip ddr2 -file ../user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc
    read_sdc camera_to_dsi_display.sdc
    read_sdc label_lock_cdc.sdc
    read_sdc -ip ddr2 ../user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc
    read_sdc -ip w128_d512_fifo ../user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl
    export_db v42_elab.db
    optimize_rtl
    report_area -file v42_rtl.area
    export_db v42_rtl.db
    optimize_gate -packarea v42_gate.area
    legalize_phy_inst
    update_timing
    report_timing_summary -file v42_gate.timing
    export_db v42_gate.db
    if {[info exists ::env(V42_SYNTH_ONLY)] && $::env(V42_SYNTH_ONLY) eq "1"} {
        puts "V42 SYNTHESIS COMPLETE"
        exit 0
    }
    load_run_param -run phy_1
    read_adc v40_macro_guide.adc
    v42_apply_impl_margin
    set_param place effort high
    set_param place hfn_opt_effort high
    set_param place opt_timing high
    set_param place ofv 70
    set_param place opt_max_density 50
    set_param place target_density 0.6
    set_param place target_density_pp 0.7
    set_param place aggressive_opt 20
    set_param place enhanced_beeline_opt 2
    set_param place enhanced_gp on
    set_param place non_crit_opt on
    set_param place post_place_opt high
    set_param place enable_congestion_recovery on
    set_param route effort high
    set_param route post_route_opt ultra
    place
    v42_apply_impl_margin
    report_path_margin
    update_timing -mode manhattan
    report_timing_summary -file v42_place.timing
    export_db v42_place.db
    file mkdir $v42_route_output
    cd $v42_route_output
    route
    v42_apply_impl_margin
    report_path_margin
    report_area -io_info -file v42_phy.area
    update_timing -mode final
    report_timing_status -file v42_guarded.ts
    report_timing_summary -file v42_guarded.timing
    export_db v42_guarded_pr.db
    set v42_guard_f [open v42_guarded.ts r]
    set v42_guard_text [read $v42_guard_f]
    close $v42_guard_f
    foreach v42_guard_field {SWNS STNS HWNS HTNS} {
        if {![regexp [format {%s:\s*(-?[0-9.]+)ns} $v42_guard_field] $v42_guard_text -> v42_guard_value] || $v42_guard_value<0} {
            error "Implementation reserve failed: $v42_guard_field"
        }
    }
    # Keep all original SDC constraints and clock periods; drop the extra goal.
    reset_path_margin -all
    update_timing -mode final
    report_timing_status -file v42_phy.ts
    report_timing_summary -file v42_pr.timing
    report_clock_utilization -file v42_clocks.txt
    export_db v42_pr.db
    set v42_timing_file [open v42_phy.ts r]
    set v42_timing_text [read $v42_timing_file]
    close $v42_timing_file
    foreach timing_field {SWNS STNS HWNS HTNS} {
        if {![regexp [format {%s:\s*(-?[0-9.]+)ns} $timing_field] $v42_timing_text -> timing_value]} {
            error "Final timing field missing: $timing_field"
        }
        if {$timing_value < 0 || (($timing_field eq "STNS" || $timing_field eq "HTNS") && $timing_value != 0)} {
            error "Final timing failed: $timing_field = $timing_value ns"
        }
    }
    bitgen -bit v42_dynamic_label.bit
    foreach result {v42_phy.area v42_phy.ts v42_pr.timing v42_guarded.ts v42_guarded.timing v42_clocks.txt v42_pr.db v42_dynamic_label.bit} {
        file copy -force $result [file join $v42_build_root $result]
    }
} build_error]} {
    puts stderr "V42 BUILD FAILED: $build_error"
    exit 1
}
puts "V42 BUILD SUCCESS: v42_dynamic_label.bit"
exit 0
