`timescale 1ns / 1ps

// ==============================================================================
// Módulo: uart_rx
// Descrição: Receptor UART otimizado para simulação interna em FPGA.
//            Espera o Start Bit (0), recebe 8 bits de dados (LSB first) e 
//            verifica o Stop Bit (1).
// Padrão: SystemVerilog 2012
// ==============================================================================

module uart_rx(
    input  logic       clk,
    input  logic       rst_n,

    input  logic       baud_tick,
    input  logic       rx,          // Linha serial de entrada

    output logic [7:0] rx_data,     // Byte recebido
    output logic       rx_valid     // Pulso de 1 clock indicando dado válido
);

    typedef enum logic [2:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT,
        DONE
    } state_t;

    state_t current_state, next_state;

    logic [2:0] bit_idx;
    logic [7:0] shift_reg;

    // 1. Lógica Sequencial: Atualização de Estado
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE;
        else        current_state <= next_state;
    end

    // 2. Lógica Combinacional: Transição de Estados
    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (rx == 1'b0) begin // Detectou a borda de descida (Start Bit)
                    next_state = START_BIT;
                end
            end

            START_BIT: begin
                if (baud_tick) next_state = DATA_BITS;
            end

            DATA_BITS: begin
                if (baud_tick) begin
                    if (bit_idx == 3'd7) next_state = STOP_BIT;
                end
            end

            STOP_BIT: begin
                if (baud_tick) next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // 3. Lógica Sequencial: Datapath (Amostragem dos bits)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
        end else begin
            rx_valid <= 1'b0; // Default: sem dado válido

            case (current_state)
                IDLE: begin
                    bit_idx <= 3'd0;
                end

                DATA_BITS: begin
                    if (baud_tick) begin
                        // Modbus/UART transmite LSB primeiro. 
                        // Deslocamos para a direita e inserimos no MSB.
                        shift_reg <= {rx, shift_reg[7:1]}; 
                        bit_idx   <= bit_idx + 1'b1;
                    end
                end

                DONE: begin
                    rx_data  <= shift_reg;
                    rx_valid <= 1'b1; // Avisa a camada Modbus que chegou um byte
                end
            endcase
        end
    end

endmodule