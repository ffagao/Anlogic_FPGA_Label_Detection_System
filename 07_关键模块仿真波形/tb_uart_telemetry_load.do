# Start ModelSim in this directory, then do tb_uart_telemetry_load.do
view wave
catch {dataset close captured}
dataset open tb_uart_telemetry.wlf captured
add wave -radix hexadecimal -label {clk} captured:/tb_uart_telemetry/clk
add wave -radix hexadecimal -label {rst} captured:/tb_uart_telemetry/rst
add wave -radix hexadecimal -label {tx} captured:/tb_uart_telemetry/tx
add wave -radix hexadecimal -label {data[0]} captured:/tb_uart_telemetry/rx_data00
add wave -radix hexadecimal -label {data[1]} captured:/tb_uart_telemetry/rx_data01
add wave -radix hexadecimal -label {data[2]} captured:/tb_uart_telemetry/rx_data02
add wave -radix hexadecimal -label {data[3]} captured:/tb_uart_telemetry/rx_data03
add wave -radix hexadecimal -label {data[4]} captured:/tb_uart_telemetry/rx_data04
add wave -radix hexadecimal -label {data[5]} captured:/tb_uart_telemetry/rx_data05
add wave -radix hexadecimal -label {data[6]} captured:/tb_uart_telemetry/rx_data06
add wave -radix hexadecimal -label {data[7]} captured:/tb_uart_telemetry/rx_data07
add wave -radix hexadecimal -label {data[8]} captured:/tb_uart_telemetry/rx_data08
add wave -radix hexadecimal -label {data[9]} captured:/tb_uart_telemetry/rx_data09
add wave -radix hexadecimal -label {data[10]} captured:/tb_uart_telemetry/rx_data10
add wave -radix hexadecimal -label {data[11]} captured:/tb_uart_telemetry/rx_data11
add wave -radix hexadecimal -label {data[12]} captured:/tb_uart_telemetry/rx_data12
add wave -radix hexadecimal -label {data[13]} captured:/tb_uart_telemetry/rx_data13
add wave -radix hexadecimal -label {data[14]} captured:/tb_uart_telemetry/rx_data14
add wave -radix hexadecimal -label {data[15]} captured:/tb_uart_telemetry/rx_data15
add wave -radix hexadecimal -label {data[16]} captured:/tb_uart_telemetry/rx_data16
add wave -radix hexadecimal -label {data[17]} captured:/tb_uart_telemetry/rx_data17
add wave -radix hexadecimal -label {data[18]} captured:/tb_uart_telemetry/rx_data18
add wave -radix hexadecimal -label {data[19]} captured:/tb_uart_telemetry/rx_data19
add wave -radix hexadecimal -label {data[20]} captured:/tb_uart_telemetry/rx_data20
add wave -radix hexadecimal -label {data[21]} captured:/tb_uart_telemetry/rx_data21
add wave -radix hexadecimal -label {data[22]} captured:/tb_uart_telemetry/rx_data22
add wave -radix hexadecimal -label {data[23]} captured:/tb_uart_telemetry/rx_data23
add wave -radix hexadecimal -label {data[24]} captured:/tb_uart_telemetry/rx_data24
add wave -radix hexadecimal -label {data[25]} captured:/tb_uart_telemetry/rx_data25
add wave -radix hexadecimal -label {data[26]} captured:/tb_uart_telemetry/rx_data26
add wave -radix hexadecimal -label {data[27]} captured:/tb_uart_telemetry/rx_data27
add wave -radix hexadecimal -label {data[28]} captured:/tb_uart_telemetry/rx_data28
add wave -radix hexadecimal -label {data[29]} captured:/tb_uart_telemetry/rx_data29
add wave -radix hexadecimal -label {data[30]} captured:/tb_uart_telemetry/rx_data30
add wave -radix hexadecimal -label {data[31]} captured:/tb_uart_telemetry/rx_data31
add wave -radix hexadecimal -label {data[32]} captured:/tb_uart_telemetry/rx_data32
add wave -radix hexadecimal -label {data[33]} captured:/tb_uart_telemetry/rx_data33
add wave -radix hexadecimal -label {data[34]} captured:/tb_uart_telemetry/rx_data34
add wave -radix hexadecimal -label {data[35]} captured:/tb_uart_telemetry/rx_data35
add wave -radix hexadecimal -label {checksum} captured:/tb_uart_telemetry/checksum
wave zoom full
