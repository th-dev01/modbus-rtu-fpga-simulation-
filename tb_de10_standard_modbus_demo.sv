`timescale 1ns / 1ps

module tb_de10_standard_modbus_demo;
    logic       CLOCK_50 = 1'b0;
    logic [3:0] KEY;
    logic [9:0] SW;
    logic [9:0] LEDR;
    logic [6:0] HEX0;
    logic [6:0] HEX1;
    logic [6:0] HEX2;
    logic [6:0] HEX3;
    logic [6:0] HEX4;
    logic [6:0] HEX5;

    int cycles;

    always #5 CLOCK_50 = ~CLOCK_50;

    de10_standard_modbus_demo #(
        .CLOCK_FREQ           (8_000_000),
        .BAUD_RATE            (1_000_000),
        .MASTER_TIMEOUT_CYCLES(700),
        .DEMO_DELAY_CYCLES    (10)
    ) dut (.*);

    initial begin
        KEY = 4'b1110;
        // SW9=1 seleciona modo automatico. SW7:0 fornece a semente A5.
        SW = 10'b10_1010_0101;

        repeat (5) @(posedge CLOCK_50);
        @(negedge CLOCK_50);
        KEY[0] = 1'b1;

        // Pulso em KEY3; os sincronizadores internos detectam a borda.
        repeat (5) @(posedge CLOCK_50);
        @(negedge CLOCK_50);
        KEY[3] = 1'b0;
        repeat (4) @(posedge CLOCK_50);
        @(negedge CLOCK_50);
        KEY[3] = 1'b1;

        cycles = 0;
        while (!LEDR[4] && cycles < 100_000) begin
            @(posedge CLOCK_50);
            cycles++;
        end

        assert (LEDR[4])
            else $fatal(1, "Autoteste da placa nao terminou");
        assert (LEDR[5] && !LEDR[6])
            else $fatal(1, "Autoteste terminou sem aprovacao");
        assert (!LEDR[7])
            else $fatal(1, "Autoteste detectou colisao entre escravos");

        $display("PASS: fluxo automatico da DE10-Standard aprovado na etapa D.");
        $finish;
    end

    initial begin
        #2ms;
        $fatal(1, "Watchdog: demonstracao da placa nao terminou");
    end

endmodule
