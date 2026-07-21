# Waveform organizado do testbench de integracao Modbus RTU.

add wave -noupdate -divider {1 - CLOCK E CONTROLE}
add wave -noupdate sim:/tb_modbus_top_level/clk
add wave -noupdate sim:/tb_modbus_top_level/rst_n
add wave -noupdate sim:/tb_modbus_top_level/dut/baud_tick

add wave -noupdate -divider {2 - COMANDO DA APLICACAO}
add wave -noupdate sim:/tb_modbus_top_level/cmd_valid
add wave -noupdate sim:/tb_modbus_top_level/cmd_ready
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/cmd_slave_addr
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/cmd_function
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/cmd_register_addr
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/cmd_write_data
add wave -noupdate -radix unsigned sim:/tb_modbus_top_level/cmd_quantity

add wave -noupdate -divider {3 - MESTRE MODBUS / QUADRO DE REQUISICAO}
add wave -noupdate sim:/tb_modbus_top_level/master_busy
add wave -noupdate sim:/tb_modbus_top_level/dut/master/state
add wave -noupdate sim:/tb_modbus_top_level/dut/master/builder_start
add wave -noupdate sim:/tb_modbus_top_level/dut/master/builder_valid
add wave -noupdate -radix unsigned sim:/tb_modbus_top_level/dut/master/builder_index
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/master_tx_data
add wave -noupdate sim:/tb_modbus_top_level/dut/master_tx_valid
add wave -noupdate sim:/tb_modbus_top_level/dut/master_tx_ready

add wave -noupdate -divider {4 - UART MESTRE PARA ESCRAVO}
add wave -noupdate sim:/tb_modbus_top_level/master_to_slave_serial
add wave -noupdate sim:/tb_modbus_top_level/dut/master_uart_tx/state
add wave -noupdate sim:/tb_modbus_top_level/dut/master_uart_tx_busy
add wave -noupdate sim:/tb_modbus_top_level/dut/slave_uart_rx/current_state
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/slave_rx_data
add wave -noupdate sim:/tb_modbus_top_level/dut/slave_rx_valid
add wave -noupdate sim:/tb_modbus_top_level/dut/slave_rx_frame_done

add wave -noupdate -divider {5 - ESCRAVO MODBUS E CRC}
add wave -noupdate sim:/tb_modbus_top_level/dut/slave/state
add wave -noupdate -radix unsigned sim:/tb_modbus_top_level/dut/slave/rx_count
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/slave/req_addr
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/slave/req_func
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/slave/req_start_addr
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/slave/req_value_or_quantity
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/slave/exception_code
add wave -noupdate sim:/tb_modbus_top_level/dut/slave_crc_clear
add wave -noupdate sim:/tb_modbus_top_level/dut/slave_crc_en
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/slave_crc_data_in
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/slave_crc_out

add wave -noupdate -divider {6 - BANCO DE REGISTRADORES}
add wave -noupdate sim:/tb_modbus_top_level/dut/slave_reg_wr_en
add wave -noupdate -radix unsigned sim:/tb_modbus_top_level/dut/slave_reg_addr
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/slave_reg_wr_data
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/slave_reg_rd_data
add wave -noupdate sim:/tb_modbus_top_level/dut/slave_reg_valid

add wave -noupdate -divider {7 - UART ESCRAVO PARA MESTRE}
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/slave_tx_data
add wave -noupdate sim:/tb_modbus_top_level/dut/slave_tx_valid
add wave -noupdate sim:/tb_modbus_top_level/dut/slave_tx_ready
add wave -noupdate sim:/tb_modbus_top_level/dut/slave_uart_tx/state
add wave -noupdate sim:/tb_modbus_top_level/slave_to_master_serial
add wave -noupdate sim:/tb_modbus_top_level/dut/master_uart_rx/current_state
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/master_rx_data
add wave -noupdate sim:/tb_modbus_top_level/dut/master_rx_valid
add wave -noupdate sim:/tb_modbus_top_level/dut/master_rx_frame_end

add wave -noupdate -divider {8 - VALIDACAO E RESPOSTA}
add wave -noupdate -radix unsigned sim:/tb_modbus_top_level/dut/master/response_length
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/dut/master/response_crc
add wave -noupdate sim:/tb_modbus_top_level/response_valid
add wave -noupdate sim:/tb_modbus_top_level/response_status
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/response_exception
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/response_data
add wave -noupdate -radix unsigned sim:/tb_modbus_top_level/response_byte_count
add wave -noupdate -radix unsigned sim:/tb_modbus_top_level/response_register_count
add wave -noupdate -radix unsigned sim:/tb_modbus_top_level/response_register_read_index
add wave -noupdate -radix hexadecimal sim:/tb_modbus_top_level/response_register_read_data
add wave -noupdate sim:/tb_modbus_top_level/response_register_read_valid
add wave -noupdate -radix unsigned sim:/tb_modbus_top_level/overflow_byte_count

configure wave -namecolwidth 280
configure wave -valuecolwidth 120
configure wave -timelineunits ns
update
