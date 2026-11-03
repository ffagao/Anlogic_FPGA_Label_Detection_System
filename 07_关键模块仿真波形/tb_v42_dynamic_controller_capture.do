onerror {quit -code 1 -f}
onfinish stop
log -r /*
vcd file tb_v42_dynamic_controller.vcd
vcd add /tb_v42_dynamic_controller/*
vcd add /tb_v42_dynamic_controller/dut/auto_phase /tb_v42_dynamic_controller/dut/auto_count
run -all
vcd flush
vcd off
quit -f
