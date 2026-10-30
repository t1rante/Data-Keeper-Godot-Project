"""Corta o arquivo de miados da Isha em um OGG por miado (assets/sons/isha/miado_N.ogg).

Rode na pasta do projeto (precisa do ffmpeg):
    python3 ferramentas/cortar_miados.py [~/Downloads/miados_isha.aif]

O arquivo de origem tem um trecho por miado, separados por silêncio absoluto (zeros),
do jeito que o Nikolas montou. Cada trecho vira um arquivo:
- começa 10 ms antes do primeiro som (o miado sai na hora do clique) e acaba 60 ms
  depois do último, com fade curto nas pontas;
- todos com o mesmo volume: a janela de 50 ms mais forte fica em -15 dB, como os sons
  do Kenney (sem passar de -1 dB de pico);
- mono (a origem é estéreo com os dois canais iguais), OGG Vorbis.
Quantos arquivos saírem, o sons.gd precisa da mesma lista (MIADOS).

Para tirar um pedaço de um miado (um barulhinho depois dele, por exemplo), ponha o
trecho em SO_ATE: {4: 0.8} guarda só os primeiros 0,8 s do quarto miado.
"""
import array
import math
import os
import subprocess
import sys

PROJETO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIGEM = os.path.expanduser("~/Downloads/miados_isha.aif")
PASTA = os.path.join(PROJETO, "assets", "sons", "isha")

TAXA = 48000
SEPARACAO = 0.3      # s de zeros que separam um miado do outro
LIMIAR_DO_COMECO = -45.0  # dB: o som começa no primeiro bloco de 5 ms acima disso
LIMIAR_DO_FIM = -50.0     # dB: e acaba no último acima disso
ANTES, DEPOIS = 0.010, 0.060
FADE_DE_ENTRADA, FADE_DE_SAIDA = 0.005, 0.040
ALVO = -15.0         # dB da janela de 50 ms mais forte
PICO_MAXIMO = -1.0   # dB
SO_ATE = {}          # {número do miado: segundos a guardar}


def db(x):
    return 20 * math.log10(max(x, 1e-9))


def ler(caminho):
    bruto = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", caminho, "-ac", "1", "-ar", str(TAXA),
                            "-f", "f32le", "-"], capture_output=True, check=True).stdout
    amostras = array.array("f")
    amostras.frombytes(bruto)
    return amostras


def trechos(a):
    """(início, fim) de cada trecho entre os silêncios de zeros."""
    lista, inicio, ultimo = [], None, None
    for i, v in enumerate(a):
        if v != 0.0:
            if inicio is None:
                inicio = i
            elif i - ultimo > SEPARACAO * TAXA:
                lista.append((inicio, ultimo + 1))
                inicio = i
            ultimo = i
    if inicio is not None:
        lista.append((inicio, ultimo + 1))
    return [t for t in lista if t[1] - t[0] > 0.05 * TAXA]  # descarta estalinhos soltos


def rms(a, i, n):
    bloco = a[i:i + n]
    return math.sqrt(sum(v * v for v in bloco) / max(1, len(bloco)))


def aparar(a, inicio, fim):
    bloco = int(0.005 * TAXA)
    altos = [i for i in range(inicio, fim, bloco) if db(rms(a, i, bloco)) > LIMIAR_DO_FIM]
    comeco = next(i for i in range(inicio, fim, bloco) if db(rms(a, i, bloco)) > LIMIAR_DO_COMECO)
    return max(inicio, comeco - int(ANTES * TAXA)), min(fim, altos[-1] + bloco + int(DEPOIS * TAXA))


def ganho(miado):
    janela = int(0.05 * TAXA)
    mais_forte = max(rms(miado, i, janela) for i in range(0, max(1, len(miado) - janela), 240))
    pico = max(abs(v) for v in miado)
    return min(ALVO - db(mais_forte), PICO_MAXIMO - db(pico))


def gravar(miado, caminho):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(TAXA), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "6", caminho], input=miado.tobytes(), check=True)


def main(origem):
    a = ler(origem)
    os.makedirs(PASTA, exist_ok=True)
    for numero, (inicio, fim) in enumerate(trechos(a), start=1):
        comeco, final = aparar(a, inicio, fim)
        if numero in SO_ATE:
            final = min(final, comeco + int(SO_ATE[numero] * TAXA))
        miado = a[comeco:final]
        g = ganho(miado)
        fator = 10 ** (g / 20)
        n = len(miado)
        entrada, saida = int(FADE_DE_ENTRADA * TAXA), int(FADE_DE_SAIDA * TAXA)
        for i in range(n):
            f = fator * min(1.0, i / entrada, (n - 1 - i) / saida)
            miado[i] *= f
        caminho = os.path.join(PASTA, "miado_%d.ogg" % numero)
        gravar(miado, caminho)
        print("miado_%d.ogg  origem %6.3f-%6.3f s  duração %.2f s  ganho %+5.1f dB" % (
            numero, comeco / TAXA, final / TAXA, n / TAXA, g))


if __name__ == "__main__":
    main(os.path.expanduser(sys.argv[1]) if len(sys.argv) > 1 else ORIGEM)
