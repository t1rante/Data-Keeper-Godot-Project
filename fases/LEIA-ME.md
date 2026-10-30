# Fases

Cada fase é um cliente: num dia de trabalho, o protagonista sai de casa,
encontra o Bruno (o supervisor) e a Ana (a colega) no escritório, conversa com o
cliente do dia, monta o diagrama ER no quadro (no dia 1 com o tutorial da Ana) e
entrega. A ordem
dos dias está em `ORDEM`, em `Script/jogo/fases.gd`: no dia 1 vem a loja de
roupas, no dia 2 a biblioteca e no dia 3 a clínica. Quando as fases acabam, a
casa avisa que não há cliente novo.

## O que tem em cada pasta

| Arquivo | O que é | Guia |
|---|---|---|
| `fase.json` | nome da fase, quem é o cliente e quanto ele paga | abaixo |
| `conversa.dtl` | a conversa com o cliente, com o menu de perguntas (timeline do Dialogic) | `COMO_ESCREVER_CONVERSAS.md` |
| `gabarito.json` | a resposta certa, com as alternativas aceitas | `COMO_ESCREVER_GABARITOS.md` |
| `palavras.json` | o banco de palavras que o jogador arrasta para os blocos | `COMO_CRIAR_BANCOS_DE_PALAVRAS.md` |
| `escritorio.dtl` (opcional) | o momento com o Bruno e a Ana antes do cliente | `COMO_ESCREVER_CONVERSAS.md` |
| `tutorial.dtl` (opcional) | as explicações da Ana no quadro, depois da conversa | `COMO_ESCREVER_CONVERSAS.md` |

`_exemplos/` guarda gabaritos que não são fase do jogo: o `exemplo_completo.json`
(usa todos os recursos do gabarito e serve de referência) e gabaritos antigos
(brigadeiros, biblioteca com estantes, desafio do aluno). Os testes usam alguns
deles.

## fase.json

```json
{
	"nome": "Loja de roupas",
	"cliente": "a dona da loja de roupas",
	"pagamento": 120
}
```

| Chave | Onde aparece |
|---|---|
| `nome` | tela de verificação, descrição dos saves ("Entregou: Loja de roupas") |
| `cliente` | dica da casa ("Hoje a dona da loja de roupas precisa de um banco de dados") e save "Antes de falar com …"; escreva com o artigo |
| `pagamento` | reais que o cliente paga por um diagrama 100% certo; nota menor recebe a mesma fração (94,7% de R$ 120 = R$ 113,64) |

## Fase nova, passo a passo

1. Crie a pasta `fases/<nome_da_fase>/` (minúsculas, sem acento nem espaço).
2. Escreva a conversa no editor do Dialogic (ou como texto) e salve como
   `conversa.dtl` dentro dela, com o menu de perguntas de
   `COMO_ESCREVER_CONVERSAS.md`. Os personagens ficam em `Timeline/Character/`.
   Se quiser, escreva também o `escritorio.dtl` e o `tutorial.dtl`.
3. Escreva o `gabarito.json` e o `palavras.json` pelos guias desta pasta.
4. Escreva o `fase.json`.
5. Ponha o nome da pasta em `ORDEM` (`Script/jogo/fases.gd`), na posição do dia
   em que o cliente deve aparecer.
6. Rode os testes. Eles conferem se toda pasta de fase está em `ORDEM`, se os
   quatro arquivos existem, se a conversa tem falas e escolhas que funcionam, se
   o escritório e o tutorial estão no formato e se o banco de palavras resolve o
   gabarito:

   ```sh
   ../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://testes/teste_verificador.gd
   ```

Para testar o quadro de uma fase sem jogar o dia inteiro, abra
`Cenas/quadro/quadro.tscn`, preencha `fase` no Inspetor do nó raiz e aperte F6.
