`timescale 1ns / 1ps

// ==============================================================================
// Módulo: uart_tx
// Descrição: Transmissor UART. Converte um byte paralelo em um fluxo serial
//            com 1 start bit, 8 data bits e 1 stop bit. Sem paridade.
// Padrão: SystemVerilog 2012
// ==============================================================================

module uart_tx(
    input  logic       clk,
    input  logic       rst_n,

    input  logic       baud_tick,

    input  logic       tx_start,
    input  logic [7:0] tx_data,

    output logic       tx,
    output logic       tx_busy,
    output logic       tx_done
);

    // Tipagem da FSM usando enum para segurança e legibilidade
    typedef enum logic [2:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Sinais internos (Datapath)
    logic [2:0] bit_idx;      // Contador de 0 a 7 para os bits de dados
    logic [7:0] shift_reg;    // Registrador de deslocamento para enviar os dados

    // --------------------------------------------------------------------------
    // Lógica Sequencial: Atualização de Estado
    // --------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // --------------------------------------------------------------------------
    // Lógica Combinacional: Transição de Estados (Next State Logic)
    // --------------------------------------------------------------------------
    always_comb begin
        // Valor padrão para evitar latches inferidos
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (tx_start) begin
                    next_state = START_BIT;
                end
            end

            START_BIT: begin
                if (baud_tick) begin
                    next_state = DATA_BITS;
                end
            end

            DATA_BITS: begin
                if (baud_tick) begin
                    if (bit_idx == 3'd7) begin
                        next_state = STOP_BIT;
                    end
                end
            end

            STOP_BIT: begin
                if (baud_tick) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // --------------------------------------------------------------------------
    // Lógica Sequencial: Datapath e Saídas Registradas (Glitches-free)
    // --------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx        <= 1'b1; // A linha serial fica em ALTA (1) em repouso
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
        end else begin
            // Valores padrão de saídas transientes
            tx_done <= 1'b0; 

            case (current_state)
                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        shift_reg <= tx_data; // Captura o dado na entrada
                        tx_busy   <= 1'b1;
                    end
                end

                START_BIT: begin
                    tx <= 1'b0; // Start bit é sempre 0 lógico
                    if (baud_tick) begin
                        bit_idx <= 3'd0;
                    end
                end

                DATA_BITS: begin
                    tx <= shift_reg[0]; // Transmite LSB primeiro (Padrão UART/Modbus)
                    if (baud_tick) begin
                        shift_reg <= {1'b0, shift_reg[7:1]}; // Shift Right
                        bit_idx   <= bit_idx + 1'b1;
                    end
                end

                STOP_BIT: begin
                    tx <= 1'b1; // Stop bit é sempre 1 lógico
                end

                DONE: begin
                    tx_busy <= 1'b0;
                    tx_done <= 1'b1; // Pulsa alto por 1 ciclo de clock
                end
            endcase
        end
    end

endmodule