# Start ModelSim in this directory, then do tb_v43_barcode_load.do
view wave
catch {dataset close captured}
dataset open tb_v43_barcode.wlf captured
add wave -radix hexadecimal -label {clk} captured:/tb_v43_barcode/clk
add wave -radix hexadecimal -label {rst} captured:/tb_v43_barcode/rst
add wave -radix hexadecimal -label {pass} captured:/tb_v43_barcode/pass
add wave -radix hexadecimal -label {key} captured:/tb_v43_barcode/key
add wave -radix hexadecimal -label {ticket} captured:/tb_v43_barcode/ticket
add wave -radix hexadecimal -label {active} captured:/tb_v43_barcode/active
add wave -radix hexadecimal -label {dut.decoder_hit} captured:/tb_v43_barcode/dut/decoder_hit
add wave -radix hexadecimal -label {dut.confirmed} captured:/tb_v43_barcode/dut/confirmed
add wave -radix hexadecimal -label {dut.done} captured:/tb_v43_barcode/dut/done
add wave -radix hexadecimal -label {dut.order} captured:/tb_v43_barcode/dut/order
add wave -radix hexadecimal -label {dut.counter} captured:/tb_v43_barcode/dut/counter
wave zoom full
