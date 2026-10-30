"""Gera o logo "DATA KEEPERS" da tela de título no estilo do logo antigo ("BANCO de DADOS").

Rode na pasta do projeto: python3 ferramentas/gerar_logo.py (precisa do Pillow).
Grava assets/logo_data_keepers.png com o mesmo tamanho de tela (1748x1240) e o mesmo
centro do logo antigo, para entrar no lugar dele sem mexer na cena.

O estilo foi medido no logo antigo (assets/Jogo de Banco de Dados.png): letras retas
da fonte 04B_19, degradê de #a6cada (em cima) para #a565b5 (embaixo), contorno preto
fino, "volume" preto em perspectiva (as letras afundam na direção de um ponto abaixo
do centro), borda branca de adesivo (~20 px) e sombra azul-escura suave para baixo e
para a esquerda. As linhas são pintadas de cima para baixo: a de baixo passa por cima
do volume da de cima, como o "de" sobre o "BANCO".

Os dois dados do logo antigo são recortados dele (cada dado é o casco convexo da
parte clara de dentro do contorno) e ficam no degrau à direita de "DATA", sobre o
"KEEPERS", dentro da mesma borda branca.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

PROJETO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTE = os.path.join(PROJETO, "assets", "04b_19", "04B_19__.TTF")
SAIDA = os.path.join(PROJETO, "assets", "logo_data_keepers.png")

TELA = (1748, 1240)
CENTRO = (874, 600)            # centro do logo antigo na mesma tela (o volume desce, então sobe um pouco)
LINHAS = ["DATA", "KEEPERS"]
LARGURA_DA_MAIOR = 800         # largura de "KEEPERS" (px); na tela de título fica longe dos botões
COR_DE_CIMA = (0xA6, 0xCA, 0xDA)
COR_DE_BAIXO = (0xA5, 0x65, 0xB5)
CONTORNO = 4                   # px, preto em volta das letras
VOLUME = 0.45                  # profundidade do volume preto, em fração da altura da letra
FUGA = 1100                    # o ponto de fuga do volume fica esse tanto abaixo do centro (px)
BORDA = 20                     # px, borda branca do adesivo
ENTRE_LETRAS = 14              # px de preto entre uma letra e a outra, como no antigo
SOMBRA = ((-10, 14), (28, 30, 74, 150))  # deslocamento e cor da sombra do adesivo
LOGO_ANTIGO = os.path.join(PROJETO, "assets", "Jogo de Banco de Dados.png")
CAIXA_DOS_DADOS = (970, 605, 1110, 720)          # onde ficam os dados no logo antigo
SEMENTES_DOS_DADOS = [[(50, 55), (55, 27)], [(93, 77), (98, 55)]]  # dentro de cada dado (na caixa)
ALTURA_DOS_DADOS = 1.00        # altura dos dados, em fração da altura da letra


def montar_linha(texto, fonte):
    """As letras retas, na mesma linha de base, com ENTRE_LETRAS px entre elas."""
    caixas = [fonte.getbbox(c, anchor="ls") for c in texto]
    largura = sum(c[2] - c[0] for c in caixas) + ENTRE_LETRAS * (len(texto) - 1)
    topo = min(c[1] for c in caixas)
    linha = Image.new("L", (largura + 40, max(c[3] for c in caixas) - topo + 40), 0)
    desenho = ImageDraw.Draw(linha)
    x = 20
    for c, caixa in zip(texto, caixas):
        desenho.text((x - caixa[0], 20 - topo), c, font=fonte, fill=255, anchor="ls")
        x += caixa[2] - caixa[0] + ENTRE_LETRAS
    linha = linha.point(lambda v: 255 if v >= 128 else 0)  # sem meio-tom: a fonte já é pixel
    return linha.crop(linha.getbbox())


def recortar_dados():
    """Os dois dados do logo antigo, com o contorno, em fundo transparente."""
    antigo = Image.open(LOGO_ANTIGO).convert("RGBA").crop(CAIXA_DOS_DADOS)
    largura, altura = antigo.size
    escuro = antigo.convert("L").point(lambda v: 255 if v <= 140 else 0).filter(ImageFilter.MaxFilter(3))
    mascara = Image.new("L", antigo.size, 0)
    for sementes in SEMENTES_DOS_DADOS:
        claro = ImageChops.invert(escuro)
        for s in sementes:
            if claro.getpixel(s) == 255:
                ImageDraw.floodfill(claro, s, 128)
        pontos = [(x, y) for y in range(altura) for x in range(largura) if claro.getpixel((x, y)) == 128]
        ImageDraw.Draw(mascara).polygon(casco_convexo(pontos), fill=255)
    mascara = dilatar_reto(mascara, 2)  # o contorno preto fica junto
    dados = Image.new("RGBA", antigo.size, (0, 0, 0, 0))
    dados.paste(antigo, (0, 0), mascara)
    return dados.crop(dados.getbbox())


def casco_convexo(pontos):
    pontos = sorted(set(pontos))

    def giro(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    baixo, cima = [], []
    for p in pontos:
        while len(baixo) >= 2 and giro(baixo[-2], baixo[-1], p) <= 0:
            baixo.pop()
        baixo.append(p)
    for p in reversed(pontos):
        while len(cima) >= 2 and giro(cima[-2], cima[-1], p) <= 0:
            cima.pop()
        cima.append(p)
    return baixo[:-1] + cima[:-1]


def dilatar(m, raio):
    """Engorda a máscara `raio` px com cantos redondos (desfoque + corte)."""
    if raio <= 0:
        return m
    borrada = m.filter(ImageFilter.GaussianBlur(raio * 0.6))
    return borrada.point(lambda v: 255 if v > 18 else 0)


def dilatar_reto(m, raio):
    """Engorda `raio` px sem arredondar: o contorno segue os degraus das letras."""
    for _ in range(raio):
        m = m.filter(ImageFilter.MaxFilter(3))
    return m


def fechar(m, raio):
    """Tapa frestas mais estreitas que 2 * `raio` px (entre uma letra e a outra) sem
    mexer no resto: engorda e afina o mesmo tanto."""
    m = dilatar_reto(m, raio)
    for _ in range(raio):
        m = m.filter(ImageFilter.MinFilter(3))
    return m


def degrade(tamanho, topo, base):
    largura, altura = tamanho
    img = Image.new("RGB", (1, altura))
    for y in range(altura):
        t = min(1.0, y / max(1, altura * 0.88))  # o fim do degradê fica liso, como no antigo
        img.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(topo, base)))
    return img.resize((largura, altura))


def afundar(m, profundidade, fuga):
    """Volume em perspectiva: cópias da máscara cada vez menores na direção do ponto `fuga`.
    `profundidade` é quanto a borda de baixo da máscara desce."""
    caixa = m.getbbox()
    distancia = fuga[1] - caixa[3]
    volume = Image.new("L", m.size, 0)
    for passo in range(0, profundidade + 1, 2):
        s = 1.0 - passo / distancia  # escala em volta do ponto de fuga
        copia = m.transform(m.size, Image.AFFINE,
                            (1 / s, 0, fuga[0] * (1 - 1 / s), 0, 1 / s, fuga[1] * (1 - 1 / s)),
                            resample=Image.NEAREST)
        volume = ImageChops.lighter(volume, copia)
    return volume


def main(saida):
    # tamanho da fonte para "KEEPERS" ficar com LARGURA_DA_MAIOR
    tamanho = 100
    for _ in range(6):
        fonte = ImageFont.truetype(FONTE, tamanho)
        largura = montar_linha(max(LINHAS, key=len), fonte).width + 2 * CONTORNO
        tamanho = int(tamanho * LARGURA_DA_MAIOR / largura)
    fonte = ImageFont.truetype(FONTE, tamanho)
    linhas = [montar_linha(t, fonte) for t in LINHAS]
    altura_da_letra = max(l.height for l in linhas)
    profundidade = int(altura_da_letra * VOLUME)

    # posições das linhas na tela: empilhadas, a de baixo cobre parte do volume da de cima
    vao = int(profundidade * 0.35)
    altura_total = sum(l.height for l in linhas) + vao * (len(linhas) - 1) + profundidade
    y = CENTRO[1] - altura_total // 2
    fuga = (CENTRO[0], CENTRO[1] + FUGA)
    camadas = []  # (letras, preto) de cada linha, pintadas de cima para baixo
    caixas = []   # (x0, y0, x1, y1) das letras de cada linha
    for l in linhas:
        letras = Image.new("L", TELA, 0)
        letras.paste(l, (CENTRO[0] - l.width // 2, y), l)
        caixas.append((CENTRO[0] - l.width // 2, y, CENTRO[0] - l.width // 2 + l.width, y + l.height))
        contorno = dilatar_reto(letras, CONTORNO)
        preto = fechar(ImageChops.lighter(contorno, afundar(contorno, profundidade, fuga)), 16)
        camadas.append((letras, preto, y, y + l.height))
        y += l.height + vao

    # os dados: no degrau à direita de "DATA", em pé sobre o "KEEPERS"
    dados = recortar_dados()
    altura = int(altura_da_letra * ALTURA_DOS_DADOS)
    dados = dados.resize((round(dados.width * altura / dados.height), altura), Image.LANCZOS)
    x_dos_dados = caixas[0][2] + CONTORNO + (caixas[1][2] - caixas[0][2] - dados.width) // 2
    y_dos_dados = caixas[1][1] - CONTORNO - altura + 4
    camada_dos_dados = Image.new("RGBA", TELA, (0, 0, 0, 0))
    camada_dos_dados.paste(dados, (x_dos_dados, y_dos_dados), dados)
    mascara_dos_dados = camada_dos_dados.getchannel("A").point(lambda v: 255 if v > 40 else 0)

    silhueta = Image.new("L", TELA, 0)
    for _, preto, _, _ in camadas:
        silhueta = ImageChops.lighter(silhueta, preto)
    silhueta = ImageChops.lighter(silhueta, mascara_dos_dados)  # a borda branca abraça os dados
    adesivo = dilatar(fechar(silhueta, 14), BORDA)
    # buracos brancos presos no meio do preto (sob a barra do T, entre as linhas) viram preto
    fora = silhueta.copy()
    ImageDraw.floodfill(fora, (0, 0), 128)
    buracos = fora.point(lambda v: 255 if v == 0 else 0)

    final = Image.new("RGBA", TELA, (0, 0, 0, 0))
    sombra = ImageChops.offset(adesivo, *SOMBRA[0]).filter(ImageFilter.GaussianBlur(5))
    final.paste(Image.new("RGBA", TELA, SOMBRA[1]), (0, 0), sombra)
    final.paste(Image.new("RGBA", TELA, (255, 255, 255, 255)), (0, 0), adesivo)
    final.paste(Image.new("RGBA", TELA, (0, 0, 0, 255)), (0, 0), buracos)
    for letras, preto, y0, y1 in camadas:
        final.paste(Image.new("RGBA", TELA, (0, 0, 0, 255)), (0, 0), preto)
        cor = Image.new("RGBA", TELA, (0, 0, 0, 0))
        cor.paste(degrade((TELA[0], y1 - y0), COR_DE_CIMA, COR_DE_BAIXO), (0, y0))
        final.paste(cor, (0, 0), letras)
    final.alpha_composite(camada_dos_dados)
    final.save(saida)
    print("gravado", saida, "fonte", tamanho, "px; caixa", final.getbbox())


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else SAIDA)
