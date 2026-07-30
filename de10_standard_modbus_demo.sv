`timescale 1ns / 1ps

import modbus_defs_pkg::*;

// Demonstracao e autoteste Modbus RTU para a Terasic DE10-Standard.
//
// KEY0: reset
// KEY1: FC06 manual no registrador 2 do escravo selecionado
// KEY2: FC03 manual no registrador 2 do escravo selecionado
// KEY3: inicia/avanca o fluxo de demonstracao
// SW9 : 0 = avanco por KEY3; 1 = avanco automatico a cada 2 segundos
// SW8 : 0 = escravo 1; 1 = escravo 2 (modo manual)
// SW7:0: valor da operacao manual e semente do autoteste
module de10_standard_modbus_demo #(
    parameter int unsigned CLOCK_FREQ = 50_000_000,
    parameter int unsigned BAUD_RATE = 115_200,
    parameter int unsigned MASTER_TIMEOUT_CYCLES = 5_000_000,
    parameter int unsigned DEMO_DELAY_CYCLES = 100_000_000
) (
    input  logic       CLOCK_50,
    input  logic [3:0] KEY,
    input  logic [9:0] SW,
    output logic [9:0] LEDR,
    output logic [6:0] HEX0,
    output logic [6:0] HEX1,
    output logic [6:0] HEX2,
    output logic [6:0] HEX3,
    output logic [6:0] HEX4,
    output logic [6:0] HEX5
);

    typedef enum logic [2:0] {
        TEST_IDLE,
        TEST_SEND,
        TEST_WAIT,
        TEST_CHECK_SECOND,
        TEST_PAUSE,
        TEST_DONE_STATE,
        TEST_FAIL_STATE
    } test_state_t;

    test_state_t test_state;

    logic [2:0] key_meta;
    logic [2:0] key_sync;
    logic [2:0] key_previous;
    logic       write_pressed;
    logic       read_pressed;
    logic       test_pressed;

    logic        cmd_valid;
    logic        cmd_ready;
    logic [7:0]  cmd_slave_addr;
    logic [7:0]  cmd_function;
    logic [15:0] cmd_register_addr;
    logic [15:0] cmd_write_data;
    logic [15:0] cmd_quantity;

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

    logic        done_latched;
    logic [2:0]  status_latched;
    logic [15:0] data_latched;
    logic        collision_latched;

    logic        test_running;
    logic        test_done;
    logic        test_pass;
    logic        test_fail;
    logic [3:0]  test_number;
    logic [3:0]  next_test_number;
    logic        test_substep;
    logic [15:0] test_value_slave_1;
    logic [15:0] test_value_slave_2;
    logic [15:0] test_value_register_3;
    logic        demo_auto_mode;
    logic [$clog2(DEMO_DELAY_CYCLES + 1)-1:0] demo_delay_count;
    logic [3:0]  left_display_value;
    logic        response_matches;

    // O manual informa que KEY possui debounce por Schmitt trigger. Os dois
    // primeiros registradores tratam a passagem para CLOCK_50.
    always_ff @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            key_meta     <= 3'b111;
            key_sync     <= 3'b111;
            key_previous <= 3'b111;
        end else begin
            key_meta     <= KEY[3:1];
            key_sync     <= key_meta;
            key_previous <= key_sync;
        end
    end

    assign write_pressed = key_previous[0] && !key_sync[0];
    assign read_pressed  = key_previous[1] && !key_sync[1];
    assign test_pressed  = key_previous[2] && !key_sync[2];

    // Criterio de aprovacao da resposta da etapa corrente.
    always_comb begin
        response_matches = 1'b0;
        case (test_number)
            4'h1: response_matches =
                (response_status == STATUS_OK) &&
                (response_data == test_value_slave_1);
            4'h2: response_matches =
                (response_status == STATUS_OK) &&
                (response_data == test_value_slave_1) &&
                (response_byte_count == 8'd2) &&
                (response_register_count == 8'd1);
            4'h3: response_matches =
                (response_status == STATUS_OK) &&
                (response_data == test_value_slave_2);
            4'h4: response_matches =
                (response_status == STATUS_OK) &&
                (response_data == test_value_slave_2) &&
                (response_register_count == 8'd1);
            4'h5: response_matches =
                (response_status == STATUS_OK) &&
                (response_data == test_value_slave_1);
            4'h6: response_matches =
                (response_status == STATUS_OK) &&
                (response_data == test_value_slave_2);
            4'h7: response_matches =
                (response_status == STATUS_OK) &&
                (response_data == test_value_register_3);
            4'h8: response_matches =
                (response_status == STATUS_OK) &&
                (response_byte_count == 8'd4) &&
                (response_register_count == 8'd2) &&
                response_register_read_valid &&
                (response_register_read_data == test_value_slave_1);
            4'h9: response_matches =
                (response_status == STATUS_EXCEPTION) &&
                (response_exception == 8'h02);
            4'hA: response_matches =
                (response_status == STATUS_EXCEPTION) &&
                (response_exception == 8'h02);
            4'hB: response_matches =
                (response_status == STATUS_EXCEPTION) &&
                (response_exception == 8'h03);
            4'hC: begin
                if (!test_substep)
                    response_matches =
                        (response_status == STATUS_UNSUPPORTED);
                else
                    response_matches =
                        (response_status == STATUS_INVALID_PARAM);
            end
            4'hD: response_matches =
                (response_status == STATUS_TIMEOUT);
            default: response_matches = 1'b0;
        endcase
    end

    always_ff @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            test_state                   <= TEST_IDLE;
            cmd_valid                    <= 1'b0;
            cmd_slave_addr               <= 8'h01;
            cmd_function                 <= FC_WRITE_SINGLE;
            cmd_register_addr            <= 16'h0002;
            cmd_write_data               <= 16'd0;
            cmd_quantity                 <= 16'd0;
            response_register_read_index <= 8'd0;
            done_latched                 <= 1'b0;
            status_latched               <= STATUS_INVALID;
            data_latched                 <= 16'd0;
            collision_latched            <= 1'b0;
            test_running                 <= 1'b0;
            test_done                    <= 1'b0;
            test_pass                    <= 1'b0;
            test_fail                    <= 1'b0;
            test_number                  <= 4'd0;
            next_test_number             <= 4'd0;
            test_substep                 <= 1'b0;
            test_value_slave_1           <= 16'd0;
            test_value_slave_2           <= 16'd0;
            test_value_register_3        <= 16'd0;
            demo_auto_mode               <= 1'b0;
            demo_delay_count             <= '0;
        end else begin
            if (cmd_valid && cmd_ready)
                cmd_valid <= 1'b0;

            if (slave_bus_collision) begin
                collision_latched <= 1'b1;
                if (test_running)
                    test_state <= TEST_FAIL_STATE;
            end

            if (response_valid) begin
                done_latched   <= 1'b1;
                status_latched <= response_status;
                if (response_status == STATUS_EXCEPTION)
                    data_latched <= {8'h00, response_exception};
                else
                    data_latched <= response_data;
            end

            if (!slave_bus_collision) begin
            case (test_state)
                TEST_IDLE: begin
                    test_running <= 1'b0;

                    if (test_pressed && !cmd_valid && cmd_ready) begin
                        test_value_slave_1    <= {8'h10, SW[7:0]};
                        test_value_slave_2    <= {8'h20, ~SW[7:0]};
                        test_value_register_3 <= {8'h30,
                                                  (SW[7:0] ^ 8'hA5)};
                        demo_auto_mode        <= SW[9];
                        test_running          <= 1'b1;
                        test_done             <= 1'b0;
                        test_pass             <= 1'b0;
                        test_fail             <= 1'b0;
                        collision_latched     <= 1'b0;
                        test_number           <= 4'h1;
                        next_test_number      <= 4'h1;
                        test_substep          <= 1'b0;
                        done_latched          <= 1'b0;
                        data_latched          <= 16'd0;
                        test_state            <= TEST_SEND;
                    end else if (write_pressed && !cmd_valid && cmd_ready) begin
                        cmd_slave_addr    <= SW[8] ? 8'h02 : 8'h01;
                        cmd_function      <= FC_WRITE_SINGLE;
                        cmd_register_addr <= 16'h0002;
                        cmd_write_data    <= {8'h00, SW[7:0]};
                        cmd_quantity      <= 16'd0;
                        cmd_valid         <= 1'b1;
                        done_latched      <= 1'b0;
                        test_done         <= 1'b0;
                        test_pass         <= 1'b0;
                        test_fail         <= 1'b0;
                    end else if (read_pressed && !cmd_valid && cmd_ready) begin
                        cmd_slave_addr               <= SW[8] ?
                                                        8'h02 : 8'h01;
                        cmd_function                 <= FC_READ_HOLDING;
                        cmd_register_addr            <= 16'h0002;
                        cmd_write_data               <= 16'd0;
                        cmd_quantity                 <= 16'd1;
                        response_register_read_index <= 8'd0;
                        cmd_valid                    <= 1'b1;
                        done_latched                 <= 1'b0;
                        test_done                    <= 1'b0;
                        test_pass                    <= 1'b0;
                        test_fail                    <= 1'b0;
                    end
                end

                TEST_SEND: begin
                    if (!cmd_valid && cmd_ready) begin
                        cmd_register_addr <= 16'h0002;
                        cmd_write_data    <= 16'd0;
                        cmd_quantity      <= 16'd0;

                        case (test_number)
                            4'h1: begin
                                cmd_slave_addr <= 8'h01;
                                cmd_function   <= FC_WRITE_SINGLE;
                                cmd_write_data <= test_value_slave_1;
                            end
                            4'h2: begin
                                cmd_slave_addr <= 8'h01;
                                cmd_function   <= FC_READ_HOLDING;
                                cmd_quantity   <= 16'd1;
                            end
                            4'h3: begin
                                cmd_slave_addr <= 8'h02;
                                cmd_function   <= FC_WRITE_SINGLE;
                                cmd_write_data <= test_value_slave_2;
                            end
                            4'h4: begin
                                cmd_slave_addr <= 8'h02;
                                cmd_function   <= FC_READ_HOLDING;
                                cmd_quantity   <= 16'd1;
                            end
                            4'h5: begin
                                cmd_slave_addr <= 8'h01;
                                cmd_function   <= FC_READ_HOLDING;
                                cmd_quantity   <= 16'd1;
                            end
                            4'h6: begin
                                cmd_slave_addr <= 8'h02;
                                cmd_function   <= FC_READ_HOLDING;
                                cmd_quantity   <= 16'd1;
                            end
                            4'h7: begin
                                cmd_slave_addr    <= 8'h01;
                                cmd_function      <= FC_WRITE_SINGLE;
                                cmd_register_addr <= 16'h0003;
                                cmd_write_data    <= test_value_register_3;
                            end
                            4'h8: begin
                                cmd_slave_addr               <= 8'h01;
                                cmd_function                 <= FC_READ_HOLDING;
                                cmd_quantity                 <= 16'd2;
                                response_register_read_index <= 8'd0;
                            end
                            4'h9: begin
                                cmd_slave_addr    <= 8'h01;
                                cmd_function      <= FC_WRITE_SINGLE;
                                cmd_register_addr <= 16'h0040;
                                cmd_write_data    <= 16'h5555;
                            end
                            4'hA: begin
                                cmd_slave_addr    <= 8'h02;
                                cmd_function      <= FC_READ_HOLDING;
                                cmd_register_addr <= 16'h003F;
                                cmd_quantity      <= 16'd2;
                            end
                            4'hB: begin
                                cmd_slave_addr    <= 8'h02;
                                cmd_function      <= FC_READ_HOLDING;
                                cmd_register_addr <= 16'h0000;
                                cmd_quantity      <= 16'd14;
                            end
                            4'hC: begin
                                cmd_slave_addr    <= 8'h01;
                                cmd_register_addr <= 16'h0000;
                                cmd_quantity      <= 16'd1;
                                if (!test_substep)
                                    cmd_function <= 8'h10;
                                else begin
                                    cmd_function <= FC_READ_HOLDING;
                                    cmd_quantity <= 16'd0;
                                end
                            end
                            default: begin // D: endereco 03 nao existe.
                                cmd_slave_addr    <= 8'h03;
                                cmd_function      <= FC_READ_HOLDING;
                                cmd_register_addr <= 16'h0000;
                                cmd_quantity      <= 16'd1;
                            end
                        endcase

                        cmd_valid    <= 1'b1;
                        done_latched <= 1'b0;
                        test_state   <= TEST_WAIT;
                    end
                end

                TEST_WAIT: begin
                    if (response_valid) begin
                        if (!response_matches) begin
                            test_state <= TEST_FAIL_STATE;
                        end else if (test_number == 4'h8) begin
                            response_register_read_index <= 8'd1;
                            test_state <= TEST_CHECK_SECOND;
                        end else if ((test_number == 4'hC) &&
                                     !test_substep) begin
                            test_substep      <= 1'b1;
                            next_test_number <= 4'hC;
                            demo_delay_count <= '0;
                            test_state       <= TEST_PAUSE;
                        end else if (test_number == 4'hD) begin
                            test_state <= TEST_DONE_STATE;
                        end else begin
                            next_test_number <= test_number + 1'b1;
                            test_substep     <= 1'b0;
                            demo_delay_count <= '0;
                            test_state       <= TEST_PAUSE;
                        end
                    end
                end

                TEST_CHECK_SECOND: begin
                    if (response_register_read_valid &&
                        (response_register_read_data ==
                         test_value_register_3)) begin
                        response_register_read_index <= 8'd0;
                        next_test_number             <= 4'h9;
                        demo_delay_count             <= '0;
                        test_state                   <= TEST_PAUSE;
                    end else begin
                        test_state <= TEST_FAIL_STATE;
                    end
                end

                // Mantem o resultado visivel sem alterar o baud rate.
                TEST_PAUSE: begin
                    if (demo_auto_mode) begin
                        if (demo_delay_count == DEMO_DELAY_CYCLES - 1) begin
                            demo_delay_count <= '0;
                            test_number      <= next_test_number;
                            test_state       <= TEST_SEND;
                        end else begin
                            demo_delay_count <= demo_delay_count + 1'b1;
                        end
                    end else if (test_pressed) begin
                        test_number <= next_test_number;
                        test_state <= TEST_SEND;
                    end
                end

                TEST_DONE_STATE: begin
                    test_running <= 1'b0;
                    test_done    <= 1'b1;
                    test_pass    <= 1'b1;
                    test_fail    <= 1'b0;
                    test_state   <= TEST_IDLE;
                end

                TEST_FAIL_STATE: begin
                    test_running <= 1'b0;
                    test_done    <= 1'b1;
                    test_pass    <= 1'b0;
                    test_fail    <= 1'b1;
                    test_state   <= TEST_IDLE;
                end

                default: test_state <= TEST_IDLE;
            endcase
            end
        end
    end

    modbus_top_level #(
        .CLOCK_FREQ           (CLOCK_FREQ),
        .BAUD_RATE            (BAUD_RATE),
        .MASTER_TIMEOUT_CYCLES(MASTER_TIMEOUT_CYCLES),
        .REGISTER_DEPTH       (64),
        .MAX_READ_REGISTERS   (125),
        .NUM_SLAVES           (2)
    ) modbus (
        .clk                         (CLOCK_50),
        .rst_n                       (KEY[0]),
        .cmd_valid                   (cmd_valid),
        .cmd_ready                   (cmd_ready),
        .cmd_slave_addr              (cmd_slave_addr),
        .cmd_function                (cmd_function),
        .cmd_register_addr           (cmd_register_addr),
        .cmd_write_data              (cmd_write_data),
        .cmd_quantity                (cmd_quantity),
        .slave_id                    (8'h01),
        .master_busy                 (master_busy),
        .response_valid              (response_valid),
        .response_status             (response_status),
        .response_exception          (response_exception),
        .response_data               (response_data),
        .response_byte_count         (response_byte_count),
        .response_register_count     (response_register_count),
        .response_register_read_index(response_register_read_index),
        .response_register_read_data (response_register_read_data),
        .response_register_read_valid(response_register_read_valid),
        .overflow_byte_count         (overflow_byte_count),
        .master_to_slave_serial      (master_to_slave_serial),
        .slave_to_master_serial      (slave_to_master_serial),
        .slave_bus_collision         (slave_bus_collision)
    );

    always_comb begin
        LEDR = 10'd0;
        LEDR[0] = master_busy;
        LEDR[1] = done_latched;
        LEDR[2] = done_latched && (status_latched == STATUS_OK);
        LEDR[3] = test_running;
        LEDR[4] = test_done;
        LEDR[5] = test_pass;
        LEDR[6] = test_fail;
        LEDR[7] = collision_latched;
        LEDR[8] = !master_to_slave_serial;
        LEDR[9] = !slave_to_master_serial;

        if (test_running || test_done || test_fail)
            left_display_value = test_number;
        else
            left_display_value = SW[8] ? 4'h2 : 4'h1;
    end

    hex7seg hex_digit_0 (.value(data_latched[3:0]),   .segments(HEX0));
    hex7seg hex_digit_1 (.value(data_latched[7:4]),   .segments(HEX1));
    hex7seg hex_digit_2 (.value(data_latched[11:8]),  .segments(HEX2));
    hex7seg hex_digit_3 (.value(data_latched[15:12]), .segments(HEX3));
    hex7seg hex_status  (.value({1'b0, status_latched}),
                         .segments(HEX4));
    hex7seg hex_left    (.value(left_display_value), .segments(HEX5));

endmodule

// Display de anodo comum da DE10-Standard: segmento ativo em nivel baixo.
module hex7seg (
    input  logic [3:0] value,
    output logic [6:0] segments
);
    always_comb begin
        case (value)
            4'h0: segments = 7'b1000000;
            4'h1: segments = 7'b1111001;
            4'h2: segments = 7'b0100100;
            4'h3: segments = 7'b0110000;
            4'h4: segments = 7'b0011001;
            4'h5: segments = 7'b0010010;
            4'h6: segments = 7'b0000010;
            4'h7: segments = 7'b1111000;
            4'h8: segments = 7'b0000000;
            4'h9: segments = 7'b0010000;
            4'hA: segments = 7'b0001000;
            4'hB: segments = 7'b0000011;
            4'hC: segments = 7'b1000110;
            4'hD: segments = 7'b0100001;
            4'hE: segments = 7'b0000110;
            default: segments = 7'b0001110;
        endcase
    end
endmodule
