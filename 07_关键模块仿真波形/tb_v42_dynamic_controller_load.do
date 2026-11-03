# Start ModelSim in this directory, then do tb_v42_dynamic_controller_load.do
view wave
catch {dataset close captured}
dataset open tb_v42_dynamic_controller.wlf captured
add wave -radix hexadecimal -label {clk} captured:/tb_v42_dynamic_controller/clk
add wave -radix hexadecimal -label {rst_n} captured:/tb_v42_dynamic_controller/rst_n
add wave -radix hexadecimal -label {learn} captured:/tb_v42_dynamic_controller/learn
add wave -radix hexadecimal -label {sample} captured:/tb_v42_dynamic_controller/sample
add wave -radix hexadecimal -label {valid} captured:/tb_v42_dynamic_controller/valid
add wave -radix hexadecimal -label {reference_set} captured:/tb_v42_dynamic_controller/reference_set
add wave -radix hexadecimal -label {dut.auto_phase} captured:/tb_v42_dynamic_controller/dut/auto_phase
add wave -radix hexadecimal -label {dut.auto_count} captured:/tb_v42_dynamic_controller/dut/auto_count
add wave -radix hexadecimal -label {result} captured:/tb_v42_dynamic_controller/result
add wave -radix hexadecimal -label {locked} captured:/tb_v42_dynamic_controller/locked
add wave -radix hexadecimal -label {total} captured:/tb_v42_dynamic_controller/total
add wave -radix hexadecimal -label {passes} captured:/tb_v42_dynamic_controller/passes
add wave -radix hexadecimal -label {unknowns} captured:/tb_v42_dynamic_controller/unknowns
wave zoom full
