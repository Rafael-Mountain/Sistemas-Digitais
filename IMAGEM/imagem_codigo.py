from PIL import Image


def converter_imagem(caminho_entrada, caminho_saida_mif, caminho_saida_cinza=None):
    """
    Converte uma imagem para o formato de arquivo de inicialização de memória (.mif)
    e, opcionalmente, salva uma versão visual da imagem em escala de cinza.

    """
    try:
        # Abre a imagem original
        imagem = Image.open(caminho_entrada)
        
        # Converte a imagem para escala de cinza de 8 bits através do modo 'L'
        imagem_cinza = imagem.convert('L')

        # --- SALVA A IMAGEM EM ESCALA DE CINZA (SE O CAMINHO FOI FORNECIDO) ---
        if caminho_saida_cinza:
            imagem_cinza.save(caminho_saida_cinza)
            print(f"Imagem em escala de cinza salva com sucesso: {caminho_saida_cinza}")

        # --- GERAÇÃO DO ARQUIVO MIF ---
        largura, altura = imagem_cinza.size
        pixels = list(imagem_cinza.getdata())
        numero_pixels = len(pixels)

        # Abre o arquivo .mif para escrita
        with open(caminho_saida_mif, 'w') as arquivo_mif:
            # Escreve o cabeçalho do arquivo MIF
            arquivo_mif.write(f"WIDTH=8;\n")
            arquivo_mif.write(f"DEPTH={numero_pixels};\n")
            arquivo_mif.write("ADDRESS_RADIX=HEX;\n")
            arquivo_mif.write("DATA_RADIX=BIN;\n")
            arquivo_mif.write("CONTENT BEGIN\n")

            # Itera sobre cada pixel e escreve no arquivo
            for endereco, valor_pixel in enumerate(pixels):
                # Escreve o endereço em HEX e o valor do pixel em BIN de 8 bits
                arquivo_mif.write(f"    {endereco:X} : {valor_pixel:08b};\n")

            arquivo_mif.write("END;\n")

        print(f"Arquivo MIF gerado com sucesso: {caminho_saida_mif}")
        print(f"Dimensões da imagem: {largura}x{altura} pixels")
        print(f"Total de pixels: {numero_pixels}")

    except FileNotFoundError:
        print(f"Erro: O arquivo não foi encontrado no caminho '{caminho_entrada}'")
    except Exception as e:
        print(f"Ocorreu um erro inesperado: {e}")


if __name__ == "__main__":

    imagem_de_entrada = 'tree.jpg'
    arquivo_mif_de_saida = 'tree.mif'
    arquivo_cinza_de_saida = 'tree.png'

    converter_imagem(imagem_de_entrada, arquivo_mif_de_saida, arquivo_cinza_de_saida)