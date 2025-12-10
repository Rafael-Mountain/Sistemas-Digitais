import os

def separar_conteudos(pasta_saida="saidas"):
    # Cria a pasta de saída, se não existir
    os.makedirs(pasta_saida, exist_ok=True)

    # Obtém a lista de arquivos .v no diretório de trabalho atual, ignorando os .BAK.v
    arquivos = [arquivo for arquivo in os.listdir() if arquivo.endswith(".v") and not arquivo.endswith(".BAK.v")]

    for arquivo in arquivos:
        try:
            # Verifica se o arquivo existe antes de tentar abrir
            if not os.path.exists(arquivo):
                print(f"⚠️ Arquivo não encontrado: {arquivo}")
                continue

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
separar_conteudos()

