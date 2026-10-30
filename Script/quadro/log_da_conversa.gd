extends Control
## Log da conversa (menu lateral "Conversa" do quadro): a conversa com o
## cliente, por escrito, para o jogador reler o pedido enquanto monta o diagrama.
##
## No jogo, mostra só o que o jogador viu, com as escolhas dele (Jogo.conversa,
## gravado por dialogos.gd e guardado no save). Pergunta que ele não fez não
## aparece: é parte do jogo.
##
## Com o quadro aberto direto no editor (sem arquivo de save, F6), não houve
## conversa: aí ler() mostra a timeline (.dtl) inteira, com todos os ramos, para
## quem está testando. Entram só as falas ("Quem: texto"); join, leave,
## [background], escolhas, comentários, condições etc. ficam de fora. O nome e a
## cor de quem fala vêm do personagem do Dialogic (Timeline/Character/*.dch).

## Começos de linha da timeline que não são fala.
const NAO_SAO_FALA := ["[", "#", "- ", "join ", "leave ", "update ", "label ", "jump ", "if ", "elif ", "else:", "set ", "do ", "return"]
const Jogo = preload("res://Script/jogo/jogo.gd")

const COR_DO_TEXTO := Color(0.16, 0.14, 0.1)
const SEM_CONVERSA := "[i]Este problema não tem conversa registrada.[/i]"
const AINDA_SEM_CONVERSA := "[i]A conversa aparece aqui quando o cliente começar a falar.[/i]"
const NO_EDITOR := "[i](Quadro aberto no editor: a conversa inteira do arquivo, com todos os ramos.)[/i]"


## Falas da timeline, em ordem: [{"quem", "cor", "texto"}]. "quem" vazio = narração.
static func ler(caminho: String) -> Array:
	var falas := []
	if not FileAccess.file_exists(caminho):
		return falas
	for linha in FileAccess.get_file_as_string(caminho).split("\n"):
		linha = linha.strip_edges()
		if linha == "" or linha == "<Empty Text Event>" or NAO_SAO_FALA.any(func(inicio): return linha.begins_with(inicio)):
			continue
		var fala := _separar(linha)
		if fala.texto != "":
			falas.append(fala)
	return falas


## "Quem (retrato): texto" -> fala. A primeira ":" sem barra antes separa os dois.
static func _separar(linha: String) -> Dictionary:
	var corte := -1
	for i in linha.length():
		if linha[i] == ":" and (i == 0 or linha[i - 1] != "\\"):
			corte = i
			break
	var quem := ""
	var texto := linha
	if corte > 0:
		quem = linha.left(corte).strip_edges()
		texto = linha.substr(corte + 1).strip_edges()
		if quem.contains("("):
			quem = quem.left(quem.find("(")).strip_edges()  # retrato
		quem = quem.trim_prefix("\"").trim_suffix("\"")
		if quem == "_":
			quem = ""
	var personagem := _personagem(quem)
	return {"quem": personagem.nome, "cor": personagem.cor, "texto": texto.replace("\\:", ":").replace("{nome}", Jogo.nome_nos_dialogos())}


## Nome e cor do personagem do Dialogic. Aceita o identificador antigo com pasta
## ("Character/Loja_de_roupa"); sem personagem, mostra o identificador.
static func _personagem(identificador: String) -> Dictionary:
	if identificador == "":
		return {"nome": "", "cor": COR_DO_TEXTO}
	for tentativa in [identificador, identificador.get_file()]:
		if DialogicResourceUtil.get_directory("dch").has(tentativa):
			var personagem := DialogicResourceUtil.get_character_resource(tentativa)
			if personagem:
				var nome: String = personagem.display_name if personagem.display_name != "" else tentativa
				nome = nome.replace("{nome}", Jogo.nome_nos_dialogos())
				# Cor clara some no papel: escurece.
				var cor: Color = personagem.color if personagem.color.get_luminance() < 0.6 else COR_DO_TEXTO
				return {"nome": nome, "cor": cor}
	return {"nome": identificador.get_file().replace("_", " "), "cor": COR_DO_TEXTO}


## Mostra a conversa do dia (Jogo.conversa). Sem arquivo de save em uso (o
## quadro aberto direto no editor), mostra a timeline `caminho` inteira.
func carregar(caminho: String) -> void:
	if not Jogo.conversa.is_empty():
		mostrar(Jogo.conversa)
	elif Jogo.slot == 0:
		mostrar(ler(caminho), NO_EDITOR)
	else:
		mostrar([], "", AINDA_SEM_CONVERSA)


## Escreve as falas no papel: [{"quem", "cor" (Color ou "#rrggbb"), "texto",
## "escolha" (opcional: o que o jogador escolheu, em itálico)}].
func mostrar(falas: Array, aviso := "", se_vazio := SEM_CONVERSA) -> void:
	var linhas := PackedStringArray()
	if aviso != "":
		linhas.append(aviso)
	var anterior := "\n"  # ninguém
	for fala in falas:
		var quem := str(fala.get("quem", ""))
		if quem != anterior:
			if not linhas.is_empty():
				linhas.append("")
			if quem != "":
				linhas.append("[b][color=#%s]%s[/color][/b]" % [_cor_no_papel(fala.get("cor")).to_html(false), quem])
			anterior = quem
		var texto := str(fala.get("texto", ""))
		linhas.append("[i]%s[/i]" % texto if fala.get("escolha", false) else texto)
	%TextoDaConversa.text = "\n".join(linhas) if not falas.is_empty() else se_vazio
	%TextoDaConversa.scroll_to_line(0)


## Cor clara some no papel: escurece.
static func _cor_no_papel(cor) -> Color:
	var c: Color = Color(cor) if cor is String else (cor if cor is Color else COR_DO_TEXTO)
	return c if c.get_luminance() < 0.6 else COR_DO_TEXTO
