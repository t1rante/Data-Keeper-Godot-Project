extends RefCounted
## Estado do jogo que atravessa as cenas e vai para o save (saves.gd): o dia, a
## hora (manhã antes do trabalho, noite depois), o dinheiro, as fases feitas, as
## compras da loja do computador e o gatinho. Fica em variáveis estáticas, então
## vale em qualquer cena sem precisar de autoload. Só regras aqui; quem troca de
## cena e salva é fluxo.gd.
##
## Um dia: acorda em casa (manhã) -> vai trabalhar -> conversa com os colegas e
## com o cliente -> monta o diagrama -> entrega e recebe -> volta para casa
## (noite) -> dorme.

const Fases = preload("res://Script/jogo/fases.gd")
const Catalogo = preload("res://Script/jogo/catalogo.gd")

const MANHA := "manha"
const NOITE := "noite"
## Nome nos diálogos quando o jogador ainda não escolheu um (save antigo, quadro no editor).
const NOME_PADRAO := "Novato"
const TAMANHO_DO_NOME := 16

## Arquivo de save em uso (1 a 4; 0 = nenhum, como ao abrir o quadro direto no editor).
static var slot := 0
## Como o protagonista é chamado nos diálogos (escolhido no NOVO JOGO).
static var nome := ""
static var dia := 1
static var momento := MANHA
## Dinheiro em centavos (inteiro, sem erro de arredondamento). Mostre com reais().
static var centavos := 0
## Fases entregues: id -> {"nota", "pago" (centavos), "dia"}.
static var fases_feitas := {}
## Fase em andamento ("" fora do trabalho).
static var fase_atual := ""
## Diagrama do quadro em andamento (para o save no meio da fase).
static var diagrama := {}
## O que foi dito na conversa com o cliente do dia, na ordem, só o que o jogador
## viu (com as escolhas dele): [{"quem", "cor", "texto", "escolha"}]. É o log
## da conversa no quadro (dialogos.gd grava, log_da_conversa.gd mostra).
static var conversa := []
## O quadro começa o tutorial da fase (não vai para o save: um save no meio do
## quadro não repete o tutorial).
static var tutorial_pendente := false
## Itens da loja do computador que o jogador tem, e o equipado em cada lugar.
static var compras := []
static var equipados := {}  # lugar -> id
static var carinhos := 0
static var carinho_hoje := false


## Volta tudo ao começo de um jogo novo no arquivo `numero`.
static func novo_jogo(numero: int, nome_escolhido := "") -> void:
	slot = numero
	nome = limpar_nome(nome_escolhido)
	dia = 1
	momento = MANHA
	centavos = 0
	fases_feitas = {}
	fase_atual = ""
	diagrama = {}
	conversa = []
	tutorial_pendente = false
	compras = []
	equipados = {}
	carinhos = 0
	carinho_hoje = false
	for item in Catalogo.itens():
		if item.preco <= 0:
			compras.append(item.id)
			equipados[item.lugar] = item.id


# --- Dia ----------------------------------------------------------------------

## Fase do dia: o primeiro cliente ainda não atendido ("" se acabaram).
static func fase_do_dia() -> String:
	for id in Fases.ORDEM:
		if not fases_feitas.has(id):
			return id
	return ""


static func pode_trabalhar() -> bool:
	return momento == MANHA and fase_do_dia() != ""


## À noite, ou a qualquer hora quando não há mais clientes.
static func pode_dormir() -> bool:
	return momento == NOITE or fase_do_dia() == ""


static func dormir() -> void:
	dia += 1
	momento = MANHA
	carinho_hoje = false


## Quanto o cliente paga por um diagrama com essa nota (a fração do pagamento).
static func pagamento(id_da_fase: String, porcentagem: float) -> int:
	var cheio: float = Fases.dados(id_da_fase).pagamento
	return int(round(cheio * clampf(porcentagem, 0.0, 100.0)))  # reais * 100 * nota / 100


## Entrega a fase em andamento: recebe, marca como feita e vira noite. Devolve o pago.
static func concluir_fase(porcentagem: float) -> int:
	var id := fase_atual if fase_atual != "" else fase_do_dia()
	var pago := pagamento(id, porcentagem)
	centavos += pago
	fases_feitas[id] = {"nota": snappedf(porcentagem, 0.1), "pago": pago, "dia": dia}
	fase_atual = ""
	diagrama = {}
	momento = NOITE
	return pago


