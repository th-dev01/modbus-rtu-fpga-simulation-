import modbus_crc_pkg::*;
import modbus_defs_pkg::*;

module modbus_master_fsm #(
    parameter int unsigned TIMEOUT_CYCLES = 1000,
    parameter int unsigned MAX_RESPONSE_BYTES = 256,
    parameter int unsigned MAX_READ_REGISTERS = 125
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        cmd_valid,
    output logic        cmd_ready,
    input  logic [7:0]  cmd_slave_addr,
    input  logic [7:0]  cmd_function,
    input  logic [15:0] cmd_register_addr,
    input  logic [15:0] cmd_write_data,
    input  logic [15:0] cmd_quantity,

    output logic [7:0]  tx_data,
    output logic        tx_valid,
    input  logic        tx_ready,

    input  logic [7:0]  rx_data,
    input  logic        rx_valid,
    input  logic        rx_frame_end,

    output logic        busy,
    output logic        response_valid,
    output modbus_status_t response_status,
    output logic [7:0]  response_exception,
    output logic [15:0] response_data,
    output logic [7:0]  response_byte_count,
    output logic [7:0]  response_register_count,
    output logic [15:0] response_registers [0:MAX_READ_REGISTERS-1],
    input  logic [7:0]  response_register_read_index,
    output logic [15:0] response_register_read_data,
    output logic        response_register_read_valid,
    output logic [15:0] overflow_byte_count
);

    typedef enum logic [2:0] {
        S_IDLE,
        S_BUILD,
        S_SEND,
        S_WAIT_RESPONSE,
        S_VALIDATE,
        S_DONE
    } state_t;

    state_t state;
    logic builder_start;
    logic builder_busy;
    logic builder_valid;
    logic [2:0] builder_index;
    logic [7:0] builder_byte;

    logic [7:0] selected_slave;
    logic [7:0] selected_function;
    logic [15:0] selected_register;
    logic [15:0] selected_value;

    logic [7:0] response_buffer [0:MAX_RESPONSE_BYTES-1];
    logic [$clog2(MAX_RESPONSE_BYTES+1)-1:0] response_length;
    logic [$clog2(TIMEOUT_CYCLES+1)-1:0] timeout_count;
    logic [15:0] response_crc;
    logic response_overflow;
    integer register_index;

    master_frame_builder frame_builder (
        .clk              (clk),
        .rst_n            (rst_n),
        .start            (builder_start),
        .slave_addr       (selected_slave),
        .function_code    (selected_function),
        .register_addr    (selected_register),
        .value_or_quantity(selected_value),
        .busy             (builder_busy),
        .frame_valid      (builder_valid),
        .frame_ready      (tx_ready && state == S_SEND),
        .frame_index      (builder_index),
        .frame_byte       (builder_byte)
    );

    assign cmd_ready = (state == S_IDLE);
    assign busy = (state != S_IDLE) && (state != S_DONE);
    assign tx_data = builder_byte;
    assign tx_valid = (state == S_SEND) && builder_valid;
    assign response_register_read_valid =
        (response_register_read_index < response_register_count) &&
        (response_register_read_index < MAX_READ_REGISTERS);
    assign response_register_read_data = response_register_read_valid
        ? response_registers[response_register_read_index] : 16'd0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= S_IDLE;
            builder_start       <= 1'b0;
            selected_slave      <= 8'd0;
            selected_function   <= 8'd0;
            selected_register   <= 16'd0;
            selected_value      <= 16'd0;
            response_length     <= '0;
            timeout_count       <= '0;
            response_crc        <= 16'hFFFF;
            response_valid      <= 1'b0;
            response_status     <= STATUS_INVALID;
            response_exception  <= 8'd0;
            response_data       <= 16'd0;
            response_byte_count <= 8'd0;
            response_register_count <= 8'd0;
            response_overflow    <= 1'b0;
            overflow_byte_count  <= 16'd0;
            for (register_index = 0; register_index < MAX_READ_REGISTERS; register_index++)
                response_registers[register_index] <= 16'd0;
        end else begin
            builder_start  <= 1'b0;
            response_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    response_length         <= '0;
                    timeout_count           <= '0;
                    response_overflow       <= 1'b0;
                    response_register_count <= 8'd0;
                    overflow_byte_count     <= 16'd0;
                    if (cmd_valid) begin
                        if ((cmd_function != FC_READ_HOLDING) &&
                            (cmd_function != FC_WRITE_SINGLE)) begin
                            response_status <= STATUS_UNSUPPORTED;
                            state <= S_DONE;
                        end else if ((cmd_function == FC_READ_HOLDING) &&
                                     ((cmd_quantity == 16'd0) ||
                                      (cmd_quantity > MODBUS_MAX_READ_REGISTERS) ||
                                      (cmd_quantity > MAX_READ_REGISTERS))) begin
                            response_status <= STATUS_INVALID_PARAM;
                            state <= S_DONE;
                        end else begin
                            selected_slave    <= cmd_slave_addr;
                            selected_function <= cmd_function;
                            selected_register <= cmd_register_addr;
                            selected_value    <= (cmd_function == FC_READ_HOLDING)
                                                 ? cmd_quantity : cmd_write_data;
                            state <= S_BUILD;
                        end
                    end
                end

                S_BUILD: begin
                    builder_start <= 1'b1;
                    state <= S_SEND;
                end

                S_SEND: begin
                    if (builder_valid && tx_ready && builder_index == 3'd7) begin
                        timeout_count   <= '0;
                        response_length <= '0;
                        response_crc    <= 16'hFFFF;
                        state <= S_WAIT_RESPONSE;
                    end
                end

                S_WAIT_RESPONSE: begin
                    if (rx_valid) begin
                        if (response_length < MAX_RESPONSE_BYTES) begin
                            response_buffer[response_length] <= rx_data;
                            response_length <= response_length + 1'b1;
                            response_crc <= crc16_update(response_crc, rx_data);
                        end else begin
                            response_overflow <= 1'b1;
                            overflow_byte_count <= overflow_byte_count + 16'd1;
                        end
                        timeout_count <= '0;
                    end else if (timeout_count == TIMEOUT_CYCLES-1) begin
                        response_status <= STATUS_TIMEOUT;
                        state <= S_DONE;
                    end else begin
                        timeout_count <= timeout_count + 1'b1;
                    end

                    if (rx_frame_end)
                        state <= S_VALIDATE;
                end

                S_VALIDATE: begin
                    response_exception  <= 8'd0;
                    response_data       <= 16'd0;
                    response_byte_count <= 8'd0;
                    response_register_count <= 8'd0;

                    if (response_overflow) begin
                        response_status <= STATUS_OVERFLOW;
                    end else if (response_length < 5) begin
                        response_status <= STATUS_INVALID;
                    end else if (response_crc != 16'h0000) begin
                        response_status <= STATUS_CRC_ERROR;
                    end else if (response_buffer[0] != selected_slave) begin
                        response_status <= STATUS_INVALID;
                    end else if (response_buffer[1] == (selected_function | 8'h80)) begin
                        if (response_length == 5) begin
                            response_status    <= STATUS_EXCEPTION;
                            response_exception <= response_buffer[2];
                        end else begin
                            response_status <= STATUS_INVALID;
                        end
                    end else if (response_buffer[1] != selected_function) begin
                        response_status <= STATUS_INVALID;
                    end else if (selected_function == FC_READ_HOLDING) begin
                        if ((response_buffer[2] == 0) ||
                            (response_buffer[2][0] != 0) ||
                            (response_buffer[2] != (selected_value[7:0] << 1)) ||
                            (response_length != response_buffer[2] + 5)) begin
                            response_status <= STATUS_INVALID;
                        end else if ((response_buffer[2] >> 1) > MAX_READ_REGISTERS) begin
                            response_status <= STATUS_OVERFLOW;
                        end else begin
                            response_status     <= STATUS_OK;
                            response_byte_count <= response_buffer[2];
                            response_register_count <= response_buffer[2] >> 1;
                            response_data       <= {response_buffer[3], response_buffer[4]};
                            for (register_index = 0; register_index < MAX_READ_REGISTERS; register_index++) begin
                                if (register_index < (response_buffer[2] >> 1)) begin
                                    response_registers[register_index] <= {
                                        response_buffer[3 + (register_index * 2)],
                                        response_buffer[4 + (register_index * 2)]
                                    };
                                end
                            end
                        end
                    end else if (selected_function == FC_WRITE_SINGLE) begin
                        if ((response_length != 8) ||
                            ({response_buffer[2], response_buffer[3]} != selected_register) ||
                            ({response_buffer[4], response_buffer[5]} != selected_value)) begin
                            response_status <= STATUS_INVALID;
                        end else begin
                            response_status <= STATUS_OK;
                            response_data   <= selected_value;
                        end
                    end else begin
                        response_status <= STATUS_INVALID;
                    end
                    state <= S_DONE;
                end

                S_DONE: begin
                    response_valid <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
