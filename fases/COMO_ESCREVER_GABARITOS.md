# Como escrever gabaritos

O botão **Verificar** compara o quadro do jogador com um gabarito JSON desta pasta
(o `gabarito.json` da fase do dia, em `fases/<fase>/`), dá a nota e explica cada ponto
que faltou para 100%. O código fica em dois arquivos:

| Arquivo | Papel |
|---|---|
| `Script/correcao/verificador.gd` | pesos, regras, escolha entre alternativas, texto do relatório |
| `Script/correcao/correcao_do_diagrama.gd` | casa os blocos do jogador com o gabarito e pontua |

`fases/_exemplos/exemplo_completo.json` usa todos os recursos abaixo. Os testes ficam em
`testes/teste_verificador.gd`.

O jogador não digita nomes: ele arrasta palavras do banco de palavras da fase
(`fases/<fase>/palavras.json`, ver `COMO_CRIAR_BANCOS_DE_PALAVRAS.md`). Todo
nome que este gabarito exige precisa estar no banco, e os testes conferem isso.

## Estrutura

```json
{
  "diagrama": { "nome": "...", "entidades": [], "relacionamentos": [], "especializacoes": [], "agregacoes": [] },
  "alternativas": [ { "nome": "...", "entidades": [], "relacionamentos": [] } ],
  "correcao": { "pesos": { "cardinalidade": 2 }, "atributosExtras": "penalizar" }
}
```

Só `diagrama` é obrigatório.

### Entidade

```json
{ "nome": "dependente", "sinonimos": ["filho"], "fraca": true,
  "atributos": [ ... ], "atributosCompletos": false }
```

- `sinonimos`: outras palavras do banco que também valem ("venda" para `pedido`).
  A comparação é exata, porque o nome vem arrastado do banco de palavras: `clientes`,
  `Cliente` e `clinte` não batem com `cliente`. Não ponha plural nem variação de
  escrita como sinônimo; ponha só palavras diferentes que sejam igualmente certas.
  **Palavras do banco com o mesmo sentido valem o mesmo:** se um relacionamento aceita
  "tem", aceita também "possui" (e "faz"/"realiza", "contém"/"inclui",
  "empréstimo"/"empresta"), quando as duas estão no banco da fase. Senão, trocar uma
  pela outra tira o ponto do nome (1 de uns 20 a 25 pontos). O teste confere esses grupos
  (`MESMO_SENTIDO` em `testes/teste_verificador.gd`); grupo novo, acrescente lá.
- `fraca`: o jogador precisa marcar a entidade como fraca (tecla F).
- `atributosCompletos`: `true` faz atributo a mais nessa entidade descontar. Por
  padrão só gera uma observação.

### Atributo

```json
{ "nome": "endereço", "chavePrimaria": false, "derivado": false, "multivalorado": false,
  "opcional": false, "componentes": [ { "nome": "rua" }, { "nome": "cidade" } ] }
```

- Marcações (`chavePrimaria`, `derivado`, `multivalorado`): `true` = o jogador
  precisa marcar; `false` ou ausente = marcar desconta; `"opcional"` = tanto faz.
- `opcional: true`: atributo aceito, mas não exigido (não vale ponto nem vira "a mais").
- `componentes`: atributo composto. Os componentes ficam ligados ao atributo, não à entidade.

### Relacionamento

```json
{ "id": "R1", "nome": "possui", "sinonimos": ["tem"], "nomeLivre": false, "identificador": true,
  "entidadeOrigem": { "nome": "funcionário", "cardinalidade": "1" },
  "entidadeDestino": { "nome": "dependente", "cardinalidade": "N" },
  "atributosRelacionamento": [ { "nome": "desde" } ] }
```

- `cardinalidade` é o número escrito **na linha perto daquela entidade**: em
  `cliente 1 —faz— N pedido`, o cliente tem 1 e o pedido tem N. `N` e `M` valem o
  mesmo ("muitos"). Também aceita `(0,1)`, `(1,N)` e `1..*`; conta o máximo.
- `participantes` no lugar de origem/destino serve para relacionamento ternário
  ou ligado a uma agregação: `[{"nome": "a", "cardinalidade": "N"}, ...]`.
- `nomeLivre: true`: qualquer nome serve; só ligações e cardinalidades contam.
- `identificador`: liga a entidade fraca à dona (tecla F no losango).
- Entidade citada aqui que não estiver em `entidades` entra no modelo sozinha.

### Especialização e agregação

