from PIL import Image, UnidentifiedImageError
import os


def converter_imagem(caminho_entrada, caminho_saida_mif, caminho_saida_cinza=None):
    """
    Converte uma imagem para um arquivo de inicialização de memória (.mif).
    Opcionalmente, salva também a imagem em escala de cinza.

    Args:
        caminho_entrada (str): Caminho da imagem original.
        caminho_saida_mif (str): Caminho para o arquivo MIF de saída.
        caminho_saida_cinza (str, opcional): Caminho para salvar a versão em escala de cinza.
    """
    try:
        # --- VERIFICA SE O ARQUIVO EXISTE ---
        if not os.path.isfile(caminho_entrada):
            raise FileNotFoundError(f"O arquivo '{caminho_entrada}' não existe.")

        # --- TENTA ABRIR A IMAGEM ---
        try:
            imagem = Image.open(caminho_entrada)
        except UnidentifiedImageError:
            raise ValueError(f"O arquivo '{caminho_entrada}' não é uma imagem válida ou está corrompido.")

        # --- CONVERTE PARA ESCALA DE CINZA ---
        imagem_cinza = imagem.convert("L")

        # --- SALVA A IMAGEM EM ESCALA DE CINZA ---
        if caminho_saida_cinza:
            try:
                imagem_cinza.save(caminho_saida_cinza)
                print(f"Imagem em escala de cinza salva: {caminho_saida_cinza}")
            except OSError as e:
                print(f"Erro ao salvar a imagem em escala de cinza: {e}")

        # --- GERAÇÃO DO ARQUIVO MIF ---
        largura, altura = imagem_cinza.size
        pixels = list(imagem_cinza.getdata())
        numero_pixels = len(pixels)

        try:
            with open(caminho_saida_mif, "w") as arquivo_mif:
                arquivo_mif.write("WIDTH=8;\n")
                arquivo_mif.write(f"DEPTH={numero_pixels};\n")
                arquivo_mif.write("ADDRESS_RADIX=HEX;\n")
                arquivo_mif.write("DATA_RADIX=BIN;\n")
                arquivo_mif.write("CONTENT BEGIN\n")

                for endereco, valor_pixel in enumerate(pixels):
                    arquivo_mif.write(f"    {endereco:X} : {valor_pixel:08b};\n")

                arquivo_mif.write("END;\n")

            print(f"Arquivo MIF gerado com sucesso: {caminho_saida_mif}")
            print(f"Dimensões da imagem: {largura}x{altura} pixels")
            print(f"Total de pixels: {numero_pixels}")

        except PermissionError:
            print(f"Permissão negada ao tentar escrever em '{caminho_saida_mif}'.")
        except OSError as e:
            print(f"Erro ao salvar o arquivo MIF: {e}")

    except Exception as e:
        print(f"Ocorreu um erro inesperado: {e}")


if __name__ == "__main__":
    imagem_de_entrada = "jean.jpg"
    arquivo_mif_de_saida = "jean.mif"
    arquivo_cinza_de_saida = "jean.png"

    converter_imagem(imagem_de_entrada, arquivo_mif_de_saida, arquivo_cinza_de_saida)
