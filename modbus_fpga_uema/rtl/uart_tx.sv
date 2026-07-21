`timescale 1ns / 1ps

// Transmissor UART 8N1. Cada bit permanece na linha durante um periodo
// completo de baud, independentemente da fase em que tx_start e recebido.
module uart_tx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       baud_tick,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx,
    output logic       tx_busy,
    output logic       tx_done
);

    typedef enum logic [2:0] {
        IDLE,
        ALIGN_START,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    } state_t;

    state_t state;
    logic [2:0] bit_idx;
    logic [7:0] shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            tx        <= 1'b1;
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;

                    if (tx_start) begin
                        shift_reg <= tx_data;
                        bit_idx   <= 3'd0;
                        tx_busy   <= 1'b1;
                        state     <= ALIGN_START;
                    end
                end

                ALIGN_START: begin
                    // Inicia o quadro exatamente em um baud_tick. Assim o
                    // start bit nunca fica mais curto por causa da fase do
                    // gerador de baud no instante de tx_start.
                    if (baud_tick) begin
                        tx    <= 1'b0;
                        state <= START_BIT;
                    end
                end

                START_BIT: begin
                    // O tick seguinte encerra um start bit completo.
                    if (baud_tick) begin
                        tx        <= shift_reg[0];
                        shift_reg <= {1'b0, shift_reg[7:1]};
                        bit_idx   <= 3'd0;
                        state     <= DATA_BITS;
                    end
                end

                DATA_BITS: begin
                    if (baud_tick) begin
                        if (bit_idx == 3'd7) begin
                            tx    <= 1'b1;
                            state <= STOP_BIT;
                        end else begin
                            tx        <= shift_reg[0];
                            shift_reg <= {1'b0, shift_reg[7:1]};
                            bit_idx   <= bit_idx + 3'd1;
                        end
                    end
                end

                STOP_BIT: begin
                    if (baud_tick) begin
                        tx      <= 1'b1;
                        tx_busy <= 1'b0;
                        tx_done <= 1'b1;
                        state   <= IDLE;
                    end
                end

                default: begin
                    state   <= IDLE;
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                end
            endcase
        end
    end

endmodule
