# Start ModelSim in this directory, then do tb_v43_barcode_pixels_load.do
view wave
catch {dataset close captured}
dataset open tb_v43_barcode_pixels.wlf captured
add wave -radix hexadecimal -label {clk} captured:/tb_v43_barcode_pixels/clk
add wave -radix hexadecimal -label {rst} captured:/tb_v43_barcode_pixels/rst
add wave -radix hexadecimal -label {de} captured:/tb_v43_barcode_pixels/de
add wave -radix hexadecimal -label {x} captured:/tb_v43_barcode_pixels/x
add wave -radix hexadecimal -label {y} captured:/tb_v43_barcode_pixels/y
add wave -radix hexadecimal -label {rgb} captured:/tb_v43_barcode_pixels/rgb
add wave -radix hexadecimal -label {candidate} captured:/tb_v43_barcode_pixels/candidate
add wave -radix hexadecimal -label {hit} captured:/tb_v43_barcode_pixels/hit
add wave -radix hexadecimal -label {payload} captured:/tb_v43_barcode_pixels/payload
wave zoom full
