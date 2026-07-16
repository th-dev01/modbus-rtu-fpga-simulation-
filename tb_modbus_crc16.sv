
`timescale 1ns / 1ps

module tb_modbus_crc16();
    logic clk;
    logic rst_n;
    logic en;
    logic clear;
    logic [7:0] data_in;
    logic [15:0] crc_out;

    modbus_crc16 uut (
        .clk(clk), .rst_n(rst_n), .en(en), .data_in(data_in),
        .clear(clear), .crc_out(crc_out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0; en = 0; clear = 0; data_in = 0;
        
        #10 rst_n = 1; clear = 1;
        #10 clear = 0;
        
        // Envia o primeiro byte: 0x02 (Address)
        data_in = 8'h02; en = 1;
        #10 en = 0;
        #10;
        
        // Envia o segundo byte: 0x07 (Function)
        data_in = 8'h07; en = 1;
        #10 en = 0;
        #10;
        
        // Verifica o resultado. Segundo o manual Modbus (Pág 41), deve ser 0x4112
        if (crc_out == 16'h4112)
            $display("SUCESSO! O CRC bateu com o exemplo do manual Modbus: %h", crc_out);
        else
            $display("ERRO! O CRC esperado era 4112, mas deu: %h", crc_out);
            
        $stop;
    end
endmodule