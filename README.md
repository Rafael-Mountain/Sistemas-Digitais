# 🚀 Sistema de Processamento de Imagem em FPGA com Zoom

Este repositório contém o código-fonte em **Verilog** para um sistema de processamento de imagem em tempo real implementado em uma **FPGA**. O sistema é capaz de carregar uma imagem de uma memória ROM, aplicar diferentes algoritmos de zoom (in e out) e exibir o resultado em um monitor **VGA**.

O projeto foi desenvolvido com foco em modularidade, clareza e eficiência, demonstrando conceitos chave de design de hardware digital, como **Máquinas de Estados Finitos (FSMs)**, **arbitragem de memória** e **pipelines de processamento de dados (data-path)**.

<img width="927" height="485" alt="Diagrama do Data-Path" src="https://github.com/user-attachments/assets/8cd3c43d-8976-408b-a987-4e3d435c17cf" />
*Diagrama conceitual do fluxo de dados durante o processamento de imagem.*

---

## ✨ Funcionalidades

O sistema oferece as seguintes capacidades:

-   **Exibição em VGA:** Saída de vídeo com resolução de **640x480 @ 60Hz**.
-   **Carregamento de Imagem:** A imagem original (320x240) é lida de uma **memória ROM** interna.
-   **Operações de Zoom:**
    -   **Zoom In:** Amplia a imagem para 640x480.
    -   **Zoom Out:** Reduz a imagem para 160x120.
-   **Seleção de Algoritmos:** Uma chave física permite alternar entre dois conjuntos de algoritmos para as operações de zoom:
    -   **Set 1 (Rápido):** **Replicação de Pixels** (Zoom In) e **Dizimação** (Zoom Out).
    -   **Set 2 (Qualidade):** **Vizinho Mais Próximo** (Zoom In) e **Média de Bloco** (Zoom Out).
-   **Controle Interativo:** Botões de `reset`, `zoom_in` e `zoom_out` para controle pelo usuário.

---

## 🔧 Arquitetura do Projeto

O sistema é dividido em módulos com responsabilidades bem definidas, orquestrados pelo módulo *top-level* `main.v`.

-   `main.v`: O módulo *top-level* que instancia e conecta todos os outros componentes.
-   `control_unit.v`: O cérebro do sistema. Uma **FSM** que gerencia os estados (`WAITING`, `PROCESSING`) e interpreta os comandos dos botões.
-   `processing_unit.v`: O gerente de operações. Ativa o módulo de algoritmo correto e gerencia o fluxo de dados para a memória.
-   `memory_module.v`: Um invólucro que contém as instâncias da **ROM** (imagem original) e da **RAM** (framebuffer de vídeo).
-   `video_controller.v`: Lê continuamente a RAM e gera os sinais de sincronismo (`HSYNC`, `VSYNC`) e os dados de cor (`RGB`) para o monitor VGA.
-   **Módulos de Algoritmos:** Cada algoritmo (`original.v`, `zoom_in_replication.v`, etc.) é um módulo separado que implementa uma única tarefa de processamento.

---

## 🧠 Lógica de Funcionamento: Data-Path e Arbitragem

O cerne do sistema é a forma como ele gerencia o acesso à **memória RAM**, um recurso compartilhado entre o processador (escrita) e o controlador de vídeo (leitura).

O sistema opera em dois modos principais, controlados pelo sinal `program_state`:

1.  **Modo de Exibição (`program_state = 0`):**
    -   Este é o estado ocioso (padrão).
    -   O `video_controller` tem acesso de **leitura** à RAM, enviando os pixels para o monitor.
    -   A `processing_unit` está inativa.

2.  **Modo de Processamento (`program_state = 1`):**
    -   Iniciado quando um botão de zoom é pressionado.
    -   A `processing_unit` ganha **prioridade total** de acesso à RAM.
    -   Um dos algoritmos é ativado, lendo dados da ROM, processando-os e **escrevendo** o resultado na RAM.
    -   Enquanto isso, o `video_controller` é "pausado" e exibe uma cor de fundo sólida para evitar artefatos visuais.

A arbitragem é implementada de forma simples e eficaz no `main.v` com multiplexadores:

```verilog
// O Processador (program_state = 1) tem prioridade de acesso.
assign final_ram_address = (program_state == 1'b1) ? proc_ram_address : video_ram_address;
assign final_ram_wren    = (program_state == 1'b1) ? proc_ram_wren : 1'b0;
```

---

## 💡 Descrição dos Algoritmos

### Operação Inicial: `original.v`

-   **Função:** Copia a imagem 320x240 da ROM para a RAM e preenche o restante do framebuffer (640x480) com a cor preta. É executado no reset para exibir a imagem inicial.

### Algoritmos de Zoom In (Ampliação)

#### Replicação de Pixels (`zoom_in_replication.v`):

-   **Conceito:** Cada pixel da imagem original é repetido para preencher um bloco de 2x2 pixels na imagem de destino.
-   **Resultado:** Rápido e simples, mas pode criar um efeito de "pixelização".

#### Vizinho Mais Próximo (`zoom_in_nearest_neighbor.v`):

-   **Conceito:** Para cada pixel na imagem de destino (grande), calcula qual seria o pixel "vizinho mais próximo" na imagem de origem (pequena) e copia sua cor.
-   **Resultado:** Visualmente idêntico à replicação, mas implementado com uma lógica de mapeamento inverso.

### Algoritmos de Zoom Out (Redução)

#### Dizimação (`zoom_out_decimation.v`):

-   **Conceito:** O método mais simples de redução. Simplesmente descarta pixels, mantendo um a cada bloco de 2x2.
-   **Resultado:** Extremamente rápido, mas com perda significativa de informação, o que pode causar serrilhamento (aliasing).

#### Média de Bloco (`zoom_out_block_average.v`):

-   **Conceito:** Calcula a cor média de cada bloco 2x2 da imagem original para gerar um único pixel na imagem de destino.
-   **Resultado:** Qualidade visual superior à dizimação, produzindo uma imagem reduzida mais suave e fiel à original.

---

## 📋 Como Utilizar

### Requisitos

-   **Hardware:** Placa FPGA com um chip da família Intel Cyclone V (ou similar), com memória RAM suficiente, botões, chaves e uma saída de vídeo VGA.
-   **Software:** Intel Quartus Prime (ou o software equivalente para sua FPGA).

### Controles Físicos

-   `reset_button`: Pressione para reiniciar o sistema e carregar a imagem original.
-   `zoom_in_button`: Pressione para aplicar o algoritmo de Zoom In selecionado.
-   `zoom_out_button`: Pressione para aplicar o algoritmo de Zoom Out selecionado.
-   `algorithm_select` (chave):
    -   **Posição 0:** Ativa o Set 1 (Replicação / Dizimação).
    -   **Posição 1:** Ativa o Set 2 (Vizinho Mais Próximo / Média de Bloco).
