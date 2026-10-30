extends Control
## Escolha de arquivo (Cenas/telas/escolha_de_arquivo.tscn), aberta pelo START
## da tela de título: os QUANTOS arquivos de save (saves.gd), cada um vazio
## (NOVO JOGO) ou com o resumo do jogo (CONTINUAR, APAGAR). APAGAR pede um
## segundo clique. Esc ou VOLTAR voltam ao título.
##
## NOVO JOGO pergunta como o protagonista quer ser chamado: o nome aparece em
## todos os diálogos do Dialogic (variável {nome}, ver dialogos.gd).

const Saves = preload("res://Script/jogo/saves.gd")
const Fluxo = preload("res://Script/jogo/fluxo.gd")
const Jogo = preload("res://Script/jogo/jogo.gd")
const Musica = preload("res://Script/jogo/musica.gd")

const FONTE := preload("res://assets/04b_19/04B_19__.TTF")
const COR_DO_CARTAO := Color(0.06666667, 0.02745098, 0.1764706, 1)
const COR_DO_TITULO := Color(0.4862745, 0.60784316, 1, 1)
const SEGUNDOS_PARA_CONFIRMAR := 3.0

var _confirmando := 0  # arquivo esperando o segundo clique em APAGAR
var _painel_do_nome: Control = null  # aberto pelo NOVO JOGO


func _ready() -> void:
	Musica.tocar(Musica.MENU)  # a música do menu continua (vinda do título, não recomeça)
	%Voltar.pressed.connect(voltar)
	montar()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _painel_do_nome:
			fechar_nome()
		else:
			voltar()


func _input(event: InputEvent) -> void:
	# A caixa de texto do nome fica com o Esc; ele fecha o painel mesmo assim.
	if _painel_do_nome and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fechar_nome()


func voltar() -> void:
	get_tree().change_scene_to_file(Fluxo.CENA_TITULO)


func montar() -> void:
	for cartao in %Arquivos.get_children():
		cartao.queue_free()
	for numero in range(1, Saves.QUANTOS + 1):
		%Arquivos.add_child(_cartao(Saves.resumo(numero)))


func jogar(numero: int) -> void:
	if Saves.existe(numero):
		if not Fluxo.continuar(numero):
			%Aviso.text = "O arquivo %d não pôde ser lido." % numero
	else:
		pedir_nome(numero)


## Painel do NOVO JOGO: o nome do protagonista nos diálogos.
func pedir_nome(numero: int) -> void:
	fechar_nome()
	var painel := Control.new()
	painel.name = "PainelDoNome"
	painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(painel)
	_painel_do_nome = painel

	var sombra := ColorRect.new()
	sombra.color = Color(0.03, 0.01, 0.1, 0.72)
	sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	painel.add_child(sombra)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	painel.add_child(centro)
	var cartao := _cartao_vazio()
	cartao.custom_minimum_size = Vector2(560, 0)
	cartao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	centro.add_child(cartao)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	cartao.add_child(coluna)
	coluna.add_child(_rotulo("ARQUIVO %d   NOVO JOGO" % numero, 24, COR_DO_TITULO, FONTE))
	coluna.add_child(_rotulo("Como você quer ser chamado nos diálogos?", 20, Color(0.91, 0.93, 1)))

	var campo := LineEdit.new()
	campo.name = "Nome"
	campo.max_length = Jogo.TAMANHO_DO_NOME
	campo.placeholder_text = "Seu nome"
	campo.add_theme_font_size_override("font_size", 26)
	campo.custom_minimum_size = Vector2(0, 52)
	campo.select_all_on_focus = true
	coluna.add_child(campo)
	var aviso := _rotulo("Até %d letras. Dá para usar acentos." % Jogo.TAMANHO_DO_NOME, 14, Color(0.85, 0.88, 1, 0.7))
	aviso.name = "AvisoDoNome"
	coluna.add_child(aviso)

	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 10)
	coluna.add_child(botoes)
	var comecar := _botao("COMECAR")
	comecar.name = "Comecar"
	botoes.add_child(comecar)
	var cancelar := _botao("VOLTAR")
	cancelar.name = "Cancelar"
	botoes.add_child(cancelar)

	comecar.pressed.connect(func(): confirmar_nome(numero, campo.text))
	campo.text_submitted.connect(func(texto: String): confirmar_nome(numero, texto))
	campo.text_changed.connect(func(_texto: String):
		aviso.text = "Até %d letras. Dá para usar acentos." % Jogo.TAMANHO_DO_NOME
		aviso.add_theme_color_override("font_color", Color(0.85, 0.88, 1, 0.7)))
	cancelar.pressed.connect(fechar_nome)
	campo.grab_focus()


