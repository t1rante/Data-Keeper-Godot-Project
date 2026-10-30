extends RefCounted
## Conversas do Dialogic no jogo: o nome do jogador, as perguntas feitas ao
## cliente e o registro do que foi dito (o log da conversa no quadro).
##
## Um dia de trabalho é uma conversa só: o momento no escritório com o Bruno e a
## Ana (fases/<id>/escritorio.dtl, opcional) e, emendada nele, a conversa com o
## cliente (fases/<id>/conversa.dtl). Os dois textos viram uma timeline aqui;
## entre eles vai o sinal INICIO_DO_CLIENTE, e só o que vem depois dele entra no
## log (Jogo.conversa): as falas que o jogador viu e as escolhas que ele fez.
## Pergunta que ele não fez não aparece no log.
##
## Variáveis do Dialogic usadas nos .dtl (declaradas em project.godot,
## dialogic/variables):
##   {nome} ............... como o jogador quer ser chamado (Jogo.nome)
##   {perguntou.p1} a p8 .. false no começo de cada conversa; as escolhas de
##                          pergunta marcam true para sumir do menu
## Guia de escrita: fases/COMO_ESCREVER_CONVERSAS.md.

const Jogo = preload("res://Script/jogo/jogo.gd")
const Fases = preload("res://Script/jogo/fases.gd")
const Skins = preload("res://Script/jogo/skins.gd")

const INICIO_DO_CLIENTE := "inicio_da_conversa_com_o_cliente"
const PERGUNTAS := 8
const PERSONAGEM_DO_JOGADOR := "Player"

static var _ligado := false
static var _gravando := false


## Antes de qualquer conversa: o nome do jogador, as perguntas zeradas, o
## retrato com a skin e o registro ligado. Pode chamar quantas vezes quiser.
static func preparar() -> void:
	var dialogic = _dialogic()
	if dialogic == null:
		return
	dialogic.VAR.set_variable("nome", Jogo.nome_nos_dialogos())
	for i in range(1, PERGUNTAS + 1):
		dialogic.VAR.set_variable("perguntou.p%d" % i, false)
	Skins.acompanhar_retratos()
	if not _ligado:
		_ligado = true
		dialogic.Text.about_to_show_text.connect(func(info: Dictionary): _ouvir_fala(info))
		dialogic.Choices.choice_selected.connect(func(info: Dictionary): _ouvir_escolha(info))
		dialogic.signal_event.connect(func(argumento): _ouvir_sinal(argumento))
		dialogic.timeline_ended.connect(func(): _gravando = false)


## Começa o dia de trabalho da fase `id`: escritório e cliente, emendados.
static func comecar_dia(id: String) -> void:
	var dialogic = _dialogic()
	if dialogic == null:
		return
	preparar()
	dialogic.start(timeline_do_dia(Fases.dados(id)))


## A timeline do dia: escritorio.dtl (se houver), o sinal de início do cliente e
## conversa.dtl. Os rótulos (label) dos dois arquivos precisam ter nomes diferentes.
static func timeline_do_dia(fase: Dictionary) -> DialogicTimeline:
	var texto := ""
	if fase.escritorio != "":
		texto += FileAccess.get_file_as_string(fase.escritorio).strip_edges() + "\n"
	texto += "[signal arg=\"%s\"]\n" % INICIO_DO_CLIENTE
	texto += FileAccess.get_file_as_string(fase.conversa)
	var timeline := DialogicTimeline.new()
	timeline.from_text(texto)
	return timeline


static func _ouvir_sinal(argumento) -> void:
	if str(argumento) == INICIO_DO_CLIENTE:
		_gravando = true
		Jogo.conversa = []


static func _ouvir_fala(info: Dictionary) -> void:
	if not _gravando:
		return
	var texto := str(info.get("text", "")).strip_edges()
	if texto == "":
		return
	var quem := ""
	var cor := Color(0.16, 0.14, 0.1)
	var personagem = info.get("character")
	if personagem != null:
		quem = _dialogic().VAR.parse_variables(personagem.get_display_name_translated())
		cor = personagem.color
	var ultima: Dictionary = Jogo.conversa.back() if not Jogo.conversa.is_empty() else {}
	if info.get("append", false) and ultima.get("quem", null) == quem and not ultima.get("escolha", false):
		ultima.texto += " " + texto  # continuação da mesma fala ([n+])
		return
	Jogo.conversa.append({"quem": quem, "cor": cor.to_html(false), "texto": texto})


static func _ouvir_escolha(info: Dictionary) -> void:
	if not _gravando:
		return
	var cor := Color(0.08, 0.19, 0.95)
	var jogador = DialogicResourceUtil.get_character_resource(PERSONAGEM_DO_JOGADOR)
	if jogador != null:
		cor = jogador.color
	Jogo.conversa.append({
		"quem": Jogo.nome_nos_dialogos(),
		"cor": cor.to_html(false),
		"texto": _dialogic().VAR.parse_variables(str(info.get("text", ""))),
		"escolha": true,
	})


## Pela árvore, e não pelo nome do autoload: assim este script compila em
## qualquer contexto (os testes o carregam antes dos autoloads existirem).
static func _dialogic():
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Dialogic")
