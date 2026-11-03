# Held level request and acknowledgment, each with two destination stages.
# Only first sampling registers are asynchronous; stage1->stage2 remains timed.
set_false_path -from [get_clocks {HDMI_PIXEL_CLK}] -through [get_nets {S_label_imaging_lock}] -to [get_regs {S_image_lock_cam_meta}]
set_false_path -from [get_clocks {pll_clk_24m}] -through [get_nets {S_ae_locked}] -to [get_regs {S_ae_locked_meta}]