## Carinho no gatinho. Devolve true se foi o primeiro do dia.
static func fazer_carinho() -> bool:
	carinhos += 1
	var primeiro := not carinho_hoje
	carinho_hoje = true
	return primeiro


# --- Loja do computador -------------------------------------------------------

static func tem(id: String) -> bool:
	return id in compras


## Compra e já equipa. Devolve "" ou o motivo de não dar.
static func comprar(id: String) -> String:
	var item := Catalogo.item(id)
	if item.is_empty():
		return "Esse item não existe."
	if tem(id):
		return "Você já tem esse item."
	var preco := int(round(item.preco * 100))
	if preco > centavos:
		return "Falta %s." % reais(preco - centavos)
	centavos -= preco
	compras.append(id)
	equipar(id)
	return ""


static func equipar(id: String) -> void:
	var item := Catalogo.item(id)
	if tem(id) and not item.is_empty():
		equipados[item.lugar] = id


## Tira o item do lugar (a skin não sai: sempre há uma roupa).
static func guardar(id: String) -> void:
	var item := Catalogo.item(id)
	if not item.is_empty() and item.tipo != "skin" and equipados.get(item.lugar) == id:
		equipados.erase(item.lugar)


static func equipado(id: String) -> bool:
	var item := Catalogo.item(id)
	return not item.is_empty() and equipados.get(item.lugar) == id


# --- Dinheiro -----------------------------------------------------------------

## 123450 -> "R$ 1.234,50".
static func reais(valor_em_centavos: int) -> String:
	var negativo := valor_em_centavos < 0
	var resto := absi(valor_em_centavos)
	var inteiro := str(resto / 100)
	var milhares := ""
	while inteiro.length() > 3:
		milhares = "." + inteiro.right(3) + milhares
		inteiro = inteiro.left(inteiro.length() - 3)
	return "%sR$ %s%s,%02d" % ["-" if negativo else "", inteiro, milhares, resto % 100]


# --- Save ---------------------------------------------------------------------

static func para_o_save() -> Dictionary:
	return {
		"nome": nome, "dia": dia, "momento": momento, "centavos": centavos,
		"fases_feitas": fases_feitas, "fase_atual": fase_atual, "diagrama": diagrama,
		"conversa": conversa,
		"compras": compras, "equipados": equipados,
		"carinhos": carinhos, "carinho_hoje": carinho_hoje,
	}


static func do_save(dados: Dictionary, numero: int) -> void:
	novo_jogo(numero, str(dados.get("nome", "")))
	dia = int(dados.get("dia", 1))
	momento = str(dados.get("momento", MANHA))
	centavos = int(dados.get("centavos", 0))
	fases_feitas = dados.get("fases_feitas", {}) if dados.get("fases_feitas") is Dictionary else {}
	fase_atual = str(dados.get("fase_atual", ""))
	diagrama = dados.get("diagrama", {}) if dados.get("diagrama") is Dictionary else {}
	if dados.get("conversa") is Array:
		conversa = dados.conversa.filter(func(fala): return fala is Dictionary)
	if dados.get("compras") is Array:
		compras = dados.compras.map(func(id): return str(id))
	if dados.get("equipados") is Dictionary:
		equipados = dados.equipados
	carinhos = int(dados.get("carinhos", 0))
	carinho_hoje = dados.get("carinho_hoje", false) == true


# --- Nome ---------------------------------------------------------------------

## O nome digitado, pronto para os diálogos: sem espaços sobrando, sem os
## caracteres que o Dialogic leria como variável ou formatação ({ } [ ]) e com
## no máximo TAMANHO_DO_NOME letras.
static func limpar_nome(texto: String) -> String:
	var limpo := ""
	for letra in texto.strip_edges():
		if not letra in "{}[]\\\n\t":
			limpo += letra
	while "  " in limpo:
		limpo = limpo.replace("  ", " ")
	return limpo.strip_edges().left(TAMANHO_DO_NOME)


## O nome que aparece nos diálogos (o padrão quando não há um).
static func nome_nos_dialogos() -> String:
	return nome if nome != "" else NOME_PADRAO
