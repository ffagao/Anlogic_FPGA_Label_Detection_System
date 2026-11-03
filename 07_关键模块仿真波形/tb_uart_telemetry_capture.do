onerror {quit -code 1 -f}
onfinish stop
log -r /*
vcd file tb_uart_telemetry.vcd
vcd add /tb_uart_telemetry/*
run -all
vcd flush
vcd off
quit -f
