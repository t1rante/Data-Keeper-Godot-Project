# Como escrever as conversas

Cada dia de trabalho tem três conversas, todas no formato do Dialogic (`.dtl`), na pasta da fase:

| Arquivo | Quando aparece | Quem fala |
|---|---|---|
| `escritorio.dtl` (opcional) | ao chegar no escritório, antes do cliente | o Bruno, a Ana e o jogador |
| `conversa.dtl` | logo depois, emendada no escritório | o cliente e o jogador, com escolhas |
| `tutorial.dtl` (opcional) | no quadro, depois da conversa | a Ana, explicando a parte técnica |

Os arquivos abrem no editor do Dialogic (aba **Dialogic** no topo do Godot) ou como texto. Este guia mostra o
formato em texto, que é o mais fácil de copiar.

## O básico

```
[background arg="res://Sprites/Fundo/Escritorio_dentro2.png" fade="0.0"]
join Player leftmost
join Loja_de_roupa rightmost
Loja_de_roupa: Oi, tudo bem? Você que é o {nome}?
Player: Sou eu! Como posso ajudar?
leave Loja_de_roupa
```

- **Fala:** `Quem: texto`. `Quem` é o identificador do personagem, em `Timeline/Character/`: `Player`, `Bruno`,
  `Ana`, `Loja_de_roupa`, `Bibliotecario`, `Médico`.
- **`{nome}`** vira o nome que o jogador escolheu no NOVO JOGO. Também é o nome que aparece acima das falas do
  `Player`.
- **Entrar e sair da tela:** `join Personagem posição` e `leave Personagem`. As posições são `leftmost`, `left`,
  `center`, `right` e `rightmost`. A caixa de texto cobre o meio da tela, então use as pontas: com o cliente,
  `Player` em `leftmost` e o cliente em `rightmost`; no escritório, o Bruno em `leftmost` e a Ana em
  `rightmost` (o jogador fala sem retrato).

## Escolhas

Uma linha que começa com `- ` é uma escolha do jogador. Ela aparece logo depois de uma fala (ou de um `label`).
O que acontece se ele escolher vai embaixo, recuado com **um Tab**:

```
Ana: Quer café? É preto, igual à minha alma.
- Aceito, puro mesmo.
	Ana: Hm. Talvez você sobreviva aqui.
- Tem com leite?
	Ana: Tem. Na padaria da esquina.
Bruno: Ó, papo reto antes do cliente chegar.
```

Depois do ramo escolhido, a conversa segue na primeira linha sem recuo.

## O menu de perguntas (a conversa com o cliente)

O cliente não fala tudo de uma vez: o jogador precisa perguntar. Se ele seguir sem perguntar, fica sem a
informação e monta o diagrama com o que tiver (a nota vem do gabarito inteiro). O formato é um menu que volta
depois de cada resposta, sem a pergunta que já foi feita, até o jogador escolher seguir:

```
Loja_de_roupa: Preciso de um sistema para registrar os meus clientes e exatamente quais produtos eles compraram!
label perguntas_da_loja
- Os clientes precisam entrar com e-mail na plataforma de vocês? | [if {perguntou.p1} == false]
	set {perguntou.p1} = true
	Loja_de_roupa: E-mail? Não, não! ... eu anoto o pedido e pronto.
	jump perguntas_da_loja
- Os clientes podem comprar mais de um produto por vez? | [if {perguntou.p2} == false]
	set {perguntou.p2} = true
	Loja_de_roupa: Claro! ... E o mesmo produto aparece em um monte de pedidos diferentes.
	jump perguntas_da_loja
- Certo, prossiga.
Loja_de_roupa: Também é importante a gente ter guardado qual tamanho de produto ele comprou!
```

Peça por peça:

- `label perguntas_da_loja` marca o lugar do menu; `jump perguntas_da_loja` volta para ele.
- `| [if {perguntou.p1} == false]` só mostra a pergunta enquanto ela não foi feita.
- `set {perguntou.p1} = true` marca a pergunta como feita.
- A última escolha, sem condição, é a que segue a conversa ("Certo, prossiga.").

Regras:

- **Há 8 marcas por conversa: `{perguntou.p1}` a `{perguntou.p8}`.** Elas voltam a `false` no começo de cada
  conversa (`Script/jogo/dialogos.gd`), então cada conversa pode usar todas. Use uma marca diferente para cada
  pergunta da mesma conversa.
- **Os `label` precisam ter nomes diferentes** no `escritorio.dtl` e no `conversa.dtl` do mesmo dia, porque os
  dois viram uma conversa só. Ponha o nome da fase no rótulo: `perguntas_da_loja`, `mais_da_loja`.
- **Cada informação que o gabarito exige precisa sair de alguma fala**, do cliente ou de uma resposta. Quem
  pergunta tudo consegue a nota máxima; quem pula perguntas perde exatamente o que elas contariam.
- **A resposta não pode trazer coisa que o gabarito não tem,** senão o jogador põe no diagrama e perde ponto
  por "a mais". Se a informação é boa, mas não é obrigatória, ponha no gabarito com `"opcional": true` ou no
  banco como `extras`.
- Escreva as perguntas como alguém de banco de dados perguntaria, e as respostas como o cliente falaria: ele não
  programa.

## O log da conversa

A aba "Conversa" do quadro mostra só o que o jogador viu, na ordem, com as escolhas dele em itálico. Pergunta
que ele não fez não aparece. O escritório não entra no log: ele começa quando o cliente começa
(`Script/jogo/dialogos.gd`). O log vai para o save.

Com o quadro aberto direto no editor (F6), não houve conversa: aí o log mostra o arquivo inteiro, com todos os
ramos, para quem está testando.

## O tutorial da Ana (`tutorial.dtl`)

São falas da Ana divididas em passos. Cada linha `# espera:` para as falas e espera o jogador fazer algo no
quadro:

```
Ana: Abre a primeira aba da direita, a dos post-its. O azul é a Entidade.
Ana: Clica no post-it azul. Vai, eu espero.
# espera: bloco_criado entidade
Ana: Agora dá um nome pra ele. Segunda aba, o banco de palavras.
# espera: bloco_nomeado entidade
Ana: Quando terminar, aperta Verificar.
```

| Espera | Libera quando o jogador… |
|---|---|
| `bloco_criado [tipo]` | cria um bloco (desse tipo) |
| `bloco_nomeado [tipo]` | dá nome a um bloco (desse tipo) |
| `blocos_ligados [tipo]` | liga dois blocos (um deles desse tipo) |
| `verificado` | aperta Verificar |

O tipo é opcional: `entidade`, `relacionamento`, `atributo`, `especializacao` ou `agregacao`. As falas depois
da última espera encerram o tutorial. Sem nenhuma espera, a Ana fala tudo de uma vez assim que a conversa com o
cliente acaba (os tutoriais dos dias 2 e 3 são assim). Linhas que começam com `#` sem ser `# espera:` são
comentários. Não use `join`: a Ana fala sem retrato, para a planta continuar à mostra.

A Ana explica o conceito; ela não conta o que o cliente disse. Senão as perguntas perdem a graça.

## Conferir

Rode o teste da correção. Ele confere, para cada fase: escritório com o Bruno e a Ana, escolhas na conversa,
todo `jump` indo para um `label` que existe, `label` sem repetir, pergunta marcada com `set` sumindo do menu,
marcas entre `p1` e `p8` e as esperas do tutorial:

```sh
../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://testes/teste_verificador.gd
```

Depois jogue o dia (F5): o roteiro `testes/roteiro_do_dia.gd` faz isso sozinho para o dia 1, perguntando tudo.