func confirmar_nome(numero: int, texto: String) -> void:
	var nome := Jogo.limpar_nome(texto)
	if nome == "":
		var aviso: Label = _painel_do_nome.find_child("AvisoDoNome", true, false)
		aviso.text = "Escreva um nome para começar."
		aviso.add_theme_color_override("font_color", Color("ff74d7"))
		return
	Fluxo.novo_jogo(numero, nome)


func fechar_nome() -> void:
	if _painel_do_nome:
		_painel_do_nome.queue_free()
		_painel_do_nome = null


func apagar(numero: int) -> void:
	if _confirmando != numero:
		_confirmando = numero
		montar()
		get_tree().create_timer(SEGUNDOS_PARA_CONFIRMAR).timeout.connect(_desistir_de_apagar.bind(numero))
		return
	Saves.apagar(numero)
	_confirmando = 0
	%Aviso.text = "Arquivo %d apagado." % numero
	montar()


func _desistir_de_apagar(numero: int) -> void:
	if _confirmando == numero:
		_confirmando = 0
		montar()


func _cartao_vazio() -> PanelContainer:
	var cartao := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_DO_CARTAO
	estilo.set_corner_radius_all(12)
	estilo.set_content_margin_all(18)
	estilo.border_color = Color(0.3150174, 0.44430792, 1, 1)
	estilo.set_border_width_all(4)
	estilo.border_width_bottom = 8
	cartao.add_theme_stylebox_override("panel", estilo)
	return cartao


func _cartao(resumo: Dictionary) -> PanelContainer:
	var cartao := _cartao_vazio()
	cartao.custom_minimum_size = Vector2(500, 200)
	cartao.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	cartao.add_child(coluna)
	coluna.add_child(_rotulo("ARQUIVO %d" % resumo.numero, 24, COR_DO_TITULO, FONTE))
	if resumo.vazio:
		coluna.add_child(_rotulo("Vazio", 16, Color(0.85, 0.88, 1, 0.7)))
	else:
		if resumo.get("nome", "") != "":
			coluna.add_child(_rotulo(resumo.nome, 22, Color(0.98, 0.98, 1)))
		coluna.add_child(_rotulo("DIA %d   %s" % [resumo.dia, resumo.dinheiro], 20, Color("5cfff1"), FONTE))
		coluna.add_child(_rotulo(resumo.descricao, 15, Color(0.91, 0.93, 1)))
		coluna.add_child(_rotulo("Salvo em " + _data(resumo.salvo_em), 12, Color(0.85, 0.88, 1, 0.6)))
	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(espaco)

	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 10)
	coluna.add_child(botoes)
	var jogar_botao := _botao("NOVO JOGO" if resumo.vazio else "CONTINUAR")
	jogar_botao.pressed.connect(jogar.bind(resumo.numero))
	botoes.add_child(jogar_botao)
	if not resumo.vazio:
		var apagar_botao := _botao("CONFIRMAR?" if _confirmando == resumo.numero else "APAGAR")
		apagar_botao.add_theme_color_override("font_color", Color("ff74d7"))
		apagar_botao.tooltip_text = "Apagar este arquivo (clique de novo para confirmar)"
		apagar_botao.pressed.connect(apagar.bind(resumo.numero))
		botoes.add_child(apagar_botao)
	return cartao


func _botao(texto: String) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.focus_mode = Control.FOCUS_NONE
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	botao.add_theme_font_override("font", FONTE)
	botao.add_theme_font_size_override("font_size", 18)
	botao.add_theme_color_override("font_color", COR_DO_TITULO)
	botao.add_theme_color_override("font_hover_color", Color(0.95, 0.95, 0.95))
	for estado in [["normal", Color(0.16, 0.12, 0.36)], ["hover", Color(0.3150174, 0.44430792, 1)], ["pressed", Color(0.2, 0.3, 0.8)]]:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = estado[1]
		estilo.set_corner_radius_all(10)
		estilo.content_margin_left = 16
		estilo.content_margin_right = 16
		estilo.content_margin_top = 8
		estilo.content_margin_bottom = 6
		botao.add_theme_stylebox_override(estado[0], estilo)
	return botao


func _rotulo(texto: String, tamanho: int, cor: Color, fonte: Font = null) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	if fonte:
		rotulo.add_theme_font_override("font", fonte)
	return rotulo


## "2026-10-03 14:32:10" -> "03/10/2026 às 14:32".
static func _data(texto: String) -> String:
	var partes := texto.split(" ")
	if partes.size() < 2 or partes[0].count("-") != 2:
		return texto
	var data := partes[0].split("-")
	return "%s/%s/%s às %s" % [data[2], data[1], data[0], partes[1].left(5)]
