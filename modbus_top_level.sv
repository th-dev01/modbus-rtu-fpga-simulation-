`timescale 1ns / 1ps

import modbus_defs_pkg::*;

module modbus_top_level #(
    parameter int unsigned CLOCK_FREQ = 50_000_000,
    parameter int unsigned BAUD_RATE = 115_200,
    parameter int unsigned MASTER_TIMEOUT_CYCLES = CLOCK_FREQ / 10,
    parameter int unsigned REGISTER_DEPTH = 64,
    parameter int unsigned MAX_READ_REGISTERS = 125
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        cmd_valid,
    output logic        cmd_ready,
    input  logic [7:0]  cmd_slave_addr,
    input  logic [7:0]  cmd_function,
    input  logic [15:0] cmd_register_addr,
    input  logic [15:0] cmd_write_data,
    input  logic [15:0] cmd_quantity,

    input  logic [7:0]  slave_id,

    output logic        master_busy,
    output logic        response_valid,
    output modbus_status_t response_status,
    output logic [7:0]  response_exception,
    output logic [15:0] response_data,
    output logic [7:0]  response_byte_count,
    output logic [7:0]  response_register_count,
    input  logic [7:0]  response_register_read_index,
    output logic [15:0] response_register_read_data,
    output logic        response_register_read_valid,
    output logic [15:0] overflow_byte_count,

    output logic        master_to_slave_serial,
    output logic        slave_to_master_serial
);

    logic baud_tick;

    logic [7:0] master_tx_data;
    logic       master_tx_valid;
    logic       master_tx_ready;
    logic [7:0] master_rx_data;
    logic       master_rx_valid;
    logic       master_rx_frame_end;

    logic [7:0] slave_rx_data;
    logic       slave_rx_valid;
    logic       slave_rx_frame_done;
    logic [7:0] slave_tx_data;
    logic       slave_tx_valid;
    logic       slave_tx_ready;

    logic       master_uart_tx_busy;
    logic       master_uart_tx_done;
    logic       slave_uart_tx_busy;
    logic       slave_uart_tx_done;

    logic       slave_crc_en;
    logic       slave_crc_clear;
    logic [7:0] slave_crc_data_in;
    logic [15:0] slave_crc_out;

    logic       slave_reg_wr_en;
    logic [5:0] slave_reg_addr;
    logic [15:0] slave_reg_wr_data;
    logic [15:0] slave_reg_rd_data;
    logic        slave_reg_valid;

    logic [15:0] response_registers [0:MAX_READ_REGISTERS-1];

    assign master_tx_ready = !master_uart_tx_busy;
    assign slave_tx_ready = !slave_uart_tx_busy;
    assign slave_reg_valid = (slave_reg_addr < REGISTER_DEPTH);

    baud_gen #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) baud_generator (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick)
    );

    modbus_master_fsm #(
        .TIMEOUT_CYCLES    (MASTER_TIMEOUT_CYCLES),
        .MAX_READ_REGISTERS(MAX_READ_REGISTERS)
    ) master (
        .clk                         (clk),
        .rst_n                       (rst_n),
        .cmd_valid                   (cmd_valid),
        .cmd_ready                   (cmd_ready),
        .cmd_slave_addr              (cmd_slave_addr),
        .cmd_function                (cmd_function),
        .cmd_register_addr           (cmd_register_addr),
        .cmd_write_data              (cmd_write_data),
        .cmd_quantity                (cmd_quantity),
        .tx_data                     (master_tx_data),
        .tx_valid                    (master_tx_valid),
        .tx_ready                    (master_tx_ready),
        .rx_data                     (master_rx_data),
        .rx_valid                    (master_rx_valid),
        .rx_frame_end                (master_rx_frame_end),
        .busy                        (master_busy),
        .response_valid              (response_valid),
        .response_status             (response_status),
        .response_exception          (response_exception),
        .response_data               (response_data),
        .response_byte_count         (response_byte_count),
        .response_register_count     (response_register_count),
        .response_registers          (response_registers),
        .response_register_read_index(response_register_read_index),
        .response_register_read_data (response_register_read_data),
        .response_register_read_valid(response_register_read_valid),
        .overflow_byte_count         (overflow_byte_count)
    );

    uart_tx master_uart_tx (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .tx_start  (master_tx_valid && master_tx_ready),
        .tx_data   (master_tx_data),
        .tx        (master_to_slave_serial),
        .tx_busy   (master_uart_tx_busy),
        .tx_done   (master_uart_tx_done)
    );

    uart_rx slave_uart_rx (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .rx        (master_to_slave_serial),
        .rx_data   (slave_rx_data),
        .rx_valid  (slave_rx_valid)
    );

    frame_timer slave_frame_timer (
        .clk        (clk),
        .rst_n      (rst_n),
        .baud_tick  (baud_tick),
        .rx         (master_to_slave_serial),
        .frame_done (slave_rx_frame_done)
    );

    modbus_slave slave (
        .clk          (clk),
        .rst_n        (rst_n),
        .slave_id     (slave_id),
        .rx_data      (slave_rx_data),
        .rx_valid     (slave_rx_valid),
        .rx_frame_done(slave_rx_frame_done),
        .tx_data      (slave_tx_data),
        .tx_valid     (slave_tx_valid),
        .tx_ready     (slave_tx_ready),
        .crc_en       (slave_crc_en),
        .crc_clear    (slave_crc_clear),
        .crc_data_in  (slave_crc_data_in),
        .crc_out      (slave_crc_out),
        .reg_wr_en    (slave_reg_wr_en),
        .reg_addr     (slave_reg_addr),
        .reg_wr_data  (slave_reg_wr_data),
        .reg_rd_data  (slave_reg_rd_data),
        .reg_valid    (slave_reg_valid)
    );

    modbus_crc16 slave_crc (
        .clk     (clk),
        .rst_n   (rst_n),
        .en      (slave_crc_en),
        .data_in (slave_crc_data_in),
        .clear   (slave_crc_clear),
        .crc_out (slave_crc_out)
    );

    modbus_register_file #(
        .DEPTH(REGISTER_DEPTH)
    ) slave_registers (
        .clk     (clk),
        .rst_n   (rst_n),
        .addr    ({10'd0, slave_reg_addr}),
        .we      (slave_reg_wr_en),
        .data_in (slave_reg_wr_data),
        .data_out(slave_reg_rd_data)
    );

    uart_tx slave_uart_tx (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .tx_start  (slave_tx_valid && slave_tx_ready),
        .tx_data   (slave_tx_data),
        .tx        (slave_to_master_serial),
        .tx_busy   (slave_uart_tx_busy),
        .tx_done   (slave_uart_tx_done)
    );

    uart_rx master_uart_rx (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .rx        (slave_to_master_serial),
        .rx_data   (master_rx_data),
        .rx_valid  (master_rx_valid)
    );

    frame_timer master_frame_timer (
        .clk        (clk),
        .rst_n      (rst_n),
        .baud_tick  (baud_tick),
        .rx         (slave_to_master_serial),
        .frame_done (master_rx_frame_end)
    );

endmodule
