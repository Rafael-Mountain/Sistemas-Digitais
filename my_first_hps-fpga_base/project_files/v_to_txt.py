import os

def separar_conteudos(arquivos, pasta_saida="saidas"):
    # Cria a pasta de saída, se não existir
    os.makedirs(pasta_saida, exist_ok=True)

    for arquivo in arquivos:
        try:
            with open(arquivo, "r", encoding="utf-8") as f:
                conteudo = f.read()
            
            # Nome do arquivo de saída (mesmo nome + .txt)
            nome_base = os.path.basename(arquivo)
            nome_saida = os.path.splitext(nome_base)[0] + ".txt"
            caminho_saida = os.path.join(pasta_saida, nome_saida)

            with open(caminho_saida, "w", encoding="utf-8") as f:
                f.write(conteudo)
            
            print(f"✅ Conteúdo de '{arquivo}' salvo em '{caminho_saida}'")

        except Exception as e:
            print(f"⚠️ Erro ao processar {arquivo}: {e}")


# Exemplo de uso:
lista_arquivos = [
    "zoom_in_replication.v",
    "zoom_out_decimation.v",
    "zoom_out_block_average.v",
    "zoom_in_nearest_neighbor.v",
    "original.v",
    "processing_unit.v",
    "memory_module.v",
    "control_unit.v",
    "video_controller.v",
    "instruct_decoder.v",
    "instruct_memory.v",
    "vga_module.v",
    "main.v",
    "clock_divider.v"
    ]

separar_conteudos(lista_arquivos)
