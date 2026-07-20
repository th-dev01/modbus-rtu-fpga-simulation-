package modbus_crc_pkg;

    function automatic logic [15:0] crc16_update(
        input logic [15:0] crc_in,
        input logic [7:0] data
    );
        logic [15:0] next_crc;
        int bit_index;
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

endpackage
