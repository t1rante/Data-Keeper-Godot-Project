"""Retrato da Ana, desenhado em código no estilo dos outros retratos do jogo.

Rode na pasta do projeto: python3 ferramentas/gerar_retrato_da_ana.py (precisa do Pillow).
Grava Sprites/Personagens/Ana.png. Quando a arte final chegar, ela substitui esse arquivo
e este script deixa de ser necessário.

Grade de 160x90 "pixels" (12 px cada) ampliada para 1920x1080. Rosto no mesmo lugar
e tamanho dos outros (olhos em x~912 e x~1176, y~470; queixo em y~720), paleta
quente dos outros retratos (pele laranja, contorno marrom-escuro), olhos grandes com
brilho e um leve desfoque no fim (os outros retratos não são pixel art exata).
A Ana é a versão gótica desse estilo: pele mais clara, cabelo preto com reflexo
roxo e franja reta, olhos semicerrados com delineado, batom ameixa, piercings,
gargantilha e moletom ameixa com o broche "</>".
"""
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

W, H, U = 160, 90, 12
C = {
    "pele": (255, 182, 128), "pele_sombra": (232, 134, 80), "pele_funda": (198, 96, 52), "pele_luz": (255, 210, 166),
    "contorno_pele": (55, 17, 6), "contorno": (14, 8, 12),
    "cabelo": (33, 25, 41), "cabelo_escuro": (17, 11, 21), "cabelo_brilho": (70, 55, 98), "cabelo_reflexo": (112, 92, 156),
    "branco_olho": (251, 242, 232), "iris": (26, 10, 24), "iris_clara": (104, 56, 132), "delineador": (12, 5, 10),
    "sombra_olho": (150, 74, 98), "palpebra": (204, 120, 84),
    "boca": (110, 30, 66), "boca_clara": (160, 60, 100), "boca_brilho": (204, 116, 146),
    "moletom": (54, 37, 66), "moletom_sombra": (33, 22, 43), "moletom_luz": (82, 58, 100),
    "cordao": (200, 156, 242), "prata": (228, 230, 240), "prata_sombra": (150, 152, 172),
    "broche": (152, 88, 226), "broche_escuro": (102, 52, 162),
}


def cor(nome):
    return C[nome] + (255,)


class Tela:
    def __init__(self):
        self.im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def p(self, x, y, nome):
        if 0 <= x < W and 0 <= y < H:
            self.im.putpixel((x, y), cor(nome))

    def linha(self, pontos, nome):
        self.d.line(pontos, fill=cor(nome), width=1)

    def ret(self, x0, y0, x1, y1, nome):
        self.d.rectangle([x0, y0, x1, y1], fill=cor(nome))

    @staticmethod
    def mascara(desenhar):
        m = Image.new("L", (W, H), 0)
        desenhar(ImageDraw.Draw(m))
        return m

    def pintar(self, mascara, nome):
        self.im.paste(Image.new("RGBA", (W, H), cor(nome)), (0, 0), mascara)


def mover(m, dx, dy):
    return ImageChops.offset(m, dx, dy)


def menos(a, b):
    return ImageChops.subtract(a, b)


def junto(a, b):
    return ImageChops.darker(a, b)


def ou(*ms):
    r = ms[0]
    for m in ms[1:]:
        r = ImageChops.lighter(r, m)
    return r


M = Tela.mascara


