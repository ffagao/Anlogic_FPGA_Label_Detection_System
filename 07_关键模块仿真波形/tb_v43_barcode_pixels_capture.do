onerror {quit -code 1 -f}
onfinish stop
log -r /*
vcd file tb_v43_barcode_pixels.vcd
vcd add /tb_v43_barcode_pixels/*
run -all
vcd flush
vcd off
quit -f
