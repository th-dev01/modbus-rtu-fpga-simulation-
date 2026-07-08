module modbus_master_fsm #(
    parameter int unsigned TIMEOUT_CYCLES = 1000,
    parameter int unsigned MAX_RESPONSE_BYTES = 256
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
    output logic [2:0]  response_status,
    output logic [7:0]  response_exception,
    output logic [15:0] response_data,
    output logic [7:0]  response_byte_count
);

    localparam logic [7:0] FC_READ_HOLDING = 8'h03;
    localparam logic [7:0] FC_WRITE_SINGLE = 8'h06;

    localparam logic [2:0] STATUS_OK       = 3'd0;
    localparam logic [2:0] STATUS_EXCEPTION= 3'd1;
    localparam logic [2:0] STATUS_CRC_ERROR= 3'd2;
    localparam logic [2:0] STATUS_TIMEOUT  = 3'd3;
    localparam logic [2:0] STATUS_INVALID  = 3'd4;

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

    function automatic logic [15:0] crc16_update(
        input logic [15:0] crc_in,
        input logic [7:0] data
    );
        logic [15:0] next_crc;
        integer bit_index;
        begin
            next_crc = crc_in ^ data;
            for (bit_index = 0; bit_index < 8; bit_index++) begin
                if (next_crc[0])
                    next_crc = (next_crc >> 1) ^ 16'hA001;
                else
                    next_crc = next_crc >> 1;
            end
            return next_crc;
        end
    endfunction

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
        end else begin
            builder_start  <= 1'b0;
            response_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    response_length <= '0;
                    timeout_count   <= '0;
                    if (cmd_valid) begin
                        selected_slave    <= cmd_slave_addr;
                        selected_function <= cmd_function;
                        selected_register <= cmd_register_addr;
                        selected_value    <= (cmd_function == FC_READ_HOLDING)
                                             ? cmd_quantity : cmd_write_data;
                        state <= S_BUILD;
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
                    if (rx_valid && response_length < MAX_RESPONSE_BYTES) begin
                        response_buffer[response_length] <= rx_data;
                        response_length <= response_length + 1'b1;
                        response_crc <= crc16_update(response_crc, rx_data);
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

                    if (response_length < 5) begin
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
                            (response_length != response_buffer[2] + 5)) begin
                            response_status <= STATUS_INVALID;
                        end else begin
                            response_status     <= STATUS_OK;
                            response_byte_count <= response_buffer[2];
                            response_data       <= {response_buffer[3], response_buffer[4]};
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
