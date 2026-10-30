extends RefCounted
## Fases do jogo: um cliente por dia, na ordem de ORDEM. Cada fase é uma pasta
## em fases/ com os mesmos quatro arquivos (ver fases/LEIA-ME.md):
##   fase.json ....... nome, quem é o cliente e quanto ele paga (R$ por 100%)
##   conversa.dtl .... a conversa com o cliente (timeline do Dialogic)
##   gabarito.json ... a resposta certa (fases/COMO_ESCREVER_GABARITOS.md)
##   palavras.json ... o banco de palavras (fases/COMO_CRIAR_BANCOS_DE_PALAVRAS.md)
## Opcionais:
##   escritorio.dtl .. o momento com o Bruno e a Ana antes do cliente
##   tutorial.dtl .... as explicações da Ana no quadro (tutorial_do_quadro.gd)
## Fase nova: a pasta e o nome dela em ORDEM. Os testes conferem os arquivos.

const PASTA := "res://fases/"
## Ordem dos dias: no dia 1 vem o primeiro cliente, e assim por diante.
const ORDEM := ["loja_de_roupa", "biblioteca", "clinica"]


static func existe(id: String) -> bool:
	return id in ORDEM


## Tudo de uma fase: {"id", "nome", "cliente", "pagamento", "conversa",
## "gabarito", "palavras", "escritorio", "tutorial"}. Fase desconhecida vira a
## primeira. "escritorio" e "tutorial" são opcionais: "" se a pasta não tem.
static func dados(id: String) -> Dictionary:
	if not existe(id):
		id = ORDEM[0]
	var pasta := PASTA + id + "/"
	var info = JSON.parse_string(FileAccess.get_file_as_string(pasta + "fase.json")) \
			if FileAccess.file_exists(pasta + "fase.json") else null
	if not info is Dictionary:
		info = {}
	return {
		"id": id,
		"nome": str(info.get("nome", id)),
		"cliente": str(info.get("cliente", "o cliente")),
		"pagamento": float(info.get("pagamento", 100.0)),
		"conversa": pasta + "conversa.dtl",
		"gabarito": pasta + "gabarito.json",
		"palavras": pasta + "palavras.json",
		"escritorio": _se_existir(pasta + "escritorio.dtl"),
		"tutorial": _se_existir(pasta + "tutorial.dtl"),
	}


static func _se_existir(caminho: String) -> String:
	return caminho if FileAccess.file_exists(caminho) else ""
