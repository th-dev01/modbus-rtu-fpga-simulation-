`timescale 1ns / 1ps

import modbus_defs_pkg::*;

module tb_modbus_top_level;
    // Parametros reduzidos aceleram a simulacao sem alterar o protocolo.
    localparam int unsigned CLOCK_FREQ = 8_000_000;
    localparam int unsigned BAUD_RATE = 1_000_000;
    localparam int unsigned MASTER_TIMEOUT_CYCLES = 700;
    localparam int unsigned MAX_READ_REGISTERS = 8;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic        cmd_valid;
    logic        cmd_ready;
    logic [7:0]  cmd_slave_addr;
    logic [7:0]  cmd_function;
    logic [15:0] cmd_register_addr;
    logic [15:0] cmd_write_data;
    logic [15:0] cmd_quantity;
    logic [7:0]  slave_id;

    logic        master_busy;
    logic        response_valid;
    modbus_status_t response_status;
    logic [7:0]  response_exception;
    logic [15:0] response_data;
    logic [7:0]  response_byte_count;
    logic [7:0]  response_register_count;
    logic [7:0]  response_register_read_index;
    logic [15:0] response_register_read_data;
    logic        response_register_read_valid;
    logic [15:0] overflow_byte_count;
    logic        master_to_slave_serial;
    logic        slave_to_master_serial;

    int tests_passed = 0;

    always #5 clk = ~clk;

    modbus_top_level #(
        .CLOCK_FREQ          (CLOCK_FREQ),
        .BAUD_RATE           (BAUD_RATE),
        .MASTER_TIMEOUT_CYCLES(MASTER_TIMEOUT_CYCLES),
        .REGISTER_DEPTH      (64),
        .MAX_READ_REGISTERS  (MAX_READ_REGISTERS)
    ) dut (.*);

    task automatic send_command(
        input logic [7:0]  address,
        input logic [7:0]  function_code,
        input logic [15:0] register_address,
        input logic [15:0] write_data,
        input logic [15:0] quantity
    );
        begin
            wait (cmd_ready);
            @(negedge clk);
            cmd_slave_addr    = address;
            cmd_function      = function_code;
            cmd_register_addr = register_address;
            cmd_write_data    = write_data;
            cmd_quantity      = quantity;
            cmd_valid         = 1'b1;
            @(negedge clk);
            cmd_valid         = 1'b0;
        end
    endtask

    task automatic wait_response(input modbus_status_t expected_status);
        int cycles;
        int byte_index;
        begin
            cycles = 0;
            while (!response_valid && cycles < 10_000) begin
                @(posedge clk);
                cycles++;
            end

            assert (response_valid)
                else $fatal(1, "Timeout do testbench aguardando response_valid");
            if (response_status != expected_status) begin
                $display("DIAGNOSTICO: status=%0d length=%0d crc_acumulado=0x%04h",
                         response_status, dut.master.response_length,
                         dut.master.response_crc);
                for (byte_index = 0;
                     byte_index < dut.master.response_length;
                     byte_index++) begin
                    $display("  RX[%0d] = 0x%02h", byte_index,
                             dut.master.response_buffer[byte_index]);
                end
            end
            assert (response_status == expected_status)
                else $fatal(1, "Status esperado=%0d, recebido=%0d",
                            expected_status, response_status);
            tests_passed++;
            @(negedge clk);
        end
    endtask

    task automatic expect_register(
        input logic [7:0] index,
        input logic [15:0] expected_value
    );
        begin
            response_register_read_index = index;
            #1;
            assert (response_register_read_valid)
                else $fatal(1, "Registrador de resposta %0d nao esta valido", index);
            assert (response_register_read_data == expected_value)
                else $fatal(1, "Registrador %0d: esperado=0x%04h, recebido=0x%04h",
                            index, expected_value, response_register_read_data);
        end
    endtask

    initial begin
        cmd_valid                    = 1'b0;
        cmd_slave_addr               = 8'd0;
        cmd_function                 = 8'd0;
        cmd_register_addr            = 16'd0;
        cmd_write_data               = 16'd0;
        cmd_quantity                 = 16'd0;
        slave_id                     = 8'h01;
        response_register_read_index = 8'd0;

        repeat (5) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // FC06: escreve 0xABCD no holding register 2.
        send_command(8'h01, FC_WRITE_SINGLE, 16'h0002, 16'hABCD, 16'd0);
        wait_response(STATUS_OK);
        assert (response_data == 16'hABCD)
            else $fatal(1, "Eco FC06 incorreto: 0x%04h", response_data);

        // FC03: confirma a escrita percorrendo toda a cadeia serial.
        send_command(8'h01, FC_READ_HOLDING, 16'h0002, 16'd0, 16'd1);
        wait_response(STATUS_OK);
        assert (response_byte_count == 8'd2 && response_register_count == 8'd1)
            else $fatal(1, "Contagem FC03 incorreta");
        expect_register(8'd0, 16'hABCD);

        // Escreve o registrador seguinte e le ambos em uma unica requisicao.
        send_command(8'h01, FC_WRITE_SINGLE, 16'h0003, 16'h1234, 16'd0);
        wait_response(STATUS_OK);
        send_command(8'h01, FC_READ_HOLDING, 16'h0002, 16'd0, 16'd2);
        wait_response(STATUS_OK);
        assert (response_byte_count == 8'd4 && response_register_count == 8'd2)
            else $fatal(1, "Contagem da leitura multipla incorreta");
        expect_register(8'd0, 16'hABCD);
        expect_register(8'd1, 16'h1234);

        // Endereco fora do banco deve retornar Illegal Data Address (0x02).
        send_command(8'h01, FC_WRITE_SINGLE, 16'h0040, 16'h5555, 16'd0);
        wait_response(STATUS_EXCEPTION);
        assert (response_exception == 8'h02)
            else $fatal(1, "Excecao esperada=0x02, recebida=0x%02h",
                        response_exception);

        // Um endereco de escravo inexistente nao responde e gera timeout.
        send_command(8'h02, FC_READ_HOLDING, 16'h0000, 16'd0, 16'd1);
        wait_response(STATUS_TIMEOUT);

        $display("PASS: %0d testes de integracao Modbus RTU aprovados.", tests_passed);
        $finish;
    end

    initial begin
        #2ms;
        $fatal(1, "Watchdog: a simulacao nao terminou no tempo esperado");
    end

endmodule