def main(saida):
    t = Tela()
    # ---------------- formas (grade 160x90)
    cabelo_tras = M(lambda d: (d.ellipse([59, 3, 115, 58], fill=255),
                               d.polygon([(59, 31), (115, 31), (117, 56), (119, 74), (118, 84), (116, 90),
                                          (113, 86), (110, 90), (64, 90), (61, 86), (58, 90), (56, 84), (55, 74), (57, 56)], fill=255)))
    capuz = M(lambda d: d.ellipse([66, 62, 108, 80], fill=255))
    pescoco = M(lambda d: d.rectangle([80, 54, 94, 72], fill=255))
    moletom = M(lambda d: d.polygon([(46, 90), (49, 81), (57, 75), (70, 71), (80, 71), (94, 71),
                                       (104, 71), (117, 75), (125, 81), (128, 90)], fill=255))
    rosto = M(lambda d: (d.ellipse([65, 16, 109, 60], fill=255),
                         d.polygon([(73, 49), (87, 63), (101, 49)], fill=255)))
    orelha = M(lambda d: d.ellipse([104, 36, 113, 50], fill=255))
    mecha_esq = M(lambda d: d.polygon([(61, 24), (67, 22), (69, 34), (67, 48), (66, 62), (66, 76),
                                         (65, 86), (63, 92), (60, 88), (57, 92), (57, 70), (59, 46)], fill=255))
    # a mecha da direita passa atrás da orelha e cai a partir do lóbulo (orelha e argola à mostra)
    mecha_dir = M(lambda d: d.polygon([(113, 54), (116, 50), (118, 62), (119, 76), (120, 92),
                                         (117, 88), (114, 92), (113, 74), (112, 62)], fill=255))
    franja = M(lambda d: (d.ellipse([63, 5, 111, 44], fill=255) if False else None,
                          d.chord([63, 4, 111, 52], 180, 360, fill=255),
                          d.rectangle([63, 26, 111, 28], fill=255)))

    # ---------------- pintura em camadas (de trás para a frente)
    t.pintar(cabelo_tras, "cabelo")
    t.pintar(menos(cabelo_tras, mover(cabelo_tras, -3, 0)), "cabelo_escuro")
    t.pintar(capuz, "moletom_sombra")
    t.pintar(pescoco, "pele_sombra")
    t.pintar(M(lambda d: d.rectangle([80, 54, 94, 61], fill=255)), "pele_funda")  # sombra do queixo no pescoço
    t.pintar(moletom, "moletom")
    t.pintar(menos(moletom, mover(moletom, 5, 0)), "moletom_sombra")
    t.pintar(menos(moletom, mover(moletom, -5, 0)), "moletom_sombra")
    t.pintar(M(lambda d: d.polygon([(57, 76), (70, 72), (68, 75), (59, 79)], fill=255)), "moletom_luz")
    t.pintar(M(lambda d: d.polygon([(117, 76), (104, 72), (106, 75), (115, 79)], fill=255)), "moletom_luz")
    # capuz em volta do pescoço: dobra clara e o vão escuro no meio
    t.pintar(M(lambda d: d.polygon([(72, 71), (80, 69), (87, 77), (94, 69), (102, 71), (95, 80), (87, 83), (79, 80)], fill=255)), "moletom_luz")
    t.pintar(M(lambda d: d.polygon([(80, 71), (87, 78), (94, 71), (94, 73), (87, 80), (80, 73)], fill=255)), "moletom_sombra")
    # orelha antes do rosto: o rosto cobre a parte de dentro, como nos outros retratos
    t.pintar(orelha, "pele")
    t.pintar(menos(orelha, mover(orelha, -2, 0)), "pele_sombra")
    # rosto: luz na testa e na bochecha, sombra nas bordas
    t.pintar(rosto, "pele")
    t.pintar(menos(rosto, mover(rosto, 2, 0)), "pele_sombra")    # borda esquerda
    t.pintar(menos(rosto, mover(rosto, -2, 0)), "pele_sombra")   # borda direita
    t.pintar(menos(rosto, mover(rosto, 0, -3)), "pele_sombra")   # queixo
    # bochechas e mandíbula arredondadas: faixa de sombra na metade de baixo e a borda mais escura
    metade_de_baixo = M(lambda d: d.rectangle([0, 44, W, H], fill=255))
    t.pintar(junto(menos(rosto, mover(rosto, 3, -1)), metade_de_baixo), "pele_sombra")
    t.pintar(junto(menos(rosto, mover(rosto, -3, -1)), metade_de_baixo), "pele_sombra")
    t.pintar(junto(menos(rosto, mover(rosto, 0, -1)), metade_de_baixo), "pele_funda")
    # dobra de dentro da orelha (um C aberto para o rosto) e o contorno de fora
    for x, y in [(111, 39), (111, 40), (110, 41), (110, 42), (110, 43), (110, 44), (111, 45), (111, 46)]:
        t.p(x, y, "pele_funda")
    for x, y in [(110, 39), (109, 42), (109, 43), (110, 46), (110, 47)]:
        t.p(x, y, "pele_sombra")
    t.p(112, 42, "pele_luz")
    t.p(112, 43, "pele_luz")
    t.pintar(menos(menos(orelha, orelha.filter(ImageFilter.MinFilter(3))), rosto), "contorno_pele")
    # cabelo da frente
    t.pintar(mecha_dir, "cabelo")
    t.pintar(menos(mecha_dir, mover(mecha_dir, -2, 0)), "cabelo_escuro")
    t.pintar(mecha_esq, "cabelo")
    t.pintar(menos(mecha_esq, mover(mecha_esq, 2, 0)), "cabelo_escuro")
    t.pintar(franja, "cabelo")
    t.pintar(junto(menos(mover(franja, 0, 1), franja), rosto), "pele_sombra")   # sombra da franja, só na testa

    # ---------------- textura do cabelo: fios e reflexo roxo
    t.linha([(71, 12), (78, 9), (87, 7), (96, 8), (103, 11)], "cabelo_brilho")   # arco de brilho
    t.linha([(75, 12), (82, 9), (88, 8)], "cabelo_reflexo")
    t.linha([(92, 9), (98, 10)], "cabelo_reflexo")
    # fios da franja: saem do alto da cabeça em leque até a ponta reta
    for fim in [68, 75, 82, 92, 99, 106]:
        t.linha([(round(87 + (fim - 87) * 0.35), 11), (fim, 27)], "cabelo_escuro")
    # mechas de brilho ao lado de alguns fios (luz vinda de cima)
    for fim, dentro in [(72, 1), (79, 1), (96, -1), (103, -1)]:
        t.linha([(round(87 + (fim - 87) * 0.45) + dentro, 14), (fim + dentro, 23)], "cabelo_brilho")
    for x, y0, y1, nome in [(60, 34, 66, "cabelo_brilho"), (63, 54, 88, "cabelo_brilho"), (58, 60, 90, "cabelo_escuro"),
                            (115, 56, 80, "cabelo_brilho"), (118, 70, 90, "cabelo_brilho"), (113, 66, 90, "cabelo_escuro"),
                            (116, 30, 46, "cabelo_brilho")]:
        t.linha([(x, y0), (x, y1)], nome)
    # ponta reta da franja com a borda escura (o corte "bloco" fica nítido)
    t.pintar(menos(franja, mover(franja, 0, -1)), "cabelo_escuro")

    # ---------------- olhos grandes, semicerrados, com delineado gatinho
    def olho(cx, lado):
        fora = -1 if lado == "esq" else 1          # direção do canto de fora
        x0, x1 = cx - 5, cx + 4                    # 10 de largura
        # sombra ameixa e pálpebra
        for x in range(x0, x1 + 1):
            t.p(x, 32, "sombra_olho")
        # abertura (8 linhas) com o branco nos cantos
        for y in range(34, 42):
            for x in range(x0 + (1 if y in (34, 41) else 0), x1 + 1 - (1 if y in (34, 41) else 0)):
                t.p(x, y, "branco_olho")
        # íris grande e escura (6 x 8), mais roxa embaixo
        for y in range(34, 42):
            for x in range(cx - 3, cx + 3):
                t.p(x, y, "iris")
        for x in range(cx - 2, cx + 2):
            t.p(x, 39, "iris_clara")
            t.p(x, 40, "iris_clara")
        t.p(cx - 3, 41, "branco_olho")
        t.p(cx + 2, 41, "branco_olho")
        # brilhos (como nos outros retratos: um grande em cima, um pequeno embaixo)
        t.ret(cx - 2, 35, cx - 1, 36, "branco_olho")
        t.p(cx + 1, 39, "branco_olho")
        # pálpebra pesada: delineador grosso cobrindo o topo da íris (cara de tédio)
        for x in range(x0, x1 + 1):
            t.p(x, 33, "delineador")
            t.p(x, 34, "delineador")
        # asinha para fora
        borda = x0 if lado == "esq" else x1
        for i in range(1, 4):
            t.p(borda + fora * i, 34 - i, "delineador")
        t.p(borda + fora, 34, "delineador")
        # cílio de baixo no canto de fora e a linha d'água
        for i in range(4):
            t.p((x0 + i) if lado == "esq" else (x1 - i), 42, "delineador")
        for x in range(x0 + 1, x1):
            t.p(x, 43, "pele_sombra")

    olho(77, "esq")
    olho(98, "dir")
    # sobrancelhas: aparecem logo abaixo da franja; a da direita levantada (sarcasmo)
    for y in (30, 31):  # a da esquerda reta, com 2 de espessura
        t.linha([(71, y), (82, y)], "cabelo_escuro")
    for dy in (0, 1):   # a da direita sobe para fora: sarcasmo
        t.linha([(93, 30 + dy), (97, 30 + dy)], "cabelo_escuro")
        t.linha([(98, 29 + dy), (101, 29 + dy)], "cabelo_escuro")
        t.linha([(102, 28 + dy), (104, 28 + dy)], "cabelo_escuro")

    # ---------------- nariz, boca e queixo
    t.p(88, 46, "pele_sombra")
    t.p(89, 47, "pele_sombra")
    t.p(89, 48, "pele_funda")
    t.p(88, 49, "pele_funda")
    t.p(87, 49, "pele_sombra")
    # meio sorriso de canto, batom ameixa
    t.linha([(83, 53), (91, 53)], "boca")
    t.linha([(92, 52), (93, 52)], "boca")
    t.p(94, 51, "boca")
    t.linha([(84, 54), (91, 54)], "boca_clara")
    t.linha([(86, 55), (89, 55)], "boca_clara")
    t.p(87, 54, "boca_brilho")
    t.p(88, 54, "boca_brilho")
    t.p(82, 53, "pele_funda")
    t.linha([(85, 58), (90, 58)], "pele_sombra")  # sombra embaixo do lábio

    # ---------------- acessórios
    t.p(112, 40, "prata")  # dois piercings na borda da orelha
    t.p(112, 45, "prata")
    for x, y in [(109, 49), (108, 50), (110, 50), (109, 51)]:  # argola presa no lóbulo
        t.p(x, y, "prata")
    t.p(110, 51, "prata_sombra")
    t.linha([(80, 64), (94, 64)], "contorno")  # gargantilha
    t.linha([(80, 65), (94, 65)], "contorno")
    for x, y in [(86, 66), (86, 67), (87, 68), (88, 68), (89, 67)]:  # pingente de lua
        t.p(x, y, "prata")
    t.p(87, 67, "prata_sombra")
    t.linha([(83, 79), (82, 88)], "cordao")
    t.linha([(91, 79), (92, 88)], "cordao")
    for x in (81, 82, 92, 93):
        t.p(x, 89, "prata")
    t.ret(99, 81, 112, 87, "broche")  # broche </>, no peito, longe da borda da tela
    t.linha([(99, 87), (112, 87)], "broche_escuro")
    for x, y in [(102, 84), (103, 83), (103, 85), (109, 84), (108, 83), (108, 85), (105, 85), (106, 84), (107, 83)]:
        t.p(x, y, "branco_olho")
    t.linha([(58, 82), (62, 90)], "moletom_sombra")  # dobras
    t.linha([(116, 80), (112, 90)], "moletom_sombra")

    # ---------------- contorno marrom-escuro (perto da pele) e quase preto (no resto)
    alfa = t.im.getchannel("A")
    borda = menos(alfa.filter(ImageFilter.MaxFilter(3)), alfa)
    pele = ou(rosto, orelha, pescoco)
    final = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    final.paste(Image.new("RGBA", (W, H), cor("contorno")), (0, 0), borda)
    final.paste(Image.new("RGBA", (W, H), cor("contorno_pele")), (0, 0), junto(borda, pele.filter(ImageFilter.MaxFilter(3))))
    final.alpha_composite(t.im)
    # linha do rosto onde ele encontra o cabelo e o pescoço (abaixo da franja)
    cabelo_frente = ou(mecha_esq, mecha_dir, franja)
    contorno_rosto = menos(rosto, rosto.filter(ImageFilter.MinFilter(3)))
    contorno_rosto = menos(contorno_rosto, cabelo_frente)
    contorno_rosto = menos(contorno_rosto, M(lambda d: d.rectangle([0, 0, W, 28], fill=255)))
    junto_da_orelha = junto(contorno_rosto, orelha.filter(ImageFilter.MaxFilter(3)))
    final.paste(Image.new("RGBA", (W, H), cor("contorno_pele")), (0, 0), menos(contorno_rosto, junto_da_orelha))
    final.paste(Image.new("RGBA", (W, H), cor("pele_funda")), (0, 0), junto_da_orelha)

    centrado = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    centrado.paste(final, (-8, 0))
    final = centrado
    grande = final.resize((W * U, H * U), Image.NEAREST)
    grande = grande.filter(ImageFilter.GaussianBlur(0.9))  # "pixels" macios como nos outros retratos
    grande.save(saida)
    print("gravado", saida, grande.size, "bbox", grande.getbbox())


if __name__ == "__main__":
    import os
    projeto = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(projeto, "Sprites", "Personagens", "Ana.png"))
