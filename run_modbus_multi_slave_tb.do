onerror {quit -code 1}

catch {quit -sim}

set TB_LIB work_msim_multi
if {![file isdirectory $TB_LIB]} {
    vlib $TB_LIB
}

vlog -work $TB_LIB -sv \
    modbus_defs_pkg.sv \
    modbus_crc_pkg.sv \
    modbus_crc16.sv \
    master_frame_builder.sv \
    modbus_master_fsm.sv \
    modbus_register_file.sv \
    modbus_slave.sv \
    modbus_fpga_uema/rtl/baud_gen.sv \
    modbus_fpga_uema/rtl/uart_tx.sv \
    modbus_fpga_uema/rtl/uart_rx.sv \
    modbus_fpga_uema/rtl/frame_timer.sv \
    modbus_top_level.sv \
    tb_modbus_multi_slave.sv

vsim $TB_LIB.tb_modbus_multi_slave
do wave_modbus_multi_slave_tb.do
run -all
wave zoom full
