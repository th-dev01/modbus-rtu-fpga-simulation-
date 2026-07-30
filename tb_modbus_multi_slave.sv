`timescale 1ns / 1ps

import modbus_defs_pkg::*;

module tb_modbus_multi_slave;
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
    logic        slave_bus_collision;

    int tests_passed = 0;

    always #5 clk = ~clk;

    modbus_top_level #(
        .CLOCK_FREQ           (CLOCK_FREQ),
        .BAUD_RATE            (BAUD_RATE),
        .MASTER_TIMEOUT_CYCLES(MASTER_TIMEOUT_CYCLES),
        .REGISTER_DEPTH       (64),
        .MAX_READ_REGISTERS   (MAX_READ_REGISTERS),
        .NUM_SLAVES           (2)
    ) dut (.*);

    // Em operacao normal nunca pode haver dois transmissores ativos.
    always @(posedge clk) begin
        if (rst_n)
            assert (!slave_bus_collision)
                else $fatal(1, "Colisao detectada no barramento dos escravos");
    end

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
        begin
            cycles = 0;
            while (!response_valid && cycles < 10_000) begin
                @(posedge clk);
                cycles++;
            end

            assert (response_valid)
                else $fatal(1, "Timeout do testbench aguardando resposta");
            assert (response_status == expected_status)
                else $fatal(1, "Status esperado=%0d, recebido=%0d",
                            expected_status, response_status);
            assert (!slave_bus_collision)
                else $fatal(1, "Resposta recebida durante colisao");
            tests_passed++;
            @(negedge clk);
        end
    endtask

    task automatic expect_single_register(input logic [15:0] expected_value);
        begin
            assert (response_byte_count == 8'd2)
                else $fatal(1, "Byte count esperado=2, recebido=%0d",
                            response_byte_count);
            assert (response_register_count == 8'd1)
                else $fatal(1, "Register count esperado=1, recebido=%0d",
                            response_register_count);
            response_register_read_index = 8'd0;
            #1;
            assert (response_register_read_valid)
                else $fatal(1, "Registrador de resposta indisponivel");
            assert (response_register_read_data == expected_value)
                else $fatal(1, "Valor esperado=0x%04h, recebido=0x%04h",
                            expected_value, response_register_read_data);
        end
    endtask

    task automatic read_and_expect(
        input logic [7:0] address,
        input logic [15:0] register_address,
        input logic [15:0] expected_value
    );
        begin
            send_command(address, FC_READ_HOLDING, register_address,
                         16'd0, 16'd1);
            wait_response(STATUS_OK);
            expect_single_register(expected_value);
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

        // Mesmo endereco de registrador, dados diferentes em cada escravo.
        send_command(8'h01, FC_WRITE_SINGLE, 16'h0002, 16'h10A5, 16'd0);
        wait_response(STATUS_OK);
        assert (response_data == 16'h10A5)
            else $fatal(1, "Eco FC06 do escravo 1 incorreto");

        send_command(8'h02, FC_WRITE_SINGLE, 16'h0002, 16'h205A, 16'd0);
        wait_response(STATUS_OK);
        assert (response_data == 16'h205A)
            else $fatal(1, "Eco FC06 do escravo 2 incorreto");

        read_and_expect(8'h01, 16'h0002, 16'h10A5);
        read_and_expect(8'h02, 16'h0002, 16'h205A);

        // Altera somente o escravo 2 e confirma isolamento bidirecional.
        send_command(8'h02, FC_WRITE_SINGLE, 16'h0002, 16'h2F0F, 16'd0);
        wait_response(STATUS_OK);
        read_and_expect(8'h01, 16'h0002, 16'h10A5);
        read_and_expect(8'h02, 16'h0002, 16'h2F0F);

        // Leitura multipla do escravo 1.
        send_command(8'h01, FC_WRITE_SINGLE, 16'h0003, 16'h30C3, 16'd0);
        wait_response(STATUS_OK);
        send_command(8'h01, FC_READ_HOLDING, 16'h0002, 16'd0, 16'd2);
        wait_response(STATUS_OK);
        assert (response_byte_count == 8'd4 &&
                response_register_count == 8'd2)
            else $fatal(1, "Contagem da leitura multipla incorreta");
        response_register_read_index = 8'd0;
        #1;
        assert (response_register_read_data == 16'h10A5)
            else $fatal(1, "Primeiro registrador multiplo incorreto");
        response_register_read_index = 8'd1;
        #1;
        assert (response_register_read_data == 16'h30C3)
            else $fatal(1, "Segundo registrador multiplo incorreto");

        // Cada escravo deve produzir suas proprias excecoes.
        send_command(8'h01, FC_WRITE_SINGLE, 16'h0040, 16'h5555, 16'd0);
        wait_response(STATUS_EXCEPTION);
        assert (response_exception == 8'h02)
            else $fatal(1, "Excecao do escravo 1 incorreta");

        send_command(8'h02, FC_READ_HOLDING, 16'h003F, 16'd0, 16'd2);
        wait_response(STATUS_EXCEPTION);
        assert (response_exception == 8'h02)
            else $fatal(1, "Excecao do escravo 2 incorreta");

        // O terceiro endereco nao esta instanciado.
        send_command(8'h03, FC_READ_HOLDING, 16'h0000, 16'd0, 16'd1);
        wait_response(STATUS_TIMEOUT);

        $display("PASS: %0d testes multi-escravo Modbus RTU aprovados.",
                 tests_passed);
        $finish;
    end

    initial begin
        #3ms;
        $fatal(1, "Watchdog: a simulacao multi-escravo nao terminou");
    end

endmodule
