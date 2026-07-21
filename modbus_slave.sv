// ============================================================
// Modulo: modbus_slave
// Descricao: Escravo Modbus RTU sintetizavel com suporte a
//            FC03 (Read Holding Registers) e FC06
//            (Write Single Register).
// ============================================================

`timescale 1ns / 1ps

module modbus_slave (
    input  logic        clk,
    input  logic        rst_n,

    input  logic [7:0]  slave_id,

    input  logic [7:0]  rx_data,
    input  logic        rx_valid,
    input  logic        rx_frame_done,

    output logic [7:0]  tx_data,
    output logic        tx_valid,
    input  logic        tx_ready,

    output logic        crc_en,
    output logic        crc_clear,
    output logic [7:0]  crc_data_in,
    input  logic [15:0] crc_out,

    output logic        reg_wr_en,
    output logic [5:0]  reg_addr,
    output logic [15:0] reg_wr_data,
    input  logic [15:0] reg_rd_data,
    input  logic        reg_valid
);

    localparam int REGISTER_DEPTH = 64;
    localparam int MAX_FRAME_SIZE = 32;
    localparam int MAX_RESPONSE_SIZE = 32;
    localparam int COUNT_WIDTH = $clog2(MAX_FRAME_SIZE + 1);
    localparam int MAX_READ_REGISTERS = (MAX_RESPONSE_SIZE - 5) / 2;
    localparam logic [COUNT_WIDTH-1:0] COUNT_ONE = 1;
    localparam logic [COUNT_WIDTH-1:0] MIN_FRAME_COUNT = 4;
    localparam logic [COUNT_WIDTH-1:0] REQUEST_FRAME_COUNT = 8;
    localparam logic [COUNT_WIDTH-1:0] FRAME_CAPACITY = MAX_FRAME_SIZE;
    localparam logic [COUNT_WIDTH-1:0] EXCEPTION_PAYLOAD_COUNT = 3;
    localparam logic [COUNT_WIDTH-1:0] WRITE_PAYLOAD_COUNT = 6;

    localparam logic [7:0] FC_READ_HOLDING = 8'h03;
    localparam logic [7:0] FC_WRITE_SINGLE = 8'h06;

    localparam logic [7:0] EXC_ILLEGAL_FUNCTION   = 8'h01;
    localparam logic [7:0] EXC_ILLEGAL_DATA_ADDR  = 8'h02;
    localparam logic [7:0] EXC_ILLEGAL_DATA_VALUE = 8'h03;

    typedef enum logic [4:0] {
        S_IDLE,
        S_RECEIVE,
        S_CRC_CLEAR_REQ,
        S_CRC_FEED_REQ,
        S_CRC_WAIT_REQ,
        S_CHECK_REQUEST,
        S_READ_SETUP,
        S_READ_CAPTURE,
        S_WRITE_REGISTER,
        S_BUILD_EXCEPTION,
        S_BUILD_WRITE_RESPONSE,
        S_CRC_CLEAR_RESP,
        S_CRC_FEED_RESP,
        S_CRC_WAIT_RESP,
        S_APPEND_RESP_CRC,
        S_TRANSMIT
    } state_t;

    state_t state;

    logic [7:0] rx_buffer [0:MAX_FRAME_SIZE-1];
    logic [7:0] tx_buffer [0:MAX_RESPONSE_SIZE-1];

    logic [COUNT_WIDTH-1:0] rx_count;
    logic [COUNT_WIDTH-1:0] tx_count;
    logic [COUNT_WIDTH-1:0] payload_count;
    logic [COUNT_WIDTH-1:0] tx_index;
    logic [COUNT_WIDTH-1:0] crc_index;
    logic                   rx_overflow;

    logic [7:0]  req_addr;
    logic [7:0]  req_func;
    logic [15:0] req_start_addr;
    logic [15:0] req_value_or_quantity;
    logic [7:0]  exception_code;
    logic [7:0]  read_index;
    logic [7:0]  read_quantity;

    integer reset_index;

    always_comb begin
        req_addr              = rx_buffer[0];
        req_func              = rx_buffer[1];
        req_start_addr        = {rx_buffer[2], rx_buffer[3]};
        req_value_or_quantity = {rx_buffer[4], rx_buffer[5]};

        // Interface ready/valid: o byte e valid permanecem estaveis ate a
        // UART aceita-los. O indice so avanca no handshake tx_valid && tx_ready.
        tx_valid = (state == S_TRANSMIT);
        tx_data  = tx_buffer[tx_index];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                 <= S_IDLE;
            rx_count              <= '0;
            tx_count              <= '0;
            payload_count         <= '0;
            tx_index              <= '0;
            crc_index             <= '0;
            rx_overflow           <= 1'b0;
            exception_code        <= 8'd0;
            read_index            <= 8'd0;
            read_quantity         <= 8'd0;
            crc_en                <= 1'b0;
            crc_clear             <= 1'b0;
            crc_data_in           <= 8'd0;
            reg_wr_en             <= 1'b0;
            reg_addr              <= 6'd0;
            reg_wr_data           <= 16'd0;

            for (reset_index = 0; reset_index < MAX_FRAME_SIZE; reset_index++) begin
                rx_buffer[reset_index] <= 8'd0;
                tx_buffer[reset_index] <= 8'd0;
            end
        end else begin
            crc_en    <= 1'b0;
            crc_clear <= 1'b0;
            reg_wr_en <= 1'b0;

            case (state)
                S_IDLE: begin
                    rx_count    <= '0;
                    rx_overflow <= 1'b0;
                    tx_index    <= '0;

                    if (rx_valid) begin
                        rx_buffer[0] <= rx_data;
                        rx_count     <= COUNT_ONE;
                        state        <= S_RECEIVE;
                    end
                end

                S_RECEIVE: begin
                    if (rx_valid) begin
                        if (rx_count < FRAME_CAPACITY) begin
                            rx_buffer[rx_count] <= rx_data;
                            rx_count <= rx_count + COUNT_ONE;
                        end else begin
                            rx_overflow <= 1'b1;
                        end
                    end else if (rx_frame_done) begin
                        if (!rx_overflow && (rx_count >= MIN_FRAME_COUNT)) begin
                            state <= S_CRC_CLEAR_REQ;
                        end else begin
                            state <= S_IDLE;
                        end
                    end
                end

                S_CRC_CLEAR_REQ: begin
                    crc_clear <= 1'b1;
                    crc_index <= '0;
                    state     <= S_CRC_FEED_REQ;
                end

                S_CRC_FEED_REQ: begin
                    crc_en      <= 1'b1;
                    crc_data_in <= rx_buffer[crc_index];

                    if (crc_index == (rx_count - COUNT_ONE)) begin
                        state <= S_CRC_WAIT_REQ;
                    end

                    crc_index <= crc_index + COUNT_ONE;
                end

                S_CRC_WAIT_REQ: begin
                    state <= S_CHECK_REQUEST;
                end

                S_CHECK_REQUEST: begin
                    exception_code <= 8'd0;

                    if ((crc_out != 16'h0000) || (req_addr != slave_id)) begin
                        state <= S_IDLE;
                    end else if ((req_func != FC_READ_HOLDING) &&
                                 (req_func != FC_WRITE_SINGLE)) begin
                        exception_code <= EXC_ILLEGAL_FUNCTION;
                        state <= S_BUILD_EXCEPTION;
                    end else if (rx_count != REQUEST_FRAME_COUNT) begin
                        exception_code <= EXC_ILLEGAL_DATA_VALUE;
                        state <= S_BUILD_EXCEPTION;
                    end else if (req_func == FC_READ_HOLDING) begin
                        if ((req_value_or_quantity == 16'd0) ||
                            (req_value_or_quantity > MAX_READ_REGISTERS)) begin
                            exception_code <= EXC_ILLEGAL_DATA_VALUE;
                            state <= S_BUILD_EXCEPTION;
                        end else if ((req_start_addr >= REGISTER_DEPTH) ||
                                     ((req_start_addr + req_value_or_quantity) > REGISTER_DEPTH)) begin
                            exception_code <= EXC_ILLEGAL_DATA_ADDR;
                            state <= S_BUILD_EXCEPTION;
                        end else begin
                            read_index    <= 8'd0;
                            read_quantity <= req_value_or_quantity[7:0];
                            reg_addr      <= req_start_addr[5:0];
                            state         <= S_READ_SETUP;
                        end
                    end else begin
                        if (req_start_addr >= REGISTER_DEPTH) begin
                            exception_code <= EXC_ILLEGAL_DATA_ADDR;
                            state <= S_BUILD_EXCEPTION;
                        end else begin
                            reg_addr    <= req_start_addr[5:0];
                            reg_wr_data <= req_value_or_quantity;
                            state       <= S_WRITE_REGISTER;
                        end
                    end
                end

                S_READ_SETUP: begin
                    tx_buffer[0] <= req_addr;
                    tx_buffer[1] <= req_func;
                    tx_buffer[2] <= read_quantity << 1;
                    state        <= S_READ_CAPTURE;
                end

                S_READ_CAPTURE: begin
                    if (reg_valid) begin
                        tx_buffer[3 + (read_index * 2)] <= reg_rd_data[15:8];
                        tx_buffer[4 + (read_index * 2)] <= reg_rd_data[7:0];

                        if (read_index == (read_quantity - 8'd1)) begin
                            payload_count <= 3 + (read_quantity * 2);
                            state <= S_CRC_CLEAR_RESP;
                        end else begin
                            read_index <= read_index + 8'd1;
                            reg_addr <= req_start_addr[5:0] + read_index[5:0] + 6'd1;
                        end
                    end else begin
                        exception_code <= EXC_ILLEGAL_DATA_ADDR;
                        state <= S_BUILD_EXCEPTION;
                    end
                end

                S_WRITE_REGISTER: begin
                    reg_wr_en <= 1'b1;
                    state     <= S_BUILD_WRITE_RESPONSE;
                end

                S_BUILD_EXCEPTION: begin
                    tx_buffer[0]  <= req_addr;
                    tx_buffer[1]  <= req_func | 8'h80;
                    tx_buffer[2]  <= exception_code;
                    payload_count <= EXCEPTION_PAYLOAD_COUNT;
                    state         <= S_CRC_CLEAR_RESP;
                end

                S_BUILD_WRITE_RESPONSE: begin
                    tx_buffer[0]  <= req_addr;
                    tx_buffer[1]  <= req_func;
                    tx_buffer[2]  <= req_start_addr[15:8];
                    tx_buffer[3]  <= req_start_addr[7:0];
                    tx_buffer[4]  <= req_value_or_quantity[15:8];
                    tx_buffer[5]  <= req_value_or_quantity[7:0];
                    payload_count <= WRITE_PAYLOAD_COUNT;
                    state         <= S_CRC_CLEAR_RESP;
                end

                S_CRC_CLEAR_RESP: begin
                    crc_clear <= 1'b1;
                    crc_index <= '0;
                    state     <= S_CRC_FEED_RESP;
                end

                S_CRC_FEED_RESP: begin
                    crc_en      <= 1'b1;
                    crc_data_in <= tx_buffer[crc_index];

                    if (crc_index == (payload_count - COUNT_ONE)) begin
                        state <= S_CRC_WAIT_RESP;
                    end

                    crc_index <= crc_index + COUNT_ONE;
                end

                S_CRC_WAIT_RESP: begin
                    state <= S_APPEND_RESP_CRC;
                end

                S_APPEND_RESP_CRC: begin
                    tx_buffer[payload_count] <= crc_out[7:0];
                    tx_buffer[payload_count + COUNT_ONE] <= crc_out[15:8];
                    tx_count <= payload_count + 6'd2;
                    tx_index <= '0;
                    state    <= S_TRANSMIT;
                end

                S_TRANSMIT: begin
                    if (tx_ready) begin
                        if (tx_index == (tx_count - COUNT_ONE)) begin
                            state <= S_IDLE;
                        end

                        tx_index <= tx_index + COUNT_ONE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
