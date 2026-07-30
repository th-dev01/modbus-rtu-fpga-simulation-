`timescale 1ns / 1ps

// ==============================================================================
// Módulo: frame_timer
// Descrição: Temporizador Modbus T3.5. Conta ciclos de baud_tick enquanto a 
//            linha serial está inativa. Gera um pulso frame_done se passar
//            de 3.5 tempos de caractere (aprox 39 bits de inatividade).
// ==============================================================================

module frame_timer(
    input  logic clk,
    input  logic rst_n,
    
    input  logic baud_tick,
    input  logic rx,         // Linha serial sendo monitorada

    output logic frame_done
);

    // 39 ticks equivale a aproximadamente 3.5 caracteres (11 bits cada)
    localparam int T3_5_TICKS = 39; 
    
    // Contador precisa ir até 39, 6 bits são suficientes (máximo 63)
    logic [5:0] idle_counter;
    logic timer_en;

    // Habilita o timer apenas quando a linha está em IDLE (alta)
    assign timer_en = (rx == 1'b1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idle_counter <= '0;
            frame_done   <= 1'b0;
        end else begin
            frame_done <= 1'b0; // Sinal transiente por padrão

            if (!timer_en) begin
                // Se a linha foi a zero (início de um dado), zera o timer
                idle_counter <= '0;
            end else if (baud_tick) begin
                if (idle_counter < T3_5_TICKS) begin
                    idle_counter <= idle_counter + 1'b1;
                end else if (idle_counter == T3_5_TICKS) begin
                    frame_done   <= 1'b1; // Avisa o Modbus que o frame acabou
                    idle_counter <= idle_counter + 1'b1; // Evita gerar pulso contínuo
                end
            end
        end
    end

endmodule