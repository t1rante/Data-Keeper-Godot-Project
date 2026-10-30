"""Gera o degradê em pixel art do fundo da tela de título (assets/fundo_do_titulo.png).

Rode na pasta do projeto: python3 ferramentas/gerar_fundo_do_titulo.py (precisa do Pillow).

A imagem é pequena (288x162) e a cena estica 4 vezes sem suavizar (texture_filter
"Nearest"): cada pixel vira um bloco de 4 px na tela de 1152x648. O degradê é em
faixas lisas de azul-escuro, cada vez mais fortes para baixo, com uma tira de
pontilhado (dithering Bayer 4x4) na passagem de uma faixa para a outra, como se faz
em pixel art. O terço de cima fica vazio (o logo não muda).

A imagem vai com a força cheia; quem deixa discreto é a cena: o nó Degrade da
tela de título tem self_modulate com alfa baixo (mexa ali para mais ou menos forte).
"""
import os
import sys

from PIL import Image

PROJETO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(PROJETO, "assets", "fundo_do_titulo.png")

TAMANHO = (288, 162)
COR = (0x16, 0x1E, 0x6E)  # azul-escuro (o do fundo é #7c9bff)
COMECO = 0.30             # o degradê começa a 30% da altura
FAIXAS = 5                # quantas faixas até embaixo
PONTILHADO = 0.45         # fração de cada faixa que é tira pontilhada
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def main(saida):
    largura, altura = TAMANHO
    img = Image.new("RGBA", TAMANHO, COR + (0,))
    for y in range(altura):
        t = max(0.0, (y / (altura - 1) - COMECO) / (1 - COMECO))
        nivel = t * FAIXAS
        faixa = int(nivel)
        resto = nivel - faixa
        # só o fim de cada faixa é pontilhado; o começo é liso
        rampa = max(0.0, (resto - (1 - PONTILHADO)) / PONTILHADO)
        for x in range(largura):
            limiar = (BAYER[y % 4][x % 4] + 0.5) / 16
            f = min(FAIXAS, faixa + (1 if rampa > limiar else 0))
            img.putpixel((x, y), COR + (round(255 * f / FAIXAS),))
    img.save(saida)
    print("gravado", saida)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else SAIDA)
