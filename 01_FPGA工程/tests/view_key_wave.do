# Run after compiling with run_key_simulations.py.
# In ModelSim change directory to tests/sim_out, then:
# do ../view_key_wave.do
# Change the top below to select a different testbench.
set top tb_v42_dynamic_controller
vsim -lib v34_work $top
add wave -r sim:/$top/*
run -all
wave zoom full
