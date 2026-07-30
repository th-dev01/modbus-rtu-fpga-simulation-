`timescale 1ns / 1ps

// ==============================================================================
// Módulo: baud_gen
// Descrição: Gerador de Baud Rate para UART. Gera um pulso (baud_tick) com 
//            duração de 1 ciclo de clock na frequência especificada.
// Padrão: SystemVerilog 2012
// ==============================================================================

module baud_gen #(
    parameter int CLOCK_FREQ = 50_000_000, // Frequência do clock da FPGA (50 MHz)
    parameter int BAUD_RATE  = 115200      // Taxa de transmissão desejada
)(
    input  logic clk,
    input  logic rst_n,                    // Reset assíncrono ativo em nível baixo

    output logic baud_tick
);

    // O contador precisa ir de 0 até (CLOCK_FREQ / BAUD_RATE) - 1
    // Para 50MHz e 115200bps, o valor máximo é 434.
    localparam int MAX_COUNT = (CLOCK_FREQ / BAUD_RATE) - 1;
    
    // Calcula o número de bits necessários para o contador (largura do registrador)
    localparam int COUNT_WIDTH = $clog2(MAX_COUNT + 1);

    logic [COUNT_WIDTH-1:0] counter;

    // Lógica Sequencial: Contador
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= '0;
            baud_tick <= 1'b0;
        end else begin
            if (counter == MAX_COUNT[COUNT_WIDTH-1:0]) begin
                counter <= '0;
                baud_tick <= 1'b1; // Gera o pulso
            end else begin
                counter <= counter + 1'b1;
                baud_tick <= 1'b0;
            end
        end
    end

endmodule