`timescale 1ns / 1ps

import modbus_crc_pkg::*;

module tb_modbus_slave_bad_crc;
    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic [7:0]  rx_data;
    logic        rx_valid;
    logic        rx_frame_done;
    logic [7:0]  tx_data;
    logic        tx_valid;
    logic        tx_ready;
    logic        crc_en;
    logic        crc_clear;
    logic [7:0]  crc_data_in;
    logic [15:0] crc_out;
    logic        reg_wr_en;
    logic [5:0]  reg_addr;
    logic [15:0] reg_wr_data;
    logic [15:0] reg_rd_data;
    logic        reg_valid;

    logic [7:0] frame [0:7];
    logic [15:0] calculated_crc;
    logic saw_tx;
    logic saw_write;
    int index;

    always #5 clk = ~clk;

    assign tx_ready = 1'b1;
    assign reg_valid = (reg_addr < 64);
    assign reg_rd_data = 16'h0000;

    modbus_slave dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .slave_id     (8'h01),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .rx_frame_done(rx_frame_done),
        .tx_data      (tx_data),
        .tx_valid     (tx_valid),
        .tx_ready     (tx_ready),
        .crc_en       (crc_en),
        .crc_clear    (crc_clear),
        .crc_data_in  (crc_data_in),
        .crc_out      (crc_out),
        .reg_wr_en    (reg_wr_en),
        .reg_addr     (reg_addr),
        .reg_wr_data  (reg_wr_data),
        .reg_rd_data  (reg_rd_data),
        .reg_valid    (reg_valid)
    );

    modbus_crc16 crc (
        .clk     (clk),
        .rst_n   (rst_n),
        .en      (crc_en),
        .data_in (crc_data_in),
        .clear   (crc_clear),
        .crc_out (crc_out)
    );

    always @(posedge clk) begin
        if (tx_valid)
            saw_tx <= 1'b1;
        if (reg_wr_en)
            saw_write <= 1'b1;
    end

    task automatic send_frame;
        int byte_index;
        begin
            for (byte_index = 0; byte_index < 8; byte_index++) begin
                @(negedge clk);
                rx_data  = frame[byte_index];
                rx_valid = 1'b1;
                @(negedge clk);
                rx_valid = 1'b0;
            end
            @(negedge clk);
            rx_frame_done = 1'b1;
            @(negedge clk);
            rx_frame_done = 1'b0;
        end
    endtask

    initial begin
        rx_data       = 8'd0;
        rx_valid      = 1'b0;
        rx_frame_done = 1'b0;
        saw_tx        = 1'b0;
        saw_write     = 1'b0;

        repeat (5) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // FC06: escravo 1, registrador 2, dado ABCD.
        frame[0] = 8'h01;
        frame[1] = 8'h06;
        frame[2] = 8'h00;
        frame[3] = 8'h02;
        frame[4] = 8'hAB;
        frame[5] = 8'hCD;
        calculated_crc = 16'hFFFF;
        for (index = 0; index < 6; index++)
            calculated_crc = crc16_update(calculated_crc, frame[index]);
        frame[6] = calculated_crc[7:0] ^ 8'h01;
        frame[7] = calculated_crc[15:8];

        send_frame();
        repeat (80) @(posedge clk);
        assert (!saw_tx)
            else $fatal(1, "Escravo respondeu a um quadro com CRC invalido");
        assert (!saw_write)
            else $fatal(1, "CRC invalido alterou o banco de registradores");

        // Repete o mesmo quadro com CRC correto para validar o estimulo.
        saw_tx    = 1'b0;
        saw_write = 1'b0;
        frame[6]  = calculated_crc[7:0];
        send_frame();
        repeat (80) @(posedge clk);
        assert (saw_tx)
            else $fatal(1, "Quadro de controle com CRC valido nao respondeu");
        assert (saw_write)
            else $fatal(1, "Quadro FC06 valido nao realizou a escrita");

        $display("PASS: CRC invalido foi descartado sem resposta e sem escrita.");
        $finish;
    end

    initial begin
        #100us;
        $fatal(1, "Watchdog: teste de CRC nao terminou");
    end

endmodule
