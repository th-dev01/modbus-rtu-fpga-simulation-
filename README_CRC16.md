# Módulo Modbus CRC-16

Este módulo implementa o cálculo do CRC-16 para o protocolo Modbus RTU em hardware. 

- Diferencial: uso de lógica combinacional para calcular todos os 
8 deslocamentos de um byte em um único ciclo de clock.

## 1. Pinagem (Entradas e Saídas)

| Pino | Tipo | Tamanho | Função |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 bit | Sinal de clock do sistema. |
| `rst_n` | Input | 1 bit | Reset assíncrono (nível baixo). |
| `en` | Input | 1 bit | Habilita a leitura de um novo byte. |
| `clear` | Input | 1 bit | Reinicia o CRC para `0xFFFF` (início de um novo quadro). |
| `data_in` | Input | 8 bits | O byte da mensagem recebido. |
| `crc_out` | Output | 16 bits | O resultado atual do cálculo do CRC. |

## 2. Explicando o Código (Bloco a Bloco)

A arquitetura do código é dividida em três partes principais: declaração de variáveis, cálculo matemático (combinacional) e atualização da memória (sequencial).

### Passo A: Variáveis Internas

```systemverilog
logic [15:0] crc_reg;  // Memória física do CRC atual
logic [15:0] next_crc; // Fio que carrega o resultado da matemática
```

- O que faz: `crc_reg atua` como o flip-flop que guarda o valor oficial. `next_crc` é apenas a ponte que liga o resultado da conta até o registrador.

### Passo B: O Motor Matemático (Lógica Combinacional)

```systemverilog
always_comb begin
    logic [15:0] temp_crc;
    temp_crc = crc_reg ^ {8'h00, data_in};
```
- O que faz: O bloco `always_comb` cria portas lógicas puras (sem clock). A primeira linha realiza a regra do Modbus: faz um XOR (Ou Exclusivo) entre o valor atual do CRC e o novo byte que chegou (`data_in`).

```systemverilog
for (int i = 0; i < 8; i++) begin
        if (temp_crc[0] == 1'b1) 
            temp_crc = (temp_crc >> 1) ^ 16'hA001;
        else
            temp_crc = temp_crc >> 1;
    end
    next_crc = temp_crc;
end
```

- O que faz: Este é o "desenrolamento de laço" (loop unrolling). A FPGA criará fisicamente 8 camadas de portas lógicas.
    - O `if (temp_crc[0] == 1'b1)` verifica se o bit menos significativo (LSB) é 1.
        - Se for 1: desloca o valor para a direita (`>> 1`) e injeta o polinômio oficial do Modbus (`^ 16'hA001`).
        - Se for 0: apenas desloca para a direita.
    - No final, o resultado da conta inteira é entregue para o fio `next_crc`.

### Passo C: Atualização do Hardware (Lógica Sequencial)

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        crc_reg <= 16'hFFFF;
    else if (clear)
        crc_reg <= 16'hFFFF;
    else if (en)
        crc_reg <= next_crc;
end
```

- O que faz: Este bloco `always_ff` cria os Flip-Flops acionados pelo clk (síncronos).

    - Regra 1: Se a placa for resetada (`rst_n`), o CRC vai para `0xFFFF`.
    - Regra 2: Se a FSM mandar o sinal de clear (nova mensagem chegando), o CRC volta para a semente inicial `0xFFFF`.
    - Regra 3: Se o pulso de en (`enable`) for ativado, o registrador grava oficialmente o resultado da matemática gerada no Passo B (`next_crc`).

### Passo D: Saída Externa

```systemverilog
assign crc_out = crc_reg;
```

- O que faz: Conecta a memória interna do módulo de forma contínua e ininterrupta ao pino de saída `crc_out`, permitindo que o resto da FPGA leia o valor do CRC a qualquer momento.