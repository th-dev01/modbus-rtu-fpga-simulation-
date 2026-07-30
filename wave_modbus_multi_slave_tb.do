# Waveform do teste de integracao com dois escravos Modbus RTU.

add wave -noupdate -divider {1 - CLOCK E COMANDO}
add wave -noupdate sim:/tb_modbus_multi_slave/clk
add wave -noupdate sim:/tb_modbus_multi_slave/rst_n
add wave -noupdate sim:/tb_modbus_multi_slave/cmd_valid
add wave -noupdate sim:/tb_modbus_multi_slave/cmd_ready
add wave -noupdate -radix hexadecimal sim:/tb_modbus_multi_slave/cmd_slave_addr
add wave -noupdate -radix hexadecimal sim:/tb_modbus_multi_slave/cmd_function
add wave -noupdate -radix hexadecimal sim:/tb_modbus_multi_slave/cmd_register_addr
add wave -noupdate -radix hexadecimal sim:/tb_modbus_multi_slave/cmd_write_data
add wave -noupdate -radix unsigned sim:/tb_modbus_multi_slave/cmd_quantity

add wave -noupdate -divider {2 - BARRAMENTO SERIAL COMPARTILHADO}
add wave -noupdate sim:/tb_modbus_multi_slave/master_to_slave_serial
add wave -noupdate sim:/tb_modbus_multi_slave/slave_to_master_serial
add wave -noupdate sim:/tb_modbus_multi_slave/slave_bus_collision
add wave -noupdate {sim:/tb_modbus_multi_slave/dut/slave_tx_serial}
add wave -noupdate {sim:/tb_modbus_multi_slave/dut/slave_uart_tx_busy}

add wave -noupdate -divider {3 - ESCRAVO 1 - ENDERECO 01}
add wave -noupdate {sim:/tb_modbus_multi_slave/dut/slave_nodes[0]/slave/state}
add wave -noupdate -radix hexadecimal {sim:/tb_modbus_multi_slave/dut/slave_nodes[0]/slave/req_addr}
add wave -noupdate -radix hexadecimal {sim:/tb_modbus_multi_slave/dut/slave_nodes[0]/slave/req_func}
add wave -noupdate {sim:/tb_modbus_multi_slave/dut/slave_reg_wr_en[0]}
add wave -noupdate -radix unsigned {sim:/tb_modbus_multi_slave/dut/slave_reg_addr[0]}
add wave -noupdate -radix hexadecimal {sim:/tb_modbus_multi_slave/dut/slave_reg_wr_data[0]}
add wave -noupdate -radix hexadecimal {sim:/tb_modbus_multi_slave/dut/slave_reg_rd_data[0]}

add wave -noupdate -divider {4 - ESCRAVO 2 - ENDERECO 02}
add wave -noupdate {sim:/tb_modbus_multi_slave/dut/slave_nodes[1]/slave/state}
add wave -noupdate -radix hexadecimal {sim:/tb_modbus_multi_slave/dut/slave_nodes[1]/slave/req_addr}
add wave -noupdate -radix hexadecimal {sim:/tb_modbus_multi_slave/dut/slave_nodes[1]/slave/req_func}
add wave -noupdate {sim:/tb_modbus_multi_slave/dut/slave_reg_wr_en[1]}
add wave -noupdate -radix unsigned {sim:/tb_modbus_multi_slave/dut/slave_reg_addr[1]}
add wave -noupdate -radix hexadecimal {sim:/tb_modbus_multi_slave/dut/slave_reg_wr_data[1]}
add wave -noupdate -radix hexadecimal {sim:/tb_modbus_multi_slave/dut/slave_reg_rd_data[1]}

add wave -noupdate -divider {5 - RESPOSTA DO MESTRE}
add wave -noupdate sim:/tb_modbus_multi_slave/master_busy
add wave -noupdate sim:/tb_modbus_multi_slave/response_valid
add wave -noupdate sim:/tb_modbus_multi_slave/response_status
add wave -noupdate -radix hexadecimal sim:/tb_modbus_multi_slave/response_exception
add wave -noupdate -radix hexadecimal sim:/tb_modbus_multi_slave/response_data
add wave -noupdate -radix unsigned sim:/tb_modbus_multi_slave/response_register_count
add wave -noupdate -radix unsigned sim:/tb_modbus_multi_slave/response_register_read_index
add wave -noupdate -radix hexadecimal sim:/tb_modbus_multi_slave/response_register_read_data
add wave -noupdate -radix hexadecimal sim:/tb_modbus_multi_slave/dut/master/response_crc

configure wave -namecolwidth 320
configure wave -valuecolwidth 120
configure wave -timelineunits ns
update
