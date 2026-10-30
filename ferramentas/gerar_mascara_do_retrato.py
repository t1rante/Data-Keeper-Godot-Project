"""Gera a máscara da jaqueta do retrato do protagonista nos diálogos.

O retrato (Sprites/Personagens/Player.png) é pintado, com muitos tons, então a
skin não troca cores exatas como no sprite da caminhada: o shader do retrato
(Script/jogo/skins.gd) pinta só onde esta máscara é branca. Rode de novo se o
Player.png for repintado:

    python3 ferramentas/gerar_mascara_do_retrato.py

Precisa do Pillow (pip install pillow). Escreve a máscara em
Sprites/Personagens/Player_mascara_jaqueta.png, uma prévia com quatro skins em
ferramentas/previa_mascara.png e mostra a cor média da jaqueta: se ela mudar,
copie-a para JAQUETA_DO_RETRATO em skins.gd.
"""
import colorsys
import os
from collections import deque

from PIL import Image, ImageFilter

PROJETO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RETRATO = os.path.join(PROJETO, "Sprites", "Personagens", "Player.png")
MASCARA = os.path.join(PROJETO, "Sprites", "Personagens", "Player_mascara_jaqueta.png")
PREVIA = os.path.join(PROJETO, "ferramentas", "previa_mascara.png")

TOPO = 760              # a jaqueta só existe abaixo desta linha
REGIAO_MINIMA = 6000    # pixels: as duas metades da jaqueta; o resto são traços soltos
# Recortes (x0, x1, y0, y1): traços do rosto e do pescoço pintados no mesmo vermelho
# escuro da sombra da jaqueta (o fechamento de buracos os emenda na gola).
RECORTES = [
    (1000, 1050, 760, 844),  # queixo, lado direito (acima da gola)
    (805, 850, 760, 828),    # mandíbula, lado esquerdo
    (799, 831, 826, 920),    # contorno do pescoço entre a gola branca e a pele, lado esquerdo
]


def vermelho_da_jaqueta(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return (h * 360 < 14 or h * 360 > 340) and s > 0.4 and v > 0.12


def main():
    im = Image.open(RETRATO).convert("RGBA")
    W, H = im.size
    px = im.load()

    # 1. Todo pixel vermelho abaixo do rosto.
    cru = Image.new("L", (W, H), 0)
    cp = cru.load()
    for y in range(TOPO, H):
        for x in range(W):
            r, g, b, a = px[x, y]
            if a >= 128 and vermelho_da_jaqueta(r, g, b):
                cp[x, y] = 255

    # 2. Só as regiões grandes e contínuas (as duas metades da jaqueta).
    mascara = Image.new("L", (W, H), 0)
    mp = mascara.load()
    visto = set()
    for y0 in range(TOPO, H):
        for x0 in range(W):
            if cp[x0, y0] == 0 or (x0, y0) in visto:
                continue
            fila = deque([(x0, y0)])
            visto.add((x0, y0))
            pontos = []
            while fila:
                x, y = fila.popleft()
                pontos.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < W and TOPO <= ny < H and cp[nx, ny] and (nx, ny) not in visto:
                            visto.add((nx, ny))
                            fila.append((nx, ny))
            if len(pontos) >= REGIAO_MINIMA:
                for p in pontos:
                    mp[p] = 255

    # 3. Fecha buraquinhos (sombras escuras dentro da jaqueta) e tira os recortes.
    mascara = mascara.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    mp = mascara.load()
    for (x0, x1, y0, y1) in RECORTES:
        for y in range(y0, y1):
            for x in range(x0, x1):
                mp[x, y] = 0
    mascara.save(MASCARA)

    # 4. Cor média dos pixels vermelhos da pintura (é a "base_hsv" do shader).
    soma = [0.0, 0.0, 0.0]
    n = 0
    for y in range(TOPO, H):
        for x in range(W):
            if cp[x, y]:
                r, g, b, _ = px[x, y]
                h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                soma[0] += h if h < 0.5 else h - 1
                soma[1] += s
                soma[2] += v
                n += 1
    base = (soma[0] / n % 1.0, soma[1] / n, soma[2] / n)
    print("máscara:", os.path.relpath(MASCARA, PROJETO))
    print("JAQUETA_DO_RETRATO := Vector3(%.3f, %.3f, %.3f)" % base)

    # 5. Prévia: original e quatro skins, só a parte de baixo do retrato.
    corte = (450, 700, 1380, 1080)

    def recolorir(alvo_hex):
        th, ts, tv = colorsys.rgb_to_hsv(*(int(alvo_hex[i:i + 2], 16) / 255 for i in (1, 3, 5)))
        saida = im.copy()
        sp = saida.load()
        for y in range(corte[1], corte[3]):
            for x in range(corte[0], corte[2]):
                m = mp[x, y] / 255
                if m == 0:
                    continue
                r, g, b, a = px[x, y]
                h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                nr, ng, nb = colorsys.hsv_to_rgb(th, min(1.0, s * ts / base[1]), min(1.0, v * tv / base[2]))
                sp[x, y] = (int((r / 255 * (1 - m) + nr * m) * 255), int((g / 255 * (1 - m) + ng * m) * 255),
                            int((b / 255 * (1 - m) + nb * m) * 255), a)
        return saida.crop(corte).resize((465, 190))

    paineis = [im.crop(corte).resize((465, 190))]
    paineis += [recolorir(c) for c in ("#4b6bff", "#ff74d7", "#1fdc7a", "#f2f2f8")]
    paineis.append(mascara.convert("RGBA").crop(corte).resize((465, 190)))
    previa = Image.new("RGBA", (465 * 3, 190 * 2), (124, 155, 255, 255))
    for i, painel in enumerate(paineis):
        previa.alpha_composite(painel, ((i % 3) * 465, (i // 3) * 190))
    previa.save(PREVIA)
    print("prévia:", os.path.relpath(PREVIA, PROJETO))


if __name__ == "__main__":
    main()
