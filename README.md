# 🚀 Sistema de Processamento de Imagem em FPGA com Co-processamento HPS

Este repositório contém o código-fonte em **Verilog** para um sistema avançado de processamento de imagem em tempo real implementado em uma **FPGA Intel Cyclone V**, operando em um modo de **co-processamento com o Hard Processor System (HPS)**.

Ao contrário de uma implementação stand-alone, este sistema permite que o **HPS controle dinamicamente** as operações da FPGA, incluindo o **upload de imagens arbitrárias**, seleção de algoritmos e execução de transformações de zoom, com o resultado sendo exibido em um monitor **VGA**.

O projeto demonstra conceitos chave de design de hardware digital, como **Máquinas de Estados Finitos (FSMs)**, **arbitragem de memória**, **interface assíncrona/síncrona** com o HPS e **pipelines de processamento de dados (data-path)**, oferecendo grande flexibilidade através de comandos via software.

---

## 🎨 Diagramas de Arquitetura e Fluxo de Dados

Estes diagramas ilustram a arquitetura geral do sistema, a integração com o HPS, a lógica de sincronização, e o fluxo de dados para as operações de upload e processamento de imagem.

### 1. Visão Geral da Arquitetura do Sistema
![Visão Geral da Arquitetura do Sistema](https://github.com/user-attachments/assets/2b8b7dad-09af-4849-a93e-880468e3dcb2)
*Diagrama de blocos de alto nível mostrando os principais módulos da FPGA e sua conexão com o HPS.*

### 2. Integração do HPS com a FPGA na DE1-SoC
![Integração do HPS com a FPGA na DE1-SoC](https://github.com/user-attachments/assets/aa0116a6-3178-44a8-92aa-b335520e1ea3)
*Ilustração da comunicação entre o HPS e a FPGA, destacando o barramento PIO.*

### 3. Sincronização e Decodificação de Instruções HPS-FPGA
![Sincronização HPS-FPGA](https://github.com/user-attachments/assets/8d276ad8-88cc-4430-9fb9-26b98103535b)
*Detalhes do processo de sincronização do barramento PIO e detecção de strobe de instruções.*

### 4. Data-Path da Operação de Upload de Imagem
![Upload da imagem do HPS para a RAM da FPGA](https://github.com/user-attachments/assets/7c1dd556-7ce2-40f8-9472-3317c2957459)
*Fluxo de dados da instrução de upload do HPS para as RAMs da FPGA, pixel por pixel.*

### 5. Data-Path do Processamento de Imagem (Zoom)
![Processamento da imagem](https://github.com/user-attachments/assets/9d1487bf-ee81-4115-a823-a6feb968b8bb)
*Fluxo de dados durante uma operação de zoom, lendo da `ram_image` e escrevendo na `ram_op`.*

---

## ✨ Funcionalidades

O sistema oferece as seguintes capacidades, controladas dinamicamente pelo HPS:

- **Exibição em VGA:** Saída de vídeo com resolução de **640x480 @ 60Hz**.
- **Upload de Imagem Dinâmico:** A imagem original é carregada pixel a pixel para uma **RAM dedicada (`ram_image`)** via barramento PIO do HPS, permitindo processar qualquer imagem enviada por software.
- **Operações de Zoom Controladas por Software:**
    - **Zoom In (2x e 4x):** Amplia a imagem (e.g., de 160x120 para 320x240, ou para 640x480).
    - **Zoom Out (1/2x e 1/4x):** Reduz a imagem (e.g., de 320x240 para 160x120, ou para 80x60).
- **Seleção de Algoritmos por Software:** O HPS pode configurar qual algoritmo será usado para cada operação de zoom:
    - **Zoom In:**
        - **Replicação de Pixels** (rápido).
        - **Vizinho Mais Próximo** (qualidade).
    - **Zoom Out:**
        - **Decimação** (rápido).
        - **Média de Bloco** (qualidade).
- **Controle e Debug via HPS:** Comandos enviados pelo HPS via barramento PIO assíncrono.
- **Debug Visual:** Saídas de depuração para seleção de algoritmo e displays de 7 segmentos para monitorar o barramento de instruções do HPS.

---

## 🔧 Arquitetura do Projeto

O sistema é dividido em módulos com responsabilidades bem definidas, orquestrados pelo módulo *top-level* `main.v`, com ênfase na comunicação assíncrona/síncrona com o HPS.

- `main.v`: O módulo *top-level* que instancia e conecta todos os outros componentes. Inclui o sincronizador do barramento HPS PIO e o detector de strobe de instrução.
- `synchronizer.v`: Garante a sincronização dos sinais assíncronos do HPS com o clock da FPGA.
- `instruction_strobe_detector.v`: Detecta novas instruções válidas no barramento HPS PIO sincronizado.
- `control_unit.v`: O cérebro do sistema. Uma **FSM** que gerencia os estados (`WAITING`, `PROCESSING`), interpreta os opcodes de instrução do HPS e configura as seleções de algoritmo.
- `processing_unit.v`: O gerente de operações. Ativa o módulo de algoritmo ou de upload correto e gerencia o fluxo de dados entre as duas RAMs.
- `memory_module.v`: Um invólucro que contém as instâncias da **RAM de Imagem (`ram_image`)** (para a imagem original, carregável) e da **RAM de Operação (`ram_op`)** (o framebuffer de vídeo onde os resultados processados são escritos).
- `video_controller.v`: Lê continuamente a `ram_op` e gera os sinais de sincronismo (`HSYNC`, `VSYNC`) e os dados de cor (`RGB`) para o monitor VGA.
- `image_upload.v`: **NOVO MÓDULO**. Responsável por escrever pixels, um a um, nas duas RAMs (`ram_image` e `ram_op`) durante a operação de upload.
- **Módulos de Algoritmos:** Cada algoritmo (`original.v`, `zoom_in_replication.v`, etc.) é um módulo separado que implementa uma única tarefa de processamento, lendo da `ram_image` e escrevendo na `ram_op`.
- `top_module`: Módulo para controlar os displays de 7 segmentos, exibindo informações de debug do barramento HPS.

---

## 🧠 Lógica de Funcionamento: Co-processamento e Arbitragem de Memória

O cerne do sistema é a forma como ele gerencia o acesso às **memórias RAM**, recursos compartilhados entre o processador (escrita) e o controlador de vídeo (leitura), sob comando do HPS.

### Duas RAMs Dedicadas:

1.  **`ram_image` (Imagem Original):**
    - Endereçada em 15 bits (para 160x120 pixels).
    - A `image_upload` escreve nesta RAM (com dados do HPS).
    - Os módulos de algoritmo de zoom leem desta RAM.
2.  **`ram_op` (Imagem Processada/Exibida):**
    - Endereçada em 19 bits (para 640x480 pixels).
    - A `image_upload` escreve nesta RAM (com dados do HPS).
    - Os módulos de algoritmo de zoom escrevem nesta RAM.
    - O `video_controller` lê continuamente desta RAM.

### Fluxo de Controle via HPS:

1.  **Comandos Assíncronos:** O HPS envia instruções de 32 bits para a FPGA via um barramento PIO.
2.  **Sincronização:** Os módulos `synchronizer` e `instruction_strobe_detector` garantem que a `control_unit` receba comandos síncronos e estáveis.
3.  **Decodificação:** A `control_unit` decodifica o `opcode` da instrução:
    - **Ações (ex: `UPLOAD`, `ZOOM_IN`, `ZOOM_OUT`):** Mudam o `program_state` para `PROCESSING`. A `processing_unit` ativa o módulo correspondente, que lê da `ram_image` e/ou escreve na `ram_op`.
    - **Configurações (ex: `REPLICATION`, `NEAREST_NEIGHBOR`):** A `control_unit` atualiza os sinais `zoom_in_algo_select` ou `zoom_out_algo_select` sem alterar o `program_state`.
4.  **Arbitragem de `ram_op`:** O `main.v` implementa a arbitragem para o acesso à `ram_op`:
    ```verilog
    assign final_op_addr = (program_state == 1'b1) ? proc_op_addr : video_ram_address;
    assign final_op_wren = (program_state == 1'b1) ? proc_op_wren : 1'b0;
    ```
    - No **Modo de Exibição (`program_state = 0` / `WAITING`):** O `video_controller` tem acesso exclusivo de **leitura** à `ram_op`.
    - No **Modo de Processamento (`program_state = 1` / `PROCESSING`):** A `processing_unit` (ou o módulo `image_upload` sendo ativo) ganha **prioridade total de escrita** na `ram_op`. O `video_controller` continua a ler, exibindo o processamento em tempo real (ou a imagem carregada).

---

## 💡 Descrição das Operações e Algoritmos

### Upload de Imagem (`image_upload.v`)

- **Função:** Recebe o endereço e os dados de um pixel diretamente do HPS. Escreve esse pixel na `ram_image` (a imagem original) e na `ram_op` (para exibição imediata).
- **Resolução Base:** A imagem original é de 160x120 pixels.

### Operação Inicial/Cópia (`original.v`)

- **Função:** Copia a imagem de 160x120 da `ram_image` para a `ram_op` e, opcionalmente, preenche o restante da `ram_op` (se a resolução de destino for maior) com uma cor de fundo. É acionada no reset ou para exibir a imagem base de 160x120.

### Algoritmos de Zoom In (Ampliação)

#### Replicação de Pixels (`zoom_in_replication.v`):

- **Conceito:** Cada pixel da imagem de origem é repetido para preencher um bloco de pixels na imagem de destino (e.g., um pixel vira um bloco 2x2).
- **Resultado:** Rápido e simples, mas pode criar um efeito de "pixelização".

#### Vizinho Mais Próximo (`zoom_in_nearest_neighbor.v`):

- **Conceito:** Para cada pixel na imagem de destino, calcula qual seria o pixel "vizinho mais próximo" na imagem de origem e copia sua cor.
- **Resultado:** Visualmente idêntico à replicação para ampliações inteiras, mas com uma lógica de mapeamento inverso.

### Algoritmos de Zoom Out (Redução)

#### Decimação (`zoom_out_decimation.v`):

- **Conceito:** O método mais simples de redução. Simplesmente descarta pixels, mantendo um a cada bloco de pixels na imagem de origem.
- **Resultado:** Extremamente rápido, mas com perda significativa de informação, o que pode causar serrilhamento (aliasing).

#### Média de Bloco (`zoom_out_block_average.v`):

- **Conceito:** Calcula a cor média de um bloco de pixels da imagem original para gerar um único pixel na imagem de destino.
- **Resultado:** Qualidade visual superior à decimação, produzindo uma imagem reduzida mais suave e fiel à original.

---

## 📋 Como Utilizar

### Requisitos

- **Hardware:** Placa FPGA com um chip da família Intel Cyclone V (ou similar), incluindo o **Hard Processor System (HPS)**, memória RAM suficiente, e uma saída de vídeo VGA.
- **Software:** Intel Quartus Prime para síntese e programação da FPGA. Um ambiente Linux (embarcado no HPS ou externo) para rodar o software de controle (ex: programa em C) que se comunica via barramento PIO com a FPGA.

### Controles (via Software HPS)

- As operações e seleções de algoritmo são controladas por **instruções de 32 bits enviadas via barramento PIO do HPS**.
- Um programa em C rodando no HPS seria responsável por:
    - Enviar sequências de `UPLOAD` para carregar uma imagem.
    - Enviar `INST_REPLICATION` ou `INST_NEAREST_NEIGHBOR` para configurar o algoritmo de Zoom In.
    - Enviar `INST_DECIMATION` ou `INST_BLOCK_AVERAGE` para configurar o algoritmo de Zoom Out.
    - Enviar `INST_ZOOM_IN` para executar o zoom in (aplicando o algoritmo configurado).
    - Enviar `INST_ZOOM_OUT` para executar o zoom out (aplicando o algoritmo configurado).
- Um botão de `reset` físico ainda reiniciaria o sistema FPGA.

---

## ▶️ Demonstração

### 1. Upload e Estado Inicial (Pós-Reset ou Imagem Base)

Assista ao vídeo abaixo para ver o processo de upload da imagem pixel a pixel do HPS para a FPGA, resultando na imagem original de 160x120 pixels exibida no monitor. Este estado é alcançado após o Power-On Reset (POR), um reset manual, ou após a conclusão de um upload pelo HPS.

https://github.com/user-attachments/assets/4c2c63f6-1bf0-4a35-b36c-06b1719bf2d4

*Vídeo: Upload dinâmico da imagem para a FPGA e exibição inicial.*

### 2. Exemplo de Zoom In (Utilizando algoritmo configurável)

O HPS envia um comando de `ZOOM_IN`, e a FPGA amplia a imagem para uma resolução maior (e.g., 640x480) usando o algoritmo de ampliação previamente configurado (ex: Replicação de Pixels ou Vizinho Mais Próximo).

![Imagem ampliada (640x480) utilizando um algoritmo de zoom in.](https://github.com/user-attachments/assets/bf9b42b7-0afa-4fcd-a15e-61571451d44c)

*Imagem: Exemplo de imagem ampliada no monitor VGA.*

### 3. Exemplo de Zoom Out (Utilizando algoritmo configurável)

O HPS envia um comando de `ZOOM_OUT`, e a FPGA reduz a imagem para uma resolução menor (e.g., 160x120 ou 80x60) usando o algoritmo de redução previamente configurado (ex: Decimação ou Média de Bloco).

![Imagem reduzida (160x120) utilizando um algoritmo de zoom out.](https://github.com/user-attachments/assets/f42a702a-a707-4e3e-b8c6-845610687052)
