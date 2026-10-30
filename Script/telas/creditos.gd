extends CanvasLayer
## Créditos (Cenas/telas/creditos.tscn), abertos pelo CREDITOS da tela de título,
## por cima dela (a música do menu continua). VOLTAR ou Esc fecham.
##
## Para mudar os créditos, edite EQUIPE: cada grupo tem um título (na fonte
## 04B_19, então sem acento) e uma lista de [nome, função]. A Isha (a gata, voz
## dos miados) está no ELENCO. Nomes e funções usam
## a fonte padrão e podem ter acento.

signal fechou

const FONTE_DOS_TITULOS := preload("res://assets/04b_19/04B_19__.TTF")
const EQUIPE := [
	{"grupo": "ORIENTACAO", "cor": Color("ffd84d"), "pessoas": [
		["Leonardo Tortoro Pereira", "Orientador"],
	]},
	{"grupo": "PIBIC", "cor": Color("5cfff1"), "pessoas": [
		["Ana Esther dos Santos Loureiro", "Design e arte"],
		["Bruno Artur da Silva", "Programador e Level Design"],
		["Daniel Luiz de Castro da Silva", "Roteirista e Programador"],
	]},
	{"grupo": "IC", "cor": Color("ff74d7"), "pessoas": [
		["Nikolas Ribeiro Klasa", "Sound Design, Level Design, Roteirista e integração com LLMs"],
	]},
	{"grupo": "ELENCO", "cor": Color("8dff9e"), "pessoas": [
		["Isha", "Voice Actor"],
	]},
]
const COR_DO_GRUPO := Color(0.4862745, 0.60784316, 1, 1)
const COR_DO_NOME := Color(0.96, 0.96, 1, 1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	%Voltar.pressed.connect(fechar)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fechar()


func fechar() -> void:
	fechou.emit()
	queue_free()


## Todos os nomes, na ordem dos créditos (para os testes).
static func nomes() -> Array:
	var lista := []
	for grupo in EQUIPE:
		for pessoa in grupo.pessoas:
			lista.append(pessoa[0])
	return lista


func _montar() -> void:
	for filho in %Equipe.get_children():
		filho.queue_free()
	for grupo in EQUIPE:
		if %Equipe.get_child_count() > 0:  # respiro entre os grupos
			var espaco := Control.new()
			espaco.custom_minimum_size = Vector2(0, 6)
			%Equipe.add_child(espaco)
		var titulo := _rotulo(grupo.grupo, 18, COR_DO_GRUPO)
		titulo.add_theme_font_override("font", FONTE_DOS_TITULOS)
		%Equipe.add_child(titulo)
		var grade := GridContainer.new()
		grade.columns = 2
		grade.add_theme_constant_override("h_separation", 24)
		grade.add_theme_constant_override("v_separation", 4)
		%Equipe.add_child(grade)
		for pessoa in grupo.pessoas:
			var nome := _rotulo(pessoa[0], 19, COR_DO_NOME)
			nome.custom_minimum_size = Vector2(300, 0)
			grade.add_child(nome)
			var funcao := _rotulo(pessoa[1], 16, grupo.cor)
			funcao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			funcao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			grade.add_child(funcao)


func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return rotulo
