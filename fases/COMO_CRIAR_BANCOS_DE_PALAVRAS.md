# Como criar um banco de palavras

No quadro, o jogador não digita nomes. Ele abre o menu **Palavras** (a aba logo
abaixo da aba dos post-its) e arrasta uma palavra até um bloco. As palavras de
cada fase ficam no `palavras.json` da pasta dela, junto com a conversa e o
gabarito (ver `LEIA-ME.md` nesta pasta). Já existem os bancos da loja de roupas,
da biblioteca e da clínica.

| Arquivo da fase | O que é |
|---|---|
| `fases/<fase>/conversa.dtl` | a conversa com o cliente (Dialogic) |
| `fases/<fase>/gabarito.json` | a resposta certa (ver `COMO_ESCREVER_GABARITOS.md`) |
| `fases/<fase>/palavras.json` | as palavras que o jogador pode usar (este guia) |

## Formato

```json
{
  "problema": "Loja de roupas",
  "descricao": "Para quem for editar: de onde vêm as palavras.",
  "ordem": "alfabetica",
  "palavras": ["cliente", "pedido", "produto", "faz", "contém", "tamanho", "cor", "preço"],
  "extras": ["nome", "CPF", "data"],
  "distratores": ["loja", "vendedor", "vitrine", { "texto": "caixa", "usos": 1 }]
}
```

| Chave | Obrigatória | O que faz |
|---|---|---|
| `palavras` | sim | nomes que resolvem o problema; precisam cobrir o gabarito |
| `extras` | não | nomes plausíveis que o gabarito não exige; usar não desconta |
| `distratores` | não | nomes errados de propósito; usar desconta |
| `ordem` | não | `"alfabetica"` (padrão), `"embaralhada"` ou `"arquivo"` |

- No jogo, as três listas aparecem misturadas: o jogador não sabe qual palavra é
  de qual lista. A separação serve para quem escreve o banco e para o teste.
- Cada palavra é um texto (`"cliente"`) ou um objeto com limite de usos
  (`{"texto": "caixa", "usos": 1}`). Sem limite, a mesma palavra pode nomear
  quantos blocos o jogador quiser. Isso é necessário para nomes que se repetem,
  como o atributo `nome` em várias entidades ou dois relacionamentos `possui`.
  Quando o limite acaba, a ficha fica apagada e não arrasta mais.
- A ficha de uma palavra que já está no quadro ganha uma faixa ciana à esquerda.
- Escreva a palavra exatamente como no gabarito ("preço", "item do pedido"). O
  verificador compara o texto exato, com as mesmas letras, acentos e maiúsculas:
  "Preço" ou "preco" no banco não batem com "preço" no gabarito. O teste acusa
  essa diferença.
- Sem arquivo de banco, o jogo avisa no console e usa os nomes que o gabarito
  exige, sem distratores. Dá para jogar, mas fica fácil demais.

## Passo a passo

1. **Leia a conversa** (`conversa.dtl` da fase) e marque o que o cliente fala:
   - **substantivos** que viram coisas a guardar (cliente, pedido, produto): entidades;
   - **características** dessas coisas (tamanho, cor, preço): atributos;
   - **verbos** que ligam duas coisas (faz, contém): relacionamentos.
2. **Copie os nomes do gabarito para `palavras`:**
   - todas as entidades e todos os atributos que não são `opcional`;
   - os relacionamentos que não têm `nomeLivre`;
   - o rótulo das especializações que têm `nome`.

   Use o nome principal de cada item, que é o que as mensagens da correção mostram
   ("arraste a palavra 'cliente'"). Um sinônimo do gabarito pode entrar também, se
   for outra palavra igualmente certa. Se o gabarito tem
   `alternativas`, ponha também as palavras delas (na loja, "item do pedido",
   "tem" e "refere-se"); o teste não cobra, mas sem elas o jogador não consegue
   montar a alternativa. Relacionamento com `nomeLivre` aceita qualquer nome, mas
   ponha alguns verbos para o jogador não deixar o losango vazio.
3. **Coloque em `extras`** o que é razoável modelar, mas o cliente não pediu:
   identificadores ("código", "CPF") e dados comuns ("nome", "data"). O verificador
   só avisa quando o jogador usa um desses.
4. **Coloque em `distratores`** os erros que você quer que o aluno aprenda a evitar.
   Bons tipos:
   - **O próprio negócio** (`loja`, `biblioteca`, `clínica`): o erro clássico é
	 criar uma entidade para o dono do sistema.
   - **Objetos do cenário que ninguém registra** (`vitrine`, `sacola`, `balcão`).
   - **Pessoas e processos que a conversa não cita** (`vendedor`, `fornecedor`,
	 `pagamento`).
   - **Armadilhas de tipo:** uma palavra que parece entidade mas é atributo, ou o
	 contrário. Essas ficam em `palavras` se forem resposta. Quem desconta, nesse
	 caso, é o verificador ("'cor' foi desenhado como entidade, mas é atributo").

   Um distrator não pode ser resposta: nem do modelo principal, nem de uma
   alternativa, nem sinônimo de uma resposta. Se for, o jogador que o usa é
   corrigido como certo. O teste acusa esse caso.
5. **Tamanho:** de 15 a 30 palavras cabem no menu sem rolar muito. Uma proporção
   que funciona é 1 distrator para cada 2 ou 3 palavras certas.
6. **A fase precisa estar na ordem dos dias** (`ORDEM` em `Script/jogo/fases.gd`;
   ver `LEIA-ME.md`).
7. **Rode os testes** (abaixo). Eles conferem, para o banco de cada fase:
   - se o arquivo carrega e o gabarito da mesma pasta existe;
   - se há palavra para cada nome que o gabarito exige (a falha diz qual falta:
	 `banco x.json tem palavra para atributos 'cor'`);
   - se nenhum distrator é resposta do gabarito.

## Exemplo: a loja de roupas

Na conversa, o cliente diz: "Tenho vários produtos, cada um com tamanho, cor e
preço. Também preciso registrar clientes, pedidos e quais produtos foram
vendidos." No `fases/loja_de_roupa/palavras.json`, isso vira:

- **palavras** (resposta): cliente, pedido, produto, faz, contém, tamanho, cor e
  preço; mais "item do pedido", "tem" e "refere-se", da resposta alternativa com
  entidade associativa;
- **extras**: nome, CPF, data, quantidade e código. Fazem sentido, mas o cliente
  não pediu;
- **distratores**: loja (o próprio negócio); vitrine, sacola e caixa (objetos do
  cenário); vendedor, fornecedor e pagamento (fora da conversa).

## Rodar os testes

Na pasta do projeto:

```sh
../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://testes/teste_verificador.gd
```
