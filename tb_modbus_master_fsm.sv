`timescale 1ns/1ps

module tb_modbus_master_fsm;
    localparam int TIMEOUT_CYCLES = 30;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic cmd_valid;
    logic cmd_ready;
    logic [7:0] cmd_slave_addr;
    logic [7:0] cmd_function;
    logic [15:0] cmd_register_addr;
    logic [15:0] cmd_write_data;
    logic [15:0] cmd_quantity;
    logic [7:0] tx_data;
    logic tx_valid;
    logic tx_ready = 1'b1;
    logic [7:0] rx_data;
    logic rx_valid;
    logic rx_frame_end;
    logic busy;
    logic response_valid;
    logic [2:0] response_status;
    logic [7:0] response_exception;
    logic [15:0] response_data;
    logic [7:0] response_byte_count;

    logic [7:0] captured_request [0:7];
    int captured_count;

    always #5 clk = ~clk;

    modbus_master_fsm #(
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES)
    ) dut (.*);

    function automatic logic [15:0] crc16_update(
        input logic [15:0] crc_in,
        input logic [7:0] data
    );
        logic [15:0] crc;
        int bit_index;
        begin
            crc = crc_in ^ data;
            for (bit_index = 0; bit_index < 8; bit_index++)
                crc = crc[0] ? ((crc >> 1) ^ 16'hA001) : (crc >> 1);
            return crc;
        end
    endfunction

    always_ff @(posedge clk) begin
        if (tx_valid && tx_ready) begin
            captured_request[captured_count] <= tx_data;
            captured_count <= captured_count + 1;
        end
    end

    task automatic issue_command(
        input logic [7:0] function_code,
        input logic [15:0] register_addr,
        input logic [15:0] value,
        input logic [15:0] quantity
    );
        begin
            wait (cmd_ready);
            @(negedge clk);
            cmd_slave_addr   = 8'h01;
            cmd_function     = function_code;
            cmd_register_addr= register_addr;
            cmd_write_data   = value;
            cmd_quantity     = quantity;
            cmd_valid        = 1'b1;
            @(negedge clk);
            cmd_valid        = 1'b0;
            wait (captured_count == 8);
        end
    endtask

    task automatic send_response(
        input int payload_length,
        input logic [7:0] payload [0:253],
        input logic corrupt_crc,
        input int delay_cycles
    );
        logic [15:0] crc;
        int index;
        begin
            repeat (delay_cycles) @(posedge clk);
            crc = 16'hFFFF;
            for (index = 0; index < payload_length; index++)
                crc = crc16_update(crc, payload[index]);

            for (index = 0; index < payload_length; index++) begin
                @(negedge clk); rx_data = payload[index]; rx_valid = 1'b1;
                @(negedge clk); rx_valid = 1'b0;
            end
            @(negedge clk); rx_data = corrupt_crc ? (crc[7:0] ^ 8'h01) : crc[7:0]; rx_valid = 1'b1;
            @(negedge clk); rx_valid = 1'b0;
            @(negedge clk); rx_data = crc[15:8]; rx_valid = 1'b1;
            @(negedge clk); rx_valid = 1'b0;
            @(negedge clk); rx_frame_end = 1'b1;
            @(negedge clk); rx_frame_end = 1'b0;
        end
    endtask

    task automatic expect_status(input logic [2:0] expected);
        begin
            wait (response_valid);
            assert (response_status == expected)
                else $fatal(1, "Status esperado=%0d, recebido=%0d", expected, response_status);
            @(posedge clk);
            captured_count = 0;
        end
    endtask

    initial begin
        logic [7:0] payload [0:253];
        cmd_valid = 0; rx_data = 0; rx_valid = 0; rx_frame_end = 0;
        captured_count = 0;
        repeat (3) @(posedge clk); rst_n = 1'b1;

        // FC03: leitura válida de um registrador com retorno 0x1234.
        issue_command(8'h03, 16'h0000, 16'h0000, 16'h0001);
        payload[0]=8'h01; payload[1]=8'h03; payload[2]=8'h02;
        payload[3]=8'h12; payload[4]=8'h34;
        send_response(5, payload, 1'b0, 2);
        expect_status(3'd0);
        assert (response_data == 16'h1234 && response_byte_count == 2);

        // FC06: eco válido da escrita.
        issue_command(8'h06, 16'h0002, 16'hABCD, 16'h0000);
        payload[0]=8'h01; payload[1]=8'h06; payload[2]=8'h00;
        payload[3]=8'h02; payload[4]=8'hAB; payload[5]=8'hCD;
        send_response(6, payload, 1'b0, 1);
        expect_status(3'd0);

        // Resposta de exceção: Illegal Data Address.
        issue_command(8'h03, 16'hFFFF, 16'h0000, 16'h0001);
        payload[0]=8'h01; payload[1]=8'h83; payload[2]=8'h02;
        send_response(3, payload, 1'b0, 1);
        expect_status(3'd1);
        assert (response_exception == 8'h02);

        // CRC inválido.
        issue_command(8'h03, 16'h0000, 16'h0000, 16'h0001);
        payload[0]=8'h01; payload[1]=8'h03; payload[2]=8'h02;
        payload[3]=8'h56; payload[4]=8'h78;
        send_response(5, payload, 1'b1, 1);
        expect_status(3'd2);

        // Ausência de resposta.
        issue_command(8'h03, 16'h0000, 16'h0000, 16'h0001);
        expect_status(3'd3);

        $display("Todos os testes do mestre Modbus foram aprovados.");
        $finish;
    end

endmodule
