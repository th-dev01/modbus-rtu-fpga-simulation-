`timescale 1ns / 1ps

// ==============================================================================
// Módulo: tb_uart
// Descrição: Testbench completo para a Camada Física (UART + Timer T3.5).
//            Conecta o transmissor ao receptor e envia bytes para validar
//            a integridade dos dados e o disparo do frame_timer.
// Padrão: SystemVerilog 2012
// ==============================================================================

module tb_uart();

    // --------------------------------------------------------------------------
    // Parâmetros e Sinais
    // --------------------------------------------------------------------------
    // Para a simulação rodar mais rápido, aumentamos o Baud Rate neste TB.
    // Em hardware real, mantenha 115200. Aqui usamos 1 Mbps apenas para 
    // encurtar o tempo de waveform no ModelSim.
    localparam int CLK_FREQ   = 50_000_000;
    localparam int BAUD_RATE  = 1_000_000;  

    logic clk;
    logic rst_n;

    // Sinais da UART
    logic       baud_tick;
    logic       tx_start;
    logic [7:0] tx_data;
    logic       serial_line;
    logic       tx_busy;
    logic       tx_done;

    logic [7:0] rx_data;
    logic       rx_valid;

    // Sinal do Timer
    logic       frame_done;

    // --------------------------------------------------------------------------
    // Instanciação dos Módulos (DUT - Device Under Test)
    // --------------------------------------------------------------------------
    
    // 1. Gerador de Baud Rate
    baud_gen #(
        .CLOCK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut_baud (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick)
    );

    // 2. Transmissor UART
    uart_tx dut_tx (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .tx_start  (tx_start),
        .tx_data   (tx_data),
        .tx        (serial_line), // Conecta a saída tx à linha serial
        .tx_busy   (tx_busy),
        .tx_done   (tx_done)
    );

    // 3. Receptor UART
    uart_rx dut_rx (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .rx        (serial_line), // Lê da mesma linha serial
        .rx_data   (rx_data),
        .rx_valid  (rx_valid)
    );

    // 4. Temporizador de Fim de Frame Modbus
    frame_timer dut_timer (
        .clk        (clk),
        .rst_n      (rst_n),
        .baud_tick  (baud_tick),
        .rx         (serial_line),
        .frame_done (frame_done)
    );

    // --------------------------------------------------------------------------
    // Geração de Clock (50 MHz -> T = 20 ns)
    // --------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #10 clk = ~clk; 
    end

    // --------------------------------------------------------------------------
    // Task Auxiliar para envio de bytes
    // --------------------------------------------------------------------------
    task send_byte(input [7:0] data_to_send);
        begin
            @(posedge clk);
            tx_data  = data_to_send;
            tx_start = 1'b1;
            
            @(posedge clk);
            tx_start = 1'b0; // Pulso de 1 clock
            
            // Aguarda o TX avisar que terminou
            wait(tx_done == 1'b1);
            $display("[Tempo %0t ns] Transmissao concluida: 0x%h", $time, data_to_send);
        end
    endtask

    // --------------------------------------------------------------------------
    // Bloco de Estímulos Principal
    // --------------------------------------------------------------------------
    initial begin
        // Inicialização
        rst_n    = 1'b0;
        tx_start = 1'b0;
        tx_data  = 8'h00;

        $display("==================================================");
        $display("INICIANDO SIMULACAO DA CAMADA FISICA (UART)");
        $display("==================================================");

        // Aguarda 100 ns e solta o reset
        #100;
        rst_n = 1'b1;
        #100;

        // Teste 1: Enviar caractere 'A' (0x41)
        $display("\n---> Teste 1: Enviando byte 0x41 ('A')");
        send_byte(8'h41);

        // Teste 2: Enviar caractere 'B' (0x42) logo em seguida
        $display("\n---> Teste 2: Enviando byte 0x42 ('B')");
        send_byte(8'h42);

        // Teste 3: Aguardar o Timeout do Modbus (T3.5)
        $display("\n---> Teste 3: Aguardando silence timer (frame_done)...");
        wait(frame_done == 1'b1);
        $display("[Tempo %0t ns] TIMER T3.5 DISPARADO! Frame Modbus encerrado.", $time);

        // Teste 4: Enviar um byte de broadcast Modbus simulado (0x00)
        #5000; // Um pequeno atraso extra
        $display("\n---> Teste 4: Enviando byte 0x00 (Broadcast)");
        send_byte(8'h00);

        // Deixa a simulação rodar mais um pouco para ver o último timer
        wait(frame_done == 1'b1);
        
        $display("\n==================================================");
        $display("SIMULACAO CONCLUIDA COM SUCESSO!");
        $display("==================================================");
        
        // Encerra a simulação
        $stop;
    end

    // --------------------------------------------------------------------------
    // Monitoramento do RX (Opcional: imprime sozinho quando chega dado)
    // --------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rx_valid) begin
            $display("[Tempo %0t ns] RECEPTOR LEU: 0x%h", $time, rx_data);
            
            // Verificação automática básica
            if (rx_data !== tx_data) begin
                $error("FALHA DE INTEGRIDADE: RX recebeu 0x%h mas era esperado 0x%h", rx_data, tx_data);
            end
        end
    end

endmodule