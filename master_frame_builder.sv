import modbus_crc_pkg::*;

module master_frame_builder (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [7:0]  slave_addr,
    input  logic [7:0]  function_code,
    input  logic [15:0] register_addr,
    input  logic [15:0] value_or_quantity,
    output logic        busy,
    output logic        frame_valid,
    input  logic        frame_ready,
    output logic [2:0]  frame_index,
    output logic [7:0]  frame_byte
);

    logic [7:0] frame [0:7];
    logic [15:0] crc;
    integer crc_index;
    integer reset_index;

    always_comb begin
        crc = 16'hFFFF;
        for (crc_index = 0; crc_index < 6; crc_index++)
            crc = crc16_update(crc, frame[crc_index]);

        frame_valid = busy;
        case (frame_index)
            3'd6: frame_byte = crc[7:0];
            3'd7: frame_byte = crc[15:8];
            default: frame_byte = frame[frame_index];
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy        <= 1'b0;
            frame_index <= 3'd0;
            for (reset_index = 0; reset_index < 8; reset_index++)
                frame[reset_index] <= 8'd0;
        end else begin
            if (start && !busy) begin
                frame[0] <= slave_addr;
                frame[1] <= function_code;
                frame[2] <= register_addr[15:8];
                frame[3] <= register_addr[7:0];
                frame[4] <= value_or_quantity[15:8];
                frame[5] <= value_or_quantity[7:0];
                busy        <= 1'b1;
                frame_index <= 3'd0;
            end else if (busy) begin
                if (frame_ready) begin
                    if (frame_index == 3'd7) begin
                        busy <= 1'b0;
                    end else begin
                        frame_index <= frame_index + 3'd1;
                    end
                end
            end
        end
    end

endmodule
