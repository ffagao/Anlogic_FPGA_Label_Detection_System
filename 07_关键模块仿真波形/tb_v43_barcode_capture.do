onerror {quit -code 1 -f}
onfinish stop
log -r /*
vcd file tb_v43_barcode.vcd
vcd add /tb_v43_barcode/*
vcd add /tb_v43_barcode/dut/decoder_hit /tb_v43_barcode/dut/confirmed /tb_v43_barcode/dut/done /tb_v43_barcode/dut/order /tb_v43_barcode/dut/counter
run -all
vcd flush
vcd off
quit -f
