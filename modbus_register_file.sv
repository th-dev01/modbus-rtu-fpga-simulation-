`timescale 1ns / 1ps

module modbus_register_file #(
    parameter DEPTH = 64
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] addr,
    input  logic        we,
    input  logic [15:0] data_in,
    output logic [15:0] data_out
);

    logic [15:0] registers [0:DEPTH-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++) begin
                registers[i] <= 16'h0000;
            end
        end else if (we) begin
            if (addr < DEPTH) begin
                registers[addr] <= data_in;
            end
        end
    end

    always_comb begin
        if (addr < DEPTH)
            data_out = registers[addr];
        else
            data_out = 16'h0000;
    end

endmodule