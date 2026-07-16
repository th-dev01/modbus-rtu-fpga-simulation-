// Validacao de escrita e leitura
`timescale 1ns / 1ps

module tb_modbus_register_file();
    logic clk;
    logic rst_n;
    logic [15:0] addr;
    logic we;
    logic [15:0] data_in;
    logic [15:0] data_out;

    modbus_register_file #(.DEPTH(64)) uut (
        .clk(clk), .rst_n(rst_n), .addr(addr),
        .we(we), .data_in(data_in), .data_out(data_out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0; we = 0; addr = 0; data_in = 0;
        
        #10 rst_n = 1;
        
        // Simula Funcao 06: Mestre escreve o valor 0xABCD no endereco 0x000A (10)
        #10;
        addr = 16'h000A;
        data_in = 16'hABCD;
        we = 1;
        #10 we = 0;
        
        // Simula Funcao 03: Mestre le o valor do endereco 0x000A
        #10;
        addr = 16'h000A;
        #5;
        if (data_out == 16'hABCD)
            $display("SUCESSO: Leitura/Escrita validadas! Valor lido: %h", data_out);
        else
            $display("ERRO: Valor esperado ABCD, mas lido: %h", data_out);
            
        $stop;
    end
endmodule