extends RefCounted
## Arquivos de save: até QUANTOS, em user://saves/arquivo_N.json. O jogo salva
## sozinho nos savepoints (fluxo.gd) e quando o jogador salva pelo menu de opções:
##   inicio_do_dia ..... acordou em casa
##   antes_do_cliente .. chegou ao trabalho, logo antes da conversa
##   fim_da_fase ....... entregou o diagrama ao cliente
##   manual ............ menu de opções > Salvar
## Cada save guarda onde retomar ("lugar": home, cliente ou quadro), um texto
## para a tela de escolha de arquivo e o estado do jogo (jogo.gd).

const Jogo = preload("res://Script/jogo/jogo.gd")
const Fases = preload("res://Script/jogo/fases.gd")
const ArquivoJson = preload("res://Script/jogo/arquivo_json.gd")

const PASTA := "user://saves/"
const QUANTOS := 4
const VERSAO := 1
const LUGARES := ["home", "cliente", "quadro"]


static func caminho(numero: int) -> String:
	return PASTA + "arquivo_%d.json" % numero


static func existe(numero: int) -> bool:
	return FileAccess.file_exists(caminho(numero))


## O save inteiro ({} se não existe ou não é um save válido).
static func ler(numero: int) -> Dictionary:
	if not existe(numero):
		return {}
	var dados = ArquivoJson.ler(caminho(numero))
	if not dados is Dictionary or not dados.get("jogo") is Dictionary:
		return {}
	return dados


## Para a tela de escolha: {"numero", "vazio", "nome", "dia", "dinheiro", "descricao", "salvo_em"}.
static func resumo(numero: int) -> Dictionary:
	var dados := ler(numero)
	if dados.is_empty():
		return {"numero": numero, "vazio": true}
	return {
		"numero": numero,
		"vazio": false,
		"nome": str(dados.jogo.get("nome", "")),
		"dia": int(dados.jogo.get("dia", 1)),
		"dinheiro": Jogo.reais(int(dados.jogo.get("centavos", 0))),
		"descricao": str(dados.get("descricao", "")),
		"salvo_em": str(dados.get("salvo_em", "")),
	}


## Grava o estado atual no arquivo em uso. `motivo`: um dos savepoints acima;
## `lugar`: onde o jogo continua ao carregar. Sem arquivo em uso, não grava.
static func salvar(motivo: String, lugar: String) -> bool:
	if Jogo.slot < 1 or Jogo.slot > QUANTOS:
		return false
	DirAccess.make_dir_recursive_absolute(PASTA)
	var dados := {
		"versao": VERSAO,
		"motivo": motivo,
		"lugar": lugar if lugar in LUGARES else "home",
		"descricao": _descricao(motivo, lugar),
		"salvo_em": Time.get_datetime_string_from_system(false, true),
		"jogo": Jogo.para_o_save(),
	}
	# Grava ao lado e troca: se o jogo fechar no meio, o save antigo continua inteiro.
	var temporario := caminho(Jogo.slot) + ".tmp"
	if not ArquivoJson.gravar(temporario, dados):
		return false
	return DirAccess.rename_absolute(temporario, caminho(Jogo.slot)) == OK


## Lê o save para o jogo (jogo.gd). Devolve o save ({} se não deu).
static func carregar(numero: int) -> Dictionary:
	var dados := ler(numero)
	if not dados.is_empty():
		Jogo.do_save(dados.jogo, numero)
	return dados


static func apagar(numero: int) -> void:
	if existe(numero):
		DirAccess.remove_absolute(caminho(numero))


static func _descricao(motivo: String, lugar: String) -> String:
	var hora := "manhã" if Jogo.momento == Jogo.MANHA else "noite"
	match motivo:
		"inicio_do_dia":
			return "Começo do dia %d" % Jogo.dia
		"antes_do_cliente":
			return "Antes de falar com %s" % Fases.dados(Jogo.fase_atual).cliente
		"fim_da_fase":
			var ultima := ""
			for id in Jogo.fases_feitas:
				if int(Jogo.fases_feitas[id].get("dia", 0)) == Jogo.dia:
					ultima = id
			return "Entregou: %s" % Fases.dados(ultima).nome if ultima != "" else "Fase entregue"
	if lugar == "quadro":
		return "Salvo no meio do diagrama: %s" % Fases.dados(Jogo.fase_atual).nome
	return "Salvo em casa, de %s" % hora
