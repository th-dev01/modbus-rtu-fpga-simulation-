onerror {quit -code 1}

catch {quit -sim}

set TB_LIB work_msim_crc
if {![file isdirectory $TB_LIB]} {
    vlib $TB_LIB
}

vlog -work $TB_LIB -sv \
    modbus_crc_pkg.sv \
    modbus_crc16.sv \
    modbus_slave.sv \
    tb_modbus_slave_bad_crc.sv

vsim $TB_LIB.tb_modbus_slave_bad_crc
run -all
