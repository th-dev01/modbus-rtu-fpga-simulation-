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
    integer i;

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

    always_comb begin
        crc = 16'hFFFF;
        for (i = 0; i < 6; i++)
            crc = crc16_update(crc, frame[i]);

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
            for (i = 0; i < 8; i++)
                frame[i] <= 8'd0;
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