```json
{ "entidadePai": { "nome": "funcionário" },
  "entidadesFilhas": [ { "nome": "engenheiro" }, { "nome": "secretário" } ],
  "nome": "d" }
{ "nome": "Alocação", "relacionamento": "R2" }
```

- Especialização: o triângulo precisa estar ligado ao pai e a cada filha. `nome`
  é opcional e, se existir, é o que deve estar escrito no triângulo (ex.: `d`/`o`, `t`/`p`).
- Agregação: `relacionamento` é o nome ou o `id` do relacionamento que ela envolve.
  Outros relacionamentos se ligam à agregação pelo nome dela em `participantes`.

### Alternativas

Cada item de `alternativas` é um diagrama completo, igualmente certo. O jogador
fica com a melhor nota entre o principal e as alternativas. A loja de roupas usa
isso para aceitar o N:M `pedido—produto` como a entidade associativa "item do pedido".

## Como a nota é calculada

1. **Casamento.** Cada item do gabarito é associado a um bloco do quadro:
   - **Entidade:** pelo nome exato (ou um dos sinônimos).
	 A que não bate pelo nome casa pelo **papel**, se tiver os mesmos atributos e
	 ligações (a palavra "vendedor" no lugar de "cliente"). Nesse caso perde só o ponto do nome.
   - **Relacionamento:** pelas entidades que ele liga; o nome só desempata. Três
	 "possui" no mesmo modelo não se confundem.
   - **Atributo:** pelo nome dentro do dono certo. Se não estiver ali, pelo nome em
	 qualquer lugar do quadro, e então vale metade ("está ligado a X, mas é atributo de Y").
2. **Pontos** (`PESOS_PADRAO` em `verificador.gd`):

   | Item | Pontos |
   |---|---|
   | entidade | 2 |
   | atributo | 1 |
   | nome do relacionamento | 1 |
   | ligação do relacionamento com cada entidade | 1 |
   | cardinalidade de cada ponta | 1 |
   | cada marcação exigida (chave, derivado, multivalorado, fraca, identificador) | 1 |
   | cada ligação da especialização | 1 |
   | agregação | 1 |
   | ligação da agregação com o relacionamento envolvido | 1 |

3. **Penalidades** (1 ponto cada) entram no total possível:
   - bloco a mais;
   - ligação com entidade que não participa do relacionamento;
   - marcação indevida;
   - ligação que a notação proíbe: entidade—entidade, relacionamento—relacionamento,
	 especialização com algo que não é entidade, atributo solto ou com dois donos.
4. **Nota** = pontos obtidos ÷ (pontos possíveis + penalidades).

O relatório mostra quanto cada problema tirou da nota, e a soma dessas linhas é
exatamente o que falta para 100%. Atributos a mais e entidade sem chave aparecem
em "Observações" e não descontam.

Quando um item falta, o relatório procura a causa provável:
- **Tipo trocado:** "'cor' foi desenhado como entidade, mas é atributo".
- **Entidades ligadas direto:** "Você ligou 'cliente' direto em 'pedido'".
- **Cardinalidades invertidas:** uma mensagem só, com a regra de leitura.
- **Componente fora do lugar:** "Componente do atributo composto ligado à entidade".
- **Atributos em cadeia:** "'cor' está ligado ao atributo 'tamanho'. Ligar um atributo em
  outro quer dizer que ele é parte de um atributo composto; ligue 'cor' direto à entidade
  'produto'". Vale metade, como qualquer atributo fora do lugar.

Nesses casos o erro é punido uma vez só.

## Ajustes por gabarito

```json
"correcao": {
  "pesos": { "entidade": 3, "cardinalidade": 2, "extra": 0.5 },
  "limiarPapel": 0.5,
  "creditoPorPapel": 0.5,
  "creditoForaDoLugar": 0.5,
  "atributosExtras": "avisar"
}
```

| Chave | O que faz |
|---|---|
| `limiarPapel` | fração de atributos/ligações iguais para casar uma entidade pelo papel |
| `creditoPorPapel` | quanto vale a entidade certa com nome errado (0 a 1) |
| `creditoForaDoLugar` | quanto vale o atributo certo no dono errado (0 a 1) |
| `atributosExtras` | `"avisar"` (padrão) ou `"penalizar"` para o gabarito inteiro |

## Rodar os testes

Na pasta do projeto:

```sh
../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://testes/teste_verificador.gd
# imprime o relatório de alguns casos:
../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://testes/teste_verificador.gd -- --mostrar
```
