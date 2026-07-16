# Módulo Modbus Register File (Banco de Registradores)

Este módulo implementa o armazenamento interno de dados (*Holding Registers*) para o escravo Modbus RTU simulado em hardware. 

- Diferencial: uso de profundidade parametrizável e leitura puramente combinacional, garantindo que o dado solicitado fique disponível imediatamente para a montagem do quadro de resposta, sem atraso de *clock*.

## 1. Pinagem (Entradas e Saídas)

| Pino | Tipo | Tamanho | Função |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 bit | Sinal de clock do sistema. |
| `rst_n` | Input | 1 bit | Reset assíncrono (nível baixo). |
| `addr` | Input | 16 bits | Endereço alvo do registrador (recebido pelo decodificador). |
| `we` | Input | 1 bit | *Write Enable* (Habilita a escrita, ativado pela Função 06). |
| `data_in` | Input | 16 bits | Dados para escrever no registrador alvo. |
| `data_out` | Output | 16 bits | Dados instantâneos lidos do registrador (Usado pela Função 03). |

*Nota: O módulo possui um parâmetro configurável `DEPTH = 64` que define a quantidade total de registradores suportados fisicamente pela FPGA.*

## 2. Explicando o Código (Bloco a Bloco)

A arquitetura do código é dividida em três partes principais: criação da matriz de memória, lógica de proteção/escrita (sequencial) e lógica de leitura (combinacional).

### Passo A: Variáveis Internas (A Memória)

```systemverilog
logic [15:0] registers [0:DEPTH-1];
```

- O que faz: Cria fisicamente a memória RAM interna (um array bidimensional). Cada posição tem 16 bits de largura e a quantidade total de posições é definida pelo parâmetro estático `DEPTH`.

### Passo B: Escrita no Banco (Lógica Sequencial)
```
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
```
O que faz: Este bloco `always_ff` é acionado pela borda de subida do clock e gerencia as alterações definitivas na memória.
    - Regra 1: Se a placa for resetada (`rst_n`), um laço for zera imediatamente todos os registradores, garantindo o estado seguro `0x0000` no início da operação.
    - Regra 2: Se o pino `we` for ativado pela FSM, o bloco realiza uma verificação de segurança, conferindo se o endereço solicitado (`addr`) é menor que o limite da memória (`DEPTH`).
    - Regra 3: Passando na verificação, o dado recebido (`data_in`) é salvo de forma permanente no registrador alvo.

### Passo C: Leitura do Banco (Lógica Combinacional)
```
always_comb begin
    if (addr < DEPTH)
        data_out = registers[addr];
    else
        data_out = 16'h0000;
end
```
- O que faz: O bloco `always_comb` atua como um multiplexador sem depender do clock, criando um caminho direto para a leitura do mestre.

    - Comportamento Normal: Se o endereço solicitado (`addr`) for válido, o conteúdo daquela posição da memória é copiado instantaneamente para a saída `data_out`.
    - Proteção: Se houver tentativa de leitura de um endereço que não existe (maior que o `DEPTH`), o hardware aciona a proteção e coloca `0x0000` na saída (o disparo da Exceção Modbus correspondente fica a cargo da FSM que gerencia o quadro).