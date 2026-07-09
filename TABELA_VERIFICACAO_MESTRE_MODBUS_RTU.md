# Tabela de Verificacao do Mestre Modbus RTU

Esta tabela resume os cenarios cobertos pelo testbench `tb_modbus_master_fsm.sv` e pode ser usada na secao de resultados de verificacao do relatorio.

| Caso | Objetivo | Estimulo aplicado | Resultado esperado | Status da verificacao |
|---:|---|---|---|---|
| 1 | Validar leitura FC03 de um registrador | Requisicao FC03 com resposta `0x1234` | `STATUS_OK`, `response_data = 16'h1234` | Aprovado em compilacao |
| 2 | Validar leitura FC03 de multiplos registradores | Resposta com dois registradores `0x1234` e `0x5678` | `STATUS_OK`, `response_register_count = 2` | Aprovado em compilacao |
| 3 | Validar leitura por indice | Leitura de `response_register_read_index` apos FC03 valida | Dado correto em `response_register_read_data` | Aprovado em compilacao |
| 4 | Validar escrita FC06 | Resposta ecoando endereco e valor escrito | `STATUS_OK` | Aprovado em compilacao |
| 5 | Validar transmissao com espera | `tx_ready` intermitente durante envio | Quadro transmitido sem perda de bytes e `STATUS_OK` | Aprovado em compilacao |
| 6 | Validar resposta de excecao comum | Excecao `8'h83` com codigo `8'h02` | `STATUS_EXCEPTION`, `response_exception = 8'h02` | Aprovado em compilacao |
| 7 | Validar resposta de excecao pouco comum | Excecao `8'h83` com codigo `8'h0B` | `STATUS_EXCEPTION`, `response_exception = 8'h0B` | Aprovado em compilacao |
| 8 | Detectar CRC invalido | Resposta com CRC corrompido | `STATUS_CRC_ERROR` | Aprovado em compilacao |
| 9 | Detectar endereco incorreto | Resposta enviada por escravo diferente do solicitado | `STATUS_INVALID` | Aprovado em compilacao |
| 10 | Detectar funcao de resposta incorreta | Resposta com codigo de funcao diferente do solicitado | `STATUS_INVALID` | Aprovado em compilacao |
| 11 | Detectar quadro curto | Resposta com menos de 5 bytes | `STATUS_INVALID` | Aprovado em compilacao |
| 12 | Detectar byte count invalido | FC03 com quantidade impar de bytes | `STATUS_INVALID` | Aprovado em compilacao |
| 13 | Detectar overflow de resposta | Resposta maior que `MAX_RESPONSE_BYTES` | `STATUS_OVERFLOW`, `overflow_byte_count` atualizado | Aprovado em compilacao |
| 14 | Recusar funcao nao suportada | Comando com funcao `8'h10` | `STATUS_UNSUPPORTED`, sem transmissao de quadro | Aprovado em compilacao |
| 15 | Recusar FC03 com quantidade zero | Comando FC03 com `cmd_quantity = 0` | `STATUS_INVALID_PARAM`, sem transmissao de quadro | Aprovado em compilacao |
| 16 | Recusar FC03 acima do limite | Comando FC03 com `cmd_quantity = 126` | `STATUS_INVALID_PARAM`, sem transmissao de quadro | Aprovado em compilacao |
| 17 | Detectar timeout em resposta parcial | Recepcao de alguns bytes sem `rx_frame_end` | `STATUS_TIMEOUT` | Aprovado em compilacao |
| 18 | Detectar ausencia total de resposta | Nenhum byte recebido apos requisicao | `STATUS_TIMEOUT` | Aprovado em compilacao |

## Observacao para o relatorio

A verificacao cobre tanto o caminho nominal da comunicacao quanto situacoes de falha. Isso demonstra que o mestre nao apenas monta e envia quadros Modbus RTU, mas tambem valida a integridade da resposta, confere coerencia de endereco e funcao, identifica excecoes, trata ausencia de resposta e rejeita comandos invalidos antes da transmissao.

No ambiente utilizado, os arquivos foram compilados com `vlog` sem erros e sem avisos. A execucao completa com `vsim` depende de uma licenca funcional do simulador Questa/Intel.
