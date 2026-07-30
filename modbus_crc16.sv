`timescale 1ns / 1ps

module modbus_crc16 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        en,
    input  logic [7:0]  data_in,
    input  logic        clear,
    output logic [15:0] crc_out
);

    logic [15:0] crc_reg;
    logic [15:0] next_crc;

    always_comb begin
        logic [15:0] temp_crc;
        
        temp_crc = crc_reg ^ {8'h00, data_in};
        
        for (int i = 0; i < 8; i++) begin
            if (temp_crc[0] == 1'b1) 
                temp_crc = (temp_crc >> 1) ^ 16'hA001;
            else
                temp_crc = temp_crc >> 1;
        end
        next_crc = temp_crc;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            crc_reg <= 16'hFFFF;
        else if (clear)
            crc_reg <= 16'hFFFF;
        else if (en)
            crc_reg <= next_crc;
    end

    assign crc_out = crc_reg;

endmodule